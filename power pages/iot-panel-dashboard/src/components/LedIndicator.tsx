import React from 'react';

/* Physical LED color palette — matches actual hardware */
export const LED_COLORS: Record<string, { color: string; glow: string; animation: string }> = {
  blue:   { color: '#3B82F6', glow: 'rgba(59,130,246,0.30)',  animation: 'ledPulseBlue   2s ease-in-out infinite' },
  orange: { color: '#F59E0B', glow: 'rgba(245,158,11,0.30)',  animation: 'ledPulseOrange 2s ease-in-out infinite' },
  green:  { color: '#22C55E', glow: 'rgba(34,197,94,0.30)',   animation: 'ledPulse       2s ease-in-out infinite' },
  yellow: { color: '#EAB308', glow: 'rgba(234,179,8,0.30)',   animation: 'ledPulseYellow 2s ease-in-out infinite' },
};

interface LedIndicatorProps {
  label: string;
  on: boolean;
  /** Physical LED color name: 'blue' | 'orange' | 'green' | 'yellow' */
  ledColor?: keyof typeof LED_COLORS;
  /** BCM GPIO pin number */
  gpio?: number;
  deviceId?: string;
}

export const LedIndicator: React.FC<LedIndicatorProps> = ({
  label, on, ledColor = 'green', gpio, deviceId,
}) => {
  const { color, glow, animation } = LED_COLORS[ledColor] ?? LED_COLORS.green;
  return (
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
        border: `1px solid ${on ? color : 'var(--color-border-strong)'}`,
        borderRadius: 'var(--radius-md)',
        minWidth: '80px',
        transition: 'border-color 0.2s',
        boxShadow: on ? `0 0 10px 2px ${glow}` : 'var(--shadow-card)',
      }}
    >
      <div
        aria-hidden="true"
        style={{
          width: '18px', height: '18px',
          borderRadius: '50%',
          background: on ? color : 'var(--color-border-strong)',
          boxShadow: on ? `0 0 8px 3px ${glow}` : 'none',
          animation: on ? animation : 'none',
          transition: 'background 0.3s, box-shadow 0.3s',
        }}
      />
      <div style={{
        fontFamily: 'var(--font-heading)',
        fontSize: '11px',
        letterSpacing: '0.06em',
        textTransform: 'uppercase',
        color: on ? color : 'var(--color-text-muted)',
        textAlign: 'center',
      }}>
        {label}
      </div>
      {gpio !== undefined && (
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '9px',
          color: 'var(--color-text-muted)',
          letterSpacing: '0.06em',
          textAlign: 'center',
        }}>
          GPIO {gpio}
        </div>
      )}
      {deviceId && (
        <div style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '9px',
          color: 'var(--color-border-strong)',
          textAlign: 'center',
        }}>
          {deviceId}
        </div>
      )}
    </div>
  );
};
