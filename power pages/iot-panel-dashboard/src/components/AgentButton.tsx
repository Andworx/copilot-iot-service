import { useState } from 'react';

interface AgentButtonProps {
  hasIssues: boolean;
  // TODO: Wire to Copilot Studio agent (Issue #12)
  onHelpRequest?: () => void;
}

/**
 * Conditional "Help Now" button that surfaces when IoT issues are detected.
 * Renders null when hasIssues is false.
 * When an agent is integrated, replace the stub panel with a real Copilot Studio
 * embedded chat or deep-link call.
 */
export function AgentButton({ hasIssues, onHelpRequest }: AgentButtonProps) {
  const [panelOpen, setPanelOpen] = useState(false);

  if (!hasIssues) return null;

  function handleClick() {
    setPanelOpen(true);
    // TODO: Wire to Copilot Studio agent — replace this stub (Issue #12)
    onHelpRequest?.();
    console.info('[AgentButton] Help requested — Copilot Studio agent not yet wired.');
  }

  return (
    <>
      {/* Floating Help Now button */}
      <button
        onClick={handleClick}
        aria-label="Get AI assistance for current IoT issues"
        style={{
          position: 'fixed',
          bottom: '32px',
          right: '32px',
          zIndex: 100,
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '12px 20px',
          background: 'var(--color-surface)',
          border: '1px solid var(--color-warning)',
          borderRadius: 'var(--radius-md)',
          color: 'var(--color-warning)',
          fontFamily: 'var(--font-heading)',
          fontSize: '13px',
          fontWeight: 600,
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
          cursor: 'pointer',
          animation: 'amberPulse 2s ease-in-out infinite',
          transition: 'background 0.15s, transform 0.1s',
        }}
        onMouseEnter={e => {
          (e.currentTarget as HTMLButtonElement).style.background = 'rgba(245,158,11,0.12)';
          (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1.03)';
        }}
        onMouseLeave={e => {
          (e.currentTarget as HTMLButtonElement).style.background = 'var(--color-surface)';
          (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1)';
        }}
      >
        <span style={{ fontSize: '16px' }}>⚠</span>
        Help Now
      </button>

      {/* Stub agent panel — replace with Copilot Studio embed */}
      {panelOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="AI Agent — Issue Assistance"
          style={{
            position: 'fixed',
            bottom: '96px',
            right: '32px',
            zIndex: 101,
            width: '340px',
            background: 'var(--color-surface)',
            border: '1px solid var(--color-warning)',
            borderRadius: 'var(--radius-md)',
            boxShadow: 'var(--shadow-glow-amber)',
            overflow: 'hidden',
          }}
        >
          {/* Panel header */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '10px 14px',
            borderBottom: '1px solid var(--color-border-strong)',
            background: 'var(--color-surface-2)',
          }}>
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '11px',
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              color: 'var(--color-warning)',
            }}>
              ⚠ AI Agent — Issue Assistance
            </span>
            <button
              onClick={() => setPanelOpen(false)}
              aria-label="Close agent panel"
              style={{
                background: 'none',
                border: 'none',
                color: 'var(--color-text-muted)',
                cursor: 'pointer',
                fontSize: '16px',
                lineHeight: 1,
                padding: '2px 4px',
              }}
            >
              ×
            </button>
          </div>

          {/* Panel body — placeholder */}
          <div style={{ padding: '20px 16px', textAlign: 'center' }}>
            <div style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '12px',
              color: 'var(--color-text-muted)',
              lineHeight: 1.6,
              marginBottom: '12px',
            }}>
              Copilot Studio agent not yet connected.
              <br />
              <span style={{ color: 'var(--color-border-strong)', fontSize: '11px' }}>
                TODO: Wire to Copilot Studio agent (Issue #12)
              </span>
            </div>
            <div style={{
              padding: '10px',
              background: 'var(--color-surface-3)',
              border: '1px dashed var(--color-border-strong)',
              borderRadius: 'var(--radius-sm)',
              fontFamily: 'var(--font-heading)',
              fontSize: '11px',
              color: 'var(--color-text-muted)',
              letterSpacing: '0.04em',
            }}>
              AGENT EMBED AREA
            </div>
          </div>
        </div>
      )}
    </>
  );
}
