import { readFileSync } from "node:fs";
import path from "node:path";

type DevConfig = {
  environmentUrl?: string;
};

function readDevConfig(): DevConfig {
  const configPath = path.resolve(process.cwd(), "scripts", "config-dev.json");
  return JSON.parse(readFileSync(configPath, "utf8")) as DevConfig;
}

export function resolvePortalBaseUrl(): string {
  return process.env.PLAYWRIGHT_BASE_URL || readDevConfig().environmentUrl || "https://YOUR_ORG_URL";
}
