import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './test/browser',
  fullyParallel: true,
  workers: 2,
  use: {
    channel: process.platform === 'win32' ? 'msedge' : undefined,
    baseURL: 'http://127.0.0.1:4174/QueryBuilder4Delphi/',
    viewport: { width: 1366, height: 900 },
  },
  webServer: {
    command: 'node preview.mjs',
    env: { PORT: '4174', BASE_PATH: '/QueryBuilder4Delphi/' },
    url: 'http://127.0.0.1:4174/QueryBuilder4Delphi/',
  },
});
