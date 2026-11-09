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

- **1 / 2** pick the trowel or the brush. **Right-click** always brushes.
- **Trowel:** a click removes one layer for 1 stamina. If that layer was the last one above the
  find, it chips the find.
- **Brush:** hold for about half a second to remove one layer for 3 stamina. Never chips.
- **Blue boxes** are where your site map says the find is; the numbers are its guess at how many
  layers sit above it. **Dark green soil** is a stain, often (not always) one layer above the find.
- **M** cycles the map grade (rough, measured, fine) on the same ground. **H** hides the map.
- **E** ends the dig and lifts what's exposed. **Space** replays the same ground, **R** new ground.
- **`** shows the debug overlay: true layers left, `F`for find tiles,`s` for stains.

After playing, add an entry to [PLAYTEST_LOG.md](PLAYTEST_LOG.md).

## Layout

- `src/engine`: pure TypeScript rules with no Phaser and no DOM, testable in Node
- `src/scenes`: Phaser scenes that draw the rules and turn input into actions
- `tests`: Vitest, including a simple bot that checks a better map makes a better dig
