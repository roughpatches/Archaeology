# Session handoff

**Phase:** 3, feel prototypes. The expedition gray-box is merged (PR #3; Andrew: "this is what I
had in mind"). The overworld gray-box (D35 to D40, FEEL_OVERWORLD.md) is built and waiting for a
playtest.

## Shipped so far

- Godot 4.7 project: pixel-art display settings, `GameState` and `SaveService` autoloads,
  versioned saves with migrations (now version 2), seeded RNG, debug overlay (`` ` ``), headless
  test runner, CI.
- Expedition (`core/expedition/`, `scenes/expedition/`): branching tunnels with one-way drops and
  unreliable hints (D31), a shifting jungle tomb (D32, D33), close camera and lamp light (D34),
  ways out (D38).
- Overworld (`core/calendar.gd`, `core/overworld/`, `scenes/overworld/`): half-day time and
  seasons (D35, D36), the island around camp (D37), foraging, crafting gear (D39), Professor
  Philius, the tomb entrance. The boot scene loads or starts a game and goes to the island.

## Next

1. Andrew playtests the overworld and the full loop (island, tomb, home) and logs it in
   PLAYTEST_LOG.md (questions in FEEL_OVERWORLD.md and FEEL_EXPEDITION.md).
2. Rework or pass. Then the vertical slice (phase 4): supply boat, selling and donating finds,
   displays, camp building.

## Open questions

- D30: unlockable shortcuts and permanent anchors over several runs, replacing multi-day digs
  (D16)?
- What the supply boat, museums and camp building look like in the slice.

## Known issues

- None known. Godot downloads work from cloud sessions now; the "Archaeology Game (Godot)"
  environment is the fallback.
