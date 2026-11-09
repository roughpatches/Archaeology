// Gray-box survey: placeholder shapes only (FEEL_FIELDWORK.md). Readings build up the site map,
// which is handed to the dig. All rules live in src/engine/survey.ts.
import Phaser from 'phaser';
import { applyMap, LANTERN_CROWN } from '../engine/dig';
import {
  canRead,
  coverage,
  createSurvey,
  endSurveyDay,
  findGrades,
  reach,
  read,
  surveyHints,
  tileGrade,
  type SurveyState,
} from '../engine/survey';
import { CROWN_KEY, type DigHandoff } from './DigScene';

const TILE = 42;
const GRID_X = 24;
const GRID_Y = 64;
const PANEL_X = 640;

const UNREAD = 0x2b2722;
const NOTHING = 0x4a6572;
const SOMETHING = 0xd9893f;
const MAP_LINE = 0x5fd0e0;
const TRUTH = 0xff9ad5;
const INK = '#e8e2cf';
const QUIET = '#9c927d';

/** Blends two 0xRRGGBB colours, `t` of the way from `a` to `b`. */
function mix(a: number, b: number, t: number): number {
  const channel = (shift: number) => {
    const from = (a >> shift) & 0xff;
    const to = (b >> shift) & 0xff;
    return Math.round(from + (to - from) * t) << shift;
  };
  return channel(16) | channel(8) | channel(0);
}

interface TileView {
  ground: Phaser.GameObjects.Rectangle;
  estimate: Phaser.GameObjects.Text;
}

export class SurveyScene extends Phaser.Scene {
  private state!: SurveyState;
  private views: TileView[] = [];
  private overlay!: Phaser.GameObjects.Graphics;
  private staminaBar!: Phaser.GameObjects.Rectangle;
  private header!: Phaser.GameObjects.Text;
  private panel!: Phaser.GameObjects.Text;
  private hovered = -1;
  private showDebug = false;

  constructor() {
    super('survey');
  }

  create(data: { seed?: number } = {}): void {
    this.views = [];
    this.hovered = -1;
    this.input.mouse?.disableContextMenu();

    const fromUrl = Number(new URLSearchParams(window.location.search).get('seed'));
    const seed =
      data.seed ?? (Number.isFinite(fromUrl) && fromUrl > 0 ? fromUrl : Date.now() % 100000);
    // A new site holds a Crown piece you haven't found yet, while any are left.
    const found: Set<number> = this.registry.get(CROWN_KEY) ?? new Set();
    const missing = Array.from({ length: LANTERN_CROWN.pieces }, (_, k) => k + 1).filter(
      (p) => !found.has(p),
    );
    this.state = createSurvey(seed, missing.length ? missing[seed % missing.length] : undefined);

    this.header = this.add.text(GRID_X, 22, '', { fontSize: '18px', color: INK });
    this.buildGrid();
    this.add.text(PANEL_X, 64, 'Stamina today', { fontSize: '14px', color: INK });
    this.add.rectangle(PANEL_X, 86, 290, 12, 0x3a352d).setOrigin(0, 0);
    this.staminaBar = this.add.rectangle(PANEL_X, 86, 290, 12, 0x7fc06a).setOrigin(0, 0);
    this.panel = this.add.text(PANEL_X, 108, '', {
      fontSize: '13px',
      color: INK,
      lineSpacing: 5,
      wordWrap: { width: 300 },
    });
    this.add
      .text(
        GRID_X,
        500,
        'Survey the site, then dig it. Warm squares: something is down there. Cool squares: ' +
          'probably nothing. The fainter a square, the less sure the survey is. Blue boxes are ' +
          'the map you will dig with.',
        { fontSize: '13px', color: QUIET, lineSpacing: 4, wordWrap: { width: 590 } },
      )
      .setOrigin(0, 0);
    this.bindKeys();
    this.render();
  }

