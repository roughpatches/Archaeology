# Session handoff

**Phase:** 3, feel prototype. The dig passed its first playtest as a prototype; v2 is built and
waiting for its playtest.

## Shipped last session

- Repository set up: Phaser 3.90 + Vite + TypeScript, ESLint, Prettier, Vitest, CI.
- Dig v1, playtested by Andrew (PLAYTEST_LOG.md).
- Dig v2 (D13 to D16): four tools (pick, trowel, brush, probe), three finds per site including a
  Lantern Crown piece, holding to lift a find with damage from soil still against it, and digs
  over several days with overnight weathering. Rules in `src/engine/dig.ts`, scene in
  `src/scenes/DigScene.ts`.
- FEEL_FIELDWORK.md: the proposal for scouting and surveying (D17).

## Next

1. Andrew playtests dig v2 and logs it.
2. Gray-box the survey (FEEL_FIELDWORK.md), so the dig's map comes from surveying.
3. Then scouting, then the three chained over several days.

## Open questions

- The four FEEL_DIG.md playtest questions.

## Known issues

- Finds-tray progress lasts only for the session; there is no save yet.
- The production bundle is about 1.2 MB, almost all Phaser.
