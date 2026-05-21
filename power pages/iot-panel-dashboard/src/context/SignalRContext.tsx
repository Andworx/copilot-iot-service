import { createContext, useContext, type ReactNode } from 'react';
import { useSignalR, type SignalRState } from '../hooks/useSignalR';

export const SignalRContext = createContext<SignalRState | null>(null);

export function SignalRProvider({ children }: { children: ReactNode }) {
  const state = useSignalR();
  return <SignalRContext.Provider value={state}>{children}</SignalRContext.Provider>;
}

export function useSignalRContext(): SignalRState {
  const ctx = useContext(SignalRContext);
  if (!ctx) throw new Error('useSignalRContext must be used inside <SignalRContext.Provider>');
  return ctx;
}