  private buildGrid(): void {
    const { cols, rows } = this.state.site.config;
    for (let i = 0; i < cols * rows; i++) {
      const { x, y } = this.tileOrigin(i);
      const ground = this.add
        .rectangle(x + TILE / 2, y + TILE / 2, TILE - 2, TILE - 2, UNREAD)
        .setInteractive();
      ground.on('pointerdown', () => this.takeReading(i));
      const estimate = this.add.text(x + 3, y + 1, '', { fontSize: '12px', color: '#bff3fa' });
      this.views.push({ ground, estimate });
    }
    this.overlay = this.add.graphics();
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      const i = this.tileAt(p.x, p.y);
      if (i === this.hovered) return;
      this.hovered = i;
      this.drawOverlay();
    });
  }

  private bindKeys(): void {
    const kb = this.input.keyboard!;
    kb.on('keydown-N', () => this.sleep());
    kb.on('keydown-D', () => this.startDigging());
    kb.on('keydown-R', () => this.scene.restart({ seed: Math.floor(Math.random() * 99999) + 1 }));
    kb.on('keydown-BACKTICK', () => {
      this.showDebug = !this.showDebug;
      this.drawOverlay();
    });
  }

  // ---- play --------------------------------------------------------------------------------

  private takeReading(i: number): void {
    if (!canRead(this.state)) return this.float(i, 'too tired');
    const sensed = read(this.state, i);
    this.render();

    // A ping spreads from the reading; the squares it sensed settle into their new colour.
    const { x, y } = this.tileOrigin(i);
    const ring = this.add
      .circle(x + TILE / 2, y + TILE / 2, 6)
      .setStrokeStyle(2, 0xffffff, 0.9)
      .setFillStyle(0xffffff, 0);
    this.tweens.add({
      targets: ring,
      radius: TILE * (this.state.config.radius + 0.5),
      alpha: 0,
      duration: 550,
      ease: 'Quad.Out',
      onComplete: () => ring.destroy(),
    });
    const grounds = sensed.map((j) => this.views[j].ground);
    this.tweens.add({ targets: grounds, alpha: { from: 0.4, to: 1 }, duration: 400 });
  }

  private sleep(): void {
    this.cameras.main.fadeOut(350, 0, 0, 0);
    this.cameras.main.once('camerafadeoutcomplete', () => {
      endSurveyDay(this.state);
      this.render();
      this.cameras.main.fadeIn(450, 0, 0, 0);
    });
  }

  /** Hands the site and the map the survey made to the dig, which starts the next morning. */
  private startDigging(): void {
    const s = this.state;
    applyMap(s.site, surveyHints(s), findGrades(s));
    const handoff: DigHandoff = { site: s.site, day: s.day };
    this.cameras.main.fadeOut(350, 0, 0, 0);
    this.cameras.main.once('camerafadeoutcomplete', () => this.scene.start('dig', handoff));
  }

  private float(i: number, words: string): void {
    const { x, y } = this.tileOrigin(i);
    const t = this.add
      .text(x + TILE / 2, y, words, { fontSize: '13px', color: QUIET, fontStyle: 'bold' })
      .setOrigin(0.5, 1);
    this.tweens.add({
      targets: t,
      y: y - 24,
      alpha: 0,
      duration: 800,
      onComplete: () => t.destroy(),
    });
  }

  // ---- drawing -----------------------------------------------------------------------------

  private render(): void {
    const s = this.state;
    const hints = surveyHints(s);
    s.beliefs.forEach((b, i) => {
      const v = this.views[i];
      const sure = Math.min(1, b.confidence / s.config.fine);
      const lean = Math.min(1, Math.max(0, b.mean));
      const reading = mix(NOTHING, SOMETHING, lean);
      v.ground.setFillStyle(b.confidence === 0 ? UNREAD : mix(UNREAD, reading, 0.25 + sure * 0.75));
      const h = hints[i];
      v.estimate.setText(
        h.predicted && h.depthEstimate !== null ? `${h.exact ? '' : '~'}${h.depthEstimate}` : '',
      );
    });
    this.drawOverlay(hints);

    const c = coverage(s);
    const pct = (n: number) => `${Math.round(n * 100)}%`;
    const marked = hints.filter((h) => h.predicted).length;
    this.header.setText(`Survey  ·  day ${s.day}  ·  seed ${s.seed}`);
    this.staminaBar.setSize(290 * (s.stamina / s.config.stamina), 12);
    this.panel.setText(
      [
        `${s.stamina} / ${s.config.stamina}`,
        '',
        `Click a square to take a reading (${s.config.readingCost} stamina). It senses everything ` +
          `within ${s.config.radius} squares, most surely right under it.`,
        '',
        `Readings taken: ${s.readings.length}`,
        `Site recorded: ${pct(c.fine)} fine, ${pct(c.measured)} measured, ${pct(c.rough)} rough, ` +
          `${pct(c.none)} unread`,
        `Squares on the map: ${marked}`,
        '',
        'Overlapping readings make the map surer. A find mapped finely is easier to dig and ' +
          'recorded with full context; a rough one gets no depths.',
        '',
        'There are three finds somewhere on this site.',
        '',
        'D start digging tomorrow',
        'N sleep  ·  R new site  ·  ` debug',
      ].join('\n'),
    );
  }

  private drawOverlay(hints = surveyHints(this.state)): void {
    const s = this.state;
    const g = this.overlay.clear();
    g.lineStyle(2, MAP_LINE, 0.8);
    hints.forEach((h, i) => {
      if (!h.predicted) return;
      const { x, y } = this.tileOrigin(i);
      g.strokeRect(x + 4, y + 4, TILE - 10, TILE - 10);
    });
    g.fillStyle(0xffffff, 0.8);
    for (const i of new Set(s.readings)) {
      const { x, y } = this.tileOrigin(i);
      g.fillCircle(x + TILE - 7, y + TILE - 7, 3);
    }
    if (this.showDebug) {
      g.lineStyle(2, TRUTH, 0.9);
      s.site.tiles.forEach((t, i) => {
        if (t.object < 0) return;
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x + 1, y + 1, TILE - 4, TILE - 4);
      });
    }
    if (this.hovered >= 0) {
      g.lineStyle(1, 0xffffff, 0.6);
      for (const { i } of reach(s, this.hovered)) {
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x, y, TILE - 2, TILE - 2);
      }
      g.lineStyle(2, 0xffffff, 0.9);
      const { x, y } = this.tileOrigin(this.hovered);
      g.strokeRect(x, y, TILE - 2, TILE - 2);
      const grade = tileGrade(s, this.hovered);
      this.header.setText(
        `Survey  ·  day ${s.day}  ·  seed ${s.seed}  ·  this square: ${grade ?? 'unread'}`,
      );
    }
  }

  // ---- geometry ----------------------------------------------------------------------------

  private tileOrigin(i: number): { x: number; y: number } {
    const cols = this.state.site.config.cols;
    return { x: GRID_X + (i % cols) * TILE, y: GRID_Y + Math.floor(i / cols) * TILE };
  }

  private tileAt(px: number, py: number): number {
    const { cols, rows } = this.state.site.config;
    const x = Math.floor((px - GRID_X) / TILE);
    const y = Math.floor((py - GRID_Y) / TILE);
    return x >= 0 && x < cols && y >= 0 && y < rows ? y * cols + x : -1;
  }
}
