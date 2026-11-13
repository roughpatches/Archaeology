# Session handoff

**Phase:** 4, vertical slice. The expedition gray-box passed (PR #3). The overworld (PR #4) was
merged on Andrew's call before a playtest. The supply boat, traders, collectors and coin (D42,
D43) are the first slice pieces.

## Shipped so far

- Godot 4.7 project: pixel-art display settings, `GameState` and `SaveService` autoloads,
  versioned saves with migrations (now version 3), seeded RNG, debug overlay (`` ` ``), headless
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

## Next

1. Andrew plays the full loop (island, tomb, boat) and logs it in PLAYTEST_LOG.md.
2. Rest of the slice: camp upgrades bought with coin (brighter lamp, bigger bag, more stamina,
   permanent anchors from D30), a display shelf and journal, one story beat with Philius, a title
   screen and quitting mid-expedition.

## Open questions

- D30: unlockable shortcuts and permanent anchors over several runs?
- What renown unlocks.

## Known issues

- None known.
