# Rendering contract

The shared source of truth for how the game is drawn (D48). The art guide (ART_GUIDE.md) and any
code that swaps the gray-box shapes for sprites both defer to this file. Every number here is a
starting value: change it here first, with a decision, then in art and code.

Status: PROVISIONAL until the first art batch has been seen in the game.

## 1. Screen and scale

| | Value | Where it lives |
| --- | --- | --- |
| Viewport | 480 × 270 | `project.godot` |
| Window | 1440 × 810 (3×), integer scaling only | `project.godot` |
| Camera zoom | 2 on the island and in the tomb | `ZOOM` in both scenes |
| Tile | 16 × 16 art pixels | `TILE` in both scenes |
| One art pixel | 2 viewport pixels, 6 screen pixels at 1440 × 810 | |
| Tiles on screen | 15 × 8.4 | |
| Texture filter | Nearest, no mipmaps | `default_texture_filter=0` |
| Pixel snap | Transforms and vertices snap to whole pixels | `project.godot` |

Rules:

- Art is drawn at 1× on a 16 px grid and never scaled in code. No sub-pixel sprites, no
  rotation except in 90° steps, and no scaling except the camera's 2×.
- The HUD, prompts, journal and dig view are drawn at viewport scale (1×, not zoomed). UI art is
  therefore authored for 480 × 270, where one art pixel is one viewport pixel.
- A tomb chamber is 13 × 9 tiles, so a chamber nearly fills the screen (D34). Art must not try
  to show more than that.

## 2. Footprints and anchors

The rules only know tiles. Art can overhang upward, but what blocks movement is always the tile
footprint below.

