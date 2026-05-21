import { useSignalRContext } from '../context/SignalRContext';
import { GPIO_CONFIG } from '../types/telemetry';
import { AgentButton } from '../components/AgentButton';

/* ── Helpers ────────────────────────────────── */
function hexToRgb(hex: string): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `${r}, ${g}, ${b}`;
}

/* ── Big LED circle ─────────────────────────── */
interface LedProps {
  label: string;
  gpio: number;
  color: string;
  on: boolean;
  /** True when the Pi is disconnected — state is unknown, render as off/dim */
  unknown?: boolean;
}

function BigLed({ label, gpio, color, on, unknown = false }: LedProps) {
  const rgb = hexToRgb(color);
  const dimColor = `rgba(${rgb}, 0.12)`;
  const glowColor = `rgba(${rgb}, 0.55)`;
  const ringColor = `rgba(${rgb}, 0.35)`;

  const ariaLabel = unknown
    ? `${label} LED — unknown (Pi disconnected)`
    : `${label} LED — ${on ? 'ON' : 'OFF'}`;

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
        border: `1px solid ${on && !unknown ? `rgba(${rgb}, 0.50)` : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-lg)',
        boxShadow: on && !unknown ? `0 0 24px rgba(${rgb}, 0.18)` : 'var(--shadow-card)',
        opacity: unknown ? 0.55 : 1,
        transition: 'all 0.3s ease',
      }}
    >
      {/* Circle */}
      <div
        aria-label={ariaLabel}
        style={{
          width: '90px',
          height: '90px',
          borderRadius: '50%',
          background: on && !unknown
            ? `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.35) 0%, ${color} 45%, rgba(${rgb}, 0.75) 100%)`
            : `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.05) 0%, ${dimColor} 60%)`,
          boxShadow: on && !unknown
            ? `0 0 0 6px ${ringColor}, 0 0 32px ${glowColor}, 0 0 60px rgba(${rgb}, 0.25), inset 0 2px 6px rgba(255,255,255,0.20)`
            : `0 0 0 4px rgba(255,255,255,0.04), inset 0 2px 4px rgba(0,0,0,0.40)`,
          border: `2px solid ${on && !unknown ? color : 'rgba(255,255,255,0.08)'}`,
          transition: 'all 0.3s ease',
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {unknown && (
          <span style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '22px',
            color: 'var(--color-text-muted)',
            userSelect: 'none',
          }}>?</span>
        )}
      </div>
      <div style={{ textAlign: 'center' }}>
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '13px',
          fontWeight: 700,
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: on && !unknown ? color : 'var(--color-text-muted)',
        }}>
          {label}
        </div>
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          letterSpacing: '0.04em',
          color: 'var(--color-text-muted)',
          marginTop: '2px',
        }}>
          GPIO {gpio}
        </div>
      </div>
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '10px',
        fontWeight: 700,
        letterSpacing: '0.12em',
        textTransform: 'uppercase',
        padding: '3px 10px',
        borderRadius: 'var(--radius-sm)',
        background: on && !unknown ? `rgba(${rgb}, 0.15)` : 'var(--color-surface-2)',
        color: on && !unknown ? color : 'var(--color-text-muted)',
        border: `1px solid ${on && !unknown ? `rgba(${rgb}, 0.35)` : 'var(--color-border)'}`,
      }}>
        {unknown ? '—' : on ? 'ON' : 'OFF'}
      </div>
    </div>
  );
}

/* ── Switch row ─────────────────────────────── */
interface SwitchProps {
  label: string;
  gpio: number;
  pressed: boolean;
  /** True when the Pi is disconnected — state is unknown */
  unknown?: boolean;
}

function SwitchRow({ label, gpio, pressed, unknown = false }: SwitchProps) {
  return (
    <div
      className="animate-in"
      aria-label={`${label}: ${unknown ? 'unknown (Pi disconnected)' : pressed ? 'pressed' : 'open'}`}
      style={{
        background: 'var(--color-surface)',
        border: `1px solid ${pressed && !unknown ? 'var(--color-primary)' : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-md)',
        padding: 'var(--sp-3) var(--sp-5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: pressed && !unknown ? 'var(--shadow-glow-accent)' : 'none',
        opacity: unknown ? 0.55 : 1,
        transition: 'all 0.2s ease',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
        <div style={{
          width: '14px',
          height: '14px',
          borderRadius: '3px',
          background: pressed && !unknown ? 'var(--color-primary)' : 'var(--color-border-strong)',
          boxShadow: pressed && !unknown ? '0 0 8px rgba(245,158,11,0.55)' : 'none',
          transition: 'all 0.2s ease',
          flexShrink: 0,
        }} />
        <div>
          <div style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '14px',
            fontWeight: 700,
            letterSpacing: '0.06em',
            color: pressed && !unknown ? 'var(--color-text-bright)' : 'var(--color-text)',
          }}>
            {label}
          </div>
          <div style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '10px',
            color: 'var(--color-text-muted)',
            letterSpacing: '0.04em',
            marginTop: '2px',
          }}>
            GPIO {gpio}
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
        background: pressed && !unknown ? 'rgba(245,158,11,0.15)' : 'var(--color-surface-2)',
        color: pressed && !unknown ? 'var(--color-primary)' : 'var(--color-text-muted)',
        border: `1px solid ${pressed && !unknown ? 'rgba(245,158,11,0.40)' : 'var(--color-border)'}`,
      }}>
        {unknown ? '—' : pressed ? 'PRESSED' : 'OPEN'}
      </div>
    </div>
  );
}

