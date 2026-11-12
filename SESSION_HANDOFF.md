# Session handoff

**Phase:** 2 to 3. The game was rescoped on 12 Nov 2026 (D19 to D27): one island, expeditions as
the core verb, Godot. The Godot project is set up; the expedition feel prototype is next.

## Shipped so far

- Godot 4.7 project: pixel-art display settings (480 × 270 base, integer scaling, nearest
  filtering), `GameState` and `SaveService` autoloads, versioned saves with migrations, a seeded RNG
  in `core/`, a boot scene with a debug overlay (`` ` ``), a headless test runner, and CI.
- The Phaser gray-box (dig v1 playtested and passed, dig v2 and survey built but not playtested)
  stays on its branch as a reference. Its feel specs are in `docs/phaser-prototype/`.

## Next

1. Andrew opens the project in Godot 4.7.2 and confirms it runs.
2. Feel spec for the expedition (FEEL_EXPEDITION.md): read, decide, feedback, and the numbers to
   start from.
3. Expedition gray-box: generated floors from room pieces, stamina and supplies, a dig spot with the
   four tools and lifting, avoid-or-scare creatures, descend or turn back. Then a playtest.

## Open questions

- D26: do overworld days still end when you sleep? (Assumed yes.)
- Does depth over several runs (shortcuts) replace multi-day digs (D16)?

## Known issues

- Godot can't be downloaded in the Default cloud environment. Use the "Archaeology Game (Godot)"
  environment, which allows GitHub, to run Godot in cloud sessions.
