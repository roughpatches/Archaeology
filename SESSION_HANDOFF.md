# Session handoff

**Phase:** 3, feel prototype (gray-box dig).

## Shipped last session

- Repository set up: Phaser 3.90 + Vite + TypeScript, ESLint, Prettier, Vitest, CI.
- The dig as pure rules (`src/engine/dig.ts`) with tests, including a bot showing that a better map
  gives a better dig.
- A gray-box Phaser scene for it (`src/scenes/DigScene.ts`) with a debug overlay.
- Pitch, decisions D1 to D12, and the feel spec.

## Next

1. Andrew plays the gray-box and fills in PLAYTEST_LOG.md.
2. Rework the dig from what the playtest says (back to the three feel questions first).
3. Once the dig passes: gray-box the survey-to-map hand-off.

## Open questions

- Is a fine map too generous? (FEEL_DIG.md, question 4.)

## Known issues

- None known. The production bundle is about 1.2 MB, almost all Phaser; fine for now.
