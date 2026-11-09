// The dig, as pure rules. No Phaser and no DOM, so it can be tested and tuned in Node.
// See FEEL_DIG.md for what this is meant to feel like and why.
import { mulberry32, type Rng } from './rng';

export type MapGrade = 'rough' | 'measured' | 'fine';
export type Tool = 'trowel' | 'brush';
export type Condition = 'pristine' | 'intact' | 'worn' | 'fragment';
export type Context = 'unrecorded' | 'noted' | 'documented';

export const MAP_GRADES: readonly MapGrade[] = ['rough', 'measured', 'fine'];

export interface DigConfig {
  cols: number;
  rows: number;
  /** Soil layers above the find level, per tile. */
  minDepth: number;
  maxDepth: number;
  /** Tiles the buried find covers. */
  findSize: number;
  stamina: number;
  trowelCost: number;
  brushCost: number;
  /** Chance a find tile shows a darker stain when one layer is left above it. */
  stainChance: number;
  /** Chance an empty tile shows the same stain (a false lead). */
  falseStainChance: number;
}

export const DEFAULT_CONFIG: DigConfig = {
  cols: 12,
  rows: 9,
  minDepth: 2,
  maxDepth: 4,
  findSize: 12,
  stamina: 100,
  trowelCost: 1,
  brushCost: 3,
  stainChance: 0.75,
  falseStainChance: 0.08,
};

export interface Tile {
  /** Layers still to remove. 0 means dug down to the find level. */
  depth: number;
  /** Starting depth, kept for the debug overlay and tests. */
  startDepth: number;
  isFind: boolean;
  chipped: boolean;
  stain: boolean;
}

export interface MapHint {
  /** The map marks this tile as part of the find. */
  predicted: boolean;
  /** The map's guess at the tile's depth; null when the map doesn't say. */
  depthEstimate: number | null;
}

export interface DigState {
  config: DigConfig;
  seed: number;
  grade: MapGrade;
  tiles: Tile[];
  hints: MapHint[];
  stamina: number;
  ended: boolean;
  actions: { trowel: number; brush: number };
}

/** What one action did, so the scene can give feedback for it. */
export type DigEvent =
  | 'blocked' // nothing happened (no stamina, nothing left, or the dig is over)
  | 'removed' // a layer came off, more remain
  | 'floor' // reached the find level on an empty tile: wasted effort
  | 'exposed' // reached the find level on a find tile, cleanly
  | 'chipped'; // a trowel broke through onto the find and damaged it

export interface DigResult {
  total: number;
  exposed: number;
  chips: number;
  condition: Condition;
  context: Context;
  staminaLeft: number;
}

const NEIGHBOURS = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
] as const;

function neighbours(i: number, cols: number, rows: number): number[] {
  const x = i % cols;
  const y = Math.floor(i / cols);
  const out: number[] = [];
  for (const [dx, dy] of NEIGHBOURS) {
    const nx = x + dx;
    const ny = y + dy;
    if (nx >= 0 && nx < cols && ny >= 0 && ny < rows) out.push(ny * cols + nx);
  }
  return out;
}

const pick = <T>(rng: Rng, items: readonly T[]): T => items[Math.floor(rng() * items.length)];

/** Grows one connected blob of `size` tiles from `start`. */
function growBlob(rng: Rng, cols: number, rows: number, size: number, start: number): Set<number> {
  const shape = new Set([start]);
  while (shape.size < size) {
    const frontier: number[] = [];
    for (const i of shape) {
      for (const n of neighbours(i, cols, rows)) if (!shape.has(n)) frontier.push(n);
    }
    if (frontier.length === 0) break;
    shape.add(pick(rng, frontier));
  }
  return shape;
}

/** Depths vary gently across the trench, so neighbours tell you something about each other. */
function makeDepths(rng: Rng, c: DigConfig): number[] {
  const span = c.maxDepth - c.minDepth;
  const raw = Array.from({ length: c.cols * c.rows }, () => rng());
  return raw.map((_, i) => {
    const ns = neighbours(i, c.cols, c.rows);
    const avg = (raw[i] * 2 + ns.reduce((s, n) => s + raw[n], 0)) / (2 + ns.length);
    // Smoothing pulls values toward the middle; stretch them back out before rounding.
    const stretched = Math.min(1, Math.max(0, (avg - 0.5) * 2.2 + 0.5));
    return c.minDepth + Math.round(stretched * span);
  });
}

