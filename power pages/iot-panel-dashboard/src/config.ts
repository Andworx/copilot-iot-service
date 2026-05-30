// Central configuration — reads env vars at build time from .env.local
// Copy .env.local.example → .env.local and fill in real values
//
// SECURITY NOTE: Never add secrets (keys, passwords, tokens) here.
// All values here are baked into the JS bundle and visible to any browser user.
// Secrets must stay server-side — see azure-functions/iot-signalr-func/src/app.js
// for the negotiate (anonymous) and directline-token (server-side secret) endpoints.

export const config = {
  // Azure Function base URL (without trailing slash or path)
  // e.g. https://func-aw-iot-copilot.azurewebsites.net
  signalrNegotiateUrl: import.meta.env.VITE_SIGNALR_NEGOTIATE_URL as string,

  // Azure Function endpoint that issues short-lived Direct Line tokens.
  // e.g. https://func-aw-iot-copilot.azurewebsites.net/api/directline-token
  // The actual Direct Line secret is stored in the Function app settings — never here.
  directlineTokenUrl: import.meta.env.VITE_DIRECTLINE_TOKEN_URL as string,

  // Target device ID (single Pi)
  targetDeviceId: import.meta.env.VITE_TARGET_DEVICE_ID as string || 'raspberry-pi-iotpanel',
} as const;

export const isDev = import.meta.env.DEV;
