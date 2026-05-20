import { useState, useEffect } from 'react';

/* ── Types ─────────────────────────────────────────────────── */
interface PiHealth {
  connected: boolean;
  uptime: string;
  cpuTempC: number;
  cpuLoadPct: number;
  memUsedPct: number;
  activeRule: string | null;
  switchesActive: number;
  ledsOn: number;
}

interface PageHealth {
  status: 'online' | 'degraded' | 'offline';
  responseMs: number;
  environment: string;
  lastDeployed: Date;
}

/* ── Stub data (replace with SignalR + Dataverse WebAPI — Issue #12) ── */
const MOCK_PI: PiHealth = {
  connected: true,
  uptime: '3d 14h 22m',
  cpuTempC: 54.2,
  cpuLoadPct: 18,
  memUsedPct: 41,
  activeRule: 'all_lights_on',
  switchesActive: 2,
  ledsOn: 4,
};

const MOCK_PAGE: PageHealth = {
  status: 'online',
  responseMs: 182,
  environment: 'IoT-Agents',
  lastDeployed: new Date(Date.now() - 1000 * 60 * 60 * 2),
};

/* ── Helpers ────────────────────────────────────────────────── */
function formatAgo(d: Date): string {
  const mins = Math.floor((Date.now() - d.getTime()) / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

function SectionHeading({ children }: { children: React.ReactNode }) {
  return (
    <h2
      style={{
        fontSize: '10px',
        letterSpacing: '0.12em',
        textTransform: 'uppercase',
        color: 'var(--color-text-muted)',
        marginBottom: 'var(--sp-3)',
        fontFamily: 'var(--font-heading)',
        fontWeight: 600,
      }}
    >
      {children}
    </h2>
  );
}

interface HealthBarProps {
  label: string;
  value: number;
  max: number;
  unit: string;
  warnAt: number;
  critAt: number;
}

function HealthBar({ label, value, max, unit, warnAt, critAt }: HealthBarProps) {
  const pct = Math.min((value / max) * 100, 100);
  const color =
    value >= critAt ? 'var(--color-danger)' :
    value >= warnAt ? 'var(--color-warning)' :
    'var(--color-accent)';

  return (
    <div style={{ marginBottom: 'var(--sp-4)' }}>
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        marginBottom: '4px',
        fontFamily: 'var(--font-heading)',
        fontSize: '11px',
      }}>
        <span style={{ color: 'var(--color-text-muted)' }}>{label}</span>
        <span style={{ color }}>{value}{unit}</span>
      </div>
      <div style={{
        height: '4px',
        background: 'var(--color-border-strong)',
        borderRadius: '2px',
        overflow: 'hidden',
      }}>
        <div style={{
          width: `${pct}%`,
          height: '100%',
          background: color,
          borderRadius: '2px',
          transition: 'width 0.4s ease',
        }} />
      </div>
    </div>
  );
}

interface StatCardProps {
  label: string;
  value: string;
  active?: boolean;
}

function StatCard({ label, value, active = true }: StatCardProps) {
  return (
    <div
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
      <div style={{
        fontSize: '11px',
        color: 'var(--color-text-muted)',
        marginTop: '4px',
        letterSpacing: '0.04em',
        textTransform: 'uppercase',
        fontFamily: 'var(--font-heading)',
      }}>
        {label}
      </div>
    </div>
  );
}

