# Working on Archaeology

Read DECISIONS.md and SESSION_HANDOFF.md first, and confirm the current phase before doing anything.

## Stack

Phaser 3 + Vite + TypeScript, desktop browser only, Vitest for tests. No backend.

## Rules

- **Game rules live in `src/engine` and stay pure:** no Phaser, no DOM, no `window`. ESLint enforces
  this. Scenes read engine state and call engine functions; they never own persistent state.
- **Prove the verb before building around it.** We are in the feel-prototype phase (see
  FEEL_DIG.md). Don't add art, content or adjacent systems until the dig passes a playtest in
  PLAYTEST_LOG.md.
- Gray-box means placeholder shapes, no final art, and a debug overlay (`` ` ``) that shows internal
  values. Keep the debug overlay until the vertical slice is done.
- Every number in `DEFAULT_CONFIG` is a starting value for tuning, not a decision.
- New decisions go into DECISIONS.md with the next number. Never edit a decision silently; supersede
  it.
- Before pushing: `npm run lint && npm run format:check && npm run check && npm test && npm run build`.

## Porting from The Last Archive

The earlier game (roughpatches/thelastarchive) has engine code worth copying when a system needs it:
seeded RNG (already copied to `src/engine/rng.ts`), save and migrations, loot tables, survey
coverage, and the minigame model/renderer split. Copy the module and adapt it; don't add a
dependency on that repo.
