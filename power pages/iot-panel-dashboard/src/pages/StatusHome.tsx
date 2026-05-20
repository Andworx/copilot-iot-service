import { useState, useEffect } from 'react';
import { AgentButton } from '../components/AgentButton';

/* ── Types ─────────────────────────────────── */
interface LedState {
  id: string;
  label: string;
  gpio: number;
  physicalPin: number;
  color: string;
  on: boolean;
  state: 'ok' | 'error' | 'warning' | 'off';
}

interface SwitchState {
  id: string;
  label: string;
  gpio: number;
  physicalPin: number;
  pressed: boolean;
}

interface PiConnection {
  connected: boolean;
  lastSeen: Date | null;
  ipAddress: string;
  uptime: string;
}

interface FaultMessage {
  id: string;
  message: string;
  timestamp: Date;
  severity: 'error' | 'warning';
}

/*
 * Stub data — raspberry-pi-iotpanel
 * Replace with SignalR + Dataverse WebAPI (Issue #12)
 *
 * LEDs:     GPIO 18 (Blue/Power), 24 (Orange/Status), 25 (Green/Network), 12 (Yellow/Error)
 * Switches: GPIO 5 (SW1), 6 (SW2), 13 (SW3), 19 (SW4) — pull-up, LOW when pressed
 */
const MOCK_LEDS: LedState[] = [
  { id: 'led-0', label: 'Power',   gpio: 18, physicalPin: 12, color: '#3B82F6', on: true,  state: 'ok'    },
  { id: 'led-1', label: 'Status',  gpio: 24, physicalPin: 18, color: '#F59E0B', on: true,  state: 'ok'    },
  { id: 'led-2', label: 'Network', gpio: 25, physicalPin: 22, color: '#22C55E', on: true,  state: 'ok'    },
  { id: 'led-3', label: 'Error',   gpio: 12, physicalPin: 32, color: '#EAB308', on: false, state: 'off'   },
];

const MOCK_SWITCHES: SwitchState[] = [
  { id: 'sw-1', label: 'SW1', gpio: 5,  physicalPin: 29, pressed: true  },
  { id: 'sw-2', label: 'SW2', gpio: 6,  physicalPin: 31, pressed: false },
  { id: 'sw-3', label: 'SW3', gpio: 13, physicalPin: 33, pressed: true  },
  { id: 'sw-4', label: 'SW4', gpio: 19, physicalPin: 35, pressed: false },
];

const MOCK_PI: PiConnection = {
  connected: true,
  lastSeen: new Date(Date.now() - 4000),
  ipAddress: '192.168.1.100',
  uptime: '2d 14h 07m',
};

const MOCK_FAULTS: FaultMessage[] = [];

/* ── Helpers ────────────────────────────────── */
const STATE_META: Record<LedState['state'], { color: string; label: string; glow?: string }> = {
  ok:      { color: 'var(--color-success)', label: 'ON',   glow: 'var(--shadow-glow-accent)' },
  error:   { color: 'var(--color-danger)',  label: 'ERR',  glow: 'var(--shadow-glow-danger)'  },
  warning: { color: 'var(--color-warning)', label: 'WARN', glow: 'var(--shadow-glow-amber)'   },
  off:     { color: 'var(--color-border-strong)', label: 'OFF' },
};

