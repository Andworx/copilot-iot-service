import React from 'react';

interface SwitchIndicatorProps {
  label: string;
  on: boolean;
  /** BCM GPIO pin number */
  gpio?: number;
  deviceId?: string;
}

export const SwitchIndicator: React.FC<SwitchIndicatorProps> = ({ label, on, gpio, deviceId }) => (
  <div
    role="status"
    aria-label={`${label}: ${on ? 'on' : 'off'}`}
    style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '12px 16px',
      background: 'var(--color-surface)',
      border: `1px solid ${on ? 'var(--color-primary)' : 'var(--color-border-strong)'}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: on ? 'var(--shadow-glow-amber)' : 'var(--shadow-card)',
      transition: 'border-color 0.2s, box-shadow 0.2s',
      gap: '12px',
    }}
  >
    <div>
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '12px',
        letterSpacing: '0.06em',
        textTransform: 'uppercase',
        color: on ? 'var(--color-primary)' : 'var(--color-text)',
      }}>
        {label}
      </div>
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '10px',
        color: 'var(--color-text-muted)',
        marginTop: '2px',
        letterSpacing: '0.04em',
      }}>
        {gpio !== undefined ? `GPIO ${gpio}` : ''}{deviceId ? ` · ${deviceId}` : ''}
      </div>
    </div>
    {/* Toggle track (read-only) */}
    <div
      aria-hidden="true"
      style={{
        width: '36px', height: '20px',
        borderRadius: '2px',
        background: on ? 'var(--color-primary)' : 'var(--color-surface-3)',
        border: `1px solid ${on ? 'var(--color-primary)' : 'var(--color-border-strong)'}`,
        position: 'relative',
        flexShrink: 0,
        transition: 'background 0.2s',
      }}
    >
      <div style={{
        position: 'absolute',
        top: '2px', left: on ? '18px' : '2px',
        width: '14px', height: '14px',
        borderRadius: '1px',
        background: on ? '#0A0F0A' : 'var(--color-text-muted)',
        transition: 'left 0.15s',
      }} />
    </div>
  </div>
);
