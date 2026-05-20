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
 * Logical wiring (panel_controller.py + wiring/README.md):
 *   Switches: 3.3V (internal ~50kΩ PU) → GPIO IN → Switch → GND  (LOW = pressed)
 *   LEDs:     GPIO OUT → 330Ω → LED anode → cathode → GND         (HIGH = on)
 *
 * Pairs by row (index-matched for diagram):
 *   Row 0: SW1 GPIO 5  ↔ LED0 GPIO 18 (Blue)
 *   Row 1: SW2 GPIO 6  ↔ LED1 GPIO 24 (Orange)
 *   Row 2: SW3 GPIO 13 ↔ LED2 GPIO 25 (Green)
 *   Row 3: SW4 GPIO 19 ↔ LED3 GPIO 12 (Yellow)
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

const AMBER_RGB = '245, 158, 11';

const WIRE_KEYFRAMES = `
@keyframes wireFlow {
  0%   { left: -50%; }
  100% { left: 120%; }
}
`;

/* ── Switch box — left column ───────────────── */
function SwitchBox({ sw, row }: { sw: GpioSwitch; row: number }) {
  return (
    <div
      className="animate-in"
      style={{
        gridColumn: 1,
        gridRow: row + 1,
        background: 'var(--color-surface)',
        border: `1px solid ${sw.pressed ? `rgba(${AMBER_RGB}, 0.55)` : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-md)',
        padding: '6px 10px',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        boxShadow: sw.pressed ? `0 0 10px rgba(${AMBER_RGB}, 0.20)` : 'none',
        transition: 'all 0.2s',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '2px' }}>
        <div style={{
          width: '12px', height: '12px', borderRadius: '2px', flexShrink: 0,
          background: sw.pressed ? `rgba(${AMBER_RGB}, 1)` : 'var(--color-surface-2)',
          border: `1px solid ${sw.pressed ? `rgba(${AMBER_RGB}, 0.8)` : 'var(--color-border-strong)'}`,
          boxShadow: sw.pressed ? `0 0 6px rgba(${AMBER_RGB}, 0.55)` : 'none',
          transition: 'all 0.2s',
        }} />
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', fontWeight: 700, color: 'var(--color-text-bright)', letterSpacing: '0.06em' }}>
          {sw.label}
        </span>
      </div>
      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', color: 'var(--color-text-muted)', letterSpacing: '0.04em', marginBottom: '1px' }}>
        GPIO {sw.gpio} · Pin {sw.physicalPin}
      </div>
      <div style={{
        fontFamily: 'var(--font-heading)', fontSize: '9px', fontWeight: 700,
        letterSpacing: '0.10em', textTransform: 'uppercase',
        color: sw.pressed ? `rgba(${AMBER_RGB}, 1)` : 'var(--color-text-muted)',
      }}>
        {sw.pressed ? 'PRESSED' : 'OPEN'}
      </div>
      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '8px', color: 'var(--color-border-strong)', marginTop: '2px' }}>
        ⏚ GND
      </div>
    </div>
  );
}

/* ── Switch wire — col 2 (SW → Pi, rightward) ─ */
/* Circuit: Switch leg to GND, other leg to GPIO; ~50kΩ internal PU to 3.3V keeps HIGH until pressed */
function SwitchWire({ sw, row }: { sw: GpioSwitch; row: number }) {
  return (
    <div
      style={{
        gridColumn: 2,
        gridRow: row + 1,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        overflow: 'hidden',
      }}
    >
      {/* Base wire */}
      <div style={{
        position: 'absolute',
        left: 0, right: 0,
        height: '3px',
        top: '50%',
        transform: 'translateY(-50%)',
        background: sw.pressed ? `rgba(${AMBER_RGB}, 0.35)` : 'var(--color-border)',
        transition: 'background 0.3s',
      }} />
      {/* ~50kΩ pull-up resistor symbol (near Pi, right side) */}
      <div style={{
        position: 'absolute',
        right: '14px',
        top: '50%',
        transform: 'translateY(-50%)',
        width: '34px', height: '13px',
        background: 'var(--color-surface-2)',
        border: `1px solid ${sw.pressed ? `rgba(${AMBER_RGB}, 0.45)` : 'var(--color-border)'}`,
        borderRadius: '2px',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1,
      }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '7px', color: 'var(--color-text-muted)', whiteSpace: 'nowrap' }}>~50kΩ</span>
      </div>
      {/* Arrowhead pointing right (toward Pi) */}
      <div style={{
        position: 'absolute',
        right: 0,
        top: '50%',
        transform: 'translateY(-50%)',
        width: 0, height: 0,
        borderTop: '5px solid transparent',
        borderBottom: '5px solid transparent',
        borderLeft: `6px solid ${sw.pressed ? `rgba(${AMBER_RGB}, 0.55)` : 'var(--color-border)'}`,
      }} />
    </div>
  );
}

/* ── Pi center — col 3, spans all 4 rows ──────
   Shows matched IN GPIO (left edge) and OUT GPIO (right edge) per row
   Circuit: internal PU → GPIO IN | GPIO OUT → 330Ω → LED → GND               */
function PiCenter({ switches, leds }: { switches: GpioSwitch[]; leds: GpioLed[] }) {
  return (
    <div
      style={{
        gridColumn: 3,
        gridRow: '1 / 5',
        background: 'linear-gradient(170deg, #0d1a0d 0%, #0a1210 100%)',
        border: '2px solid var(--color-accent)',
        borderRadius: 'var(--radius-md)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'stretch',
        boxShadow: '0 0 18px rgba(22, 163, 74, 0.25), inset 0 1px 0 rgba(255,255,255,0.04)',
        overflow: 'hidden',
      }}
    >
      {/* Label */}
      <div style={{
        textAlign: 'center',
        fontFamily: 'var(--font-heading)',
        fontSize: '8px',
        letterSpacing: '0.14em',
        textTransform: 'uppercase',
        color: 'var(--color-accent)',
        padding: '5px 4px 4px',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        flexShrink: 0,
      }}>
        RPi GPIO
      </div>

      {/* 4 pin rows */}
      {[0, 1, 2, 3].map((i) => (
        <div
          key={i}
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 7px',
            borderBottom: i < 3 ? '1px solid rgba(255,255,255,0.05)' : 'none',
          }}
        >
          {/* Input pin connector dot + label */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <div style={{
              width: '6px', height: '6px', borderRadius: '50%',
              background: switches[i].pressed ? `rgba(${AMBER_RGB}, 1)` : 'rgba(255,255,255,0.15)',
              boxShadow: switches[i].pressed ? `0 0 5px rgba(${AMBER_RGB}, 0.7)` : 'none',
              transition: 'all 0.2s',
            }} />
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '9px',
              color: switches[i].pressed ? `rgba(${AMBER_RGB}, 1)` : 'var(--color-text-muted)',
              letterSpacing: '0.03em',
              transition: 'color 0.2s',
            }}>
              {switches[i].gpio}
            </span>
          </div>

          {/* IN | OUT separator */}
          <span style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '7px',
            color: 'rgba(255,255,255,0.20)',
            letterSpacing: '0.04em',
          }}>
            IN|OUT
          </span>

          {/* Output pin label + connector dot */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '9px',
              color: leds[i].on ? leds[i].color : 'var(--color-text-muted)',
              letterSpacing: '0.03em',
              transition: 'color 0.2s',
            }}>
              {leds[i].gpio}
            </span>
            <div style={{
              width: '6px', height: '6px', borderRadius: '50%',
              background: leds[i].on ? leds[i].color : 'rgba(255,255,255,0.15)',
              boxShadow: leds[i].on ? `0 0 5px ${leds[i].color}` : 'none',
              transition: 'all 0.2s',
            }} />
          </div>
        </div>
      ))}
    </div>
  );
}

/* ── LED wire — col 4 (Pi → LED, rightward with current animation) ──
   Circuit: GPIO OUT → 330Ω → LED anode; current flows right when LED is ON  */
function LedWire({ led, row, index }: { led: GpioLed; row: number; index: number }) {
  const rgb = hexToRgb(led.color);
  const delay = `${index * 0.20}s`;
  return (
    <div
      style={{
        gridColumn: 4,
        gridRow: row + 1,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        overflow: 'hidden',
      }}
    >
      {/* Arrowhead at Pi output (left edge) */}
      <div style={{
        position: 'absolute',
        left: 0,
        top: '50%',
        transform: 'translateY(-50%)',
        width: 0, height: 0,
        borderTop: '5px solid transparent',
        borderBottom: '5px solid transparent',
        borderLeft: `6px solid ${led.on ? `rgba(${rgb}, 0.55)` : 'var(--color-border)'}`,
      }} />
      {/* Base wire */}
      <div style={{
        position: 'absolute',
        left: 0, right: 0,
        height: '3px',
        top: '50%',
        transform: 'translateY(-50%)',
        background: led.on ? `rgba(${rgb}, 0.25)` : 'var(--color-border)',
        transition: 'background 0.4s',
      }} />
      {/* 330Ω resistor symbol (center of wire) */}
      <div style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        transform: 'translate(-50%, -50%)',
        width: '32px', height: '13px',
        background: 'var(--color-surface-2)',
        border: `1px solid ${led.on ? `rgba(${rgb}, 0.50)` : 'var(--color-border)'}`,
        borderRadius: '2px',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1,
        transition: 'border-color 0.3s',
      }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '7px', color: 'var(--color-text-muted)' }}>330Ω</span>
      </div>
      {/* Animated current pulse — flows left→right when LED is ON */}
      {led.on && (
        <div style={{
          position: 'absolute',
          top: '50%',
          transform: 'translateY(-50%)',
          height: '3px',
          width: '35%',
          background: `linear-gradient(90deg, transparent 0%, ${led.color} 50%, transparent 100%)`,
          animation: `wireFlow 1.4s linear ${delay} infinite`,
          boxShadow: `0 0 6px rgba(${rgb}, 0.85)`,
          zIndex: 2,
        }} />
      )}
    </div>
  );
}

/* ── LED box — right column ─────────────────── */
function LedBox({ led, row }: { led: GpioLed; row: number }) {
  const rgb = hexToRgb(led.color);
  return (
    <div
      className="animate-in"
      style={{
        gridColumn: 5,
        gridRow: row + 1,
        background: 'var(--color-surface)',
        border: `1px solid ${led.on ? `rgba(${rgb}, 0.55)` : 'var(--color-border)'}`,
        borderRadius: 'var(--radius-md)',
        padding: '6px 10px',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        boxShadow: led.on ? `0 0 14px rgba(${rgb}, 0.18)` : 'none',
        transition: 'all 0.3s',
      }}
    >
      {/* LED bulb circle */}
      <div style={{
        width: '32px', height: '32px', borderRadius: '50%', flexShrink: 0,
        background: led.on
          ? `radial-gradient(circle at 38% 35%, rgba(255,255,255,0.35) 0%, ${led.color} 50%)`
          : `rgba(${rgb}, 0.08)`,
        border: `2px solid ${led.on ? led.color : `rgba(${rgb}, 0.18)`}`,
        boxShadow: led.on ? `0 0 14px rgba(${rgb}, 0.65), 0 0 0 3px rgba(${rgb}, 0.15)` : 'none',
        transition: 'all 0.3s',
      }} />
      <div>
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '11px', fontWeight: 700, letterSpacing: '0.06em',
          color: led.on ? led.color : 'var(--color-text-muted)',
          marginBottom: '1px',
        }}>
          {led.label}
        </div>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          Pin {led.physicalPin}
        </div>
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '8px', color: 'var(--color-border-strong)', marginTop: '1px' }}>
          ⏚ GND
        </div>
      </div>
    </div>
  );
}

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
        <div className="shimmer" style={{ height: '480px', borderRadius: 'var(--radius-lg)' }} />
      ) : device ? (
        <>
          {/* ── Device info card ─────────────── */}
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

          {/* ── Wire diagram ──────────────────── */}
          <section aria-labelledby="wiring-heading">
            {/* Section header */}
            <div style={{ marginBottom: 'var(--sp-4)' }}>
              <h2
                id="wiring-heading"
                style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: '4px' }}
              >
                GPIO Wiring — Live View
              </h2>
              <p style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', letterSpacing: '0.04em' }}>
                Animated pulse = current flowing · Switch circuit: 3.3V → ~50kΩ PU → GPIO IN → SW → GND · LED circuit: GPIO OUT → 330Ω → LED → GND
              </p>
            </div>

            {/* Column header labels */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: '110px 1fr 120px 1fr 110px',
              marginBottom: '6px',
              columnGap: '6px',
            }}>
              <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)' }}>
                Switches (IN)
              </div>
              <div />
              <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-accent)', textAlign: 'center' }}>
                GPIO Header
              </div>
              <div />
              <div style={{ fontFamily: 'var(--font-heading)', fontSize: '9px', letterSpacing: '0.10em', textTransform: 'uppercase', color: 'var(--color-text-muted)', textAlign: 'right' }}>
                LEDs (OUT)
              </div>
            </div>

            {/* 5-column CSS grid — Pi spans all 4 rows */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: '110px 1fr 120px 1fr 110px',
                gridTemplateRows: 'repeat(4, 64px)',
                columnGap: '6px',
                rowGap: '6px',
              }}
            >
              {/* Pi center — spans rows 1–4 */}
              <PiCenter switches={device.switches} leds={device.leds} />

              {/* 4 rows: switch box + switch wire + LED wire + LED box */}
              {[0, 1, 2, 3].map((i) => (
                <div key={i} style={{ display: 'contents' }}>
                  <SwitchBox  sw={device.switches[i]} row={i} />
                  <SwitchWire sw={device.switches[i]} row={i} />
                  {/* col 3 = Pi (placed above) */}
                  <LedWire    led={device.leds[i]} row={i} index={i} />
                  <LedBox     led={device.leds[i]} row={i} />
                </div>
              ))}
            </div>
          </section>

          <p style={{ marginTop: 'var(--sp-6)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
            Live GPIO state via SignalR — Issue #12 · Source: panel_controller.py + wiring/README.md
          </p>
        </>
      ) : null}
    </div>
  );
}
