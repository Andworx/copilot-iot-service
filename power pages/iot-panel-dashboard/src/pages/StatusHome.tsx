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
 * LEDs:     GPIO 18 (Blue/Power), 24 (Orange/Status), 25 (Green/Network), 12 (Yellow/Error)
 * Switches: GPIO 5 (SW1), 6 (SW2), 13 (SW3), 19 (SW4) — pull-up, LOW when pressed
 */
const MOCK_LEDS: LedState[] = [
  { id: 'led-0', label: 'GPIO 18', gpio: 18, physicalPin: 12, color: '#3B82F6', on: true  },
  { id: 'led-1', label: 'GPIO 24', gpio: 24, physicalPin: 18, color: '#F59E0B', on: true  },
  { id: 'led-2', label: 'GPIO 25', gpio: 25, physicalPin: 22, color: '#22C55E', on: true  },
  { id: 'led-3', label: 'GPIO 12', gpio: 12, physicalPin: 32, color: '#EAB308', on: false },
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
function formatAgo(date: Date): string {
  const s = Math.floor((Date.now() - date.getTime()) / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  return `${Math.floor(m / 60)}h ago`;
}

function hexToRgb(hex: string): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `${r}, ${g}, ${b}`;
}

/* ── Big LED circle ─────────────────────────── */
function BigLed({ led }: { led: LedState }) {
  const rgb = hexToRgb(led.color);
  const dimColor = `rgba(${rgb}, 0.12)`;
  const brightColor = led.color;
  const glowColor = `rgba(${rgb}, 0.55)`;
  const ringColor = `rgba(${rgb}, 0.35)`;

  return (
    <div
      className="animate-in"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 'var(--sp-3)',
        padding: 'var(--sp-5) var(--sp-4)',
        background: 'var(--color-surface)',
        border: `1px solid ${led.on ? `rgba(${rgb}, 0.50)` : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-lg)',
        boxShadow: led.on ? `0 0 24px rgba(${rgb}, 0.18)` : 'var(--shadow-card)',
        transition: 'all 0.3s ease',
      }}
    >
      {/* Circle */}
      <div
        aria-label={`${led.label} LED — ${led.on ? 'ON' : 'OFF'}`}
        style={{
          width: '90px',
          height: '90px',
          borderRadius: '50%',
          background: led.on
            ? `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.35) 0%, ${brightColor} 45%, rgba(${rgb}, 0.75) 100%)`
            : `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.05) 0%, ${dimColor} 60%)`,
          boxShadow: led.on
            ? `0 0 0 6px ${ringColor}, 0 0 32px ${glowColor}, 0 0 60px rgba(${rgb}, 0.25), inset 0 2px 6px rgba(255,255,255,0.20)`
            : `0 0 0 4px rgba(255,255,255,0.04), inset 0 2px 4px rgba(0,0,0,0.40)`,
          border: `2px solid ${led.on ? brightColor : 'rgba(255,255,255,0.08)'}`,
          transition: 'all 0.3s ease',
          flexShrink: 0,
        }}
      />

      {/* Label */}
      <div style={{ textAlign: 'center' }}>
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '13px',
          fontWeight: 700,
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: led.on ? brightColor : 'var(--color-text-muted)',
        }}>
          {led.label}
        </div>
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          letterSpacing: '0.04em',
          color: 'var(--color-text-muted)',
          marginTop: '2px',
        }}>
          Pin {led.physicalPin}
        </div>
      </div>

      {/* ON / OFF badge */}
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '10px',
        fontWeight: 700,
        letterSpacing: '0.12em',
        textTransform: 'uppercase',
        padding: '3px 10px',
        borderRadius: 'var(--radius-sm)',
        background: led.on ? `rgba(${rgb}, 0.15)` : 'var(--color-surface-2)',
        color: led.on ? brightColor : 'var(--color-text-muted)',
        border: `1px solid ${led.on ? `rgba(${rgb}, 0.35)` : 'var(--color-border)'}`,
      }}>
        {led.on ? 'ON' : 'OFF'}
      </div>
    </div>
  );
}

/* ── Switch row ─────────────────────────────── */
function SwitchRow({ sw }: { sw: SwitchState }) {
  return (
    <div
      className="animate-in"
      style={{
        background: 'var(--color-surface)',
        border: `1px solid ${sw.pressed ? 'var(--color-primary)' : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-md)',
        padding: 'var(--sp-3) var(--sp-5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: sw.pressed ? 'var(--shadow-glow-accent)' : 'none',
        transition: 'all 0.2s ease',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
        {/* Square LED indicator */}
        <div style={{
          width: '14px',
          height: '14px',
          borderRadius: '3px',
          background: sw.pressed ? 'var(--color-primary)' : 'var(--color-border-strong)',
          boxShadow: sw.pressed ? '0 0 8px rgba(245,158,11,0.55)' : 'none',
          transition: 'all 0.2s ease',
          flexShrink: 0,
        }} />
        <div>
          <div style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '14px',
            fontWeight: 700,
            letterSpacing: '0.06em',
            color: sw.pressed ? 'var(--color-text-bright)' : 'var(--color-text)',
          }}>
            {sw.label}
          </div>
          <div style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '10px',
            color: 'var(--color-text-muted)',
            letterSpacing: '0.04em',
            marginTop: '2px',
          }}>
            GPIO {sw.gpio} · Pin {sw.physicalPin}
          </div>
        </div>
      </div>
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '11px',
        fontWeight: 700,
        letterSpacing: '0.12em',
        textTransform: 'uppercase',
        padding: '4px 12px',
        borderRadius: 'var(--radius-sm)',
        background: sw.pressed ? 'rgba(245,158,11,0.15)' : 'var(--color-surface-2)',
        color: sw.pressed ? 'var(--color-primary)' : 'var(--color-text-muted)',
        border: `1px solid ${sw.pressed ? 'rgba(245,158,11,0.40)' : 'var(--color-border)'}`,
      }}>
        {sw.pressed ? 'PRESSED' : 'OPEN'}
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

  const hasIssues = faults.length > 0 || (pi !== null && !pi.connected);

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
        {lastUpdated && (
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
            {lastUpdated.toLocaleTimeString()}
          </span>
        )}
      </div>

      {/* ── LED SECTION ─────────────────────────── */}
      <section aria-labelledby="led-heading" style={{ marginBottom: 'var(--sp-6)' }}>
        <h2
          id="led-heading"
          style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-4)', fontFamily: 'var(--font-heading)' }}
        >
          LED Output — Active HIGH, 330Ω
        </h2>
        {loading ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--sp-4)' }}>
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="shimmer" style={{ height: '200px', borderRadius: 'var(--radius-lg)' }} />
            ))}
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--sp-4)' }}>
            {leds.map(led => <BigLed key={led.id} led={led} />)}
          </div>
        )}
      </section>

      {/* ── SWITCH SECTION ──────────────────────── */}
      <section aria-labelledby="switch-heading" style={{ marginBottom: 'var(--sp-6)' }}>
        <h2
          id="switch-heading"
          style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-4)', fontFamily: 'var(--font-heading)' }}
        >
          Switch Input — Pull-up, LOW when pressed
        </h2>
        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="shimmer" style={{ height: '56px', borderRadius: 'var(--radius-md)' }} />
            ))}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {switches.map(sw => <SwitchRow key={sw.id} sw={sw} />)}
          </div>
        )}
      </section>

      {/* ── FAULT LOG ───────────────────────────── */}
      {!loading && faults.length > 0 && (
        <section aria-labelledby="fault-heading" style={{ marginBottom: 'var(--sp-6)' }}>
          <h2
            id="fault-heading"
            style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)', fontFamily: 'var(--font-heading)' }}
          >
            Active Fault Log
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {faults.map(f => (
              <div
                key={f.id}
                className="animate-in"
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  padding: 'var(--sp-3) var(--sp-4)',
                  background: 'var(--color-surface)',
                  border: `1px solid ${f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)'}`,
                  borderRadius: 'var(--radius-md)',
                }}
              >
                <div style={{
                  width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0,
                  background: f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)',
                  animation: f.severity === 'error' ? 'ledPulseError 1.2s ease-in-out infinite' : 'none',
                }} />
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: f.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)', flex: 1 }}>
                  {f.message}
                </span>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', whiteSpace: 'nowrap' }}>
                  {formatAgo(f.timestamp)}
                </span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── BOTTOM: Pi connection + system status ── */}
      <div style={{ borderTop: '1px solid var(--color-border-strong)', paddingTop: 'var(--sp-5)', marginTop: 'var(--sp-2)', display: 'flex', flexDirection: 'column', gap: 'var(--sp-3)' }}>

        {/* System nominal banner */}
        {!loading && (
          <div
            className="animate-in"
            style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: 'var(--sp-3) var(--sp-5)',
              background: 'var(--color-surface)',
              border: `1px solid ${(pi?.connected && faults.length === 0) ? 'var(--color-success)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              boxShadow: (pi?.connected && faults.length === 0) ? 'var(--shadow-glow-accent)' : 'var(--shadow-glow-danger)',
            }}
          >
            <div style={{
              width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0,
              background: (pi?.connected && faults.length === 0) ? 'var(--color-success)' : 'var(--color-danger)',
              animation: (pi?.connected && faults.length === 0) ? 'ledPulse 3s ease-in-out infinite' : 'ledPulseError 1s ease-in-out infinite',
            }} />
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', letterSpacing: '0.08em', textTransform: 'uppercase', color: (pi?.connected && faults.length === 0) ? 'var(--color-success)' : 'var(--color-danger)' }}>
              {(pi?.connected && faults.length === 0) ? 'All Systems Nominal' : 'Faults Detected'}
            </span>
          </div>
        )}

        {/* Pi connection row */}
        {!loading && pi && (
          <div
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${pi.connected ? 'rgba(34,197,94,0.30)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              padding: 'var(--sp-3) var(--sp-5)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: 'var(--sp-4)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{
                width: '8px', height: '8px', borderRadius: '50%',
                background: pi.connected ? 'var(--color-success)' : 'var(--color-danger)',
                animation: pi.connected ? 'ledPulse 3s ease-in-out infinite' : 'ledPulseError 1s ease-in-out infinite',
              }} />
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', fontWeight: 600, color: 'var(--color-text-bright)', letterSpacing: '0.04em' }}>
                raspberry-pi-iotpanel
              </span>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.08em', textTransform: 'uppercase', color: pi.connected ? 'var(--color-success)' : 'var(--color-danger)' }}>
                {pi.connected ? 'CONNECTED' : 'DISCONNECTED'}
              </span>
            </div>
            <div style={{ display: 'flex', gap: 'var(--sp-5)', flexWrap: 'wrap' }}>
              {[
                { k: 'IP',        v: pi.ipAddress },
                { k: 'Uptime',    v: pi.uptime    },
                { k: 'Last seen', v: pi.lastSeen ? formatAgo(pi.lastSeen) : '—' },
              ].map(({ k, v }) => (
                <div key={k} style={{ textAlign: 'right' }}>
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>{k}</div>
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text)' }}>{v}</div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      <p style={{ marginTop: 'var(--sp-6)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
        Live data via SignalR — Issue #12 · Dataverse: andy_iottelemetryevent
      </p>

      <AgentButton hasIssues={hasIssues} />
    </div>
  );
}