function formatAgo(date: Date): string {
  const s = Math.floor((Date.now() - date.getTime()) / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  return `${Math.floor(m / 60)}h ago`;
}

/* ── LED status card ────────────────────────── */
function LedStatusCard({ led }: { led: LedState }) {
  const meta = STATE_META[led.state];
  const dotColor = led.on ? led.color : 'var(--color-border-strong)';
  return (
    <div
      className="animate-in"
      style={{
        background: 'var(--color-surface)',
        border: `1px solid ${led.on ? led.color : 'var(--color-border-strong)'}`,
        borderRadius: 'var(--radius-md)',
        padding: 'var(--sp-3) var(--sp-4)',
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
        boxShadow: led.on && meta.glow ? meta.glow : 'var(--shadow-card)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <div
          aria-hidden="true"
          style={{
            width: '10px',
            height: '10px',
            borderRadius: '50%',
            background: dotColor,
            flexShrink: 0,
            animation: led.on
              ? (led.state === 'error' ? 'ledPulseError 1.2s ease-in-out infinite' : 'ledPulse 2.5s ease-in-out infinite')
              : 'none',
          }}
        />
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          color: meta.color,
        }}>
          {meta.label}
        </span>
      </div>
      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '13px', fontWeight: 600, color: 'var(--color-text-bright)', letterSpacing: '0.04em' }}>
        {led.label}
      </div>
      <div style={{ fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.06em', fontFamily: 'var(--font-heading)' }}>
        GPIO {led.gpio} · Pin {led.physicalPin}
      </div>
    </div>
  );
}

/* ── Switch status row ──────────────────────── */
function SwitchStatusRow({ sw }: { sw: SwitchState }) {
  return (
    <div
      className="animate-in"
      style={{
        background: 'var(--color-surface)',
        border: `1px solid ${sw.pressed ? 'var(--color-primary)' : 'var(--color-border-strong)'}`,
        borderRadius: 'var(--radius-sm)',
        padding: 'var(--sp-2) var(--sp-4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 'var(--sp-3)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
        <div style={{
          width: '8px',
          height: '8px',
          borderRadius: '1px',
          background: sw.pressed ? 'var(--color-primary)' : 'var(--color-border-strong)',
          flexShrink: 0,
        }} />
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', fontWeight: 600, letterSpacing: '0.06em', color: 'var(--color-text-bright)' }}>
          {sw.label}
        </span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-4)' }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          GPIO {sw.gpio}
        </span>
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: sw.pressed ? 'var(--color-primary)' : 'var(--color-text-muted)',
          fontWeight: sw.pressed ? 700 : 400,
        }}>
          {sw.pressed ? 'PRESSED' : 'OPEN'}
        </span>
      </div>
    </div>
  );
}

