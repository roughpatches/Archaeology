import { describe, expect, it } from 'vitest';
import { applyMap, findResult, use } from '../src/engine/dig';
import {
  coverage,
  createSurvey,
  DEFAULT_SURVEY,
  endSurveyDay,
  findGrades,
  read,
  reach,
  surveyHints,
  tileGrade,
  type SurveyState,
} from '../src/engine/survey';
import { grid, gridThenFocus } from './surveybot';

const RANK = { rough: 1, measured: 2, fine: 3 } as const;
const averageRank = (plan: (s: SurveyState) => void) => {
  let total = 0;
  for (let seed = 1; seed <= 100; seed++) {
    const s = createSurvey(seed);
    plan(s);
    total += findGrades(s).reduce((sum, g) => sum + RANK[g], 0);
  }
  return total / 300;
};

describe('readings', () => {
  it('cost stamina and sense the tiles within reach', () => {
    const s = createSurvey(3);
    const centre = 4 * s.site.config.cols + 6;
    expect(read(s, centre).sort()).toEqual(
      reach(s, centre)
        .map((r) => r.i)
        .sort(),
    );
    expect(reach(s, centre)).toHaveLength(13);
    expect(s.stamina).toBe(DEFAULT_SURVEY.stamina - DEFAULT_SURVEY.readingCost);
  });

  it('come out the same for the same readings', () => {
    const a = createSurvey(9);
    const b = createSurvey(9);
    for (const i of [10, 40, 70]) {
      read(a, i);
      read(b, i);
    }
    expect(a.beliefs).toEqual(b.beliefs);
  });

  it('stop when the day is spent, until the next day', () => {
    const s = createSurvey(3);
    s.stamina = DEFAULT_SURVEY.readingCost - 1;
    expect(read(s, 20)).toEqual([]);
    endSurveyDay(s);
    expect(s.day).toBe(2);
    expect(read(s, 20).length).toBeGreaterThan(0);
  });

  it('are surest right under the reading, and grow surer with each one', () => {
    const s = createSurvey(3);
    const cols = s.site.config.cols;
    expect(tileGrade(s, 50)).toBeNull();
    read(s, 50);
    expect(tileGrade(s, 50)).toBe('measured');
    expect(tileGrade(s, 51)).toBe('rough');
    expect(tileGrade(s, 50 + 2 * cols)).toBeNull();
    read(s, 50);
    expect(tileGrade(s, 50)).toBe('fine');
  });
});

describe('the map it makes', () => {
  it('marks nothing where nobody has looked', () => {
    expect(surveyHints(createSurvey(5)).some((h) => h.predicted)).toBe(false);
    expect(coverage(createSurvey(5)).none).toBeCloseTo(1);
  });

  it('gets better with more surveying', () => {
    const sparse = averageRank((s) => grid(s, 3));
    const dense = averageRank((s) => grid(s, 2));
    const focused = averageRank((s) => gridThenFocus(s, 2));
    expect(dense).toBeGreaterThan(sparse);
    expect(focused).toBeGreaterThan(dense);
  });

  it('records each find in the dig at the grade its survey reached', () => {
    const s = createSurvey(12);
    gridThenFocus(s, 2);
    const grades = findGrades(s);
    applyMap(s.site, surveyHints(s), grades);
    expect(s.site.grade).toBe('surveyed');
    const contexts = { rough: 'unrecorded', measured: 'noted', fine: 'documented' } as const;
    grades.forEach((g, o) => expect(findResult(s.site, o).context).toBe(contexts[g]));
    // The site is dug as normal afterwards.
    expect(use(s.site, 0, 'probe')).toHaveLength(1);
  });
});
