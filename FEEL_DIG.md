# Feel spec: the dig

The dig is the core verb. This is the gate: nothing else gets built until it passes a playtest.

## Read: what the player sees

- A trench of 12 × 9 tiles. Each tile has 2 to 4 layers of soil above the find level; depths vary
  gently, so neighbours hint at each other.
- Soil colour shows **layers removed**, never layers remaining, so the ground alone doesn't give the
  answer away.
- The **site map** overlays blue boxes where it thinks the find is:
  - **Fine:** the exact outline and exact depths.
  - **Measured:** mostly right; a few tiles missed or extra; depths off by one about half the time
    (shown as `~3`).
  - **Rough:** a bigger blob, shifted up to two tiles, with no depths.
- A **stain** (dark green) shows on most find tiles, and a few empty ones, when one layer is left.
- Stamina is a bar that every action spends.

## Decide: the real choice

Trowel or brush, tile by tile. The trowel is cheap (1) but chips the find if it breaks through onto
it. The brush is safe but costs 3. Brushing everything costs more stamina than you have, so the
player must judge, from the map and the stains, when they're one layer away. Which tiles to open
first is the second choice: a rough map means exploring, and exploring spends stamina.

What a player can do wrong: trowel through onto the find (chip), brush tiles that weren't close
(waste), dig where nothing is (waste), or run out before the find is fully exposed.

## Feedback: good, mediocre and bad must look different

- A clean exposure pops gold with a small bounce and the word "found".
- A chip shakes the camera, turns the tile red, and says "chip!".
- Reaching bare floor on an empty tile turns it pale and says "nothing".
- The result card scales in: **Pristine** (gold, slow bounce, sparkles), **Intact**, **Worn**,
  **Fragment** (grey, quick).

Condition: Pristine = all exposed, no chips. Intact = all exposed, chips ≤ 15% of the find. Worn =
at least 60% exposed, chips ≤ 40%. Otherwise Fragment.

## What the numbers say so far

A simple bot that digs only where the map points (`tests/bot.ts`), over 500 seeds:

| Map      | Pristine | Intact | Worn | Fragment | Stamina left |
| -------- | -------- | ------ | ---- | -------- | ------------ |
| Rough    | 0%       | 1%     | 49%  | 50%      | 21           |
| Measured | 3%       | 3%     | 86%  | 8%       | 38           |
| Fine     | 100%     | 0%     | 0%   | 0%       | 40           |

So the map clearly matters. A person who follows stains and explores should beat the bot on rough
and measured maps; the playtest finds out whether that feels like skill or like guessing.

## Questions the playtest should answer

1. Did trowel-or-brush feel like a choice, or did one tool always win?
2. Did the stains and the map feel like reading the ground, or like being told the answer?
3. Did a Pristine find feel earned, and a Fragment feel like your own fault?
4. Is a fine map too generous (100% Pristine for careful play)?
