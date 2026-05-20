import React from 'react';

export type Status = 'online' | 'offline' | 'warning' | 'connecting';

interface StatusBadgeProps {
  status: Status;
  label?: string;
}

const config: Record<Status, { color: string; dot: string; text: string }> = {
  online:     { color: '#10B981', dot: '#10B981', text: 'Online' },
  offline:    { color: '#EF4444', dot: '#EF4444', text: 'Offline' },
  warning:    { color: '#F59E0B', dot: '#F59E0B', text: 'Warning' },
  connecting: { color: '#6B7280', dot: '#6B7280', text: 'Connecting' },
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({ status, label }) => {
  const { color, dot, text } = config[status];
  return (
    <span
      role="status"
      aria-label={`Status: ${label ?? text}`}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '6px',
        fontFamily: 'var(--font-heading)',
        fontSize: '11px',
        fontWeight: 500,
        letterSpacing: '0.06em',
        textTransform: 'uppercase',
        color,
      }}
    >
      <span
        aria-hidden="true"
        style={{
          width: '7px', height: '7px',
          borderRadius: '50%',
          background: dot,
          flexShrink: 0,
          animation: status === 'online' ? 'ledPulse 2s ease-in-out infinite' : undefined,
        }}
      />
      {label ?? text}
    </span>
  );
};
