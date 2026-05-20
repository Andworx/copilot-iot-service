import React, { useState, useEffect } from 'react';
import { StatusBadge, type Status } from '../components/StatusBadge';

/* ── Types ─────────────────────────────────── */
interface DeviceInfo {
  id: string;
  name: string;
  location: string;
  status: Status;
  lastSeen: Date;
  switchCount: number;
  ledCount: number;
  firmwareVersion: string;
  ipAddress: string;
}

/* ── Stub data (replace with Dataverse WebAPI) ─── */
const MOCK_DEVICES: DeviceInfo[] = [
  {
    id: 'RPi-Node-01',
    name: 'Raspberry Pi Node 01',
    location: 'Server Room A',
    status: 'online',
    lastSeen: new Date(Date.now() - 12000),
    switchCount: 2,
    ledCount: 3,
    firmwareVersion: '1.4.2',
    ipAddress: '192.168.1.101',
  },
  {
    id: 'RPi-Node-02',
    name: 'Raspberry Pi Node 02',
    location: 'Lab B',
    status: 'offline',
    lastSeen: new Date(Date.now() - 18 * 60 * 1000),
    switchCount: 2,
    ledCount: 3,
    firmwareVersion: '1.3.9',
    ipAddress: '192.168.1.102',
  },
];

function formatLastSeen(d: Date) {
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

/* ── Component ─────────────────────────────── */
export default function DeviceStatus() {
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const [loading, setLoading] = useState(true);

  // Stub: replace with Dataverse WebAPI call
  useEffect(() => {
    const timer = setTimeout(() => {
      setDevices(MOCK_DEVICES);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  const onlineCount = devices.filter(d => d.status === 'online').length;

  return (
    <div>
      {/* Header */}
      <div className="animate-in" style={{ marginBottom: 'var(--sp-6)' }}>
        <h1 style={{ fontSize: '22px', marginBottom: '4px' }}>Device Status</h1>
        <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>
          {loading ? 'Loading…' : `${onlineCount} of ${devices.length} nodes online`}
        </p>
      </div>

      {/* Device cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 'var(--sp-5)' }}>
        {loading
          ? [1, 2].map(i => (
              <div key={i} className="shimmer" style={{ height: '220px', borderRadius: 'var(--radius-lg)' }} />
            ))
          : devices.map(device => (
              <article
                key={device.id}
                className="animate-in"
                aria-label={`Device: ${device.name}`}
                style={{
                  background: 'var(--color-surface)',
                  border: `1px solid ${device.status === 'online' ? 'var(--color-accent)' : 'var(--color-border)'}`,
                  borderRadius: 'var(--radius-lg)',
                  padding: 'var(--sp-5)',
                  boxShadow: 'var(--shadow-card)',
                  transition: 'box-shadow 0.2s',
                }}
                onMouseEnter={e => (e.currentTarget.style.boxShadow = 'var(--shadow-card-hover)')}
                onMouseLeave={e => (e.currentTarget.style.boxShadow = 'var(--shadow-card)')}
              >
                {/* Card header */}
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--sp-4)' }}>
                  <div>
                    <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '2px' }}>{device.name}</h2>
                    <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-text-muted)' }}>
                      {device.location}
                    </div>
                  </div>
                  <StatusBadge status={device.status} />
                </div>

                {/* Stat row */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--sp-3)', marginBottom: 'var(--sp-4)' }}>
                  {[
                    { label: 'Switches', value: String(device.switchCount) },
                    { label: 'LEDs', value: String(device.ledCount) },
                  ].map(({ label, value }) => (
                    <div
                      key={label}
                      style={{ background: 'var(--color-surface-2)', borderRadius: 'var(--radius-sm)', padding: '10px 12px' }}
                    >
                      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '20px', fontWeight: 600, color: 'var(--color-text)' }}>
                        {value}
                      </div>
                      <div style={{ fontSize: '12px', color: 'var(--color-text-muted)' }}>{label}</div>
                    </div>
                  ))}
                </div>

                {/* Meta */}
                <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--sp-3)', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  {[
                    { key: 'Device ID', val: device.id },
                    { key: 'IP', val: device.ipAddress },
                    { key: 'Firmware', val: `v${device.firmwareVersion}` },
                    { key: 'Last seen', val: formatLastSeen(device.lastSeen) },
                  ].map(({ key, val }) => (
                    <div key={key} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--font-heading)', fontSize: '12px' }}>
                      <span style={{ color: 'var(--color-text-muted)' }}>{key}</span>
                      <span style={{ color: 'var(--color-text)', fontWeight: 500 }}>{val}</span>
                    </div>
                  ))}
                </div>
              </article>
            ))
        }
      </div>
    </div>
  );
}
