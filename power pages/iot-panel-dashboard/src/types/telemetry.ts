// Shared types for SignalR telemetry messages from iot-signalr-func

// GPIO mappings for the Raspberry Pi IoT panel
export const GPIO_CONFIG = {
  switches: [
    { index: 0, gpio: 5,  label: 'SW1' },
    { index: 1, gpio: 6,  label: 'SW2' },
    { index: 2, gpio: 13, label: 'SW3' },
    { index: 3, gpio: 19, label: 'SW4' },
  ],
  leds: [
    { index: 0, gpio: 18, label: 'GPIO 18', color: '#3B82F6', colorName: 'Blue'   },
    { index: 1, gpio: 24, label: 'GPIO 24', color: '#F59E0B', colorName: 'Orange' },
    { index: 2, gpio: 25, label: 'GPIO 25', color: '#22C55E', colorName: 'Green'  },
    { index: 3, gpio: 12, label: 'GPIO 12', color: '#EAB308', colorName: 'Yellow' },
  ],
} as const;

// Data payload inside SendTelemetryUpdate
export interface TelemetryData {
  switches: [number, number, number, number];      // 1=pressed, 0=open (SW1-SW4)
  actual_leds: [number, number, number, number];   // 1=on, 0=off (GPIO 18,24,25,12)
  expected_leds: [number, number, number, number];
  active_rule: string;
  mismatch: boolean;
  needs_help?: boolean;
}

// Full SignalR message for SendTelemetryUpdate
export interface TelemetryMessage {
  deviceId: string;
  timestamp: string;
  source: string;
  data: TelemetryData;
}

// SignalR message for TriggerAgentHelp
export interface AgentHelpMessage {
  deviceId: string;
  timestamp: string;
  active_rule: string;
  switches: [number, number, number, number];
  expected_leds: [number, number, number, number];
  actual_leds: [number, number, number, number];
  mismatch: boolean;
}

// Derived UI state from telemetry
export interface IoTState {
  deviceId: string;
  lastUpdated: string;
  switches: boolean[];     // true=pressed, index 0-3
  leds: boolean[];         // true=on, index 0-3
  expectedLeds: boolean[];
  mismatch: boolean;
  activeRule: string;
}

// Single event entry for History page
export interface TelemetryEvent {
  id: string;
  timestamp: string;
  deviceId: string;
  eventType: 'telemetry' | 'help-triggered' | 'connected' | 'disconnected';
  switches?: boolean[];
  leds?: boolean[];
  mismatch?: boolean;
  activeRule?: string;
  message?: string;
}

// Connection status
export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting' | 'error';
