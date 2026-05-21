import { useEffect, useRef, useState, useCallback } from 'react';
import * as signalR from '@microsoft/signalr';
import { config } from '../config';
import type {
  IoTState,
  TelemetryMessage,
  AgentHelpMessage,
  TelemetryEvent,
  ConnectionStatus,
} from '../types/telemetry';

const MAX_EVENTS = 200; // ring buffer size for live event accumulation

export interface SignalRState {
  iotState: IoTState | null;
  connectionStatus: ConnectionStatus;
  needsHelp: boolean;
  events: TelemetryEvent[];        // accumulated live events (newest first)
  clearNeedsHelp: () => void;
}

function buildIoTState(msg: TelemetryMessage): IoTState {
  return {
    deviceId: msg.deviceId,
    lastUpdated: msg.timestamp,
    switches: msg.data.switches.map((v) => v === 1),
    leds: msg.data.actual_leds.map((v) => v === 1),
    expectedLeds: msg.data.expected_leds.map((v) => v === 1),
    mismatch: msg.data.mismatch,
    activeRule: msg.data.active_rule,
  };
}

function makeTelemetryEvent(msg: TelemetryMessage): TelemetryEvent {
  return {
    id: `${msg.deviceId}-${msg.timestamp}`,
    timestamp: msg.timestamp,
    deviceId: msg.deviceId,
    eventType: 'telemetry',
    switches: msg.data.switches.map((v) => v === 1),
    leds: msg.data.actual_leds.map((v) => v === 1),
    mismatch: msg.data.mismatch,
    activeRule: msg.data.active_rule,
  };
}

function makeHelpEvent(msg: AgentHelpMessage): TelemetryEvent {
  return {
    id: `help-${msg.deviceId}-${msg.timestamp}`,
    timestamp: msg.timestamp,
    deviceId: msg.deviceId,
    eventType: 'help-triggered',
    switches: msg.switches.map((v) => v === 1),
    leds: msg.actual_leds.map((v) => v === 1),
    mismatch: msg.mismatch,
    activeRule: msg.active_rule,
    message: `Agent help triggered — rule: ${msg.active_rule}`,
  };
}

export function useSignalR(): SignalRState {
  const [iotState, setIoTState] = useState<IoTState | null>(null);
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('disconnected');
  const [needsHelp, setNeedsHelp] = useState(false);
  const [events, setEvents] = useState<TelemetryEvent[]>([]);

  const connectionRef = useRef<signalR.HubConnection | null>(null);
  const isMountedRef = useRef(true);

  const clearNeedsHelp = useCallback(() => setNeedsHelp(false), []);

  const prependEvent = useCallback((evt: TelemetryEvent) => {
    setEvents((prev) => [evt, ...prev].slice(0, MAX_EVENTS));
  }, []);

  useEffect(() => {
    isMountedRef.current = true;

    if (!config.signalrNegotiateUrl || !config.signalrFuncKey) {
      console.warn('[useSignalR] Missing VITE_SIGNALR_NEGOTIATE_URL or VITE_SIGNALR_FUNC_KEY — skipping SignalR connection');
      setConnectionStatus('error');
      return;
    }

    let stopped = false;

    async function connect() {
      if (!isMountedRef.current) return;
      setConnectionStatus('connecting');

      // Step 1: negotiate — Azure SignalR Serverless requires explicit negotiate
      let negotiateInfo: { url: string; accessToken: string };
      try {
        const res = await fetch(
          `${config.signalrNegotiateUrl}/api/negotiate?code=${config.signalrFuncKey}`
        );
        if (!res.ok) throw new Error(`negotiate HTTP ${res.status}`);
        negotiateInfo = await res.json();
      } catch (err) {
        console.error('[useSignalR] negotiate failed:', err);
        if (isMountedRef.current) setConnectionStatus('error');
        return;
      }

      if (stopped || !isMountedRef.current) return;

      // Step 2: build connection with accessTokenFactory + skipNegotiation (Serverless requirement)
      const conn = new signalR.HubConnectionBuilder()
        .withUrl(negotiateInfo.url, {
          accessTokenFactory: () => negotiateInfo.accessToken,
          transport: signalR.HttpTransportType.WebSockets,
          skipNegotiation: true, // REQUIRED for Azure SignalR Serverless
        })
        .withAutomaticReconnect([0, 2000, 5000, 10000, 30000])
        .configureLogging(signalR.LogLevel.Warning)
        .build();

      conn.onreconnecting(() => {
        if (isMountedRef.current) setConnectionStatus('reconnecting');
      });
      conn.onreconnected(() => {
        if (isMountedRef.current) setConnectionStatus('connected');
      });
      conn.onclose(() => {
        if (isMountedRef.current) setConnectionStatus('disconnected');
      });

      // Message: telemetry update from IoT Hub via Logic App
      conn.on('SendTelemetryUpdate', (msg: TelemetryMessage) => {
        if (!isMountedRef.current) return;
        setIoTState(buildIoTState(msg));
        prependEvent(makeTelemetryEvent(msg));
        // Clear needsHelp if the mismatch has resolved
        if (!msg.data.mismatch) setNeedsHelp(false);
      });

      // Message: agent help required
      conn.on('TriggerAgentHelp', (msg: AgentHelpMessage) => {
        if (!isMountedRef.current) return;
        setNeedsHelp(true);
        prependEvent(makeHelpEvent(msg));
      });

      connectionRef.current = conn;

      try {
        await conn.start();
        if (isMountedRef.current) setConnectionStatus('connected');
      } catch (err) {
        console.error('[useSignalR] start failed:', err);
        if (isMountedRef.current) setConnectionStatus('error');
      }
    }

    connect();

    return () => {
      isMountedRef.current = false;
      stopped = true;
      connectionRef.current?.stop().catch(() => {});
      connectionRef.current = null;
    };
  }, []); // connect once on mount

  return { iotState, connectionStatus, needsHelp, events, clearNeedsHelp };
}
