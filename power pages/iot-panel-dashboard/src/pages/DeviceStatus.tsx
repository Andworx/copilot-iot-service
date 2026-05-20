import { useState, useEffect } from 'react';
import { StatusBadge, type Status } from '../components/StatusBadge';

/* ── Types ─────────────────────────────────── */
interface GpioPin {
  gpio: number;
  physicalPin: number;
  label: string;
  type: 'switch' | 'led';
  color?: string;
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
  pins: GpioPin[];
}

/*
 * raspberry-pi-iotpanel — single device in IoT Hub
 * Switches: GPIO 5/6/13/19 (BCM) — pull-up, LOW when pressed
 * LEDs:     GPIO 18/24/25/12 (BCM) — active HIGH via 330Ω resistor
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
  pins: [
    { gpio: 5,  physicalPin: 29, label: 'SW1',     type: 'switch' },
    { gpio: 6,  physicalPin: 31, label: 'SW2',     type: 'switch' },
    { gpio: 13, physicalPin: 33, label: 'SW3',     type: 'switch' },
    { gpio: 19, physicalPin: 35, label: 'SW4',     type: 'switch' },
    { gpio: 18, physicalPin: 12, label: 'Power',   type: 'led',    color: '#3B82F6' },
    { gpio: 24, physicalPin: 18, label: 'Status',  type: 'led',    color: '#F59E0B' },
    { gpio: 25, physicalPin: 22, label: 'Network', type: 'led',    color: '#22C55E' },
    { gpio: 12, physicalPin: 32, label: 'Error',   type: 'led',    color: '#EAB308' },
  ],
};

function formatLastSeen(d: Date) {
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

/* ── Component ─────────────────────────────── */
export default function DeviceStatus() {
  const [device, setDevice] = useState<DeviceInfo | null>(null);
  const [loading, setLoading] = useState(true);

  // Stub: replace with IoT Hub / Dataverse WebAPI call (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setDevice(MOCK_DEVICE);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div>
      {/* Header */}
      <div className="animate-in" style={{ marginBottom: 'var(--sp-6)' }}>
        <h1 style={{ fontSize: '22px', marginBottom: '4px' }}>Device Status</h1>
        <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>
          {loading ? 'Loading…' : device?.status === 'online' ? '1 device online' : '1 device offline'}
        </p>
      </div>

      {loading ? (
        <div className="shimmer" style={{ height: '340px', borderRadius: 'var(--radius-lg)' }} />
      ) : device ? (
        <article
          className="animate-in"
          aria-label={`Device: ${device.name}`}
          style={{
            background: 'var(--color-surface)',
            border: `1px solid ${device.status === 'online' ? 'var(--color-accent)' : 'var(--color-border)'}`,
            borderRadius: 'var(--radius-lg)',
            padding: 'var(--sp-5)',
            boxShadow: device.status === 'online' ? 'var(--shadow-glow-accent)' : 'var(--shadow-card)',
            maxWidth: '640px',
          }}
        >
          {/* Card header */}
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--sp-5)' }}>
            <div>
              <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '4px' }}>{device.name}</h2>
              <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-text-muted)' }}>
                {device.location}
              </div>
            </div>
            <StatusBadge status={device.status} />
          </div>

          {/* Meta */}
          <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--sp-4)', display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: 'var(--sp-5)' }}>
            {[
              { key: 'Device ID',  val: device.id },
              { key: 'IP Address', val: device.ipAddress },
              { key: 'Firmware',   val: `v${device.firmwareVersion}` },
              { key: 'Uptime',     val: device.uptime },
              { key: 'Last seen',  val: formatLastSeen(device.lastSeen) },
            ].map(({ key, val }) => (
              <div key={key} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--font-heading)', fontSize: '12px' }}>
                <span style={{ color: 'var(--color-text-muted)' }}>{key}</span>
                <span style={{ color: 'var(--color-text)', fontWeight: 500 }}>{val}</span>
              </div>
            ))}
          </div>

          {/* GPIO pin table */}
          <div>
            <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--color-text-muted)', marginBottom: 'var(--sp-3)' }}>
              GPIO Pinout
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-2)' }}>
              {device.pins.map(pin => (
                <div
                  key={pin.gpio}
                  style={{
                    background: 'var(--color-surface-2)',
                    border: '1px solid var(--color-border)',
                    borderRadius: 'var(--radius-sm)',
                    padding: '8px 12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                  }}
                >
                  {pin.type === 'led' && pin.color && (
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: pin.color, flexShrink: 0, boxShadow: `0 0 6px ${pin.color}` }} />
                  )}
                  {pin.type === 'switch' && (
                    <span style={{ width: '8px', height: '8px', borderRadius: '2px', background: 'var(--color-primary)', flexShrink: 0 }} />
                  )}
                  <div style={{ fontFamily: 'var(--font-heading)', fontSize: '12px' }}>
                    <span style={{ color: 'var(--color-text)', fontWeight: 600 }}>{pin.label}</span>
                    <span style={{ color: 'var(--color-text-muted)', marginLeft: '6px' }}>GPIO {pin.gpio}</span>
                    <span style={{ color: 'var(--color-border-strong)', marginLeft: '6px', fontSize: '10px' }}>Pin {pin.physicalPin}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </article>
      ) : null}
    </div>
  );
}
