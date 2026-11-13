# Art guide

What to make for the first art pass, in order, and how each asset meets RENDERING_CONTRACT.md.
The contract wins wherever the two differ. Everything here is original art (D2): no references
to existing games' characters or tiles in prompts.

## Style

- Top-down, three-quarter view (Pixel Lab: "high top-down" for tiles and props, "low top-down"
  for characters).
- 16 px tiles, 32 × 32 character frames, a dark 1 px outline (`#050504`) on characters and props,
  none on ground tiles.
- Basic shading, low to medium detail. Shapes over texture: at 6× on screen, every pixel shows.
- Wondrous and warm: worn stone, green growth, gold and jade accents, never grim.
- Colours from the contract's palette (section 4).

## Batch 1: the loop you see every run

Make these first; they replace most of the gray-box.

| # | Asset | Size | Frames | Prompt idea |
| --- | --- | --- | --- | --- |
| 1 | Player, the archaeologist | 32 × 32 | 4 directions × 4 walk + 2 idle | young archaeologist, wide-brim hat, blue shirt, satchel, rope coil on shoulder |
| 2 | Professor Philius | 32 × 32 | down idle, 2 | old eccentric professor, round spectacles, wild white hair, purple waistcoat, dusty field coat |
| 3 | Tomb tileset: floor ↔ wall | 16-tile corner set | 1 | ancient jungle tomb, carved mossy green-black stone walls, worn sandstone floor slabs |
| 4 | Tomb singles | 16 × 16 each | 1 | pillar (carved stone column, solid), ledge (floor lip with a drop on the right), rubble (broken stone chunks), roots on floor (flat) |
| 5 | Stream water | 16 × 16 | 4 | shallow stream over stone, moving to one side, light foam |
| 6 | Tomb markers | 16 × 16 each | 1 | rope hanging from above (green), rope anchor spike with rope, shaft of daylight from a crack above, stone stairs going down |
| 7 | Dig spot | 16 × 16 | 3 states | disturbed earth mound with a shard poking out; the same mapped (gold pegs and string); dug out (flat, empty) |
| 8 | Crystal node and spring | 16 × 16 each | 1 | cyan crystal cluster growing from stone; small clear spring pool in stone |
| 9 | Tomb creature | 32 × 32 | 4 directions × 2, flee 2, stunned 1 | jungle tomb lizard-cat, red markings, curious more than evil |
| 10 | Island tilesets | 16-tile corner sets × 4 seasons | 1 | grass ↔ jungle wall, grass ↔ sand, sand ↔ sea; seasons: dry gold, rains deep green, bloom bright green, mists grey-green |
| 11 | Camp props | tent 16 × 32, the rest 16 × 16 | 1 | canvas field tent (orange), camp workbench with tools, display shelf with 5 slots, camp plans board on an easel |
| 12 | Tomb entrance | 16 × 32 | 1 | vine-covered stone doorway into a hillside, dark inside |

## Batch 2: the island's life

| # | Asset | Size | Frames | Prompt idea |
| --- | --- | --- | --- | --- |
| 13 | Plants | 16 × 16 | ready and picked | vine fiber, hardwood sapling, resin tree knot, wild fruit bush, glowcap mushrooms (glowing cyan, night) |
| 14 | Supply boat and jetty | boat 48 × 32, jetty 16 × 16 | 1 | small wooden supply boat with a cream sail; plank jetty |
| 15 | Traders | 32 × 32 | down idle, 2 | one base merchant, then five palette swaps and hat or prop changes (Mira, Dace, Tamsin, Corvin, Brask the outfitter) |
| 16 | Collectors | 32 × 32 | down idle, 2 | one base museum curator, three swaps (Varga, Okafor, Sel) |

## Batch 3: UI

| # | Asset | Size | Frames | Prompt idea |
| --- | --- | --- | --- | --- |
| 17 | Find icons | 16 × 16 at 1× | 1 | jade bead, clay effigy, bone flute, obsidian blade, serpent idol, star-chart shard, gold-leaf mask piece, star-carved lintel stone |
| 18 | Dig tools | 16 × 16 at 1× | 1 | pick, trowel, brush, probe |
| 19 | Title logo | free | 1 | later, once the name is chosen |

## Checks before an asset goes in

1. Sized and anchored as the contract's section 2 says, on a 16 px grid.
2. Readable at 15% brightness (put it under a dark overlay and look).
3. Blocking things look solid; flat things have no height (contract section 2).
4. Its state changes show in shape, not only colour (contract section 4).
5. Saved under `art/` with the contract's naming (section 8).

## With Pixel Lab

Pixel Lab can't be reached from the cloud threads yet: it needs a claude.ai connector or the
environment's network and secrets set up first. Until then, generate in Pixel Lab directly and
drop the PNGs into `art/` on a branch. Use the character tool for 1, 2, 9, 15 and 16, the top-down
tileset tool for 3 and 10, and single images for the rest. Keep the seed and settings for each
asset in `art/SOURCES.md`, so a redo stays consistent.
