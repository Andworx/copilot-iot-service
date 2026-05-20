import React from 'react';

interface SwitchIndicatorProps {
  label: string;
  on: boolean;
  deviceId?: string;
}

export const SwitchIndicator: React.FC<SwitchIndicatorProps> = ({ label, on, deviceId }) => (
  <div
    role="status"
    aria-label={`${label}: ${on ? 'on' : 'off'}`}
    style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '12px 16px',
      background: 'var(--color-surface)',
      border: `1px solid ${on ? 'var(--color-accent)' : 'var(--color-border)'}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: on ? '0 0 0 1px var(--color-accent)' : 'none',
      transition: 'border-color 0.2s, box-shadow 0.2s',
      gap: '12px',
    }}
  >
    <div>
      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '13px', fontWeight: 500, color: 'var(--color-text)' }}>
        {label}
      </div>
      {deviceId && (
        <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-text-muted)', marginTop: '2px' }}>
          {deviceId}
        </div>
      )}
    </div>
    {/* Toggle track (read-only) */}
    <div
      aria-hidden="true"
      style={{
        width: '40px', height: '22px',
        borderRadius: '11px',
        background: on ? 'var(--color-accent)' : 'var(--color-border-strong)',
        position: 'relative',
        flexShrink: 0,
        transition: 'background 0.2s',
      }}
    >
      <div style={{
        position: 'absolute',
        top: '3px', left: on ? '21px' : '3px',
        width: '16px', height: '16px',
        borderRadius: '50%',
        background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
        transition: 'left 0.2s',
      }} />
    </div>
  </div>
);
