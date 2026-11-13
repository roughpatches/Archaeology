# Session handoff

**Phase:** 4, vertical slice. The expedition gray-box passed (PR #3). The overworld (PR #4) was
merged on Andrew's call before a playtest. The supply boat, traders, collectors and coin (D42,
D43), camp upgrades (D44), the display shelf and journal (D45), one Philius story beat (D46)
and a title screen with pausing (D47) complete the slice. It is waiting for a playtest.

## Shipped so far

- Godot 4.7 project: pixel-art display settings, `GameState` and `SaveService` autoloads,
  versioned saves with migrations (now version 4), seeded RNG, debug overlay (`` ` ``), headless
  test runner, CI.
- Expedition (`core/expedition/`, `scenes/expedition/`): branching tunnels with one-way drops and
  unreliable hints (D31), a shifting jungle tomb (D32, D33), close camera and lamp light (D34),
  ways out (D38), smooth turn-based movement (D41).
- Overworld (`core/calendar.gd`, `core/overworld/`, `scenes/overworld/`): half-day time and
  seasons (D35, D36), the island around camp (D37), foraging, crafting gear (D39), Professor
  Philius, the tomb entrance.
- Supply boat (`core/boat.gd`, `core/finds.gd`): calls every 1–3 days with one of five traders
  and, often, a museum collector (D42, D43). Sell finds and crystal for coin (1–9, 0), buy gear
  from the outfitter (Z/X/C), donate to collectors for renown and a 150-coin grant per finished
  collection. The dock is south of camp.
- Camp (`core/overworld/camp.gd`, `core/overworld/story.gd`): the camp plans board (1-4 buy
  upgrades), the display shelf (1-9 put a find out, 0 take one down), the journal (J), Philius's
  star-reader beat, the title screen (`scenes/title/`) and pause menus (Esc).

## Next

1. Andrew plays the whole slice (title, island, tomb, boat, camp) and logs it in
   PLAYTEST_LOG.md. The slice is done when the loop plays start to finish and saves and reloads.
2. Phase 5 has started: RENDERING_CONTRACT.md and ART_GUIDE.md (D48). Next is art batch 1 and a
   code change that draws sprites where they exist and falls back to the gray-box shapes.

## Open questions

- D30: unlockable shortcuts and permanent anchors over several runs?
- What renown unlocks.
- Pixel Lab isn't reachable from cloud threads yet (needs a claude.ai connector, or the
  environment's network allowlist plus a secret).
- Quitting mid-expedition undoes the trip (D47). Fine for a slice; may want a real mid-run
  save later.

## Known issues

- None known.