function makeHints(rng: Rng, c: DigConfig, grade: MapGrade, tiles: Tile[]): MapHint[] {
  const find = new Set(tiles.flatMap((t, i) => (t.isFind ? [i] : [])));
  const predicted = new Set<number>();

  if (grade === 'fine') {
    for (const i of find) predicted.add(i);
  } else if (grade === 'measured') {
    // Mostly right: a few edge tiles missed, a few neighbours marked by mistake.
    for (const i of find) if (rng() > 0.2) predicted.add(i);
    for (const i of find) {
      for (const n of neighbours(i, c.cols, c.rows))
        if (!find.has(n) && rng() < 0.12) predicted.add(n);
    }
  } else {
    // Rough: "somewhere around here". A bigger blob, shifted up to two tiles.
    const centre = [...find][Math.floor(find.size / 2)];
    const x = Math.min(c.cols - 1, Math.max(0, (centre % c.cols) + Math.round((rng() - 0.5) * 4)));
    const y = Math.min(
      c.rows - 1,
      Math.max(0, Math.floor(centre / c.cols) + Math.round((rng() - 0.5) * 4)),
    );
    for (const i of growBlob(rng, c.cols, c.rows, Math.round(c.findSize * 1.8), y * c.cols + x)) {
      predicted.add(i);
    }
  }

  return tiles.map((t, i) => {
    const marked = predicted.has(i);
    let depthEstimate: number | null = null;
    if (marked && grade === 'fine') depthEstimate = t.startDepth;
    if (marked && grade === 'measured') {
      depthEstimate = Math.max(1, t.startDepth + pick(rng, [-1, 0, 0, 1]));
    }
    return { predicted: marked, depthEstimate };
  });
}

export function createDig(
  seed: number,
  grade: MapGrade,
  config: DigConfig = DEFAULT_CONFIG,
): DigState {
  const c = config;
  const rng = mulberry32(seed);
  const depths = makeDepths(rng, c);

  // Keep the find off the trench's outer edge, so the map's outline has room around it.
  const sx = 2 + Math.floor(rng() * (c.cols - 4));
  const sy = 2 + Math.floor(rng() * (c.rows - 4));
  const find = growBlob(rng, c.cols, c.rows, c.findSize, sy * c.cols + sx);

  const tiles: Tile[] = depths.map((depth, i) => {
    const isFind = find.has(i);
    return {
      depth,
      startDepth: depth,
      isFind,
      chipped: false,
      stain: rng() < (isFind ? c.stainChance : c.falseStainChance),
    };
  });

  // Hints use their own stream so changing the map grade never changes the ground itself.
  const hints = makeHints(mulberry32(seed ^ 0x9e3779b9), c, grade, tiles);

  return {
    config: c,
    seed,
    grade,
    tiles,
    hints,
    stamina: c.stamina,
    ended: false,
    actions: { trowel: 0, brush: 0 },
  };
}

export const toolCost = (s: DigState, tool: Tool) =>
  tool === 'trowel' ? s.config.trowelCost : s.config.brushCost;

/** The stain shows only on the last layer above the find level. */
export const showsStain = (t: Tile) => t.depth === 1 && t.stain;

export const canDig = (s: DigState, i: number, tool: Tool) =>
  !s.ended && s.tiles[i] !== undefined && s.tiles[i].depth > 0 && s.stamina >= toolCost(s, tool);

/** Removes one layer from tile `i` with `tool`. Mutates `s`. */
export function dig(s: DigState, i: number, tool: Tool): DigEvent {
  if (!canDig(s, i, tool)) return 'blocked';
  const t = s.tiles[i];
  s.stamina -= toolCost(s, tool);
  s.actions[tool] += 1;
  t.depth -= 1;

  let event: DigEvent = 'removed';
  if (t.depth === 0) {
    if (!t.isFind) event = 'floor';
    else if (tool === 'trowel') {
      t.chipped = true;
      event = 'chipped';
    } else event = 'exposed';
  }

  const allExposed = s.tiles.every((x) => !x.isFind || x.depth === 0);
  if (allExposed || s.stamina < Math.min(s.config.trowelCost, s.config.brushCost)) s.ended = true;
  return event;
}

/** Stops digging and lifts out whatever is exposed. */
export function endDig(s: DigState): void {
  s.ended = true;
}

export function gradeCondition(total: number, exposed: number, chips: number): Condition {
  const f = total === 0 ? 0 : exposed / total;
  const chipRatio = total === 0 ? 0 : chips / total;
  if (f === 1 && chips === 0) return 'pristine';
  if (f === 1 && chipRatio <= 0.15) return 'intact';
  if (f >= 0.6 && chipRatio <= 0.4) return 'worn';
  return 'fragment';
}

const CONTEXT: Record<MapGrade, Context> = {
  rough: 'unrecorded',
  measured: 'noted',
  fine: 'documented',
};

export function result(s: DigState): DigResult {
  const finds = s.tiles.filter((t) => t.isFind);
  const exposed = finds.filter((t) => t.depth === 0).length;
  const chips = finds.filter((t) => t.chipped).length;
  return {
    total: finds.length,
    exposed,
    chips,
    condition: gradeCondition(finds.length, exposed, chips),
    context: CONTEXT[s.grade],
    staminaLeft: s.stamina,
  };
}
