import { describe, expect, it } from 'vitest';
import {
  area,
  canLift,
  createDig,
  DEFAULT_CONFIG,
  endDay,
  findResult,
  gradeCondition,
  lift,
  liftDamage,
  lockedSides,
  MAP_GRADES,
  siteDone,
  use,
  type Condition,
  type DigState,
  type MapGrade,
} from '../src/engine/dig';
import { playByMap } from './bot';

const findTile = (s: DigState, o = 0) => s.objects[o].tiles[0];
const plainTile = (s: DigState) => s.tiles.findIndex((t) => t.object < 0);

/** Brushes every tile of a find down to the find level (trowel first, brush the last layer). */
function expose(s: DigState, o: number) {
  for (const i of s.objects[o].tiles) {
    while (s.tiles[i].depth > 1) use(s, i, 'trowel');
    s.stamina = 100;
    use(s, i, 'brush');
  }
}

describe('createDig', () => {
  it('is the same for the same seed', () => {
    expect(createDig(7, 'fine')).toEqual(createDig(7, 'fine'));
  });

  it('buries three separate finds, one of them a Lantern Crown piece', () => {
    for (let seed = 1; seed <= 100; seed++) {
      const s = createDig(seed, 'rough');
      expect(s.objects).toHaveLength(3);
      expect(s.objects.filter((o) => o.kind.set)).toHaveLength(1);
      const all = s.objects.flatMap((o) => o.tiles);
      expect(new Set(all).size).toBe(all.length);
      s.objects.forEach((o, k) => {
        expect(o.tiles).toHaveLength(o.kind.size);
        for (const i of o.tiles) expect(s.tiles[i].object).toBe(k);
      });
    }
  });

  it('can be told which Crown piece to bury', () => {
    expect(createDig(4, 'fine', { piece: 3 }).objects[0].piece).toBe(3);
  });

  it('keeps the ground the same whatever the map grade', () => {
    const ground = (g: MapGrade) => createDig(11, g).tiles;
    expect(ground('rough')).toEqual(ground('fine'));
    expect(ground('measured')).toEqual(ground('fine'));
  });

  it('gives a fine map the exact outlines and depths, and a rough map no depths', () => {
    const fine = createDig(3, 'fine');
    fine.tiles.forEach((t, i) => {
      expect(fine.hints[i].predicted).toBe(t.object >= 0);
      if (t.object >= 0) expect(fine.hints[i].depthEstimate).toBe(t.startDepth);
    });
    expect(createDig(3, 'rough').hints.every((h) => h.depthEstimate === null)).toBe(true);
  });
});

describe('tools', () => {
  it('trowel: chips a find when it breaks through onto it', () => {
    const s = createDig(5, 'fine');
    const i = findTile(s);
    let last;
    while (s.tiles[i].depth > 0) last = use(s, i, 'trowel');
    expect(last).toEqual([{ i, kind: 'chipped' }]);
  });

  it('brush: exposes a find cleanly', () => {
    const s = createDig(5, 'fine');
    const i = findTile(s);
    while (s.tiles[i].depth > 1) use(s, i, 'trowel');
    expect(use(s, i, 'brush')).toEqual([{ i, kind: 'exposed' }]);
  });

  it('pick: takes a layer off a 3 × 3 patch for one action', () => {
    const s = createDig(5, 'fine');
    const centre = s.config.cols + 1;
    const before = area(s, centre, 'pick').map((j) => s.tiles[j].depth);
    expect(use(s, centre, 'pick')).toHaveLength(9);
    expect(area(s, centre, 'pick').map((j) => s.tiles[j].depth)).toEqual(before.map((d) => d - 1));
    expect(s.stamina).toBe(DEFAULT_CONFIG.stamina - DEFAULT_CONFIG.cost.pick);
  });

  it('probe: reveals a tile once, without digging it', () => {
    const s = createDig(5, 'fine');
    const i = plainTile(s);
    const depth = s.tiles[i].depth;
    expect(use(s, i, 'probe')).toEqual([{ i, kind: 'probed' }]);
    expect(s.tiles[i]).toMatchObject({ probed: true, depth });
    expect(use(s, i, 'probe')).toEqual([]);
  });

  it('does nothing without the stamina for it', () => {
    const s = createDig(5, 'fine');
    s.stamina = 2;
    expect(use(s, plainTile(s), 'brush')).toEqual([]);
    expect(s.stamina).toBe(2);
  });
});

