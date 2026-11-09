// Surveying, as pure rules: noisy readings over a site build up the map the dig will use.
// See FEEL_FIELDWORK.md. The ground being surveyed is a dig site from dig.ts.
import { mulberry32 } from './rng';
import { createDig, type DigState, type MapGrade, type MapHint } from './dig';

export interface SurveyConfig {
  stamina: number;
  readingCost: number;
  /** A reading senses tiles up to this many tiles away (straight-line distance). */
  radius: number;
  /** Noise on a reading of the tile under it, and how much it grows per tile of distance. */
  noiseNear: number;
  noisePerTile: number;
  /** Confidence (summed 1/noise²) a tile needs before the map marks it, guesses its depth
   * roughly, or records it exactly. */
  rough: number;
  measured: number;
  fine: number;
}

export const DEFAULT_SURVEY: SurveyConfig = {
  stamina: 100,
  readingCost: 4,
  radius: 2,
  noiseNear: 0.35,
  noisePerTile: 0.25,
  rough: 1.5,
  measured: 5,
  fine: 12,
};

export interface Belief {
  /** Weighted mean of readings: near 1 means something is buried here, near 0 means nothing. */
  mean: number;
  /** Total weight of the readings so far. 0 means never read. */
  confidence: number;
}

export interface SurveyState {
  config: SurveyConfig;
  seed: number;
  /** The site's true ground. Readings sample it; the player never sees it directly. */
  site: DigState;
  beliefs: Belief[];
  readings: number[];
  day: number;
  stamina: number;
}

export function createSurvey(seed: number, piece?: number): SurveyState {
  const site = createDig(seed, 'rough', { piece });
  return {
    config: DEFAULT_SURVEY,
    seed,
    site,
    beliefs: site.tiles.map(() => ({ mean: 0, confidence: 0 })),
    readings: [],
    day: 1,
    stamina: DEFAULT_SURVEY.stamina,
  };
}

/** Tiles a reading at `i` senses, with their distance from it. */
export function reach(s: SurveyState, i: number): { i: number; d: number }[] {
  const { cols, rows } = s.site.config;
  const r = s.config.radius;
  const x = i % cols;
  const y = Math.floor(i / cols);
  const out: { i: number; d: number }[] = [];
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      const d = Math.hypot(dx, dy);
      const nx = x + dx;
      const ny = y + dy;
      if (d <= r && nx >= 0 && nx < cols && ny >= 0 && ny < rows)
        out.push({ i: ny * cols + nx, d });
    }
  }
  return out;
}

export const canRead = (s: SurveyState) => s.stamina >= s.config.readingCost;

/** A normal sample from two uniforms (Box–Muller). */
function gaussian(rng: () => number): number {
  const u = Math.max(rng(), 1e-9);
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * rng());
}

/** Takes a reading at tile `i`. Mutates `s`. Returns the tiles it sensed. */
export function read(s: SurveyState, i: number): number[] {
  if (!canRead(s) || !s.site.tiles[i]) return [];
  s.stamina -= s.config.readingCost;
  // Each reading has its own noise stream, so the same readings give the same map every time.
  const rng = mulberry32((s.seed * 7919) ^ ((s.readings.length + 1) * 104729));
  s.readings.push(i);
  const sensed: number[] = [];
  for (const { i: j, d } of reach(s, i)) {
    const truth = s.site.tiles[j].object >= 0 ? 1 : 0;
    const noise = s.config.noiseNear + s.config.noisePerTile * d;
    const value = truth + gaussian(rng) * noise;
    const weight = 1 / (noise * noise);
    const b = s.beliefs[j];
    b.mean = (b.mean * b.confidence + value * weight) / (b.confidence + weight);
    b.confidence += weight;
    sensed.push(j);
  }
  return sensed;
}

export function endSurveyDay(s: SurveyState): void {
  s.day += 1;
  s.stamina = s.config.stamina;
}

/** How well the survey has recorded one tile. */
export function tileGrade(s: SurveyState, i: number): MapGrade | null {
  const c = s.beliefs[i].confidence;
  if (c >= s.config.fine) return 'fine';
  if (c >= s.config.measured) return 'measured';
  if (c >= s.config.rough) return 'rough';
  return null;
}

/** The map as the dig will see it: tiles the survey thinks hold something, with depth guesses. */
export function surveyHints(s: SurveyState): MapHint[] {
  const rng = mulberry32(s.seed ^ 0x5bd1e995);
  return s.site.tiles.map((t, i) => {
    const grade = tileGrade(s, i);
    // One distant reading is noisy, so a roughly read square needs a strong signal to be marked.
    const mean = s.beliefs[i].mean;
    const predicted = grade !== null && mean > (grade === 'rough' ? 0.8 : 0.5);
    // Draw the noise for every tile, so a guess here doesn't depend on readings elsewhere.
    const offset = [-1, 0, 0, 1][Math.floor(rng() * 4)];
    if (!predicted || grade === 'rough') return { predicted, depthEstimate: null };
    if (grade === 'fine') return { predicted, depthEstimate: t.startDepth, exact: true };
    return { predicted, depthEstimate: Math.max(1, t.startDepth + offset) };
  });
}

const RANK: Record<MapGrade, number> = { rough: 1, measured: 2, fine: 3 };

/**
 * How well each find was mapped: the grade most of its tiles reached. A find the survey barely
 * touched counts as rough.
 */
export function findGrades(s: SurveyState): MapGrade[] {
  return s.site.objects.map((b) => {
    const ranks = b.tiles.map((i) => RANK[tileGrade(s, i) ?? 'rough']).sort((a, z) => a - z);
    const median = ranks[Math.floor(ranks.length / 2)];
    return median >= 3 ? 'fine' : median >= 2 ? 'measured' : 'rough';
  });
}

/** Shares of the site the survey has recorded at each grade, for the panel. */
export function coverage(s: SurveyState): Record<MapGrade | 'none', number> {
  const out = { none: 0, rough: 0, measured: 0, fine: 0 };
  s.beliefs.forEach((_, i) => (out[tileGrade(s, i) ?? 'none'] += 1 / s.beliefs.length));
  return out;
}
