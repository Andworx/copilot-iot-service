/**
 * Shared formatting utilities extracted as module-level pure functions.
 * Being module-scoped, these are defined once and never re-created on render.
 * hexToRgb uses a lookup cache to avoid repeated parseInt calls for the same color.
 */

const hexCache = new Map<string, string>();

/** Convert a hex color (#RRGGBB) to an "R, G, B" string for use in rgba(). */
export function hexToRgb(hex: string): string {
  const cached = hexCache.get(hex);
  if (cached) return cached;

  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  const result = `${r}, ${g}, ${b}`;
  hexCache.set(hex, result);
  return result;
}

/** Format an ISO timestamp to a locale date+time string. */
export function formatTime(iso: string): string {
  try {
    const d = new Date(iso);
    return `${d.toLocaleDateString()} ${d.toLocaleTimeString()}`;
  } catch {
    return iso;
  }
}

/** Format a Date as relative time (e.g. "5s ago", "3m ago", "2h ago"). */
export function formatLastSeen(d: Date | null): string {
  if (!d) return '—';
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}
