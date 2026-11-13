# Feel spec: the expedition (gray-box v2, jungle tomb)

The expedition is the core verb (D23). This gray-box tests one question: **is pushing deeper
tense, and is finding things along the way satisfying?** Coloured squares only. Every number
below is a starting value for tuning.

## The run

- Walk to the **tomb entrance** on the island and press E twice. An expedition starts on floor 1
  with the stamina you have and all your gear (D39), and always takes half a day (D35). At
  night the tomb has more creatures; in the Rains, more streams (D36).
- The first expedition is an **ancient jungle tomb** (D33).
- Each floor is generated from a seed as **branching tunnels** (D31): it runs left to right
  through 5 layers of chambers. You land in the first chamber, where the **rope** (green) is.
  Tunnels fork forward from each chamber to one or more chambers in the next layer. Every chamber
  in the last layer has the **way down** (purple); on floor 5 it has a rope out instead. 5 floors.
- **Every tunnel ends in a drop** (pale tile with a ">"). You can stand on the lip and turn back,
  but once you step off there is no climbing back up. Taking a fork is a commitment.
- Chambers are 13 × 9 tiles, bigger than the screen (D34). Each chamber holds one thing: a dig site, two crystals, a creature (two from floor 4; none on
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
| Wade a stream tile             | 1       |
| Clear a rubble tile (walk into it) | 3   |
| Hit by a rockfall              | 8       |

- **Climb out** (E on a way out) to end the run with the whole bag. **Getting out is part of the
  run (D38):** the rope you came in by is only on floor 1. Deeper, you need a rope anchor you
  rig (T, in a chamber, 4 stamina), a natural shaft ("daylight"; a hint mentioning a warm draft
  leads to one), or the far end of floor 5. Rations (R) give back 20 stamina.
- **Run out of stamina** and Professor Philius drags you home: you lose half the bag, rounded up.
- The bag holds 8 items. Two flares per run.

## Read: what the player sees

- **Lamp light only (D34):** you see 5 steps over open ground and the walls around it, fading
  at the edge. Nothing stays lit behind you, so you can't see where you came from or where
  you're going. You can't see into a chamber until you drop into it.
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

## The shifting tomb (D32)

- **Rockfalls:** "Dust trickles from the ceiling" and a cross of tiles near you shows falling
  dust. Two ticks later they turn to rubble. Standing under it costs 8 stamina. Walk into rubble
  to clear a tile (3 stamina).
- **Collapses:** "A deep groan from one of the tunnels ahead" and three ticks later the first
  tiles of one way on fill with rubble and its hint reads "caved in". It never takes your last
  way on, and you can dig it out (3 a tile) if you want that way badly enough.
- **Streams:** some chambers have a stream running top to bottom. It moves one column every 6
  ticks. Wading costs 1 stamina a tile, and creatures won't cross it, so it can be a refuge.
- A rumble may start on any tick with nothing already rumbling: 4% plus 1% per floor.

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
6. **Stay or move.** Dust overhead, a groan ahead: step clear, push through before a tunnel
   caves in, or wade a stream to put water between you and a creature.
7. **What fills the bag.** Eight slots: crystals for camp, or room for one more find.

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

1. Shifting tomb (D32): did rockfalls, collapses and streams make the tomb feel alive, or just
   cost stamina? Were the warnings enough time to react?
2. Camera and light (D34): do chambers feel big? Is not seeing behind you tense, or
   disorienting in a bad way?

3. Forks (D31): did choosing a tunnel feel like a real choice? Did you trust the hints, survey
   to check them, or walk to the lip first? Did the one-way drops feel tense or unfair?
4. Did you feel the pull between going deeper and climbing out? On which floor did you turn back,
   and why?
5. Did surveying feel worth 4 stamina, or did you skip it?
6. Do the dig spots feel like a satisfying moment inside the run, or an interruption?
7. Did creatures add tension, or just annoyance? Did flares feel useful?
8. Turn-based (D29): did it feel right, or should the expedition move in real time like the
   overworld will?
