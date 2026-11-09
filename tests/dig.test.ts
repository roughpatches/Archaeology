import { describe, expect, it } from 'vitest';
import {
  createDig,
  dig,
  DEFAULT_CONFIG,
  gradeCondition,
  MAP_GRADES,
  result,
  type Condition,
  type MapGrade,
} from '../src/engine/dig';
import { playByMap } from './bot';

const findIndex = (s: ReturnType<typeof createDig>) => s.tiles.findIndex((t) => t.isFind);
const emptyIndex = (s: ReturnType<typeof createDig>) => s.tiles.findIndex((t) => !t.isFind);

describe('createDig', () => {
  it('is the same for the same seed', () => {
    expect(createDig(7, 'fine')).toEqual(createDig(7, 'fine'));
  });

  it('buries a find of the configured size, with depths in range', () => {
    for (let seed = 1; seed <= 50; seed++) {
      const s = createDig(seed, 'rough');
      expect(s.tiles.filter((t) => t.isFind)).toHaveLength(DEFAULT_CONFIG.findSize);
      for (const t of s.tiles) {
        expect(t.depth).toBeGreaterThanOrEqual(DEFAULT_CONFIG.minDepth);
        expect(t.depth).toBeLessThanOrEqual(DEFAULT_CONFIG.maxDepth);
      }
    }
  });

  it('keeps the ground the same whatever the map grade', () => {
    const ground = (g: MapGrade) => createDig(11, g).tiles;
    expect(ground('rough')).toEqual(ground('fine'));
    expect(ground('measured')).toEqual(ground('fine'));
  });

  it('gives a fine map the exact outline and depths, and a rough map no depths', () => {
    const fine = createDig(3, 'fine');
    fine.tiles.forEach((t, i) => {
      expect(fine.hints[i].predicted).toBe(t.isFind);
      if (t.isFind) expect(fine.hints[i].depthEstimate).toBe(t.startDepth);
    });
    expect(createDig(3, 'rough').hints.every((h) => h.depthEstimate === null)).toBe(true);
  });
});

describe('dig', () => {
  it('chips a find when a trowel breaks through onto it', () => {
    const s = createDig(5, 'fine');
    const i = findIndex(s);
    const events = Array.from({ length: s.tiles[i].startDepth }, () => dig(s, i, 'trowel'));
    expect(events.at(-1)).toBe('chipped');
    expect(s.tiles[i].chipped).toBe(true);
  });

  it('exposes a find cleanly with the brush', () => {
    const s = createDig(5, 'fine');
    const i = findIndex(s);
    while (s.tiles[i].depth > 1) dig(s, i, 'trowel');
    expect(dig(s, i, 'brush')).toBe('exposed');
    expect(s.tiles[i].chipped).toBe(false);
  });

  it('reaches bare floor on an empty tile, and then nothing more happens', () => {
    const s = createDig(5, 'fine');
    const i = emptyIndex(s);
    while (s.tiles[i].depth > 1) dig(s, i, 'trowel');
    expect(dig(s, i, 'trowel')).toBe('floor');
    expect(dig(s, i, 'trowel')).toBe('blocked');
  });

  it('spends stamina by tool and stops when it runs out', () => {
    const s = createDig(5, 'fine');
    const i = emptyIndex(s);
    dig(s, i, 'trowel');
    dig(s, i, 'brush');
    expect(s.stamina).toBe(DEFAULT_CONFIG.stamina - 1 - 3);
    s.stamina = 2;
    expect(dig(s, i, 'brush')).toBe('blocked');
  });

  it('ends once the whole find is exposed', () => {
    const s = createDig(9, 'fine');
    playByMap(s);
    expect(s.ended).toBe(true);
    expect(result(s).exposed).toBe(DEFAULT_CONFIG.findSize);
  });
});

describe('gradeCondition', () => {
  it('grades by how much is exposed and how much is chipped', () => {
    expect(gradeCondition(12, 12, 0)).toBe('pristine');
    expect(gradeCondition(12, 12, 1)).toBe('intact');
    expect(gradeCondition(12, 8, 2)).toBe('worn');
    expect(gradeCondition(12, 5, 0)).toBe('fragment');
  });
});

describe('the map matters', () => {
  const score: Record<Condition, number> = { pristine: 3, intact: 2, worn: 1, fragment: 0 };
  const average = (grade: MapGrade) => {
    let total = 0;
    for (let seed = 1; seed <= 300; seed++) {
      const s = createDig(seed, grade);
      playByMap(s);
      total += score[result(s).condition];
    }
    return total / 300;
  };

  it('a careful player does better with each better map', () => {
    const [rough, measured, fine] = MAP_GRADES.map(average);
    expect(fine).toBeGreaterThan(measured);
    expect(measured).toBeGreaterThan(rough);
  });

  it('a fine map, played carefully, is enough stamina for a pristine find', () => {
    for (let seed = 1; seed <= 100; seed++) {
      const s = createDig(seed, 'fine');
      playByMap(s);
      expect(result(s).condition).toBe('pristine');
    }
  });
});
