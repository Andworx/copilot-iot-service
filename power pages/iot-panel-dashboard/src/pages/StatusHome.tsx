import { useState, useEffect } from 'react';
import { AgentButton } from '../components/AgentButton';

/* ── Types ─────────────────────────────────── */
interface LedState {
  id: string;
  label: string;
  deviceId: string;
  /** 'ok' | 'error' | 'warning' | 'off' */
  state: 'ok' | 'error' | 'warning' | 'off';
}

interface ErrorMessage {
  id: string;
  deviceId: string;
  message: string;
  timestamp: Date;
  severity: 'error' | 'warning';
}

/* ── Stub data (replace with SignalR + Dataverse WebAPI — Issue #12) ── */
const MOCK_LEDS: LedState[] = [
  { id: 'led-01-pwr',  label: 'Power',   deviceId: 'RPi-Node-01', state: 'ok'      },
  { id: 'led-01-sts',  label: 'Status',  deviceId: 'RPi-Node-01', state: 'ok'      },
  { id: 'led-01-err',  label: 'Error',   deviceId: 'RPi-Node-01', state: 'off'     },
  { id: 'led-01-net',  label: 'Network', deviceId: 'RPi-Node-01', state: 'warning' },
  { id: 'led-02-pwr',  label: 'Power',   deviceId: 'RPi-Node-02', state: 'ok'      },
  { id: 'led-02-sts',  label: 'Status',  deviceId: 'RPi-Node-02', state: 'error'   },
  { id: 'led-02-err',  label: 'Error',   deviceId: 'RPi-Node-02', state: 'error'   },
  { id: 'led-02-net',  label: 'Network', deviceId: 'RPi-Node-02', state: 'ok'      },
];

const MOCK_ERRORS: ErrorMessage[] = [
  {
    id: 'err-1',
    deviceId: 'RPi-Node-02',
    message: 'Sensor read timeout — temperature probe unresponsive',
    timestamp: new Date(Date.now() - 3 * 60 * 1000),
    severity: 'error',
  },
  {
    id: 'err-2',
    deviceId: 'RPi-Node-02',
    message: 'Status LED driver fault detected',
    timestamp: new Date(Date.now() - 7 * 60 * 1000),
    severity: 'error',
  },
  {
    id: 'err-3',
    deviceId: 'RPi-Node-01',
    message: 'Network packet loss > 5% — connectivity degraded',
    timestamp: new Date(Date.now() - 14 * 60 * 1000),
    severity: 'warning',
  },
];

