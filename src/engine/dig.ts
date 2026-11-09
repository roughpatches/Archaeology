// The dig, as pure rules. No Phaser and no DOM, so it can be tested and tuned in Node.
// See FEEL_DIG.md for what this is meant to feel like and why.
import { mulberry32, type Rng } from './rng';

export type MapGrade = 'rough' | 'measured' | 'fine';
export type Tool = 'pick' | 'trowel' | 'brush' | 'probe';
export type Condition = 'pristine' | 'intact' | 'worn' | 'fragment';
export type Context = 'unrecorded' | 'noted' | 'documented';

export const MAP_GRADES: readonly MapGrade[] = ['rough', 'measured', 'fine'];
export const TOOLS: readonly Tool[] = ['pick', 'trowel', 'brush', 'probe'];

export interface DigConfig {
  cols: number;
  rows: number;
  /** Soil layers above the find level, per tile. */
  minDepth: number;
  maxDepth: number;
  /** Stamina per day. A dig can run over several days; the trench stays open. */
  stamina: number;
  cost: Record<Tool, number>;
  liftCost: number;
  /** Chance a find tile shows a darker stain when one layer is left above it. */
  stainChance: number;
  /** Chance an empty tile shows the same stain (a false lead). */
  falseStainChance: number;
}

export const DEFAULT_CONFIG: DigConfig = {
  cols: 14,
  rows: 10,
  minDepth: 2,
  maxDepth: 4,
  stamina: 100,
  cost: { pick: 3, trowel: 1, brush: 3, probe: 1 },
  liftCost: 2,
  stainChance: 0.75,
  falseStainChance: 0.08,
};

/** What can be buried. Placeholder content until the Lantern Towns are written. */
export interface FindKind {
  id: string;
  name: string;
  size: number;
  /** Set for a piece of a large artifact that is assembled at camp. */
  set?: { id: string; name: string; pieces: number };
}

export const LANTERN_CROWN = { id: 'lantern-crown', name: 'Lantern Crown', pieces: 4 };

export const FIND_KINDS: readonly FindKind[] = [
  { id: 'lantern-glass', name: 'Lantern glass', size: 4 },
  { id: 'toll-token', name: 'Toll token', size: 3 },
  { id: 'river-idol', name: 'River idol', size: 5 },
  { id: 'barge-figurehead', name: 'Barge figurehead', size: 7 },
  { id: 'marsh-drake-jaw', name: 'Marsh-drake jaw', size: 6 },
];

export interface Tile {
  /** Layers still to remove. 0 means dug down to the find level. */
  depth: number;
  /** Starting depth, kept for the debug overlay and tests. */
  startDepth: number;
  /** Index into `objects`, or -1 for plain ground. */
  object: number;
  chipped: boolean;
  stain: boolean;
  /** A probe has been pushed down here, so its true depth is known. */
  probed: boolean;
}

export interface Buried {
  kind: FindKind;
  /** For a set piece: which piece, from 1. */
  piece?: number;
  tiles: number[];
  lifted: boolean;
  /** Damage from lifting it while still locked in, and from weathering overnight. */
  extraDamage: number;
  /** How well the map recorded it, which sets the context it is recorded in. */
  mapped: MapGrade;
}

export interface MapHint {
  /** The map marks this tile as part of a find. */
  predicted: boolean;
  /** The map's guess at the tile's depth; null when the map doesn't say. */
  depthEstimate: number | null;
  /** The depth guess is exact rather than a rough guess. */
  exact?: boolean;
}

export interface DigState {
  config: DigConfig;
  seed: number;
  /** How the map was made: a fixed grade, or built up by surveying the site. */
  grade: MapGrade | 'surveyed';
  tiles: Tile[];
  objects: Buried[];
  hints: MapHint[];
  day: number;
  stamina: number;
  actions: Record<Tool | 'lift', number>;
}

/** What one action did to one tile, so the scene can give feedback for it. */
export type TileEventKind =
  | 'removed' // a layer came off, more remain
  | 'floor' // reached the find level on plain ground: wasted effort
  | 'exposed' // reached the find level on a find tile, cleanly
  | 'chipped' // a trowel or pick broke through onto a find and damaged it
  | 'probed'; // the probe found how deep this tile goes

export interface TileEvent {
  i: number;
  kind: TileEventKind;
}

export interface FindResult {
  kind: FindKind;
  piece?: number;
  total: number;
  damage: number;
  condition: Condition;
  context: Context;
}

export interface CreateOptions {
  config?: DigConfig;
  /** Which piece of the Lantern Crown this site holds; random when left out. */
  piece?: number;
}

// ---- generation ----------------------------------------------------------------------------

const NEIGHBOURS = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
] as const;

