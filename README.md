# Archaeology

A top-down fantasy archaeology game for desktop, made in Godot 4.7. You are an archaeologist on a
mysterious island: prepare at base camp, then set out on procedurally generated expeditions to
recover the finds that explain the island.

## Running it

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (the standard
   build, not .NET).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** to run. Press `` ` `` in game for the debug overlay.

## Tests

```
godot --headless --import            # first time only, builds the .godot cache
godot --headless -s res://tests/run_tests.gd
```

CI runs the same on every push, plus `gdlint` and `gdformat --check` from
[gdtoolkit](https://pypi.org/project/gdtoolkit/).

## Where things are

- `core/`: game rules as plain GDScript, no nodes or scenes. Tested directly.
- `autoload/`: `GameState` (owns everything that is saved) and `SaveService`.
- `scenes/`: what the player sees. Scenes read and call `core/` and `GameState`; they never own
  saved state.
- `data/`: content as Godot resources (finds, areas, room pieces), added as it is needed.
- `tests/`: the test runner and `test_*.gd` files.
- `docs/phaser-prototype/`: feel specs from the earlier Phaser gray-box.

Read `CLAUDE.md`, `DECISIONS.md` and `SESSION_HANDOFF.md` before changing anything.