| Kind | Frame | Footprint (blocks) | Anchor |
| --- | --- | --- | --- |
| Ground tile | 16 × 16 | its tile | top-left |
| Character (player, Philius, traders, collectors) | 32 × 32 | island: a 10 × 10 box at the feet (`HALF_BOX` 5); tomb: one tile | feet at (16, 30), body at most 16 wide and 30 tall |
| Tomb creature | 32 × 32 | one tile | feet at (16, 28), body at most 20 wide |
| Small prop (plant, bench, shelf, plans board, dig spot, crystal node, spring) | 16 × 16 | one tile | top-left of its tile |
| Tall prop (tent, tomb entrance) | 16 × 32 | the bottom tile only | bottom row sits on its tile; top row overhangs the tile above |
| Wide prop (supply boat) | 48 × 32 | its "B" tile; the rest sits over sea, which is blocked anyway | centred on its tile, hull in the bottom 16 px |
| Marker overlay (rope, anchor, shaft light, stairs) | 16 × 16 | none (it's a marker on an open tile) | top-left |
| Find icon (UI) | 16 × 16 at 1× | none | |

What looks solid must block, and what doesn't block must look flat. Grass tufts, cracks, roots
on the floor and puddles have no height. Anything with height (rocks, pillars, crates, statues)
is a blocking tile in the map or the generator, never decoration.

## 3. Layers (draw order)

| z | Layer | Contents |
| --- | --- | --- |
| 0 | Ground | island grass, sand, sea, jetty; tomb floor, wall, ledge, water, rubble |
| 1 | Ground detail | flat decoration, wall edges, stream foam, rockfall dust warning |
| 2 | Y-sorted | characters, creatures and props, sorted by the y of their feet |
| 3 | Overhead | tent roof, tomb lintels and canopy that the player walks behind |
| 4 | Light | island night darkness and lamp falloff; tomb lamp light (only lit tiles show) |
| 5 | World labels | tunnel hints, "rope", "down", "daylight", warm-draft text |
| 10 | HUD (CanvasLayer) | HUD text, prompts, journal, menus, dig view |

Light is drawn by code over the art, not baked into it. Art should read at 15% brightness, so
silhouettes carry the meaning and value contrast matters more than hue.

## 4. Palette

One master palette of 32 colours for the whole slice, so the island and the tomb sit together.
Hues come from the gray-box roles below. Andrew can swap in a published palette (for example one
from Lospec) as long as each role keeps its contrast.

| Role | Gray-box colour | Notes |
| --- | --- | --- |
| Outline / deepest shadow | `#050504` | the tomb's unseen black; also the outline colour |
| Tomb wall | `#1f2a1e` | mossy dark stone |
| Tomb pillar | `#3b4a33` | must read as solid against the wall |
| Tomb floor | `#6f6a52` | the brightest stone; walkable must be lighter than blocked |
| Ledge (drop edge) | `#a59a70` | a lip with a visible drop on its right side |
| Rubble | `#54493c` | broken stone, clearly passable-with-effort |
| Water | `#2f6f8f` | streams; 2 lighter foam tones |
| Roots and vines | `#3f6b2e` | |
| Island grass | dry `#a39a55`, rains `#4f8a3c`, bloom `#6aa84f`, mists `#6b8270` | one tile set per season (D36) |
| Island jungle | dry `#4d5a2c`, rains `#1f4a22`, bloom `#2a5a26`, mists `#344a3c` | |
| Sand / sea / jetty | `#d9c38c` / `#2c5d8a` / `#8a6a44` | |
| Player | `#4aa3ff` | the one saturated blue; nothing else uses it |
| Ways out (rope, anchor) | `#5fd35f` | green always means "you can climb out here" |
| Daylight shaft | `#fff3a8` | warm light from above |
| Stairs down | `#b07cff` | |
| Dig spot / mapped / done | `#ff9a3c` / `#ffd84a` / `#5a5a5a` | |
| Crystal | `#5ff0e6` | |
| Creature | `#e8433a` | red means danger; fleeing and stunned are poses, not only colours |
| Spring | `#7fd4ff` | |
| Philius | `#9a6fd1` | |
| Trader / collector | `#e0a040` / `#40c0a0` | each visitor is a palette swap of one base |

Meaning never rides on colour alone: every state change also changes shape or pose (a dug-out
spot loses its mound, a fleeing creature turns away, a stunned one lies flat).

## 5. Tiles and transitions

- **Island:** grass, jungle wall, sand and sea, in four season variants for grass and jungle.
  Edges between terrains use 16-tile corner (Wang) sets: grass↔jungle, grass↔sand, sand↔sea.
  The map stays a hand-laid character grid (`island_map.gd`); a lookup picks the tile from the
  four corners.
- **Tomb:** wall, floor, pillar, ledge, rubble, water. Walls need a floor↔wall corner set so
  chambers and tunnels read as carved rooms. The ledge faces right (drops are always taken moving
  right, D31); it needs one tile with a lip, not a set.
- **Animated tiles:** sea (4 frames, 4 fps), stream water (4 frames, 6 fps), dust warning (2
  frames, 4 fps).

## 6. Animation

| Thing | Frames | Rate |
| --- | --- | --- |
| Player walk | 4 directions × 4 frames | 10 fps on the island (72 px a second) |
| Player in the tomb | the same walk cycle | one step is 0.14 s (D41), so about one cycle every 4 tiles |
| Player idle | 4 directions × 2 frames | 2 fps |
| Philius, traders, collectors | down-facing idle, 2 frames | 2 fps |
| Creature | 4 directions × 2 frames, plus flee (2) and stunned (1) | 6 fps |
| Plants | ready and picked (2 still frames) | |

No animation is needed for the rules to work; a still frame is a valid first pass.

## 7. Density

- **Island:** flat decoration on at most 1 in 4 grass tiles, never on an interactable's tile or a
  path tile next to one. Interactables (plants, tent, bench, shelf, plans, tomb, visitors) must
  stand out from the scatter by both shape and value.
- **Tomb:** 2 to 4 decorations per chamber, placed on walls or as flat floor detail only.
  Tunnels get none, so a tunnel mouth and its hint are easy to read. Nothing may sit on a dig
  spot, crystal, spring, rope or stairs tile.

## 8. Files

- `art/island/`, `art/tomb/`, `art/characters/`, `art/ui/`. Lowercase names with underscores,
  for example `art/tomb/floor_wall_wang.png`.
- PNG with transparency, no anti-aliasing, no semi-transparent pixels except in light and dust
  effects.
- Sprite sheets run frames left to right and directions top to bottom (down, left, right, up).

## 9. Code side (deletion fence)

When art replaces the shapes, the scenes keep their `COLORS` tables and draw functions as the
fallback for anything without a sprite yet. The rules in `core/` never change for art. These
stay drawn by code: tunnel hint labels, the lamp and night light, the dig view grid, and all HUD
text.
