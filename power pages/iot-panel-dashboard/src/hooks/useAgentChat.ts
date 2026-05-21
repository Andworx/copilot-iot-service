import { useState, useCallback, useRef } from 'react';
import { config } from '../config';

const DIRECTLINE_BASE = 'https://directline.botframework.com/v3/directline';
const POLL_INTERVAL_MS = 1500;
const MAX_POLL_ATTEMPTS = 20; // ~30 s max

interface DLActivity {
  type: string;
  id?: string;
  from: { id: string; role?: string };
  text?: string;
  timestamp?: string;
}

interface DLActivities {
  activities: DLActivity[];
  watermark?: string;
}

export type AgentChatStatus = 'idle' | 'loading' | 'done' | 'error';

export interface AgentChatState {
  status: AgentChatStatus;
  response: string | null;
  error: string | null;
  sendPrompt: (prompt: string) => Promise<void>;
  reset: () => void;
}

export function useAgentChat(): AgentChatState {
  const [status, setStatus] = useState<AgentChatStatus>('idle');
  const [response, setResponse] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef(false);

  const reset = useCallback(() => {
    abortRef.current = true;
    setStatus('idle');
    setResponse(null);
    setError(null);
  }, []);

  const sendPrompt = useCallback(async (prompt: string) => {
    if (!config.copilotDirectLineTokenUrl) {
      setError('Copilot agent not configured. Set VITE_COPILOT_DIRECTLINE_TOKEN_URL in .env.local.');
      setStatus('error');
      return;
    }

    abortRef.current = false;
    setStatus('loading');
    setResponse(null);
    setError(null);

    try {
      // 1. Fetch Direct Line token from Copilot Studio
      const tokenRes = await fetch(config.copilotDirectLineTokenUrl);
      if (!tokenRes.ok) throw new Error(`Token fetch failed (${tokenRes.status})`);
      const tokenData = await tokenRes.json() as { token: string };
      const dlToken = tokenData.token;

      if (abortRef.current) return;

      // 2. Start a fresh Direct Line conversation
      const convRes = await fetch(`${DIRECTLINE_BASE}/conversations`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${dlToken}` },
      });
      if (!convRes.ok) throw new Error(`Start conversation failed (${convRes.status})`);
      const conv = await convRes.json() as { conversationId: string; token: string };
      const { conversationId } = conv;

      if (abortRef.current) return;

      // 3. Get initial watermark — skip any bot greeting that fires on open
      const initRes = await fetch(`${DIRECTLINE_BASE}/conversations/${conversationId}/activities`, {
        headers: { Authorization: `Bearer ${dlToken}` },
      });
      const initData = await initRes.json() as DLActivities;
      let watermark = initData.watermark ?? '0';

      if (abortRef.current) return;

      // 4. Send the user's prompt
      const sendRes = await fetch(
        `${DIRECTLINE_BASE}/conversations/${conversationId}/activities`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${dlToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            type: 'message',
            from: { id: 'iot-dashboard-user' },
            text: prompt,
          }),
        },
      );
      if (!sendRes.ok) throw new Error(`Send message failed (${sendRes.status})`);

      if (abortRef.current) return;

      // 5. Poll for the bot's response
      for (let i = 0; i < MAX_POLL_ATTEMPTS; i++) {
        if (abortRef.current) return;

        await new Promise<void>(r => setTimeout(r, POLL_INTERVAL_MS));

        const pollRes = await fetch(
          `${DIRECTLINE_BASE}/conversations/${conversationId}/activities?watermark=${watermark}`,
          { headers: { Authorization: `Bearer ${dlToken}` } },
        );
        if (!pollRes.ok) throw new Error(`Poll failed (${pollRes.status})`);

        const data = await pollRes.json() as DLActivities;
        watermark = data.watermark ?? watermark;

        const botMessages = data.activities.filter(
          a => a.type === 'message' && a.from.id !== 'iot-dashboard-user' && a.text?.trim(),
        );

        if (botMessages.length > 0) {
          setResponse(botMessages[botMessages.length - 1].text!.trim());
          setStatus('done');
          return;
        }
      }

      throw new Error('Agent did not respond in time. Please try again.');
    } catch (err) {
      if (!abortRef.current) {
        setError(err instanceof Error ? err.message : 'Unknown error occurred');
        setStatus('error');
      }
    }
  }, []);

  return { status, response, error, sendPrompt, reset };
}
