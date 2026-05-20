import { useState, useEffect } from 'react';
import { SwitchIndicator } from '../components/SwitchIndicator';
import { LedIndicator } from '../components/LedIndicator';

/* ── Types ─────────────────────────────────── */
interface SwitchState {
  id: string;
  label: string;
  deviceId: string;
  on: boolean;
}

interface LedState {
  id: string;
  label: string;
  deviceId: string;
  on: boolean;
}

interface TelemetrySnapshot {
  switches: SwitchState[];
  leds: LedState[];
  lastUpdated: Date | null;
}

/*
 * Stub data — single RPi panel wired per raspberry-pi/docs/wiring/README.md
 * Replace with SignalR + Dataverse WebAPI (Issue #12)
 *
 * Switches (BCM, pull-up, LOW when pressed):
 *   SW1  GPIO  5  Physical 29
 *   SW2  GPIO  6  Physical 31
 *   SW3  GPIO 13  Physical 33
 *   SW4  GPIO 19  Physical 35
 *
 * LEDs (active HIGH, 330 Ω series):
 *   LED0  GPIO 18  Physical 12  blue    -> Power
 *   LED1  GPIO 24  Physical 18  orange  -> Status
 *   LED2  GPIO 25  Physical 22  green   -> Network
 *   LED3  GPIO 12  Physical 32  yellow  -> Warning
 */
const MOCK_SWITCHES: SwitchState[] = [
  { id: 'sw-1', label: 'SW1 — Main',     deviceId: 'raspberry-pi-iotpanel', on: true  },
  { id: 'sw-2', label: 'SW2 — Aux',      deviceId: 'raspberry-pi-iotpanel', on: false },
  { id: 'sw-3', label: 'SW3 — Run',      deviceId: 'raspberry-pi-iotpanel', on: true  },
  { id: 'sw-4', label: 'SW4 — Override', deviceId: 'raspberry-pi-iotpanel', on: false },
];

const MOCK_LEDS: LedState[] = [
  { id: 'led-0', label: 'Power',   deviceId: 'raspberry-pi-iotpanel', on: true  },
  { id: 'led-1', label: 'Status',  deviceId: 'raspberry-pi-iotpanel', on: true  },
  { id: 'led-2', label: 'Network', deviceId: 'raspberry-pi-iotpanel', on: true  },
  { id: 'led-3', label: 'Warning', deviceId: 'raspberry-pi-iotpanel', on: false },
];

/* ── Component ─────────────────────────────── */
export default function Dashboard() {
  const [snapshot, setSnapshot] = useState<TelemetrySnapshot>({
    switches: [],
    leds: [],
    lastUpdated: null,
  });
  const [loading, setLoading] = useState(true);

  // Stub: replace with real SignalR + Dataverse WebAPI call (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setSnapshot({ switches: MOCK_SWITCHES, leds: MOCK_LEDS, lastUpdated: new Date() });
      setLoading(false);
    }, 600);
    return () => clearTimeout(timer);
  }, []);

  const onCount = snapshot.switches.filter(s => s.on).length;
  const ledOnCount = snapshot.leds.filter(l => l.on).length;

  return (
    <div>
      {/* Header row */}
      <div
        className="animate-in"
        style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--sp-3)', marginBottom: 'var(--sp-6)' }}
      >
        <div>
          <h1 style={{ fontSize: '22px', marginBottom: '4px' }}>Live Dashboard</h1>
          <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>
            raspberry-pi-iotpanel · GPIO switches to LED logic (logic_map.json)
          </p>
        </div>
        {snapshot.lastUpdated && (
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)' }}>
            Updated {snapshot.lastUpdated.toLocaleTimeString()}
          </span>
        )}
      </div>

      {/* Summary cards */}
      <div
        style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 'var(--sp-4)', marginBottom: 'var(--sp-6)' }}
        aria-label="Telemetry summary"
      >
        {[
          { label: 'Switches Active', value: loading ? '-' : `${onCount} / ${snapshot.switches.length}`, accent: onCount > 0 },
          { label: 'LEDs On',         value: loading ? '-' : `${ledOnCount} / ${snapshot.leds.length}`,   accent: ledOnCount > 0 },
          { label: 'Device Online',   value: loading ? '-' : '1',                                          accent: true },
        ].map(({ label, value, accent }) => (
          <div
            key={label}
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${accent ? 'var(--color-accent)' : 'var(--color-border)'}`,
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--sp-4) var(--sp-5)',
              boxShadow: 'var(--shadow-card)',
            }}
          >
            <div style={{ fontFamily: 'var(--font-heading)', fontSize: '24px', fontWeight: 600, color: accent ? 'var(--color-accent)' : 'var(--color-text)' }}>
              {value}
            </div>
            <div style={{ fontSize: '13px', color: 'var(--color-text-muted)', marginTop: '4px' }}>{label}</div>
          </div>
        ))}
      </div>

      {/* Two-column grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-6)', alignItems: 'start' }}>

        {/* Switches */}
        <section aria-labelledby="switches-heading">
          <h2 id="switches-heading" style={{ fontSize: '14px', letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-4)' }}>
            Switches / GPIO 5 6 13 19
          </h2>
          {loading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-3)' }}>
              {[1,2,3,4].map(i => (
                <div key={i} className="shimmer" style={{ height: '62px', borderRadius: 'var(--radius-md)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--sp-3)' }}>
              {snapshot.switches.map(sw => (
                <div key={sw.id} className="animate-in">
                  <SwitchIndicator label={sw.label} on={sw.on} deviceId={sw.deviceId} />
                </div>
              ))}
            </div>
          )}
        </section>

        {/* LEDs */}
        <section aria-labelledby="leds-heading">
          <h2 id="leds-heading" style={{ fontSize: '14px', letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-4)' }}>
            LEDs / GPIO 18 24 25 12
          </h2>
          {loading ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--sp-3)' }}>
              {[1,2,3,4].map(i => (
                <div key={i} className="shimmer" style={{ height: '96px', borderRadius: 'var(--radius-md)' }} />
              ))}
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--sp-3)' }}>
              {snapshot.leds.map(led => (
                <div key={led.id} className="animate-in">
                  <LedIndicator label={led.label} on={led.on} deviceId={led.deviceId} />
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      {/* SignalR stub notice */}
      <p style={{ marginTop: 'var(--sp-7)', fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-border-strong)', textAlign: 'center' }}>
        Live updates via SignalR - Issue #12 · Dataverse: andy_iottelemetryevent
      </p>
    </div>
  );
}
