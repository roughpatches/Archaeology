# Session handoff

**Phase:** 3, feel prototype. The game was rescoped on 12 Nov 2026 (D19 to D27). The Godot setup
is merged; the expedition gray-box (D28, D29, FEEL_EXPEDITION.md) is built and waiting for a
playtest.

## Shipped so far

- Godot 4.7 project: pixel-art display settings (480 × 270 base, integer scaling, nearest
  filtering), `GameState` and `SaveService` autoloads, versioned saves with migrations, a seeded RNG
  in `core/`, a boot scene with a debug overlay (`` ` ``), a headless test runner, and CI.
- The Phaser gray-box (dig v1 playtested and passed, dig v2 and survey built but not playtested)
  stays on its branch as a reference. Its feel specs are in `docs/phaser-prototype/`.

- Expedition gray-box: `core/expedition/` (floor_gen, dig_spot, expedition) with tests, and
  `scenes/expedition/` (explore view and dig view). Press X at the camp placeholder.

## Next

1. Andrew playtests the expedition and logs it in PLAYTEST_LOG.md (questions in
   FEEL_EXPEDITION.md).
2. Rework or pass. Then the overworld day gray-box: walk, gather, craft supplies, build, sleep.

## Open questions

- D26: do overworld days still end when you sleep? (Assumed yes.)
- D30: does depth over several runs (shortcuts) replace multi-day digs (D16)?

## Known issues

- Godot can't be downloaded in the Default cloud environment. Use the "Archaeology Game (Godot)"
  environment, which allows GitHub, to run Godot in cloud sessions.
