import { defineConfig } from "@playwright/test";

import { resolvePortalBaseUrl } from "./tests/e2e/utils/environment";

export default defineConfig({
  testDir: "./tests/e2e/specs",
  testMatch: ["**/*.live.spec.ts", "**/*.smoke.spec.ts", "**/*.deferred.spec.ts"],
  fullyParallel: false,
  timeout: 45_000,
  expect: {
    timeout: 8_000
  },
  retries: process.env.CI ? 1 : 0,
  reporter: [
    ["list"],
    ["html", { open: "never", outputFolder: "playwright-report-live" }]
  ],
  use: {
    baseURL: resolvePortalBaseUrl(),
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure"
  }
});
