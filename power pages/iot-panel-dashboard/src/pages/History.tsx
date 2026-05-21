import { useState, useEffect, useRef } from 'react';
import { useSignalRContext } from '../context/SignalRContext';
import type { TelemetryEvent } from '../types/telemetry';

/* ── Display event type ─────────────────────── */
interface DisplayEvent {
  id: string;
  timestamp: string;
  deviceId: string;
  eventType: string;
  gpio: string;
  value: string;
  highlight?: string; // optional CSS color
}

const LED_COLORS = ['#3B82F6', '#F59E0B', '#22C55E', '#EAB308'];

function signalREventToDisplay(e: TelemetryEvent): DisplayEvent {
  if (e.eventType === 'help-triggered') {
    return {
      id: e.id,
      timestamp: e.timestamp,
      deviceId: e.deviceId,
      eventType: 'help-triggered',
      gpio: '—',
      value: e.mismatch ? 'MISMATCH' : '—',
      highlight: 'var(--color-danger)',
    };
  }
  // For telemetry: emit one entry per LED that changed
  return {
    id: e.id,
    timestamp: e.timestamp,
    deviceId: e.deviceId,
    eventType: 'telemetry-snapshot',
    gpio: (e.leds ?? []).map((on, i) => on ? `GPIO ${[18,24,25,12][i]}` : '').filter(Boolean).join(', ') || '—',
    value: e.mismatch ? 'MISMATCH' : 'OK',
    highlight: e.mismatch ? 'var(--color-warning)' : undefined,
  };
}

/* ── Dataverse event → display ──────────────── */
interface DataverseRecord {
  andy_iottelemetryeventid: string;
  andy_deviceid: string;
  andy_eventtype: string;
  andy_gpiopin?: number;
  andy_value?: string;
  createdon: string;
}

function dataverseRecordToDisplay(r: DataverseRecord): DisplayEvent {
  const isFault = r.andy_eventtype?.includes('error') || r.andy_eventtype?.includes('mismatch');
  const isLedOn = r.andy_eventtype?.endsWith('_on');
  const ledIdx = [18, 24, 25, 12].indexOf(r.andy_gpiopin ?? -1);
  return {
    id: r.andy_iottelemetryeventid,
    timestamp: r.createdon,
    deviceId: r.andy_deviceid,
    eventType: r.andy_eventtype,
    gpio: r.andy_gpiopin != null ? `GPIO ${r.andy_gpiopin}` : '—',
    value: r.andy_value ?? '—',
    highlight: isFault ? 'var(--color-danger)' : isLedOn && ledIdx >= 0 ? LED_COLORS[ledIdx] : undefined,
  };
}

const PAGE_SIZE = 10;

/* ── Fetch Dataverse events ─────────────────── */
async function fetchDataverseEvents(): Promise<DisplayEvent[]> {
  try {
    // Relative URL works in Power Pages portal context; absolute in dev with proxy
    const url = '/api/data/v9.2/andy_iottelemetryevents?$orderby=createdon desc&$top=100&$select=andy_iottelemetryeventid,andy_deviceid,andy_eventtype,andy_gpiopin,andy_value,createdon';
    const res = await fetch(url, {
      headers: { 'OData-MaxVersion': '4.0', 'OData-Version': '4.0', 'Accept': 'application/json' },
    });
    if (!res.ok) throw new Error(`Dataverse HTTP ${res.status}`);
    const json = await res.json();
    return ((json.value ?? []) as DataverseRecord[]).map(dataverseRecordToDisplay);
  } catch {
    return []; // Portal may not have the table yet — silently fall back to live events
  }
}

/* ── Component ─────────────────────────────── */
export default function History() {
  const { events: signalREvents } = useSignalRContext();

  const [baseEvents, setBaseEvents] = useState<DisplayEvent[]>([]);
  const [loading, setLoading]       = useState(true);
  const [page, setPage]             = useState(0);
  const [typeFilter, setTypeFilter] = useState('');
  const loadedRef = useRef(false);

  useEffect(() => {
    if (loadedRef.current) return;
    loadedRef.current = true;
    fetchDataverseEvents().then(rows => {
      setBaseEvents(rows);
      setLoading(false);
    });
  }, []);

  // Merge: live SignalR events on top, Dataverse records below (deduplicated by id)
  const liveDisplayEvents = signalREvents.map(signalREventToDisplay);
  const baseIds = new Set(baseEvents.map(e => e.id));
  const merged: DisplayEvent[] = [
    ...liveDisplayEvents.filter(e => !baseIds.has(e.id)),
    ...baseEvents,
  ];

  const filtered = typeFilter ? merged.filter(e => e.eventType === typeFilter) : merged;
  const uniqueTypes = Array.from(new Set(merged.map(e => e.eventType))).sort();
  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const pageSlice  = filtered.slice(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  const formatTime = (iso: string) => {
    try {
      const d = new Date(iso);
      return `${d.toLocaleDateString()} ${d.toLocaleTimeString()}`;
    } catch { return iso; }
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
          Filter type
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
          {uniqueTypes.map(t => <option key={t} value={t}>{t}</option>)}
        </select>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)', marginLeft: 'auto' }}>
          {loading ? 'Loading…' : `${filtered.length} events`}
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
                    key={event.id}
                    style={{ borderBottom: '1px solid var(--color-border)', transition: 'background 0.1s' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'var(--color-surface-2)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                  >
                    <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)', whiteSpace: 'nowrap' }}>
                      {formatTime(event.timestamp)}
                    </td>
                    <td style={{ padding: '12px 16px', fontWeight: 500 }}>{event.deviceId}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ color: event.highlight ?? 'var(--color-text)', fontWeight: event.highlight ? 600 : 400 }}>
                        {event.eventType}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)' }}>{event.gpio}</td>
                    <td style={{ padding: '12px 16px', color: event.highlight ?? 'var(--color-text-muted)' }}>{event.value}</td>
                  </tr>
                ))
            }
            {!loading && pageSlice.length === 0 && (
              <tr>
                <td colSpan={5} style={{ padding: '32px 16px', textAlign: 'center', color: 'var(--color-text-muted)', fontFamily: 'var(--font-heading)', fontSize: '12px' }}>
                  No events recorded yet — waiting for telemetry from the Pi
                </td>
              </tr>
            )}
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
