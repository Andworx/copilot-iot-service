import { defineConfig } from "@playwright/test";

import { resolvePortalBaseUrl } from "./tests/e2e/utils/environment";

export default defineConfig({
  testDir: "./tests/e2e/specs",
  fullyParallel: true,
  timeout: 30_000,
  expect: {
    timeout: 5_000
  },
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ["list"],
    ["html", { open: "never", outputFolder: "playwright-report" }]
  ],
  use: {
    baseURL: resolvePortalBaseUrl(),
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure"
  },
  projects: [
    {
      name: "contract",
      testIgnore: ["**/*.live.spec.ts", "**/*.smoke.spec.ts", "**/*.deferred.spec.ts"]
    },
    {
      name: "live",
      testMatch: ["**/*.live.spec.ts", "**/*.smoke.spec.ts", "**/*.deferred.spec.ts"],
      retries: process.env.CI ? 1 : 0,
      timeout: 45_000,
      expect: { timeout: 8_000 }
    }
  ]
});
