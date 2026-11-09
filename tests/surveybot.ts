// Simple surveyors, used to check the numbers: does more surveying make a better map?
import { canRead, endSurveyDay, read, type SurveyState } from '../src/engine/survey';

/** Readings on a regular grid, `stride` tiles apart. */
export function grid(s: SurveyState, stride: number): void {
  const { cols, rows } = s.site.config;
  const start = Math.floor(stride / 2);
  for (let y = start; y < rows; y += stride) {
    for (let x = start; x < cols; x += stride) {
      if (!canRead(s)) endSurveyDay(s);
      read(s, y * cols + x);
    }
  }
}

/** A grid pass, then repeat readings on the tiles that look most promising, for `days` days. */
export function gridThenFocus(s: SurveyState, days: number): void {
  grid(s, 3);
  while (s.day < days || canRead(s)) {
    if (!canRead(s)) {
      if (s.day >= days) break;
      endSurveyDay(s);
    }
    // The least certain of the tiles that look like something.
    const target = s.beliefs
      .map((b, i) => ({ i, b }))
      .filter(({ b }) => b.mean > 0.4)
      .sort((a, z) => a.b.confidence - z.b.confidence)[0];
    if (!target) break;
    read(s, target.i);
  }
}
