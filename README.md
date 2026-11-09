# Archaeology

A top-down, fully active fantasy archaeology game for the desktop browser. You dig up the remains of
lost civilizations and extinct creatures, and piece together how each one rose and fell.

The design sketch lives in a Claude Doc; [PITCH.md](PITCH.md) and [DECISIONS.md](DECISIONS.md) hold
what's agreed. The game is in the **feel-prototype** phase: the survey and the dig exist, as gray-boxes.

## Running

```sh
npm install
npm run dev        # http://localhost:5173  (add ?seed=42 to replay the same ground)
npm test           # Vitest
npm run lint       # ESLint
npm run check      # TypeScript
npm run build      # production build into dist/
```

## Playing the gray-box

A site starts with a survey, then the dig.

**Survey**

- **Click** a square to take a reading (4 stamina). It senses everything within 2 squares, most
  surely right under it. Warm squares: something is there; cool: probably nothing; faint: unsure.
- The **blue boxes** are the map you'll dig with. Overlapping readings make it surer: rough
  squares get no depths, measured ones a guess within one layer, fine ones the exact depth.
- **N** sleeps, **D** starts digging the next morning, **R** surveys a new site.

**Dig**

- **1** pick, **2** trowel, **3** brush, **4** probe. **Right-click** always brushes.
  - Pick: a layer off a 3 × 3 patch for 3 stamina. Chips anything it breaks onto.
  - Trowel: one tile, one layer, 1 stamina. Chips a find if it breaks through onto it.
  - Brush: hold to lift one layer, 3 stamina. Never chips.
  - Probe: 1 stamina. Shows a tile's layers left, and `!` if something hard is below.
- Each site holds three finds; one is a piece of the Lantern Crown, which comes in four pieces.
- **Hold an exposed find** to lift it out (2 stamina). Orange tiles are soil still packed against
  it; lifting before clearing them damages it. Its context comes from how well it was surveyed.
- **N** sleeps: stamina comes back, the trench stays. A find left partly exposed overnight
  weathers.
- **M** swaps the survey's map for a fixed grade (rough, measured, fine), for comparison. **H**
  hides the map. **Space** replays the same ground, **R** surveys a new site.

**`** shows the debug overlay in either scene. Add `?seed=42` to the address to replay a site.
After playing, add an entry to [PLAYTEST_LOG.md](PLAYTEST_LOG.md).

## Layout

- `src/engine`: pure TypeScript rules with no Phaser and no DOM, testable in Node
- `src/scenes`: Phaser scenes that draw the rules and turn input into actions
- `tests`: Vitest, including a simple bot that checks a better map makes a better dig
