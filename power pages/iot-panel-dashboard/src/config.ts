// Central configuration — reads env vars at build time from .env.local
// Copy .env.local.example → .env.local and fill in real values

export const config = {
  // Azure Function base URL (without trailing slash or path)
  // e.g. https://func-aw-iot-signalr.azurewebsites.net
  signalrNegotiateUrl: import.meta.env.VITE_SIGNALR_NEGOTIATE_URL as string,

  // Azure Function access key for the negotiate endpoint
  signalrFuncKey: import.meta.env.VITE_SIGNALR_FUNC_KEY as string,

  // Target device ID (single Pi)
  targetDeviceId: import.meta.env.VITE_TARGET_DEVICE_ID as string || 'raspberry-pi-iotpanel',

  // Copilot Studio Direct Line token endpoint URL
  // Get from: Copilot Studio → your agent → Channels → Direct Line → Copy Token URL
  copilotDirectLineTokenUrl: import.meta.env.VITE_COPILOT_DIRECTLINE_TOKEN_URL as string,
} as const;

export const isDev = import.meta.env.DEV;
