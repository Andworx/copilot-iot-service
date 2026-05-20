import { useState, useEffect } from 'react';
import { StatusBadge, type Status } from '../components/StatusBadge';

/* ── Types ─────────────────────────────────── */
interface GpioLed {
  gpio: number;
  physicalPin: number;
  color: string;
  on: boolean;
  label: string;
}

interface GpioSwitch {
  gpio: number;
  physicalPin: number;
  pressed: boolean;
  label: string;
}

interface DeviceInfo {
  id: string;
  name: string;
  location: string;
  status: Status;
  lastSeen: Date;
  uptime: string;
  firmwareVersion: string;
  ipAddress: string;
  leds: GpioLed[];
  switches: GpioSwitch[];
}

/*
 * raspberry-pi-iotpanel — hardware wiring (source of truth: panel_controller.py)
 * Switches: GPIO 5/6/13/19 — BCM, pull-up, LOW when pressed
 * LEDs:     GPIO 18/24/25/12 — BCM, active HIGH, 330Ω to GND
 */
const MOCK_DEVICE: DeviceInfo = {
  id: 'raspberry-pi-iotpanel',
  name: 'IoT Panel — Raspberry Pi',
  location: 'Lab Bench',
  status: 'online',
  lastSeen: new Date(Date.now() - 4000),
  uptime: '3d 14h 22m',
  firmwareVersion: '1.5.0',
  ipAddress: '192.168.1.100',
  leds: [
    { gpio: 18, physicalPin: 12, color: '#3B82F6', on: true,  label: 'GPIO 18' },
    { gpio: 24, physicalPin: 18, color: '#F59E0B', on: true,  label: 'GPIO 24' },
    { gpio: 25, physicalPin: 22, color: '#22C55E', on: true,  label: 'GPIO 25' },
    { gpio: 12, physicalPin: 32, color: '#EAB308', on: false, label: 'GPIO 12' },
  ],
  switches: [
    { gpio: 5,  physicalPin: 29, pressed: true,  label: 'SW1' },
    { gpio: 6,  physicalPin: 31, pressed: false, label: 'SW2' },
    { gpio: 13, physicalPin: 33, pressed: true,  label: 'SW3' },
    { gpio: 19, physicalPin: 35, pressed: false, label: 'SW4' },
  ],
};

function formatLastSeen(d: Date) {
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

function hexToRgb(hex: string): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `${r}, ${g}, ${b}`;
}

/* ── Wire Row ───────────────────────────────── */
function LedWireRow({ led, index }: { led: GpioLed; index: number }) {
  const rgb = hexToRgb(led.color);
  const delay = `${index * 0.18}s`;

  return (
    <div
      className="animate-in"
      style={{
        display: 'grid',
        gridTemplateColumns: '90px 1fr 80px',
        alignItems: 'center',
        gap: '0',
        height: '52px',
      }}
    >
      {/* Pi GPIO label */}
      <div style={{
        background: 'var(--color-surface)',
        border: `1px solid ${led.on ? `rgba(${rgb},0.45)` : 'var(--color-border)'}`,
        borderRight: 'none',
        borderRadius: 'var(--radius-sm) 0 0 var(--radius-sm)',
        padding: '6px 12px',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
      }}>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', fontWeight: 700, color: 'var(--color-text-bright)', letterSpacing: '0.06em' }}>
          {led.label}
        </div>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          Pin {led.physicalPin}
        </div>
      </div>

      {/* Wire with flowing current animation */}
      <div style={{ position: 'relative', height: '100%', display: 'flex', alignItems: 'center', overflow: 'hidden' }}>
        {/* Base wire line */}
        <div style={{
          position: 'absolute',
          inset: '0 0 0 0',
          top: '50%',
          transform: 'translateY(-50%)',
          height: '3px',
          background: led.on ? `rgba(${rgb}, 0.25)` : 'var(--color-border)',
          transition: 'background 0.4s',
        }} />

        {/* Animated current pulse — travels left to right */}
        {led.on && (
          <div
            style={{
              position: 'absolute',
              top: '50%',
              transform: 'translateY(-50%)',
              height: '3px',
              width: '40%',
              background: `linear-gradient(90deg, transparent 0%, ${led.color} 50%, transparent 100%)`,
              animation: `wireFlow 1.4s linear ${delay} infinite`,
              boxShadow: `0 0 6px rgba(${rgb}, 0.8)`,
            }}
          />
        )}

        {/* 330Ω resistor symbol (small rectangle mid-wire) */}
        <div style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          transform: 'translate(-50%, -50%)',
          width: '28px',
          height: '12px',
          background: 'var(--color-surface-2)',
          border: `1px solid ${led.on ? `rgba(${rgb}, 0.5)` : 'var(--color-border)'}`,
          borderRadius: '2px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1,
        }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: '7px', color: 'var(--color-text-muted)', letterSpacing: '0.02em' }}>330Ω</span>
        </div>
      </div>

      {/* LED bulb */}
      <div style={{
        background: 'var(--color-surface)',
        border: `1px solid ${led.on ? `rgba(${rgb}, 0.45)` : 'var(--color-border)'}`,
        borderLeft: 'none',
        borderRadius: '0 var(--radius-sm) var(--radius-sm) 0',
        padding: '6px 10px',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
      }}>
        {/* LED circle */}
        <div style={{
          width: '28px',
          height: '28px',
          borderRadius: '50%',
          flexShrink: 0,
          background: led.on
            ? `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.35) 0%, ${led.color} 50%)`
            : `rgba(${rgb}, 0.10)`,
          border: `2px solid ${led.on ? led.color : `rgba(${rgb}, 0.20)`}`,
          boxShadow: led.on ? `0 0 12px rgba(${rgb}, 0.65), 0 0 0 4px rgba(${rgb}, 0.15)` : 'none',
          transition: 'all 0.3s',
        }} />
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          fontWeight: 700,
          letterSpacing: '0.08em',
          color: led.on ? led.color : 'var(--color-text-muted)',
        }}>
          {led.on ? 'ON' : 'OFF'}
        </span>
      </div>
    </div>
  );
}