/* ── Component ──────────────────────────────────────────────── */
export default function Dashboard() {
  const [pi, setPi] = useState<PiHealth | null>(null);
  const [page, setPage] = useState<PageHealth | null>(null);
  const [loading, setLoading] = useState(true);

  // Stub: replace with SignalR + Dataverse WebAPI (Issue #12)
  useEffect(() => {
    const t = setTimeout(() => {
      setPi(MOCK_PI);
      setPage(MOCK_PAGE);
      setLoading(false);
    }, 600);
    return () => clearTimeout(t);
  }, []);

  return (
    <div>
      {/* Page header */}
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
          <h1 style={{ fontSize: '18px', marginBottom: '4px' }}>System Health</h1>
          <p style={{ fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
            Device and portal health — raspberry-pi-iotpanel
          </p>
        </div>
      </div>

      {/* Summary stat cards */}
      <div
        style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 'var(--sp-3)', marginBottom: 'var(--sp-6)' }}
        aria-label="Health summary"
      >
        {loading ? (
          [1, 2, 3, 4].map(i => (
            <div key={i} className="shimmer" style={{ height: '72px', borderRadius: 'var(--radius-md)' }} />
          ))
        ) : pi ? (
          <>
            <StatCard label="Pi Status"         value={pi.connected ? 'ONLINE' : 'OFFLINE'} active={pi.connected} />
            <StatCard label="Uptime"             value={pi.uptime}                            active />
            <StatCard label="Switches Active"    value={`${pi.switchesActive} / 4`}           active={pi.switchesActive > 0} />
            <StatCard label="LEDs On"            value={`${pi.ledsOn} / 4`}                   active={pi.ledsOn > 0} />
          </>
        ) : null}
      </div>

      {/* Pi resource bars */}
      <section aria-labelledby="pi-health-heading" style={{ marginBottom: 'var(--sp-6)' }}>
        <SectionHeading>
          <span id="pi-health-heading">Raspberry Pi — raspberry-pi-iotpanel</span>
        </SectionHeading>

        {loading ? (
          <div className="shimmer" style={{ height: '140px', borderRadius: 'var(--radius-md)' }} />
        ) : pi ? (
          <div
            className="animate-in"
            style={{
              background: 'var(--color-surface)',
              border: `1px solid ${pi.connected ? 'var(--color-success)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              padding: 'var(--sp-5)',
              boxShadow: pi.connected ? 'var(--shadow-glow-accent)' : 'var(--shadow-glow-danger)',
            }}
          >
            {pi.activeRule && (
              <div style={{ marginBottom: 'var(--sp-4)' }}>
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
                  active rule: {pi.activeRule}
                </span>
              </div>
            )}
            <HealthBar label="CPU Temperature" value={pi.cpuTempC}    max={85}  unit="°C" warnAt={70} critAt={80} />
            <HealthBar label="CPU Load"         value={pi.cpuLoadPct}  max={100} unit="%"  warnAt={70} critAt={90} />
            <HealthBar label="Memory Used"      value={pi.memUsedPct}  max={100} unit="%"  warnAt={75} critAt={90} />
          </div>
        ) : null}
      </section>

      {/* Power Pages health */}
      <section aria-labelledby="page-health-heading">
        <SectionHeading>
          <span id="page-health-heading">Power Pages Health</span>
        </SectionHeading>

        {loading ? (
          <div className="shimmer" style={{ height: '80px', borderRadius: 'var(--radius-md)' }} />
        ) : page ? (
          <div
            className="animate-in"
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
              gap: 'var(--sp-5)',
              background: 'var(--color-surface)',
              border: `1px solid ${page.status === 'online' ? 'var(--color-success)' : page.status === 'degraded' ? 'var(--color-warning)' : 'var(--color-danger)'}`,
              borderRadius: 'var(--radius-md)',
              padding: 'var(--sp-4) var(--sp-5)',
              boxShadow: page.status === 'online' ? 'var(--shadow-glow-accent)' : 'var(--shadow-glow-danger)',
            }}
          >
            {[
              { k: 'Status',        v: page.status.toUpperCase(),    color: page.status === 'online' ? 'var(--color-success)' : 'var(--color-danger)' },
              { k: 'Response Time', v: `${page.responseMs} ms`,      color: page.responseMs > 500 ? 'var(--color-warning)' : 'var(--color-text-bright)' },
              { k: 'Environment',   v: page.environment,             color: 'var(--color-text-bright)' },
              { k: 'Last Deployed', v: formatAgo(page.lastDeployed), color: 'var(--color-text-bright)' },
            ].map(({ k, v, color }) => (
              <div key={k}>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--color-text-muted)', marginBottom: '4px' }}>{k}</div>
                <div style={{ fontFamily: 'var(--font-heading)', fontSize: '14px', fontWeight: 600, color }}>{v}</div>
              </div>
            ))}
          </div>
        ) : null}
      </section>

      <p style={{ marginTop: 'var(--sp-7)', fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center', letterSpacing: '0.04em' }}>
        Live data via SignalR — Issue #12 · Device: raspberry-pi-iotpanel
      </p>
    </div>
  );
}
