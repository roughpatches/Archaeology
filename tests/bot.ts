// A simple player for the dig, used to check that a better map really makes a better dig.
import { dig, showsStain, type DigState } from '../src/engine/dig';

/** Digs every tile the map marks: trowel down to the map's depth, brush the last layer. */
export function playByMap(s: DigState): void {
  s.hints.forEach((h, i) => {
    if (!h.predicted) return;
    const t = s.tiles[i];
    let removed = 0;
    while (t.depth > 0 && !s.ended) {
      const nearBottom =
        showsStain(t) || (h.depthEstimate !== null && removed >= h.depthEstimate - 1);
      if (dig(s, i, nearBottom ? 'brush' : 'trowel') === 'blocked') return;
      removed += 1;
    }
  });
}