/* ── Helpers ────────────────────────────────── */
const STATE_META: Record<LedState['state'], { color: string; label: string; glow?: string }> = {
  ok:      { color: 'var(--color-success)', label: 'OK',   glow: 'var(--shadow-glow-accent)' },
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

/* ── Sub-components ─────────────────────────── */
function LedStatusCard({ led }: { led: LedState }) {
  const meta = STATE_META[led.state];
  const isActive = led.state !== 'off';
  return (
    <div
      className="animate-in"
      style={{
        background: 'var(--color-surface)',
        border: `1px solid ${isActive ? meta.color : 'var(--color-border-strong)'}`,
        borderRadius: 'var(--radius-md)',
        padding: 'var(--sp-3) var(--sp-4)',
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
        boxShadow: isActive && meta.glow ? meta.glow : 'var(--shadow-card)',
      }}
    >
      {/* LED dot */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <div
          aria-hidden="true"
          style={{
            width: '10px',
            height: '10px',
            borderRadius: '50%',
            background: meta.color,
            flexShrink: 0,
            animation: led.state === 'ok' ? 'ledPulse 2.5s ease-in-out infinite'
              : led.state === 'error' ? 'ledPulseError 1.2s ease-in-out infinite'
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

      {/* Label */}
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '12px',
        color: 'var(--color-text-bright)',
        letterSpacing: '0.04em',
      }}>
        {led.label}
      </div>

      {/* Device ID */}
      <div style={{
        fontSize: '10px',
        color: 'var(--color-text-muted)',
        letterSpacing: '0.04em',
      }}>
        {led.deviceId}
      </div>
    </div>
  );
}

/* ── Main Component ─────────────────────────── */
export default function StatusHome() {
  const [leds, setLeds] = useState<LedState[]>([]);
  const [errors, setErrors] = useState<ErrorMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  // Stub: replace with real SignalR + Dataverse WebAPI call (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setLeds(MOCK_LEDS);
      setErrors(MOCK_ERRORS);
      setLastUpdated(new Date());
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  // Derive issue state for AgentButton
  const hasIssues = errors.length > 0 || leds.some(l => l.state === 'error');

  // Group LEDs by device
  const devices = [...new Set(leds.map(l => l.deviceId))];

  // Overall system status
  const hasErrors   = leds.some(l => l.state === 'error');
  const hasWarnings = leds.some(l => l.state === 'warning');
  const systemStatus = hasErrors ? 'error' : hasWarnings ? 'warning' : 'ok';
  const statusMeta = STATE_META[systemStatus];

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
            IoT node LED indicators and active fault log
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-4)' }}>
          {/* Overall status badge */}
          {!loading && (
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
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
              <span style={{
                fontFamily: 'var(--font-heading)',
                fontSize: '11px',
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
                color: statusMeta.color,
              }}>
                {systemStatus === 'ok' ? 'All Systems Nominal'
                  : systemStatus === 'error' ? 'Faults Detected'
                  : 'Warnings Active'}
              </span>
            </div>
          )}
          {lastUpdated && (
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              color: 'var(--color-text-muted)',
              letterSpacing: '0.04em',
            }}>
              {lastUpdated.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      {/* LED Status Board — grouped by device */}
      <section aria-labelledby="led-board-heading" style={{ marginBottom: 'var(--sp-6)' }}>
        <h2
          id="led-board-heading"
          style={{
            fontSize: '11px',
            letterSpacing: '0.12em',
            color: 'var(--color-text-muted)',
            marginBottom: 'var(--sp-4)',
          }}
        >
          LED Status Board
        </h2>

        {loading ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 'var(--sp-3)' }}>
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="shimmer" style={{ height: '80px', borderRadius: 'var(--radius-md)' }} />
            ))}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-5)' }}>
            {devices.map(deviceId => (
              <div key={deviceId}>
                {/* Device node label */}
                <div style={{
                  fontFamily: 'var(--font-heading)',
                  fontSize: '10px',
                  letterSpacing: '0.12em',
                  textTransform: 'uppercase',
                  color: 'var(--color-text-muted)',
                  marginBottom: 'var(--sp-3)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                }}>
                  <span style={{
                    display: 'inline-block',
                    width: '4px', height: '4px',
                    borderRadius: '50%',
                    background: 'var(--color-text-muted)',
                  }} />
                  {deviceId}
                </div>

                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))',
                  gap: 'var(--sp-3)',
                }}>
                  {leds.filter(l => l.deviceId === deviceId).map(led => (
                    <LedStatusCard key={led.id} led={led} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Error / Warning Log */}
      <section aria-labelledby="error-log-heading">
        <h2
          id="error-log-heading"
          style={{
            fontSize: '11px',
            letterSpacing: '0.12em',
            color: 'var(--color-text-muted)',
            marginBottom: 'var(--sp-4)',
          }}
        >
          Active Fault Log
        </h2>

        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {[1, 2].map(i => (
              <div key={i} className="shimmer" style={{ height: '54px', borderRadius: 'var(--radius-md)' }} />
            ))}
          </div>
        ) : errors.length === 0 ? (
          <div
            className="animate-in"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: 'var(--sp-4) var(--sp-5)',
              background: 'var(--color-surface)',
              border: '1px solid var(--color-success)',
              borderRadius: 'var(--radius-md)',
              boxShadow: 'var(--shadow-glow-accent)',
            }}
          >
            <div style={{
              width: '8px', height: '8px', borderRadius: '50%',
              background: 'var(--color-success)',
              animation: 'ledPulse 3s ease-in-out infinite',
              flexShrink: 0,
            }} />
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '12px',
              color: 'var(--color-success)',
              letterSpacing: '0.06em',
            }}>
              No active faults — all systems nominal
            </span>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
            {errors.map(err => (
              <div
                key={err.id}
                className="animate-in"
                style={{
                  display: 'grid',
                  gridTemplateColumns: '8px 1fr auto',
                  alignItems: 'start',
                  gap: '12px',
                  padding: 'var(--sp-3) var(--sp-4)',
                  background: 'var(--color-surface)',
                  border: `1px solid ${err.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)'}`,
                  borderRadius: 'var(--radius-md)',
                  boxShadow: err.severity === 'error' ? 'var(--shadow-glow-danger)' : 'var(--shadow-glow-amber)',
                }}
              >
                {/* Severity dot */}
                <div style={{
                  width: '8px', height: '8px', borderRadius: '50%', marginTop: '3px',
                  background: err.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)',
                  animation: err.severity === 'error' ? 'ledPulseError 1.2s ease-in-out infinite' : 'none',
                  flexShrink: 0,
                }} />

                {/* Message */}
                <div>
                  <div style={{
                    fontFamily: 'var(--font-heading)',
                    fontSize: '12px',
                    color: err.severity === 'error' ? 'var(--color-danger)' : 'var(--color-warning)',
                    letterSpacing: '0.04em',
                    marginBottom: '3px',
                  }}>
                    {err.message}
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
                    {err.deviceId}
                  </div>
                </div>

                {/* Timestamp */}
                <div style={{
                  fontFamily: 'var(--font-heading)',
                  fontSize: '10px',
                  color: 'var(--color-text-muted)',
                  letterSpacing: '0.04em',
                  whiteSpace: 'nowrap',
                  textAlign: 'right',
                }}>
                  {formatAgo(err.timestamp)}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Stub notice */}
      <p style={{
        marginTop: 'var(--sp-7)',
        fontFamily: 'var(--font-heading)',
        fontSize: '10px',
        color: 'var(--color-border-strong)',
        textAlign: 'center',
        letterSpacing: '0.04em',
      }}>
        Live data via SignalR — Issue #12 · Dataverse: andy_iottelemetryevent
      </p>

      {/* Conditional agent button — renders only when issues exist */}
      <AgentButton hasIssues={hasIssues} />
    </div>
  );
}
