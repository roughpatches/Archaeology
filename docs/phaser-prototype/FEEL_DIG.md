# Feel spec: the dig (v2)

The dig is the core verb. v1 passed its first playtest as a prototype; v2 adds what Andrew asked
for (PLAYTEST_LOG.md): two more tools, several finds per site, pieces of large artifacts, a more
involved uncovering, and digs that run over several days.

## Read: what the player sees

- A trench of 14 × 10 tiles. Each tile has 2 to 4 layers of soil above the find level; depths vary
  gently, so neighbours hint at each other.
- Soil colour shows **layers removed**, never layers remaining.
- Three finds are buried apart from each other: two whole finds and one piece of a large artifact.
- The **site map** overlays blue boxes where it thinks finds are. Fine: exact outlines and
  depths. Measured: mostly right, depths off by one about half the time (`~3`). Rough: bigger
  blobs, shifted, no depths.
- A **stain** (dark green) shows on most find tiles, and a few empty ones, when one layer is left.
- A **probed** tile shows its layers left in white, with `!` if something hard is below.
- An exposed find glows gold; the soil still packed against it is outlined orange, and hovering
  it says how much damage lifting it now would do.
- Stamina for the day, the day number, and a finds tray with the large artifact's pieces.

## Decide: the real choices

1. **Which tool, tile by tile.** Pick (3 stamina, 9 tiles, chips) for overburden far from finds;
   trowel (1, chips) for single tiles you know are deep; brush (3, safe) for the last layer;
   probe (1) when you'd rather pay to know than guess.
2. **When to lift.** Lift now and take damage from the soil still locking it in, or spend
   stamina clearing round it first.
3. **What to open today.** A find left partly exposed overnight weathers. So with the day's
   stamina running low, the choice is to finish and lift one find, or stop and sleep before
   exposing the next.

What a player can do wrong: pick or trowel onto a find (chip), waste stamina on empty ground,
lift a find while it's locked in, or leave a find half-exposed overnight.

## Feedback

- Clean exposure: gold pop and "found"; the last tile of a find says "free! lift it".
- Chip: camera shake, red tile, "chip!". The pick gives a light thud of its own.
- Lifting: a hold with a gold bar, then the find rises out of its socket and leaves a dark hole,
  and its card scales in with its name, condition and context. Pristine finds get a slow bounce
  and sparkles.
- Sleeping fades to black; finds that weathered overnight say so.
- The finds tray shows the large artifact's pieces filling in, then "ready to assemble at camp".

Condition from damage against the find's size: Pristine = none; Intact = up to 15% (at least 1);
Worn = up to half; otherwise Fragment.

## What the numbers say so far

A simple bot (`tests/bot.ts`) that digs only where the map points, clears round each find and
lifts it, over 300 seeds:

| Map      | Lifted finds | Pristine of those | Days per site |
| -------- | ------------ | ----------------- | ------------- |
| Fine     | 100%         | 97%               | 2.3           |
| Measured | 39%          | 73%               | 1.8           |
| Rough    | 7%           | 31%               | 2.1           |

The bot never explores beyond the map, so it leaves most finds behind on rough and measured maps;
a person following stains and probing should do far better. That's what survey quality will buy
once the map comes from the survey (FEEL_FIELDWORK.md).

## Questions the playtest should answer

1. Does each of the four tools have a job, or does one go unused?
2. Does lifting feel like a moment, and is clearing round a find worth it or a chore?
3. Does weathering make you plan your day, or just feel like a penalty?
4. Is two to three days per site with a fine map the right length?
