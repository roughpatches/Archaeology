# Feel spec: the expedition (gray-box v1)

The expedition is the core verb (D23). This gray-box tests one question: **is pushing deeper
tense, and is finding things along the way satisfying?** Coloured squares only. Every number
below is a starting value for tuning.

## The run

- Press **X** at the camp placeholder. An expedition starts on floor 1 with the day's stamina
  (100 on a fresh day).
- Each floor is generated from a seed as **branching tunnels** (D31): it runs left to right
  through 5 layers of chambers. You land in the first chamber, where the **rope** (green) is.
  Tunnels fork forward from each chamber to one or more chambers in the next layer. Every chamber
  in the last layer has the **way down** (purple); on floor 5 it has a rope out instead. 5 floors.
- **Every tunnel ends in a drop** (pale tile with a ">"). You can stand on the lip and turn back,
  but once you step off there is no climbing back up. Taking a fork is a commitment.
- Each chamber holds one thing: a dig site, two crystals, a creature (two from floor 4; none on
  floor 1), a spring (+15 stamina, once), or nothing.
- **No clock (D26). Turn-based (D29):** every step and every action is one tick, and creatures
  move on ticks. Standing still to dig lets them come to you.
- Walking is free. Stamina pays for everything else:

| Action                         | Stamina |
| ------------------------------ | ------- |
| Survey reading (Q)             | 4       |
| Spring (walk onto it)          | +15     |
| Go down a floor (E on stairs)  | 3       |
| Mine a crystal (walk into it)  | 2       |
| Dig: pick / trowel / brush / probe | 3 / 1 / 2 / 1 |
| Lift a find (L)                | 2       |
| Bitten by a creature           | 10      |

- **Climb out** (E on the rope at a floor's landing, or at the far end of floor 5) to end the run
  with the whole bag. So the push-or-return choice comes at each landing, before the first fork.
- **Run out of stamina** and Professor Philius drags you home: you lose half the bag, rounded up.
- The bag holds 8 items. Two flares per run.

## Read: what the player sees

- Fog of war: tiles within 4 steps are lit; tiles seen before stay dim. You **can't see into a
  chamber until you drop into it**; then all of it shows.
- **Tunnel hints:** each tunnel mouth is labelled with what seems to be beyond it ("old
  stonework?", "a glint?", "scratching?", "trickling water?", "still air?"). A hint is right
  65% of the time. A survey reading makes the hints of the tunnels leading on from where you
  stand true (gold, no question mark).
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

1. **Which way on.** At each fork, pick a tunnel from its hint, knowing hints are wrong a third
   of the time. You can walk to the lip to look down the tunnel, but not into the chamber, and
   walking lets creatures move. You get one chamber per layer, so every pick gives up the others.
2. **Push deeper or climb out.** Deeper floors hold rarer finds (rare: 5% on floor 1, 29% on
   floor 5) and more creatures. You can only climb out at a landing (before the first fork) or
   at the end of floor 5. Collapsing costs half the bag.
3. **Survey or not.** 4 stamina for a reading: it makes the hints ahead true, finds hidden
   spots and makes their finds documented (worth more to museums, D22), and shows you where to
   dig. Skip it and trust the hints and stains.
4. **Dig carefully or quickly.** Pick and trowel are cheap but chip the find on its last layer;
   the brush is safe but costs more. Clearing round the find before lifting costs stamina but
   saves damage. Every action is a tick, so a creature nearby makes slow work risky.
5. **Flare now or save it.** Two per run.
6. **What fills the bag.** Eight slots: crystals for camp, or room for one more find.

What a player can do wrong: chip a find, lift it while locked in, waste stamina digging empty
ground, get bitten while digging, trust a wrong hint into a creature's chamber, go one floor too deep and collapse.

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

1. Forks (D31): did choosing a tunnel feel like a real choice? Did you trust the hints, survey
   to check them, or walk to the lip first? Did the one-way drops feel tense or unfair?
2. Did you feel the pull between going deeper and climbing out? On which floor did you turn back,
   and why?
3. Did surveying feel worth 4 stamina, or did you skip it?
4. Do the dig spots feel like a satisfying moment inside the run, or an interruption?
5. Did creatures add tension, or just annoyance? Did flares feel useful?
6. Turn-based (D29): did it feel right, or should the expedition move in real time like the
   overworld will?