/* ── Page ───────────────────────────────────── */
export default function StatusHome() {
  const [leds, setLeds] = useState<LedState[]>([]);
  const [switches, setSwitches] = useState<SwitchState[]>([]);
  const [pi, setPi] = useState<PiConnection | null>(null);
  const [faults, setFaults] = useState<FaultMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  // Stub: replace with SignalR + Dataverse WebAPI (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setLeds(MOCK_LEDS);
      setSwitches(MOCK_SWITCHES);
      setPi(MOCK_PI);
      setFaults(MOCK_FAULTS);
      setLastUpdated(new Date());
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  const hasIssues = faults.length > 0 || leds.some(l => l.state === 'error') || (pi !== null && !pi.connected);

  const hasErrors   = leds.some(l => l.state === 'error') || (pi !== null && !pi.connected);
  const hasWarnings = leds.some(l => l.state === 'warning');
  const systemStatus = hasErrors ? 'error' : hasWarnings ? 'warning' : 'ok';
  const statusMeta   = STATE_META[systemStatus];

  return (
    <div>
      {/* Page header */}
      <div
        className="animate-in"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: 'var(--sp-3)',
          marginBottom: 'var(--sp-6)',
          paddingBottom: 'var(--sp-4)',
          borderBottom: '1px solid var(--color-border-strong)',
        }}
      >
        <div>
          <h1 style={{ fontSize: '18px', marginBottom: '4px' }}>System Status</h1>
          <p style={{ fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
            raspberry-pi-iotpanel · 4 LEDs · 4 GPIO switches
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-4)' }}>
          {!loading && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              padding: '6px 12px',
              background: 'var(--color-surface)',
              border: `1px solid ${statusMeta.color}`,
              borderRadius: 'var(--radius-sm)',
              boxShadow: statusMeta.glow ?? 'none',
            }}>
              <div style={{
                width: '8px', height: '8px', borderRadius: '50%',
                background: statusMeta.color,
                animation: systemStatus === 'ok' ? 'ledPulse 3s ease-in-out infinite'
                  : systemStatus === 'error' ? 'ledPulseError 1s ease-in-out infinite'
                  : 'none',
              }} />
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', letterSpacing: '0.08em', textTransform: 'uppercase', color: statusMeta.color }}>
                {systemStatus === 'ok' ? 'All Systems Nominal' : systemStatus === 'error' ? 'Faults Detected' : 'Warnings Active'}
              </span>
            </div>
          )}
          {lastUpdated && (
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
              {lastUpdated.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      {/* Pi connection status */}
      <section aria-label="Pi connection" style={{ marginBottom: 'var(--sp-5)' }}>
        <h2 style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)' }}>
          Device Connection
        </h2>
        {loading ? (
          <div className="shimmer" style={{ height: '60px', borderRadius: 'var(--radius-md)' }} />
        ) : (
          <div
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${pi?.connected ? 'var(--color-success)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              padding: 'var(--sp-3) var(--sp-5)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: 'var(--sp-4)',
              boxShadow: pi?.connected ? 'var(--shadow-glow-accent)' : 'var(--shadow-glow-danger)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{
                width: '10px', height: '10px', borderRadius: '50%',
                background: pi?.connected ? 'var(--color-success)' : 'var(--color-danger)',
                animation: pi?.connected ? 'ledPulse 3s ease-in-out infinite' : 'ledPulseError 1s ease-in-out infinite',
              }} />
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: '13px', fontWeight: 600, color: 'var(--color-text-bright)', letterSpacing: '0.04em' }}>
                raspberry-pi-iotpanel
              </span>
              <span style={{
                fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.08em', textTransform: 'uppercase',
                color: pi?.connected ? 'var(--color-success)' : 'var(--color-danger)',
              }}>
                {pi?.connected ? 'CONNECTED' : 'DISCONNECTED'}
              </span>
            </div>
            <div style={{ display: 'flex', gap: 'var(--sp-5)', flexWrap: 'wrap' }}>
              {[
                { k: 'IP',        v: pi?.ipAddress ?? '—' },
                { k: 'Uptime',    v: pi?.uptime ?? '—'    },
                { k: 'Last seen', v: pi?.lastSeen ? formatAgo(pi.lastSeen) : '—' },
              ].map(({ k, v }) => (
                <div key={k} style={{ textAlign: 'right' }}>
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>{k}</div>
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text)' }}>{v}</div>
                </div>
              ))}
            </div>
          </div>
        )}
      </section>

      {/* Two-column: LEDs + Switches */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-6)', marginBottom: 'var(--sp-6)', alignItems: 'start' }}>

        {/* LED Status Board */}
        <section aria-labelledby="led-board-heading">
          <h2 id="led-board-heading" style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)' }}>
            LED Output — Active HIGH, 330Ω
          </h2>
          {loading ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--sp-3)' }}>
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="shimmer" style={{ height: '80px', borderRadius: 'var(--radius-md)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--sp-3)' }}>
              {leds.map(led => <LedStatusCard key={led.id} led={led} />)}
            </div>
          )}
        </section>

        {/* Switch Status */}
        <section aria-labelledby="switch-board-heading">
          <h2 id="switch-board-heading" style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)' }}>
            Switch Input — Pull-up, LOW when pressed
          </h2>
          {loading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="shimmer" style={{ height: '44px', borderRadius: 'var(--radius-sm)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
              {switches.map(sw => <SwitchStatusRow key={sw.id} sw={sw} />)}
            </div>
          )}
        </section>
      </div>

      {/* Active Fault Log */}
      <section aria-labelledby="fault-log-heading">
        <h2 id="fault-log-heading" style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)' }}>
          Active Fault Log
        </h2>

        {loading ? (
          <div className="shimmer" style={{ height: '54px', borderRadius: 'var(--radius-md)' }} />
        ) : faults.length === 0 ? (
          <div
            className="animate-in"
            style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: 'var(--sp-4) var(--sp-5)',
              background: 'var(--color-surface)',
              border: '1px solid var(--color-success)',
              borderRadius: 'var(--radius-md)',
              boxShadow: 'var(--shadow-glow-accent)',
            }}
          >
            <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)', animation: 'ledPulse 3s ease-in-out infinite', flexShrink: 0 }} />
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-success)', letterSpacing: '0.06em' }}>
              No active faults — all systems nominal
            </span>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {faults.map(f => (
              <div
                key={f.id}
                className="animate-in"
                style={{
                  display: 'grid', gridTemplateColumns: '8px 1fr auto', alignItems: 'start', gap: '12px',
                  padding: 'var(--sp-3) var(--sp-4)',
                  background: 'var(--color-surface)',
                  border: `1px solid ${f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)'}`,
                  borderRadius: 'var(--radius-md)',
                  boxShadow: f.severity === 'error' ? 'var(--shadow-glow-danger)' : 'var(--shadow-glow-amber)',
                }}
              >
                <div style={{
                  width: '8px', height: '8px', borderRadius: '50%', marginTop: '3px',
                  background: f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)',
                  animation: f.severity === 'error' ? 'ledPulseError 1.2s ease-in-out infinite' : 'none',
                  flexShrink: 0,
                }} />
                <div>
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)', letterSpacing: '0.04em', marginBottom: '3px' }}>
                    {f.message}
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
                    raspberry-pi-iotpanel
                  </div>
                </div>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em', whiteSpace: 'nowrap', textAlign: 'right' }}>
                  {formatAgo(f.timestamp)}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <p style={{ marginTop: 'var(--sp-7)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
        Live data via SignalR — Issue #12 · Dataverse: andy_iottelemetryevent
      </p>

      <AgentButton hasIssues={hasIssues} />
    </div>
  );
}