/* ── Connection status banner ───────────────── */
const STATUS_COLOR: Record<string, string> = {
  connected:    'var(--color-success)',
  connecting:   'var(--color-primary)',
  reconnecting: 'var(--color-warning)',
  disconnected: 'var(--color-text-muted)',
  error:        'var(--color-danger)',
};

const STATUS_TEXT: Record<string, string> = {
  connected:    'CONNECTED',
  connecting:   'CONNECTING…',
  reconnecting: 'RECONNECTING…',
  disconnected: 'DISCONNECTED',
  error:        'CONNECTION ERROR',
};

/* ── Page ───────────────────────────────────── */
export default function StatusHome() {
  const { iotState, connectionStatus } = useSignalRContext();

  const loading = iotState === null && (connectionStatus === 'connecting' || connectionStatus === 'disconnected');
  const hasData  = iotState !== null;

  // True when we have stale data but are no longer connected — state is unknown
  const isDisconnected = hasData && connectionStatus !== 'connected';

  const leds     = hasData ? GPIO_CONFIG.leds.map((cfg, i) => ({ ...cfg, on: isDisconnected ? false : (iotState!.leds[i] ?? false) })) : [];
  const switches = hasData ? GPIO_CONFIG.switches.map((cfg, i) => ({ ...cfg, pressed: iotState!.switches[i] ?? false })) : [];

  const lastUpdated = hasData ? new Date(iotState!.lastUpdated) : null;
  const allNominal  = hasData && !iotState!.mismatch && connectionStatus === 'connected';
  const allLedsOn   = hasData && iotState!.leds.every(Boolean);

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
            Updated {lastUpdated.toLocaleTimeString()}
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
            {leds.map(led => (
              <BigLed key={led.gpio} label={led.label} gpio={led.gpio} color={led.color} on={led.on} unknown={isDisconnected} />
            ))}
          </div>
        )}
      </section>

      {/* ── HELP FIX — hidden when all LEDs are on and system is nominal ── */}
      {!(allNominal && allLedsOn) && (
        <AgentButton iotState={iotState} hasMismatch={hasData && iotState!.mismatch} />
      )}

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
            {switches.map(sw => (
              <SwitchRow key={sw.gpio} label={sw.label} gpio={sw.gpio} pressed={sw.pressed} unknown={isDisconnected} />
            ))}
          </div>
        )}
      </section>

      {/* ── MISMATCH ALERT ──────────────────────── */}
      {hasData && iotState!.mismatch && (
        <section aria-labelledby="mismatch-heading" style={{ marginBottom: 'var(--sp-6)' }}>
          <h2
            id="mismatch-heading"
            style={{ fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-danger)', marginBottom: 'var(--sp-3)', fontFamily: 'var(--font-heading)' }}
          >
            Active Fault
          </h2>
          <div
            className="animate-in"
            style={{
              display: 'flex', alignItems: 'center', gap: '12px',
              padding: 'var(--sp-3) var(--sp-4)',
              background: 'var(--color-surface)',
              border: '1px solid var(--color-danger)',
              borderRadius: 'var(--radius-md)',
            }}
          >
            <div style={{
              width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0,
              background: 'var(--color-danger)',
              animation: 'ledPulseError 1.2s ease-in-out infinite',
            }} />
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-danger)', flex: 1 }}>
              LED mismatch detected — active rule: <strong>{iotState!.activeRule}</strong>
            </span>
          </div>
        </section>
      )}

      {/* ── BOTTOM: connection status ────────────── */}
      <div style={{ borderTop: '1px solid var(--color-border-strong)', paddingTop: 'var(--sp-5)', marginTop: 'var(--sp-2)', display: 'flex', flexDirection: 'column', gap: 'var(--sp-3)' }}>
        {/* Overall system status */}
        {!loading && (
          <div
            className="animate-in"
            style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: 'var(--sp-3) var(--sp-5)',
              background: 'var(--color-surface)',
              border: `1px solid ${allNominal ? 'var(--color-success)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              boxShadow: allNominal ? 'var(--shadow-glow-accent)' : 'var(--shadow-glow-danger)',
            }}
          >
            <div style={{
              width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0,
              background: allNominal ? 'var(--color-success)' : 'var(--color-danger)',
              animation: allNominal ? 'ledPulse 3s ease-in-out infinite' : 'ledPulseError 1s ease-in-out infinite',
            }} />
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', letterSpacing: '0.08em', textTransform: 'uppercase', color: allNominal ? 'var(--color-success)' : 'var(--color-danger)' }}>
              {allNominal ? 'All Systems Nominal' : 'Faults Detected'}
            </span>
          </div>
        )}

        {/* SignalR connection pill */}
        <div
          className="animate-in"
          style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            padding: 'var(--sp-3) var(--sp-5)',
            background: 'var(--color-surface)',
            border: `1px solid ${connectionStatus === 'connected' ? 'rgba(34,197,94,0.30)' : 'var(--color-border)'}`,
            borderRadius: 'var(--radius-md)',
            justifyContent: 'space-between',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <div style={{
              width: '8px', height: '8px', borderRadius: '50%',
              background: STATUS_COLOR[connectionStatus] ?? 'var(--color-text-muted)',
              animation: connectionStatus === 'connected' ? 'ledPulse 3s ease-in-out infinite'
                : connectionStatus === 'reconnecting' || connectionStatus === 'connecting' ? 'ledPulseError 0.8s ease-in-out infinite'
                : 'none',
            }} />
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', fontWeight: 600, color: 'var(--color-text-bright)', letterSpacing: '0.04em' }}>
              raspberry-pi-iotpanel
            </span>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.08em', textTransform: 'uppercase', color: STATUS_COLOR[connectionStatus] ?? 'var(--color-text-muted)' }}>
              {STATUS_TEXT[connectionStatus] ?? connectionStatus.toUpperCase()}
            </span>
          </div>
          {lastUpdated && (
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)' }}>
              {lastUpdated.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      <p style={{ marginTop: 'var(--sp-6)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
        Live data via Azure SignalR · Issue #12 · andy_iottelemetryevent
      </p>
    </div>
  );
}
