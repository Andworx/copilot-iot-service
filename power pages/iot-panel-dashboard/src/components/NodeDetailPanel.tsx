import React, { useEffect } from 'react';
import { NODE_DATA, type NodeDef } from '../data/nodeData';

interface Props {
  node: NodeDef | null;
  onClose: () => void;
}

const TIER_LABELS: Record<NodeDef['tier'], string> = {
  edge:     'Edge Tier',
  cloud:    'Cloud Tier',
  platform: 'Platform Tier',
};

export const NodeDetailPanel: React.FC<Props> = ({ node, onClose }) => {
  // Close on Escape key
  useEffect(() => {
    if (!node) return;
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [node, onClose]);

  if (!node) return null;

  const connectedLabels = node.connectedTo
    .map(id => NODE_DATA.find(n => n.id === id)?.label ?? id);

  return (
    <>
      {/* Backdrop */}
      <div
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          zIndex: 200,
          background: 'rgba(8, 12, 8, 0.55)',
        }}
        aria-hidden="true"
      />

      {/* Slide-in panel */}
      <aside
        role="dialog"
        aria-modal="true"
        aria-label={`${node.label} component details`}
        style={{
          position: 'fixed',
          right: 0,
          top: 0,
          bottom: 0,
          zIndex: 201,
          width: 'min(380px, 92vw)',
          background: 'var(--color-surface)',
          borderLeft: '1px solid var(--color-border-strong)',
          boxShadow: '-4px 0 32px rgba(0, 0, 0, 0.65)',
          padding: 'var(--sp-6) var(--sp-5)',
          overflowY: 'auto',
          display: 'flex',
          flexDirection: 'column',
          gap: 'var(--sp-5)',
        }}
      >
        {/* Header row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 'var(--sp-3)' }}>
          <div>
            <div style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '9px',
              color: 'var(--color-text-muted)',
              letterSpacing: '0.14em',
              textTransform: 'uppercase',
              marginBottom: 'var(--sp-1)',
            }}>
              {TIER_LABELS[node.tier]}
            </div>
            <h2 style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '15px',
              fontWeight: 700,
              letterSpacing: '0.05em',
              color: node.accentColor,
              textTransform: 'uppercase',
            }}>
              {node.label}
            </h2>
            <p style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              color: 'var(--color-text-muted)',
              letterSpacing: '0.1em',
              marginTop: '3px',
            }}>
              {node.sublabel}
            </p>
          </div>

          <button
            onClick={onClose}
            aria-label="Close panel"
            style={{
              flexShrink: 0,
              background: 'none',
              border: '1px solid var(--color-border-strong)',
              color: 'var(--color-text-muted)',
              cursor: 'pointer',
              padding: '3px 8px',
              borderRadius: 'var(--radius-sm)',
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              letterSpacing: '0.12em',
              textTransform: 'uppercase',
              transition: 'border-color 0.15s, color 0.15s',
            }}
            onMouseEnter={e => {
              (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--color-text-muted)';
              (e.currentTarget as HTMLButtonElement).style.color = 'var(--color-text)';
            }}
            onMouseLeave={e => {
              (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--color-border-strong)';
              (e.currentTarget as HTMLButtonElement).style.color = 'var(--color-text-muted)';
            }}
          >
            ESC
          </button>
        </div>

        <hr />

        {/* About */}
        <section>
          <SectionLabel>About</SectionLabel>
          <p style={{ fontSize: '12px', color: 'var(--color-text)', lineHeight: 1.65 }}>
            {node.description}
          </p>
        </section>

        {/* Role in system */}
        <section>
          <SectionLabel>Role in System</SectionLabel>
          <p style={{ fontSize: '12px', color: 'var(--color-text)', lineHeight: 1.65 }}>
            {node.role}
          </p>
        </section>

        {/* Protocol */}
        <section>
          <SectionLabel>Protocol / Interface</SectionLabel>
          <code style={{
            display: 'inline-block',
            background: 'var(--color-surface-3)',
            border: '1px solid var(--color-border-strong)',
            padding: '3px 10px',
            borderRadius: 'var(--radius-sm)',
            fontSize: '11px',
            fontFamily: 'var(--font-heading)',
            color: node.accentColor,
            letterSpacing: '0.05em',
          }}>
            {node.protocol}
          </code>
        </section>

        {/* Connected to */}
        <section>
          <SectionLabel>Connected To</SectionLabel>
          <ul style={{ listStyle: 'none', display: 'flex', flexWrap: 'wrap', gap: 'var(--sp-2)' }}>
            {connectedLabels.map((label, i) => (
              <li key={i}>
                <span style={{
                  display: 'inline-block',
                  background: 'var(--color-surface-2)',
                  border: '1px solid var(--color-border-strong)',
                  padding: '3px 10px',
                  borderRadius: 'var(--radius-sm)',
                  fontSize: '10px',
                  color: 'var(--color-text)',
                  fontFamily: 'var(--font-heading)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                }}>
                  {label}
                </span>
              </li>
            ))}
          </ul>
        </section>
      </aside>
    </>
  );
};

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <h3 style={{
      fontFamily: 'var(--font-heading)',
      fontSize: '9px',
      color: 'var(--color-text-muted)',
      letterSpacing: '0.14em',
      textTransform: 'uppercase',
      marginBottom: 'var(--sp-2)',
    }}>
      {children}
    </h3>
  );
}
