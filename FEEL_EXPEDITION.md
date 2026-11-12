# Feel spec: the expedition (gray-box v1)

The expedition is the core verb (D23). This gray-box tests one question: **is pushing deeper
tense, and is finding things along the way satisfying?** Coloured squares only. Every number
below is a starting value for tuning.

## The run

- Press **X** at the camp placeholder. An expedition starts on floor 1 with the day's stamina
  (100 on a fresh day).
- Each floor is generated from a seed: 9 hand-made room pieces in a 3 × 3 grid, joined by doors
  (a spanning tree plus one extra link). The **rope** (green) is in a random room; the **way
  down** (purple) is in the room farthest from it. 5 floors.
- **No clock (D26). Turn-based (D29):** every step and every action is one tick, and creatures
  move on ticks. Standing still to dig lets them come to you.
- Walking is free. Stamina pays for everything else:

| Action                         | Stamina |
| ------------------------------ | ------- |
| Survey reading (Q)             | 4       |
| Go down a floor (E on stairs)  | 3       |
| Mine a crystal (walk into it)  | 2       |
| Dig: pick / trowel / brush / probe | 3 / 1 / 2 / 1 |
| Lift a find (L)                | 2       |
| Bitten by a creature           | 10      |

- **Climb out** (E on the rope of the floor you're on) to end the run with the whole bag.
- **Run out of stamina** and Professor Philius drags you home: you lose half the bag, rounded up.
- The bag holds 8 items. Two flares per run.

## Read: what the player sees

- Fog of war: tiles within 4 steps are lit; tiles seen before stay dim.
- **Dig spots** show as orange "dig" marks when you come within 4 steps, but only 60% of them
  show surface signs. A **survey** reading finds every spot within 5 steps, signs or not, and
  maps it (gold mark).
- Crystals (cyan) sit in the open: walk into one to mine it.
- Creatures (red) show only within your light. Pink means fleeing, dark red means stunned.
- "Something is closing in..." whenever a creature within 5 steps is hunting you.
- In a dig spot: 6 × 5 tiles, 1 to 3 layers, one find of 2 to 4 tiles. Soil lightens as layers
  come off; a dark green stain shows on most find tiles (and a few empty ones) one layer above the
  find. A surveyed spot shows the find's outline in blue with its depth. Probed tiles show layers
  left, with `!` over the find. Once the find is free, soil still packed against it is outlined
  orange, and the status line shows the damage a lift would do now.

## Decide: the real choices

1. **Push deeper or climb out.** Deeper floors hold rarer finds (rare: 5% on floor 1, 29% on
   floor 5) and one more creature each. Climbing out is only possible from the rope, which is on
   the far side of the floor from the stairs. Collapsing costs half the bag.
2. **Survey or not.** 4 stamina for a reading: it finds hidden spots and makes their finds
   documented (worth more to museums, D22), and shows you where to dig. Skip it and dig blind
   from stains.
3. **Dig carefully or quickly.** Pick and trowel are cheap but chip the find on its last layer;
   the brush is safe but costs more. Clearing round the find before lifting costs stamina but
   saves damage. Every action is a tick, so a creature nearby makes slow work risky.
4. **Flare now or save it.** Two per run.
5. **What fills the bag.** Eight slots: crystals for camp, or room for one more find.

What a player can do wrong: chip a find, lift it while locked in, waste stamina digging empty
ground, get bitten while digging, go one floor too deep and collapse on the way back.

## Feedback

- Chip: the dig screen shakes, "Chip!", a red slash on the tile.
- Clean exposure: the tile turns gold, "Found something!", then "Free! Press L to lift".
- Lift: the find's name and condition in large text (PRISTINE / INTACT / WORN / FRAGMENT) and
  its context.
- Bite: "Bitten! -10 stamina" in the log.
- End of run: a summary of the bag. Climbed out keeps everything; collapsed shows what was lost.
- Back at camp, finds and crystals are added to the save.

## Gray-box limits (on purpose)

No art, sound, camp, crafting, supply boat, shortcuts between runs, or creature variety. Creatures
are one kind that wanders, hunts within 5 steps, bites when next to you, then is stunned for 3
ticks.

## Questions the playtest should answer

1. Did you feel the pull between going deeper and climbing out? On which floor did you turn back,
   and why?
2. Did surveying feel worth 4 stamina, or did you skip it?
3. Do the dig spots feel like a satisfying moment inside the run, or an interruption?
4. Did creatures add tension, or just annoyance? Did flares feel useful?
5. Turn-based (D29): did it feel right, or should the expedition move in real time like the
   overworld will?
