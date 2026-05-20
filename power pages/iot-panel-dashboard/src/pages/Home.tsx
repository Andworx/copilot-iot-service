import { useState, useEffect } from 'react';
import { SwitchIndicator } from '../components/SwitchIndicator';
import { LedIndicator } from '../components/LedIndicator';

/* ── Types ─────────────────────────────────── */
interface SwitchState {
  id: string;
  label: string;
  gpio: number;
  physicalPin: number;
  on: boolean;
}

interface LedState {
  id: string;
  label: string;
  gpio: number;
  physicalPin: number;
  ledColor: 'blue' | 'orange' | 'green' | 'yellow';
  on: boolean;
}

interface TelemetrySnapshot {
  switches: SwitchState[];
  leds: LedState[];
  activeRule: string | null;
  lastUpdated: Date | null;
}

/*
 * Hardware layout (raspberry-pi/panel_controller.py)
 * Switches: GPIO 5, 6, 13, 19  — BCM, pull-up, LOW when pressed
 * LEDs:     GPIO 18, 24, 25, 12 — BCM, active HIGH via 330Ω resistor
 * Device:   raspberry-pi-iotpanel
 */

/* ── Stub data (replace with SignalR + Dataverse WebAPI — Issue #12) ── */
const MOCK_SWITCHES: SwitchState[] = [
  { id: 'sw-1', label: 'SW1', gpio: 5,  physicalPin: 29, on: true  },
  { id: 'sw-2', label: 'SW2', gpio: 6,  physicalPin: 31, on: false },
  { id: 'sw-3', label: 'SW3', gpio: 13, physicalPin: 33, on: true  },
  { id: 'sw-4', label: 'SW4', gpio: 19, physicalPin: 35, on: false },
];

// SW1 + SW3 active → rule: all_lights_on → all 4 LEDs on
const MOCK_LEDS: LedState[] = [
  { id: 'led-0', label: 'Power',   gpio: 18, physicalPin: 12, ledColor: 'blue',   on: true  },
  { id: 'led-1', label: 'Status',  gpio: 24, physicalPin: 18, ledColor: 'orange', on: true  },
  { id: 'led-2', label: 'Network', gpio: 25, physicalPin: 22, ledColor: 'green',  on: true  },
  { id: 'led-3', label: 'Error',   gpio: 12, physicalPin: 32, ledColor: 'yellow', on: true  },
];

/* ── Component ─────────────────────────────── */
export default function Dashboard() {
  const [snapshot, setSnapshot] = useState<TelemetrySnapshot>({
    switches: [],
    leds: [],
    activeRule: null,
    lastUpdated: null,
  });
  const [loading, setLoading] = useState(true);

  // Stub: replace with real SignalR + Dataverse WebAPI call (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setSnapshot({
        switches: MOCK_SWITCHES,
        leds: MOCK_LEDS,
        activeRule: 'all_lights_on',
        lastUpdated: new Date(),
      });
      setLoading(false);
    }, 600);
    return () => clearTimeout(timer);
  }, []);

  const swOnCount  = snapshot.switches.filter(s => s.on).length;
  const ledOnCount = snapshot.leds.filter(l => l.on).length;

  return (
    <div>
      {/* Header */}
      <div
        className="animate-in"
        style={{
          display: 'flex',
          alignItems: 'baseline',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: 'var(--sp-3)',
          marginBottom: 'var(--sp-5)',
          paddingBottom: 'var(--sp-4)',
          borderBottom: '1px solid var(--color-border-strong)',
        }}
      >
        <div>
          <h1 style={{ fontSize: '18px', marginBottom: '4px' }}>Live Dashboard</h1>
          <p style={{ fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
            GPIO switch states and LED outputs — raspberry-pi-iotpanel
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-4)' }}>
          {snapshot.activeRule && (
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              color: 'var(--color-primary)',
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              border: '1px solid var(--color-primary)',
              padding: '3px 8px',
              borderRadius: 'var(--radius-sm)',
            }}>
              rule: {snapshot.activeRule}
            </span>
          )}
          {snapshot.lastUpdated && (
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              color: 'var(--color-text-muted)',
              letterSpacing: '0.04em',
            }}>
              {snapshot.lastUpdated.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      {/* Summary cards */}
      <div
        style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 'var(--sp-3)', marginBottom: 'var(--sp-6)' }}
        aria-label="Telemetry summary"
      >
        {[
          { label: 'Switches Active', value: loading ? '—' : `${swOnCount} / ${snapshot.switches.length}`, active: swOnCount > 0 },
          { label: 'LEDs On',         value: loading ? '—' : `${ledOnCount} / ${snapshot.leds.length}`,    active: ledOnCount > 0 },
          { label: 'Device Online',   value: loading ? '—' : '1',                                           active: true },
        ].map(({ label, value, active }) => (
          <div
            key={label}
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${active ? 'var(--color-accent)' : 'var(--color-border-strong)'}`,
              borderRadius: 'var(--radius-md)',
              padding: 'var(--sp-4) var(--sp-5)',
              boxShadow: active ? 'var(--shadow-glow-accent)' : 'var(--shadow-card)',
            }}
          >
            <div style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '22px',
              fontWeight: 700,
              color: active ? 'var(--color-accent)' : 'var(--color-text)',
              letterSpacing: '0.02em',
            }}>
              {value}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', marginTop: '4px', letterSpacing: '0.04em', textTransform: 'uppercase' }}>
              {label}
            </div>
          </div>
        ))}
      </div>

      {/* Two-column grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-6)', alignItems: 'start' }}>

        {/* Switches */}
        <section aria-labelledby="switches-heading">
          <h2 id="switches-heading" style={{
            fontSize: '10px',
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
            color: 'var(--color-text-muted)',
            marginBottom: 'var(--sp-3)',
          }}>
            Switches — Pull-up, LOW when pressed
          </h2>
          {loading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
              {[1,2,3,4].map(i => (
                <div key={i} className="shimmer" style={{ height: '58px', borderRadius: 'var(--radius-md)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-2)' }}>
              {snapshot.switches.map(sw => (
                <div key={sw.id} className="animate-in">
                  <SwitchIndicator label={sw.label} on={sw.on} gpio={sw.gpio} />
                </div>
              ))}
            </div>
          )}
        </section>

        {/* LEDs */}
        <section aria-labelledby="leds-heading">
          <h2 id="leds-heading" style={{
            fontSize: '10px',
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
            color: 'var(--color-text-muted)',
            marginBottom: 'var(--sp-3)',
          }}>
            LEDs — 330Ω, Active HIGH
          </h2>
          {loading ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--sp-2)' }}>
              {[1,2,3,4].map(i => (
                <div key={i} className="shimmer" style={{ height: '100px', borderRadius: 'var(--radius-md)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--sp-2)' }}>
              {snapshot.leds.map(led => (
                <div key={led.id} className="animate-in">
                  <LedIndicator
                    label={led.label}
                    on={led.on}
                    ledColor={led.ledColor}
                    gpio={led.gpio}
                  />
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      {/* SignalR stub notice */}
      <p style={{
        marginTop: 'var(--sp-7)',
        fontFamily: 'var(--font-heading)',
        fontSize: '10px',
        color: 'var(--color-border-strong)',
        textAlign: 'center',
        letterSpacing: '0.04em',
      }}>
        Live data via SignalR — Issue #12 · Device: raspberry-pi-iotpanel
      </p>
    </div>
  );
}
