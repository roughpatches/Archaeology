# Feel spec: the overworld (gray-box v1)

The overworld is the calmer, cozier, exploratory half of the game (D37). This gray-box tests one
question: **is preparing for an expedition, around time and season, a pleasant set of real
choices?** Coloured shapes only. Every number is a starting value.

## The loop

- You start on the beach by camp: a **tent** (rest), a **workbench** (craft) and **Professor
  Philius**. Jungle paths lead north past plants to the **tomb entrance**.
- **No clock (D35).** A day has two halves, day and night. Time moves only when you:
  - **rest** at the tent: half a day passes, stamina back to full, the game saves;
  - **go into the tomb**: always half a day, whatever happens inside.
- **Walking is free; gathering costs 2 stamina.** Stamina is shared with the tomb (D40).
- **Seasons (D36):** Dry season, the Rains, Bloom, the Mists, 7 days each (placeholders).

| Plant      | When            | Seasons                 | Best season (gives 2) | Grows back |
| ---------- | --------------- | ----------------------- | --------------------- | ---------- |
| Vine fiber | day and night   | all                     | the Rains             | 2 halves   |
| Hardwood   | day and night   | all                     | none                  | 4 halves   |
| Resin      | day             | Dry, Bloom, Mists       | Dry season            | 4 halves   |
| Wild fruit | day             | the Rains, Bloom        | Bloom                 | 4 halves   |
| Glowcap    | night           | the Rains, Bloom, Mists | the Mists             | 2 halves   |

| Gear (workbench) | Recipe                     | In the tomb                               |
| ---------------- | -------------------------- | ----------------------------------------- |
| Rope anchor      | 2 vine fiber + 1 hardwood  | T: rig a way out in any chamber (4 stamina) |
| Flare            | 1 resin + 1 vine fiber     | F: creatures nearby flee                  |
| Trail ration     | 1 wild fruit + 1 glowcap   | R: +20 stamina                            |

You carry at most 3 of each and take all of it in; what you don't use comes home.

## Getting out of the tomb (D38)

The rope you came in by is only on floor 1. Deeper, you need a way out: a rope anchor you rig, a
natural shaft ("daylight"; a tunnel hint that mentions **a warm draft** leads to one), or the far
end of floor 5. No way out and no stamina means you collapse: Professor Philius drags you home and
half the bag is lost.

## Read: what the player sees

- Top of the screen: day, half, season and day of season; stamina; the pack; what you've gathered.
- Bottom: what you can do with the thing in reach, or why not ("Glowcap only shows itself at
  night", "Picked clean. It'll grow back.", "Nothing fruits..."), and the last thing that happened.
- Plants ready to gather are solid dots; ones that aren't (wrong time, season, or picked) are
  rings.
- Night: only your lamp lights the island; things beyond it disappear.
- Season colours the grass and jungle (dry gold, rain-dark green, bloom green, misty grey-green).

## Decide: the real choices

1. **Gather or set out.** Every stamina point spent gathering is one you don't take into the tomb.
2. **Day or night.** Resin and fruit only by day; glowcaps only at night. The tomb at night holds
   more creatures. Rest to change the half, at the cost of half a day.
3. **What to make.** Anchors to get out deep, flares to keep creatures off, rations to stretch a
   run. Materials overlap (vine fiber goes into both anchors and flares).
4. **When in the season.** Plants give double in their best season; fruit is gone in the Dry
   season, and the Rains flood the tomb with streams.

What a player can do wrong: tire themselves out gathering then go in weak, go deep without an
anchor, run out of fiber for both anchors and flares.

## Feedback

- Gathering: "Gathered Resin." and the count goes up; the plant turns to a ring.
- Crafting: "Made a Rope anchor." and the pack count goes up.
- Resting: "You rest until nightfall. Stamina restored." The island darkens or brightens.
- Professor Philius has lines for each season and for the night.
- Back from the tomb you appear at the entrance, half a day later, with unused gear back.

## Gray-box limits (on purpose)

No supply boat, traders, museums, displays, camp building, upgrades or story yet. No art. One
island screen. Philius's lines are placeholders.

## Questions the playtest should answer

1. Does the island feel calm and pleasant to wander, next to the tense tomb?
2. Did you face a real choice between gathering and going in? Did you ever rest just to change
   the half?
3. Did needing a way out change how you went into the tomb? Did you take anchors, and use them?
4. Do time and season feel like they matter, or just like labels?
5. Is half a day per expedition and per rest the right size?