describe('lifting', () => {
  it('needs the whole find exposed', () => {
    const s = createDig(8, 'fine');
    expect(canLift(s, 0)).toBe(false);
    expose(s, 0);
    expect(canLift(s, 0)).toBe(true);
  });

  it('damages a find lifted with soil still packed against it', () => {
    const s = createDig(8, 'fine');
    expose(s, 0);
    expect(lockedSides(s, 0).length).toBeGreaterThan(0);
    const expected = liftDamage(s, 0);
    expect(lift(s, 0)).toBe(expected);
    expect(findResult(s, 0).damage).toBe(expected);
  });

  it('lifts cleanly once the soil around it is cleared', () => {
    const s = createDig(8, 'fine');
    expose(s, 0);
    for (const n of lockedSides(s, 0)) {
      while (s.tiles[n].depth > 0) {
        s.stamina = 100;
        use(s, n, 'trowel');
      }
    }
    expect(lift(s, 0)).toBe(0);
    expect(findResult(s, 0).condition).toBe('pristine');
  });
});

describe('days', () => {
  it('restores stamina and keeps the trench open', () => {
    const s = createDig(2, 'fine');
    use(s, plainTile(s), 'trowel');
    const depths = s.tiles.map((t) => t.depth);
    endDay(s);
    expect(s.day).toBe(2);
    expect(s.stamina).toBe(DEFAULT_CONFIG.stamina);
    expect(s.tiles.map((t) => t.depth)).toEqual(depths);
  });

  it('weathers a find left partly exposed overnight', () => {
    const s = createDig(2, 'fine');
    const i = findTile(s);
    while (s.tiles[i].depth > 1) use(s, i, 'trowel');
    use(s, i, 'brush');
    expect(endDay(s)).toEqual([0]);
    expect(findResult(s, 0).damage).toBe(1);
  });
});

describe('gradeCondition', () => {
  it('grades by damage against the size of the find', () => {
    expect(gradeCondition(6, 0)).toBe('pristine');
    expect(gradeCondition(6, 1)).toBe('intact');
    expect(gradeCondition(6, 3)).toBe('worn');
    expect(gradeCondition(6, 4)).toBe('fragment');
  });
});

describe('the map matters', () => {
  const score: Record<Condition, number> = { pristine: 3, intact: 2, worn: 1, fragment: 0 };
  const play = (grade: MapGrade) => {
    let total = 0;
    let days = 0;
    let done = 0;
    for (let seed = 1; seed <= 200; seed++) {
      const s = createDig(seed, grade);
      playByMap(s);
      s.objects.forEach((b, o) => (total += b.lifted ? score[findResult(s, o).condition] : 0));
      days += s.day;
      if (siteDone(s)) done += 1;
    }
    return { average: total / 600, days: days / 200, done: done / 200 };
  };

  it('a careful player does better with each better map', () => {
    const [rough, measured, fine] = MAP_GRADES.map((g) => play(g).average);
    expect(fine).toBeGreaterThan(measured);
    expect(measured).toBeGreaterThan(rough);
  });

  it('a fine map, played carefully, finishes a site in two or three days, nearly all pristine', () => {
    const fine = play('fine');
    expect(fine.done).toBe(1);
    expect(fine.average).toBeGreaterThan(2.9);
    expect(fine.days).toBeGreaterThanOrEqual(2);
    expect(fine.days).toBeLessThanOrEqual(3);
  });
});
