import React, { useState, useEffect } from 'react';

/* ── Types ─────────────────────────────────── */
interface TelemetryEvent {
  andy_iottelemetryeventid: string;
  andy_deviceid: string;
  andy_eventtype: string;
  andy_value: string;
  createdon: string;
}

/* ── Stub data (replace with Dataverse WebAPI) ─── */
const MOCK_EVENTS: TelemetryEvent[] = Array.from({ length: 30 }, (_, i) => ({
  andy_iottelemetryeventid: `mock-${i}`,
  andy_deviceid: i % 2 === 0 ? 'RPi-Node-01' : 'RPi-Node-02',
  andy_eventtype: ['switch_on', 'switch_off', 'led_on', 'led_off'][i % 4],
  andy_value: String(i % 2),
  createdon: new Date(Date.now() - i * 3 * 60 * 1000).toISOString(),
}));

const PAGE_SIZE = 10;

const eventTypeColor: Record<string, string> = {
  switch_on:  'var(--color-accent)',
  switch_off: 'var(--color-text-muted)',
  led_on:     'var(--color-primary)',
  led_off:    'var(--color-text-muted)',
};

/* ── Component ─────────────────────────────── */
export default function History() {
  const [events, setEvents] = useState<TelemetryEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [deviceFilter, setDeviceFilter] = useState('');

  // Stub: replace with Dataverse WebAPI call
  useEffect(() => {
    const timer = setTimeout(() => {
      setEvents(MOCK_EVENTS);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  const filtered = deviceFilter
    ? events.filter(e => e.andy_deviceid.toLowerCase().includes(deviceFilter.toLowerCase()))
    : events;

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const pageSlice = filtered.slice(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  const formatTime = (iso: string) => {
    const d = new Date(iso);
    return `${d.toLocaleDateString()} ${d.toLocaleTimeString()}`;
  };

  return (
    <div>
      {/* Header */}
      <div className="animate-in" style={{ marginBottom: 'var(--sp-6)' }}>
        <h1 style={{ fontSize: '22px', marginBottom: '4px' }}>Event History</h1>
        <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>
          Telemetry log from <code style={{ fontFamily: 'var(--font-heading)', fontSize: '12px' }}>andy_iottelemetryevent</code>
        </p>
      </div>

      {/* Filter bar */}
      <div className="animate-in" style={{ display: 'flex', gap: 'var(--sp-4)', marginBottom: 'var(--sp-5)', flexWrap: 'wrap', alignItems: 'center' }}>
        <label htmlFor="device-filter" style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          Filter device
        </label>
        <input
          id="device-filter"
          type="search"
          value={deviceFilter}
          onChange={e => { setDeviceFilter(e.target.value); setPage(0); }}
          placeholder="e.g. RPi-Node-01"
          style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '13px',
            border: '1px solid var(--color-border)',
            borderRadius: 'var(--radius-sm)',
            padding: '6px 12px',
            background: 'var(--color-surface)',
            color: 'var(--color-text)',
            outline: 'none',
            width: '220px',
          }}
        />
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)', marginLeft: 'auto' }}>
          {loading ? '…' : `${filtered.length} events`}
        </span>
      </div>

      {/* Table */}
      <div style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', overflow: 'hidden', boxShadow: 'var(--shadow-card)' }}>
        <table
          style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'var(--font-heading)', fontSize: '13px' }}
          aria-label="Telemetry event history"
        >
          <thead>
            <tr style={{ borderBottom: '1px solid var(--color-border)', background: 'var(--color-surface-2)' }}>
              {['Timestamp', 'Device', 'Event Type', 'Value'].map(h => (
                <th
                  key={h}
                  scope="col"
                  style={{ padding: '10px 16px', textAlign: 'left', fontWeight: 600, fontSize: '11px', letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--color-text-muted)' }}
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading
              ? Array.from({ length: PAGE_SIZE }, (_, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid var(--color-border)' }}>
                    {[1,2,3,4].map(j => (
                      <td key={j} style={{ padding: '12px 16px' }}>
                        <div className="shimmer" style={{ height: '14px', borderRadius: '3px', width: j === 1 ? '140px' : j === 2 ? '100px' : '80px' }} />
                      </td>
                    ))}
                  </tr>
                ))
              : pageSlice.map(event => (
                  <tr
                    key={event.andy_iottelemetryeventid}
                    style={{ borderBottom: '1px solid var(--color-border)', transition: 'background 0.1s' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'var(--color-surface-2)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                  >
                    <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)' }}>
                      {formatTime(event.createdon)}
                    </td>
                    <td style={{ padding: '12px 16px', fontWeight: 500 }}>{event.andy_deviceid}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ color: eventTypeColor[event.andy_eventtype] ?? 'var(--color-text)', fontWeight: 500 }}>
                        {event.andy_eventtype}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)' }}>{event.andy_value}</td>
                  </tr>
                ))
            }
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {!loading && totalPages > 1 && (
        <div
          style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 'var(--sp-4)', marginTop: 'var(--sp-5)' }}
          role="navigation"
          aria-label="Pagination"
        >
          <button
            onClick={() => setPage(p => Math.max(0, p - 1))}
            disabled={page === 0}
            style={{
              fontFamily: 'var(--font-heading)', fontSize: '12px', padding: '6px 14px',
              border: '1px solid var(--color-border)', borderRadius: 'var(--radius-sm)',
              background: 'var(--color-surface)', color: 'var(--color-text-muted)',
              cursor: page === 0 ? 'not-allowed' : 'pointer', opacity: page === 0 ? 0.5 : 1,
            }}
          >
            ← Prev
          </button>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)' }}>
            Page {page + 1} of {totalPages}
          </span>
          <button
            onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
            disabled={page >= totalPages - 1}
            style={{
              fontFamily: 'var(--font-heading)', fontSize: '12px', padding: '6px 14px',
              border: '1px solid var(--color-border)', borderRadius: 'var(--radius-sm)',
              background: 'var(--color-surface)', color: 'var(--color-text-muted)',
              cursor: page >= totalPages - 1 ? 'not-allowed' : 'pointer', opacity: page >= totalPages - 1 ? 0.5 : 1,
            }}
          >
            Next →
          </button>
        </div>
      )}
    </div>
  );
}
