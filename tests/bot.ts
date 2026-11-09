// A simple player for the dig, used to check the numbers: does a better map make a better dig,
// and can a careful player finish a site in a few days?
import {
  canLift,
  endDay,
  lift,
  lockedSides,
  neighbours,
  showsStain,
  use,
  type DigState,
  type Tool,
} from '../src/engine/dig';

const MAX_DAYS = 8;

/** Spends stamina, sleeping first when the day's stamina runs short. */
function act(s: DigState, i: number, tool: Tool): boolean {
  if (s.stamina < s.config.cost[tool]) {
    if (s.day >= MAX_DAYS) return false;
    endDay(s);
  }
  use(s, i, tool);
  return true;
}

/** The map's marked tiles, grouped into the separate patches it shows. */
function patches(s: DigState): number[][] {
  const { cols, rows } = s.config;
  const seen = new Set<number>();
  const out: number[][] = [];
  s.hints.forEach((h, start) => {
    if (!h.predicted || seen.has(start)) return;
    const patch: number[] = [];
    const queue = [start];
    seen.add(start);
    while (queue.length) {
      const i = queue.pop()!;
      patch.push(i);
      for (const n of neighbours(i, cols, rows)) {
        if (s.hints[n].predicted && !seen.has(n)) {
          seen.add(n);
          queue.push(n);
        }
      }
    }
    out.push(patch);
  });
  return out;
}

/**
 * Digs every patch the map marks (trowel down to the map's depth, brush the last layer), then
 * clears the soil around anything exposed and lifts it, all before sleeping where it can.
 */
export function playByMap(s: DigState): void {
  for (const patch of patches(s)) {
    // Start a fresh day rather than leave a find half-exposed overnight.
    const estimate = patch.length * 11;
    if (s.stamina < estimate && s.stamina < s.config.stamina && s.day < MAX_DAYS) endDay(s);
    for (const i of patch) {
      const t = s.tiles[i];
      const h = s.hints[i];
      let removed = 0;
      while (t.depth > 0) {
        const nearBottom =
          showsStain(t) || (h.depthEstimate !== null && removed >= h.depthEstimate - 1);
        if (!act(s, i, nearBottom ? 'brush' : 'trowel')) return;
        removed += 1;
      }
    }
    s.objects.forEach((b, o) => {
      if (b.lifted || !b.tiles.every((i) => s.tiles[i].depth === 0)) return;
      for (const n of lockedSides(s, o)) {
        while (s.tiles[n].depth > 0) if (!act(s, n, 'trowel')) return;
      }
      if (!canLift(s, o) && s.day < MAX_DAYS) endDay(s);
      lift(s, o);
    });
  }
}