function SwitchWireRow({ sw, index }: { sw: GpioSwitch; index: number }) {
  const activeColor = '#F59E0B';
  const activeRgb = '245, 158, 11';

  return (
    <div
      className="animate-in"
      style={{
        display: 'grid',
        gridTemplateColumns: '90px 1fr 80px',
        alignItems: 'center',
        height: '52px',
      }}
    >
      {/* Pi GPIO label */}
      <div style={{
        background: 'var(--color-surface)',
        border: `1px solid ${sw.pressed ? `rgba(${activeRgb},0.45)` : 'var(--color-border)'}`,
        borderRight: 'none',
        borderRadius: 'var(--radius-sm) 0 0 var(--radius-sm)',
        padding: '6px 12px',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
      }}>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', fontWeight: 700, color: 'var(--color-text-bright)', letterSpacing: '0.06em' }}>
          GPIO {sw.gpio}
        </div>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          Pin {sw.physicalPin}
        </div>
      </div>

      {/* Wire */}
      <div style={{ position: 'relative', height: '100%', display: 'flex', alignItems: 'center', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute',
          inset: '0',
          top: '50%',
          transform: 'translateY(-50%)',
          height: '3px',
          background: sw.pressed ? `rgba(${activeRgb}, 0.35)` : 'var(--color-border)',
          transition: 'background 0.3s',
        }} />
        {/* Pull-up resistor (left side, near Pi) */}
        <div style={{
          position: 'absolute',
          left: '30%',
          top: '50%',
          transform: 'translate(-50%, -50%)',
          width: '28px',
          height: '12px',
          background: 'var(--color-surface-2)',
          border: `1px solid ${sw.pressed ? `rgba(${activeRgb}, 0.5)` : 'var(--color-border)'}`,
          borderRadius: '2px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1,
        }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: '7px', color: 'var(--color-text-muted)' }}>PU</span>
        </div>
        {index === 0 && (
          <span style={{
            position: 'absolute',
            top: '-14px',
            left: '30%',
            transform: 'translateX(-50%)',
            fontFamily: 'var(--font-heading)',
            fontSize: '8px',
            color: 'var(--color-text-muted)',
            letterSpacing: '0.04em',
            whiteSpace: 'nowrap',
          }}>
            Pull-up
          </span>
        )}
      </div>

      {/* Switch */}
      <div style={{
        background: 'var(--color-surface)',
        border: `1px solid ${sw.pressed ? `rgba(${activeRgb},0.45)` : 'var(--color-border)'}`,
        borderLeft: 'none',
        borderRadius: '0 var(--radius-sm) var(--radius-sm) 0',
        padding: '6px 10px',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
      }}>
        {/* Square switch indicator */}
        <div style={{
          width: '18px',
          height: '18px',
          borderRadius: '3px',
          background: sw.pressed ? activeColor : 'var(--color-surface-2)',
          border: `2px solid ${sw.pressed ? activeColor : 'var(--color-border-strong)'}`,
          boxShadow: sw.pressed ? `0 0 8px rgba(${activeRgb}, 0.55)` : 'none',
          flexShrink: 0,
          transition: 'all 0.2s',
        }} />
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          fontWeight: 700,
          letterSpacing: '0.08em',
          color: sw.pressed ? activeColor : 'var(--color-text-muted)',
        }}>
          {sw.label}
        </span>
      </div>
    </div>
  );
}