export function neighbours(i: number, cols: number, rows: number): number[] {
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

/** Grows one connected blob of up to `size` tiles from `start`, never entering `blocked`. */
function growBlob(
  rng: Rng,
  cols: number,
  rows: number,
  size: number,
  start: number,
  blocked: ReadonlySet<number> = new Set(),
): Set<number> {
  const shape = new Set([start]);
  while (shape.size < size) {
    const frontier: number[] = [];
    for (const i of shape) {
      for (const n of neighbours(i, cols, rows)) {
        if (!shape.has(n) && !blocked.has(n)) frontier.push(n);
      }
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

/** Places finds apart from each other, so each one is its own small excavation. */
function placeObjects(rng: Rng, c: DigConfig, kinds: FindKind[]): number[][] {
  const taken = new Set<number>();
  const placed: number[][] = [];
  for (const kind of kinds) {
    for (let attempt = 0; attempt < 200; attempt++) {
      const sx = 1 + Math.floor(rng() * (c.cols - 2));
      const sy = 1 + Math.floor(rng() * (c.rows - 2));
      const start = sy * c.cols + sx;
      if (taken.has(start)) continue;
      const blob = growBlob(rng, c.cols, c.rows, kind.size, start, taken);
      if (blob.size < kind.size) continue;
      placed.push([...blob]);
      // Keep a one-tile margin of plain ground around each find.
      for (const i of blob) {
        taken.add(i);
        for (const n of neighbours(i, c.cols, c.rows)) taken.add(n);
      }
      break;
    }
  }
  return placed;
}

function makeHints(rng: Rng, c: DigConfig, grade: MapGrade, s: DigState): MapHint[] {
  const predicted = new Set<number>();
  for (const o of s.objects) {
    const own = new Set(o.tiles);
    if (grade === 'fine') {
      for (const i of o.tiles) predicted.add(i);
    } else if (grade === 'measured') {
      // Mostly right: a few edge tiles missed, a few neighbours marked by mistake.
      for (const i of o.tiles) if (rng() > 0.2) predicted.add(i);
      for (const i of o.tiles) {
        for (const n of neighbours(i, c.cols, c.rows)) {
          if (!own.has(n) && rng() < 0.12) predicted.add(n);
        }
      }
    } else {
      // Rough: "somewhere around here". A bigger blob, shifted up to two tiles.
      const centre = o.tiles[Math.floor(o.tiles.length / 2)];
      const shift = () => Math.round((rng() - 0.5) * 4);
      const x = Math.min(c.cols - 1, Math.max(0, (centre % c.cols) + shift()));
      const y = Math.min(c.rows - 1, Math.max(0, Math.floor(centre / c.cols) + shift()));
      const size = Math.round(o.tiles.length * 1.8);
      for (const i of growBlob(rng, c.cols, c.rows, size, y * c.cols + x)) predicted.add(i);
    }
  }
  return s.tiles.map((t, i) => {
    const marked = predicted.has(i);
    let depthEstimate: number | null = null;
    if (marked && grade === 'fine') depthEstimate = t.startDepth;
    if (marked && grade === 'measured') {
      depthEstimate = Math.max(1, t.startDepth + pick(rng, [-1, 0, 0, 1]));
    }
    return { predicted: marked, depthEstimate, exact: marked && grade === 'fine' };
  });
}

export function createDig(seed: number, grade: MapGrade, options: CreateOptions = {}): DigState {
  const c = options.config ?? DEFAULT_CONFIG;
  const rng = mulberry32(seed);
  const depths = makeDepths(rng, c);

  // Each site holds two whole finds and one piece of the Lantern Crown.
  const wholes = [...FIND_KINDS].sort(() => rng() - 0.5).slice(0, 2);
  const crown: FindKind = {
    id: LANTERN_CROWN.id,
    name: LANTERN_CROWN.name,
    size: 4,
    set: LANTERN_CROWN,
  };
  // Always roll, so choosing the piece never changes the ground.
  const rolled = 1 + Math.floor(rng() * LANTERN_CROWN.pieces);
  const piece = options.piece ?? rolled;
  const kinds = [crown, ...wholes];
  const shapes = placeObjects(rng, c, kinds);

  const owner = new Map<number, number>();
  shapes.forEach((tiles, o) => tiles.forEach((i) => owner.set(i, o)));

  const tiles: Tile[] = depths.map((depth, i) => {
    const object = owner.get(i) ?? -1;
    return {
      depth,
      startDepth: depth,
      object,
      chipped: false,
      stain: rng() < (object >= 0 ? c.stainChance : c.falseStainChance),
      probed: false,
    };
  });

  const s: DigState = {
    config: c,
    seed,
    grade,
    tiles,
    objects: shapes.map((t, o) => ({
      kind: kinds[o],
      piece: kinds[o].set ? piece : undefined,
      tiles: t,
      lifted: false,
      extraDamage: 0,
      mapped: grade,
    })),
    hints: [],
    day: 1,
    stamina: c.stamina,
    actions: { pick: 0, trowel: 0, brush: 0, probe: 0, lift: 0 },
  };
  // Hints use their own stream so changing the map grade never changes the ground itself.
  s.hints = makeHints(mulberry32(seed ^ 0x9e3779b9), c, grade, s);
  return s;
}

/**
 * Swaps in a map made by surveying the site (see survey.ts): its marks and depth guesses, and how
 * well it recorded each find.
 */
export function applyMap(s: DigState, hints: MapHint[], mapped: MapGrade[]): void {
  s.grade = 'surveyed';
  s.hints = hints;
  s.objects.forEach((b, o) => (b.mapped = mapped[o]));
}

// ---- reading the state ---------------------------------------------------------------------

/** The stain shows only on the last layer above the find level. */
export const showsStain = (t: Tile) => t.depth === 1 && t.stain;

/** The tiles a tool works on when used at `i`: the pick works a 3 × 3 patch. */
export function area(s: DigState, i: number, tool: Tool): number[] {
  if (tool !== 'pick') return [i];
  const { cols, rows } = s.config;
  const x = i % cols;
  const y = Math.floor(i / cols);
  const out: number[] = [];
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const nx = x + dx;
      const ny = y + dy;
      if (nx >= 0 && nx < cols && ny >= 0 && ny < rows) out.push(ny * cols + nx);
    }
  }
  return out;
}

export function canUse(s: DigState, i: number, tool: Tool): boolean {
  if (s.stamina < s.config.cost[tool] || !s.tiles[i]) return false;
  if (tool === 'probe') return !s.tiles[i].probed && s.tiles[i].depth > 0;
  return area(s, i, tool).some((j) => s.tiles[j].depth > 0);
}

export const isExposed = (s: DigState, o: number) =>
  s.objects[o].tiles.every((i) => s.tiles[i].depth === 0);

/** Plain ground still packed against a find. Lifting it like this damages it. */
export function lockedSides(s: DigState, o: number): number[] {
  const { cols, rows } = s.config;
  const own = new Set(s.objects[o].tiles);
  const locked = new Set<number>();
  for (const i of own) {
    for (const n of neighbours(i, cols, rows)) {
      if (!own.has(n) && s.tiles[n].depth > 0) locked.add(n);
    }
  }
  return [...locked];
}

/** Damage a lift would do now: one point for every three tiles of soil still against it. */
export const liftDamage = (s: DigState, o: number) => Math.ceil(lockedSides(s, o).length / 3);

export const canLift = (s: DigState, o: number) =>
  !!s.objects[o] && !s.objects[o].lifted && isExposed(s, o) && s.stamina >= s.config.liftCost;

export const siteDone = (s: DigState) => s.objects.every((o) => o.lifted);

export function gradeCondition(total: number, damage: number): Condition {
  if (damage === 0) return 'pristine';
  if (damage <= Math.max(1, Math.floor(total * 0.15))) return 'intact';
  if (damage <= Math.ceil(total * 0.5)) return 'worn';
  return 'fragment';
}

const CONTEXT: Record<MapGrade, Context> = {
  rough: 'unrecorded',
  measured: 'noted',
  fine: 'documented',
};

export function findResult(s: DigState, o: number): FindResult {
  const b = s.objects[o];
  const damage = b.tiles.filter((i) => s.tiles[i].chipped).length + b.extraDamage;
  return {
    kind: b.kind,
    piece: b.piece,
    total: b.tiles.length,
    damage,
    condition: gradeCondition(b.tiles.length, damage),
    context: CONTEXT[b.mapped],
  };
}

// ---- acting --------------------------------------------------------------------------------

/** Uses `tool` at tile `i`. Mutates `s`. Returns what happened to each tile it touched. */
export function use(s: DigState, i: number, tool: Tool): TileEvent[] {
  if (!canUse(s, i, tool)) return [];
  s.stamina -= s.config.cost[tool];
  s.actions[tool] += 1;

  if (tool === 'probe') {
    s.tiles[i].probed = true;
    return [{ i, kind: 'probed' }];
  }

  const events: TileEvent[] = [];
  for (const j of area(s, i, tool)) {
    const t = s.tiles[j];
    if (t.depth === 0) continue;
    t.depth -= 1;
    let kind: TileEventKind = 'removed';
    if (t.depth === 0) {
      if (t.object < 0) kind = 'floor';
      else if (tool === 'brush') kind = 'exposed';
      else {
        t.chipped = true;
        kind = 'chipped';
      }
    }
    events.push({ i: j, kind });
  }
  return events;
}

/** Lifts an exposed find out of the trench. Returns the damage the lift itself did. */
export function lift(s: DigState, o: number): number {
  if (!canLift(s, o)) return 0;
  const damage = liftDamage(s, o);
  s.stamina -= s.config.liftCost;
  s.actions.lift += 1;
  s.objects[o].extraDamage += damage;
  s.objects[o].lifted = true;
  return damage;
}

/**
 * Ends the day: stamina comes back and the trench stays open. A find left partly exposed
 * overnight weathers, losing a point of condition. Returns the finds that weathered.
 */
export function endDay(s: DigState): number[] {
  const weathered: number[] = [];
  s.objects.forEach((b, o) => {
    if (b.lifted) return;
    if (b.tiles.some((i) => s.tiles[i].depth === 0)) {
      b.extraDamage += 1;
      weathered.push(o);
    }
  });
  s.day += 1;
  s.stamina = s.config.stamina;
  return weathered;
}
