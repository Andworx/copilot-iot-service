import { useState, useEffect } from 'react';

/* ── Types ─────────────────────────────────── */
interface TelemetryEvent {
  andy_iottelemetryeventid: string;
  andy_deviceid: string;
  andy_eventtype: string;
  andy_gpiopin: number;
  andy_value: string;
  createdon: string;
}

/*
 * GPIO map for raspberry-pi-iotpanel:
 * Switches: GPIO 5 (SW1), 6 (SW2), 13 (SW3), 19 (SW4)
 * LEDs:     GPIO 18 (Power/Blue), 24 (Status/Orange), 25 (Network/Green), 12 (Error/Yellow)
 */
const EVENT_TYPES = [
  'sw1_pressed', 'sw1_released',
  'sw2_pressed', 'sw2_released',
  'sw3_pressed', 'sw3_released',
  'sw4_pressed', 'sw4_released',
  'led_power_on', 'led_power_off',
  'led_status_on', 'led_status_off',
  'led_network_on', 'led_network_off',
  'led_error_on', 'led_error_off',
] as const;
type EventType = typeof EVENT_TYPES[number];

const GPIO_FOR_EVENT: Record<EventType, number> = {
  sw1_pressed: 5, sw1_released: 5,
  sw2_pressed: 6, sw2_released: 6,
  sw3_pressed: 13, sw3_released: 13,
  sw4_pressed: 19, sw4_released: 19,
  led_power_on: 18, led_power_off: 18,
  led_status_on: 24, led_status_off: 24,
  led_network_on: 25, led_network_off: 25,
  led_error_on: 12, led_error_off: 12,
};

const EVENT_COLOR: Partial<Record<EventType, string>> = {
  sw1_pressed:    'var(--color-accent)',
  sw2_pressed:    'var(--color-accent)',
  sw3_pressed:    'var(--color-accent)',
  sw4_pressed:    'var(--color-accent)',
  led_power_on:   '#3B82F6',
  led_status_on:  '#F59E0B',
  led_network_on: 'var(--color-accent)',
  led_error_on:   '#EAB308',
};

/* ── Stub data (replace with Dataverse WebAPI — Issue #12) ── */
const EVENT_POOL: EventType[] = [
  'sw1_pressed', 'sw1_released', 'sw3_pressed', 'sw3_released',
  'led_power_on', 'led_status_on', 'led_network_on',
  'led_error_on', 'led_error_off', 'sw2_pressed', 'sw2_released',
];

const MOCK_EVENTS: TelemetryEvent[] = Array.from({ length: 40 }, (_, i) => {
  const et = EVENT_POOL[i % EVENT_POOL.length] as EventType;
  return {
    andy_iottelemetryeventid: `mock-${i}`,
    andy_deviceid: 'raspberry-pi-iotpanel',
    andy_eventtype: et,
    andy_gpiopin: GPIO_FOR_EVENT[et],
    andy_value: et.endsWith('_pressed') || et.endsWith('_on') ? '1' : '0',
    createdon: new Date(Date.now() - i * 2 * 60 * 1000).toISOString(),
  };
});

const PAGE_SIZE = 10;

/* ── Component ─────────────────────────────── */
export default function History() {
  const [events, setEvents] = useState<TelemetryEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [typeFilter, setTypeFilter] = useState<string>('');

  // Stub: replace with Dataverse WebAPI call (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => {
      setEvents(MOCK_EVENTS);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  const filtered = typeFilter
    ? events.filter(e => e.andy_eventtype === typeFilter)
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
          Telemetry log — <code style={{ fontFamily: 'var(--font-heading)', fontSize: '12px' }}>raspberry-pi-iotpanel</code>
        </p>
      </div>

      {/* Filter bar */}
      <div className="animate-in" style={{ display: 'flex', gap: 'var(--sp-4)', marginBottom: 'var(--sp-5)', flexWrap: 'wrap', alignItems: 'center' }}>
        <label htmlFor="type-filter" style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
          Filter event
        </label>
        <select
          id="type-filter"
          value={typeFilter}
          onChange={e => { setTypeFilter(e.target.value); setPage(0); }}
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
        >
          <option value="">All events</option>
          {EVENT_TYPES.map(et => (
            <option key={et} value={et}>{et}</option>
          ))}
        </select>
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
              {['Timestamp', 'Device', 'Event Type', 'GPIO Pin', 'Value'].map(h => (
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
                    {[1,2,3,4,5].map(j => (
                      <td key={j} style={{ padding: '12px 16px' }}>
                        <div className="shimmer" style={{ height: '14px', borderRadius: '3px', width: j === 1 ? '140px' : j === 2 ? '160px' : '80px' }} />
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
                      <span style={{ color: EVENT_COLOR[event.andy_eventtype as EventType] ?? 'var(--color-text)', fontWeight: 500 }}>
                        {event.andy_eventtype}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)', fontFamily: 'var(--font-heading)' }}>
                      GPIO {event.andy_gpiopin}
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
