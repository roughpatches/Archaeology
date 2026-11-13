# Working on Archaeology

Read DECISIONS.md and SESSION_HANDOFF.md first, and confirm the current phase before doing anything.

## Stack

Godot 4.7.2-stable (standard build, not .NET), GDScript, desktop only (D19, D24). Tests run headless
with the in-repo runner (D27). Lint and format with gdtoolkit (`gdlint`, `gdformat`).

## Rules

- **Game rules live in `core/` and stay pure:** plain `RefCounted` classes, no `Node`, no scenes, no
  autoloads, no `Input`. Scenes read state and call `core/` functions; they never own saved state.
- **`GameState` owns everything saved.** It is a plain dictionary with a schema version. Any change
  to its shape bumps `SaveMigrations.CURRENT_VERSION` and adds a migration step with a test.
- **Seeded randomness only** in `core/`: take a `SeededRng` (or a seed) as an argument, never call
  global `randi()`/`randf()`. The same seed must always make the same floor.
- No `class_name` in `core/`: other scripts reach it through `preload("res://core/...")` constants.
  That keeps headless tests independent of the editor's class cache and avoids name clashes with
  autoloads.
- **Prove the verb before building around it.** Gray-box shapes and a debug overlay first. No art,
  content or adjacent systems until a mechanic passes a playtest in PLAYTEST_LOG.md.
- Every tuning number is a starting value, not a decision.
- New decisions go into DECISIONS.md with the next number. Never edit a decision silently; supersede
  it.
- Before pushing: `gdformat --check . && gdlint . && godot --headless -s res://tests/run_tests.gd`.

## Layout

- `core/` rules · `autoload/` GameState, SaveService · `scenes/` · `data/` resources · `tests/`
- `docs/phaser-prototype/` holds the feel specs and numbers from the Phaser gray-box; port its rules
  by hand when the expedition needs them.

## Porting

The Phaser gray-box (branch `claude/project-thread-bygetk`, draft PR #1) has the dig and survey rules
in `src/engine/dig.ts` and `src/engine/survey.ts`, with tests. The Last Archive
(roughpatches/thelastarchive) has save migrations and loot tables worth copying as ideas. Copy and
adapt; don't depend on either.