/* ── Keyframes injected once ───────────────── */
const WIRE_KEYFRAMES = `
@keyframes wireFlow {
  0%   { left: -40%; }
  100% { left: 110%; }
}
`;

/* ── Page ───────────────────────────────────── */
export default function DeviceStatus() {
  const [device, setDevice] = useState<DeviceInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDevice(MOCK_DEVICE);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div>
      <style>{WIRE_KEYFRAMES}</style>

      {/* Header */}
      <div className="animate-in" style={{ marginBottom: 'var(--sp-6)', paddingBottom: 'var(--sp-4)', borderBottom: '1px solid var(--color-border-strong)' }}>
        <h1 style={{ fontSize: '18px', marginBottom: '4px' }}>Devices</h1>
        <p style={{ color: 'var(--color-text-muted)', fontSize: '12px', fontFamily: 'var(--font-heading)', letterSpacing: '0.04em' }}>
          {loading ? 'Loading…' : 'IoT Hub · raspberry-pi-iotpanel'}
        </p>
      </div>

      {loading ? (
        <div className="shimmer" style={{ height: '420px', borderRadius: 'var(--radius-lg)' }} />
      ) : device ? (
        <>
          {/* ── Device card ──────────────────── */}
          <article
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${device.status === 'online' ? 'var(--color-accent)' : 'var(--color-border)'}`,
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--sp-5)',
              boxShadow: device.status === 'online' ? 'var(--shadow-glow-accent)' : 'var(--shadow-card)',
              marginBottom: 'var(--sp-6)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--sp-4)' }}>
              <div>
                <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '4px' }}>{device.name}</h2>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-text-muted)' }}>{device.location}</div>
              </div>
              <StatusBadge status={device.status} />
            </div>
            <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--sp-3)', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
              {[
                { key: 'Device ID',  val: device.id },
                { key: 'IP Address', val: device.ipAddress },
                { key: 'Firmware',   val: `v${device.firmwareVersion}` },
                { key: 'Uptime',     val: device.uptime },
                { key: 'Last seen',  val: formatLastSeen(device.lastSeen) },
              ].map(({ key, val }) => (
                <div key={key} style={{ fontFamily: 'var(--font-heading)', fontSize: '11px' }}>
                  <div style={{ color: 'var(--color-text-muted)', marginBottom: '2px' }}>{key}</div>
                  <div style={{ color: 'var(--color-text)', fontWeight: 600 }}>{val}</div>
                </div>
              ))}
            </div>
          </article>

          {/* ── Wire diagram ─────────────────── */}
          <section aria-labelledby="wiring-heading">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--sp-4)' }}>
              <h2
                id="wiring-heading"
                style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)' }}
              >
                GPIO Wiring — Live View
              </h2>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
                Animated = current flowing
              </span>
            </div>

            <div
              style={{
                background: 'var(--color-surface)',
                border: '1px solid var(--color-border-strong)',
                borderRadius: 'var(--radius-lg)',
                padding: 'var(--sp-5)',
                overflow: 'hidden',
              }}
            >
              {/* Column headers */}
              <div style={{ display: 'grid', gridTemplateColumns: '90px 1fr 80px', marginBottom: 'var(--sp-3)' }}>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)' }}>Pi GPIO</div>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)', textAlign: 'center' }}>Wire</div>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)', textAlign: 'right' }}>Component</div>
              </div>

              {/* LED wires */}
              <div style={{ marginBottom: 'var(--sp-2)' }}>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-2)', paddingLeft: '4px' }}>
                  Output — LEDs (Active HIGH)
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  {device.leds.map((led, i) => <LedWireRow key={led.gpio} led={led} index={i} />)}
                </div>
              </div>

              {/* Divider */}
              <div style={{ borderTop: '1px solid var(--color-border)', margin: 'var(--sp-4) 0' }} />

              {/* Switch wires */}
              <div>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-2)', paddingLeft: '4px' }}>
                  Input — Switches (Pull-up, LOW when pressed)
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  {device.switches.map((sw, i) => <SwitchWireRow key={sw.gpio} sw={sw} index={i} />)}
                </div>
              </div>
            </div>
          </section>

          <p style={{ marginTop: 'var(--sp-6)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
            Live GPIO state via SignalR — Issue #12 · panel_controller.py
          </p>
        </>
      ) : null}
    </div>
  );
}
