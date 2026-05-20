import React from 'react';

interface LedIndicatorProps {
  label: string;
  on: boolean;
  color?: string;
  deviceId?: string;
}

export const LedIndicator: React.FC<LedIndicatorProps> = ({
  label, on, color = 'var(--color-accent)', deviceId,
}) => (
  <div
    role="status"
    aria-label={`LED ${label}: ${on ? 'on' : 'off'}`}
    style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: '8px',
      padding: '16px 12px',
      background: 'var(--color-surface)',
      border: `1px solid ${on ? 'var(--color-accent)' : 'var(--color-border)'}`,
      borderRadius: 'var(--radius-md)',
      minWidth: '80px',
      transition: 'border-color 0.2s',
    }}
  >
    <div
      aria-hidden="true"
      style={{
        width: '20px', height: '20px',
        borderRadius: '50%',
        background: on ? color : 'var(--color-border-strong)',
        boxShadow: on ? `0 0 8px 2px var(--color-accent-glow)` : 'none',
        animation: on ? 'ledPulse 2s ease-in-out infinite' : 'none',
        transition: 'background 0.3s, box-shadow 0.3s',
      }}
    />
    <div style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-text-muted)', textAlign: 'center' }}>
      {label}
    </div>
    {deviceId && (
      <div style={{ fontFamily: 'var(--font-heading)', fontSize: '10px', color: 'var(--color-border-strong)', textAlign: 'center' }}>
        {deviceId}
      </div>
    )}
  </div>
);
