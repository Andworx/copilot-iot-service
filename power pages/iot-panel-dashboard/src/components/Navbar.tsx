import React from 'react';
import { NavLink } from 'react-router-dom';
import type { ConnectionStatus } from '../types/telemetry';

interface NavbarProps {
  connectionStatus: ConnectionStatus;
}

const navStyle: React.CSSProperties = {
  position: 'sticky', top: 0, zIndex: 100,
  background: 'var(--color-surface)',
  borderBottom: '1px solid var(--color-border-strong)',
};

const innerStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
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
    <div style={innerStyle} className="nav-inner">
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
      <ul role="list" className="nav-list">
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

      {/* Connection status — device name + SignalR state */}
      <div style={{ flexShrink: 0, display: 'flex', alignItems: 'center', gap: '6px' }}>
        <span style={{
          width: '7px', height: '7px', borderRadius: '50%', flexShrink: 0,
          background: connectionStatus === 'connected'    ? 'var(--color-success)'
                    : connectionStatus === 'reconnecting' || connectionStatus === 'connecting' ? 'var(--color-warning)'
                    : connectionStatus === 'error'        ? 'var(--color-danger)'
                    : 'var(--color-text-muted)',
          animation: connectionStatus === 'connected' ? 'ledPulse 3s ease-in-out infinite'
                   : connectionStatus === 'connecting' || connectionStatus === 'reconnecting' ? 'ledPulseError 0.8s ease-in-out infinite'
                   : 'none',
        }} />
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '11px',
          fontWeight: 600,
          letterSpacing: '0.06em',
          color: 'var(--color-text-bright)',
        }}>
          raspberry-pi-iotpanel
        </span>
        <span style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '10px',
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: connectionStatus === 'connected'    ? 'var(--color-success)'
               : connectionStatus === 'reconnecting' || connectionStatus === 'connecting' ? 'var(--color-warning)'
               : connectionStatus === 'error'        ? 'var(--color-danger)'
               : 'var(--color-text-muted)',
        }}>
          {connectionStatus === 'connected'    ? 'Connected'
         : connectionStatus === 'connecting'   ? 'Connecting…'
         : connectionStatus === 'reconnecting' ? 'Reconnecting…'
         : connectionStatus === 'error'        ? 'Error'
         : 'Disconnected'}
        </span>
      </div>
    </div>
  </nav>
);
