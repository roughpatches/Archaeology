# Session handoff

**Phase:** 3, feel prototype. Dig v1 passed its first playtest; dig v2 and the survey are built
and waiting for a playtest.

## Shipped so far

- Repository set up: Phaser 3.90 + Vite + TypeScript, ESLint, Prettier, Vitest, CI.
- Dig v1, playtested by Andrew (PLAYTEST_LOG.md).
- Dig v2 (D13 to D16): four tools, three finds per site including a Lantern Crown piece, holding
  to lift a find, and digs over several days with overnight weathering.
- Survey (D18): noisy readings build the site map; each find's grade comes from the survey and
  sets its context. The survey scene opens each site and hands its map to the dig
  (`src/engine/survey.ts`, `src/scenes/SurveyScene.ts`).
- The finds tray and Crown pieces live in the Phaser registry so they last across sites, for the
  session only.

## Next

1. Andrew playtests the survey and dig v2 together and logs it.
2. Gray-box scouting (FEEL_FIELDWORK.md): a region, surface signs, staking a claim that opens a
   survey.
3. Chain scouting, survey and dig over several days, then playtest the whole process.

## Open questions

- The playtest questions in FEEL_DIG.md and FEEL_FIELDWORK.md.

## Known issues

- No save yet: the finds tray resets when the page closes.
- The production bundle is about 1.2 MB, almost all Phaser.
