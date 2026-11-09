# Archaeology

A top-down, fully active fantasy archaeology game for the desktop browser. You dig up the remains of
lost civilizations and extinct creatures, and piece together how each one rose and fell.

The design sketch lives in a Claude Doc; [PITCH.md](PITCH.md) and [DECISIONS.md](DECISIONS.md) hold
what's agreed. The game is in the **feel-prototype** phase: only the dig exists, as a gray-box.

## Running

```sh
npm install
npm run dev        # http://localhost:5173  (add ?seed=42 to replay the same ground)
npm test           # Vitest
npm run lint       # ESLint
npm run check      # TypeScript
npm run build      # production build into dist/
```

## Playing the gray-box dig

- **1** pick, **2** trowel, **3** brush, **4** probe. **Right-click** always brushes.
  - Pick: a layer off a 3 × 3 patch for 3 stamina. Chips anything it breaks onto.
  - Trowel: one tile, one layer, 1 stamina. Chips a find if it breaks through onto it.
  - Brush: hold to lift one layer, 3 stamina. Never chips.
  - Probe: 1 stamina. Shows a tile's layers left, and `!` if something hard is below.
- Each site holds three finds; one is a piece of the Lantern Crown, which comes in four pieces.
- **Hold an exposed find** to lift it out (2 stamina). Orange tiles are soil still packed against
  it; lifting before clearing them damages it.
- **N** sleeps and starts the next day: stamina comes back, the trench stays. A find left partly
  exposed overnight weathers.
- **M** cycles the map grade (rough, measured, fine) on the same ground. **H** hides the map.
- **Space** replays the same ground, **R** opens a new site.
- **`** shows the debug overlay: true layers left, the first letter of each find, `s` for stains.

After playing, add an entry to [PLAYTEST_LOG.md](PLAYTEST_LOG.md).

## Layout

- `src/engine`: pure TypeScript rules with no Phaser and no DOM, testable in Node
- `src/scenes`: Phaser scenes that draw the rules and turn input into actions
- `tests`: Vitest, including a simple bot that checks a better map makes a better dig
