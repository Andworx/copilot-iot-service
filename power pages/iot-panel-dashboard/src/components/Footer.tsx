import React from 'react';

export const Footer: React.FC = () => (
  <footer
    className="site-footer"
    aria-label="Site footer"
    style={{
      borderTop: '1px solid var(--color-border)',
      padding: 'var(--sp-5) var(--sp-5)',
      background: 'var(--color-surface)',
    }}
  >
    <div style={{ maxWidth: '1200px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: '12px', color: 'var(--color-text-muted)', letterSpacing: '0.04em' }}>
        IoT Panel Dashboard
      </span>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: '11px', color: 'var(--color-border-strong)', letterSpacing: '0.04em' }}>
        AgenticIoT · Dataverse v9.2
      </span>
    </div>
  </footer>
);
