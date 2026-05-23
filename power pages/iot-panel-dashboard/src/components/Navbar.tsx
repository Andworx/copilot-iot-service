import React from 'react';
import { NavLink } from 'react-router-dom';
import { StatusBadge, type Status } from './StatusBadge';

interface NavbarProps {
  connectionStatus: Status;
}

const navStyle: React.CSSProperties = {
  position: 'sticky', top: 0, zIndex: 100,
  background: 'var(--color-surface)',
  borderBottom: '1px solid var(--color-border-strong)',
};

const innerStyle: React.CSSProperties = {
  maxWidth: '1200px',
  margin: '0 auto',
  padding: '0 var(--sp-5)',
  height: '52px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 'var(--sp-5)',
};

const linkStyle: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '11px',
  fontWeight: 500,
  color: 'var(--color-text-muted)',
  textDecoration: 'none',
  letterSpacing: '0.10em',
  textTransform: 'uppercase',
  padding: '4px 0',
  borderBottom: '2px solid transparent',
  transition: 'color 0.15s, border-color 0.15s',
};

const activeLinkStyle: React.CSSProperties = {
  ...linkStyle,
  color: 'var(--color-primary)',
  borderBottomColor: 'var(--color-primary)',
};

export const Navbar: React.FC<NavbarProps> = ({ connectionStatus }) => (
  <nav style={navStyle} aria-label="Main navigation">
    <div style={innerStyle}>
      {/* Wordmark */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-3)', flexShrink: 0 }}>
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '13px',
          fontWeight: 700,
          letterSpacing: '0.12em',
          textTransform: 'uppercase',
          color: 'var(--color-text-bright)',
        }}>
          IoT Panel
        </span>
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '9px',
          color: 'var(--color-text-muted)',
          letterSpacing: '0.14em',
          textTransform: 'uppercase',
          marginTop: '1px',
          borderLeft: '1px solid var(--color-border-strong)',
          paddingLeft: 'var(--sp-3)',
        }}>
          v0.1.0
        </span>
      </div>

      {/* Nav links */}
      <ul role="list" style={{ display: 'flex', gap: 'var(--sp-5)', listStyle: 'none', alignItems: 'center' }}>
        {[
          { to: '/',              label: 'Status'     },
          { to: '/history',       label: 'History'    },
          { to: '/devices',       label: 'Devices'    },
          { to: '/infrastructure', label: 'System Map' },
        ].map(({ to, label }) => (
          <li key={to}>
            <NavLink
              to={to}
              end={to === '/'}
              style={({ isActive }) => isActive ? activeLinkStyle : linkStyle}
            >
              {label}
            </NavLink>
          </li>
        ))}
      </ul>

      {/* Connection status */}
      <div style={{ flexShrink: 0 }}>
        <StatusBadge status={connectionStatus} />
      </div>
    </div>
  </nav>
);
