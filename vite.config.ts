import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Relative paths so a build can be served from any folder (GitHub Pages, itch.io, a local server).
  base: './',
  build: { chunkSizeWarningLimit: 2000 },
  test: { include: ['tests/**/*.test.ts'] },
});
