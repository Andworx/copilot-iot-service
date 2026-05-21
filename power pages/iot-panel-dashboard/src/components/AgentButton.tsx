import type { IoTState } from '../types/telemetry';
import { GPIO_CONFIG } from '../types/telemetry';
import { useAgentChat } from '../hooks/useAgentChat';

interface AgentButtonProps {
  iotState: IoTState | null;
  hasMismatch?: boolean;
}

/**
 * Builds a structured prompt from live telemetry — sent verbatim to the
 * Copilot Studio agent via Direct Line. The agent's QuickFix topic
 * recognises the "Panel quick-fix request" prefix and replies with a
 * concise numbered list of switch actions only.
 */
function buildQuickFixPrompt(state: IoTState): string {
  const leds = state.leds
    .map((on, i) => `${GPIO_CONFIG.leds[i].label}=${on ? 'ON' : 'OFF'}`)
    .join(', ');

  const switches = state.switches
    .map((pressed, i) => `${GPIO_CONFIG.switches[i].label}=${pressed ? 'PRESSED' : 'OPEN'}`)
    .join(', ');

  const allLedsOn = state.leds.every(Boolean);

  return (
    `Panel quick-fix request.\n` +
    `TARGET STATE: All 4 LEDs must be ON simultaneously. This is the only definition of a healthy panel.\n` +
    `Current LED status: ${leds}.\n` +
    `Current switch status: ${switches}.\n` +
    `All LEDs on: ${allLedsOn ? 'YES' : 'NO'}.\n` +
    `What switch actions are needed to get ALL 4 LEDs ON? ` +
    `Reply with ONLY a plain numbered list of switch actions (1-4 steps max). ` +
    `No emojis, no citations, no markdown, no preamble, no explanation.`
  );
}

/**
 * "Help Fix" bar placed between the LED and Switch sections on StatusHome.
 * Pressing it sends the current panel state to the IoT Panel Troubleshooting
 * Agent and displays its concise fix instructions inline.
 */
export function AgentButton({ iotState, hasMismatch }: AgentButtonProps) {
  const { status, response, error, sendPrompt, reset } = useAgentChat();
  const open = status !== 'idle';
  const isAlert = hasMismatch ?? (iotState?.mismatch ?? false);

  function handleClick() {
    if (!iotState) return;
    if (open) {
      reset();
      return;
    }
    sendPrompt(buildQuickFixPrompt(iotState));
  }

  const borderColor   = isAlert ? 'var(--color-danger)' : 'var(--color-border-strong)';
  const lineColor     = isAlert ? 'rgba(239,68,68,0.30)' : 'var(--color-border)';
  const buttonColor   = isAlert ? 'var(--color-danger)' : 'var(--color-text-muted)';
  const buttonBg      = isAlert ? 'rgba(239,68,68,0.10)' : 'var(--color-surface)';
  const disabled      = !iotState || status === 'loading';

  return (
    <div style={{ margin: 'var(--sp-4) 0' }}>
      {/* ── Centred bar with dividers ─────────────── */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ flex: 1, height: '1px', background: lineColor }} />

        <button
          onClick={handleClick}
          disabled={disabled}
          aria-label="Ask AI agent to diagnose the current panel state and suggest a fix"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '8px 20px',
            background: buttonBg,
            border: `1px solid ${borderColor}`,
            borderRadius: 'var(--radius-md)',
            color: buttonColor,
            fontFamily: 'var(--font-heading)',
            fontSize: '11px',
            fontWeight: 600,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            cursor: disabled ? 'not-allowed' : 'pointer',
            opacity: !iotState ? 0.45 : 1,
            animation: isAlert && !open ? 'amberPulse 2s ease-in-out infinite' : 'none',
            transition: 'background 0.15s',
            whiteSpace: 'nowrap',
          }}
          onMouseEnter={e => {
            if (!disabled) (e.currentTarget as HTMLButtonElement).style.background =
              isAlert ? 'rgba(239,68,68,0.18)' : 'var(--color-surface-2)';
          }}
          onMouseLeave={e => {
            (e.currentTarget as HTMLButtonElement).style.background = buttonBg;
          }}
        >
          {status === 'loading' ? (
            <>
              <span style={{ fontSize: '14px', animation: 'spin 1s linear infinite' }}>⟳</span>
              Asking Agent…
            </>
          ) : open ? (
            <>
              <span style={{ fontSize: '14px' }}>×</span>
              Close
            </>
          ) : (
            <>
              <span style={{ fontSize: '14px' }}>{isAlert ? '⚠' : '🔍'}</span>
              Help Fix
            </>
          )}
        </button>

        <div style={{ flex: 1, height: '1px', background: lineColor }} />
      </div>

      {/* ── Response panel ────────────────────────── */}
      {open && (
        <div
          className="animate-in"
          style={{
            marginTop: 'var(--sp-3)',
            background: 'var(--color-surface)',
            border: `1px solid ${
              status === 'error' ? 'var(--color-danger)'
                : status === 'done'  ? 'var(--color-accent)'
                : 'var(--color-border-strong)'
            }`,
            borderRadius: 'var(--radius-md)',
            overflow: 'hidden',
          }}
        >
          {/* Header */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '8px 14px',
            background: 'var(--color-surface-2)',
            borderBottom: '1px solid var(--color-border)',
          }}>
            <span style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '10px',
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              color: 'var(--color-text-muted)',
            }}>
              ⚡ IoT Panel Troubleshooting Agent
            </span>
          </div>

          {/* Body */}
          <div style={{ padding: '14px 16px' }}>
            {status === 'loading' && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div className="shimmer" style={{ width: '16px', height: '16px', borderRadius: '50%', flexShrink: 0 }} />
                <span style={{
                  fontFamily: 'var(--font-heading)',
                  fontSize: '11px',
                  color: 'var(--color-text-muted)',
                  letterSpacing: '0.04em',
                }}>
                  Analysing panel state…
                </span>
              </div>
            )}

            {status === 'done' && response && (
              <div style={{
                fontFamily: 'var(--font-mono, monospace)',
                fontSize: '13px',
                lineHeight: 1.8,
                color: 'var(--color-text-bright)',
                whiteSpace: 'pre-wrap',
              }}>
                {response}
              </div>
            )}

            {status === 'error' && (
              <div style={{
                fontFamily: 'var(--font-heading)',
                fontSize: '11px',
                color: 'var(--color-danger)',
                lineHeight: 1.6,
              }}>
                {error}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

