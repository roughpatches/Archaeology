// Gray-box dig: placeholder shapes only, to find out whether the core verb is fun (FEEL_DIG.md).
// All rules live in src/engine/dig.ts; this scene only draws them and turns input into actions.
import Phaser from 'phaser';
import {
  applyMap,
  area,
  canLift,
  canUse,
  createDig,
  endDay,
  findResult,
  isExposed,
  LANTERN_CROWN,
  lift,
  liftDamage,
  lockedSides,
  MAP_GRADES,
  showsStain,
  siteDone,
  TOOLS,
  use,
  type DigState,
  type FindResult,
  type MapGrade,
  type MapHint,
  type TileEvent,
  type Tool,
} from '../engine/dig';

const TILE = 42;
const GRID_X = 24;
const GRID_Y = 64;
const PANEL_X = 640;
const TRAY_Y = 500;
/** How long the brush must be held to lift one layer, and a find to lift it out. */
const BRUSH_MS = 450;
const LIFT_MS = 900;

// Soil turns lighter and sandier the deeper you go. Colour shows layers removed, never layers
// remaining, so the ground alone doesn't give the answer away.
const LAYER_COLOURS = [0x7d5d3e, 0x8f6c48, 0x9e7a50, 0xab8758, 0xb79464];
const STAIN = 0x5f6136;
const FLOOR = 0xd2c194;
const FIND = 0xe3c35a;
const CHIP = 0xc0503a;
const SOCKET = 0x3a3328;
const MAP_LINE = 0x5fd0e0;
const LOCKED = 0xff9a4a;
const INK = '#e8e2cf';
const QUIET = '#9c927d';

const TOOL_TEXT: Record<Tool, string> = {
  pick: 'Pick: a layer off a 3 × 3 patch. Chips anything it breaks onto.',
  trowel: 'Trowel: one tile, one layer. Chips a find if it breaks through onto it.',
  brush: 'Brush: hold for one layer. Never chips. Right-click always brushes.',
  probe: 'Probe: shows how many layers a tile has left, and ! if it hits something hard.',
};

const CONDITION_STYLE = {
  pristine: { label: 'Pristine', colour: '#f2d36b' },
  intact: { label: 'Intact', colour: '#e8e2cf' },
  worn: { label: 'Worn', colour: '#b9a77f' },
  fragment: { label: 'Fragment', colour: '#8a8172' },
} as const;

interface TileView {
  soil: Phaser.GameObjects.Rectangle;
  estimate: Phaser.GameObjects.Text;
  probe: Phaser.GameObjects.Text;
  debug: Phaser.GameObjects.Text;
}

type Hold = { kind: 'brush' | 'lift'; i: number; start: number };

/** What the survey hands over: the site, its map, and the day the survey ended. */
export interface DigHandoff {
  site: DigState;
  day: number;
}

/** The finds tray and the Crown pieces, kept in the game registry so they outlast each site. */
export const TRAY_KEY = 'tray';
export const CROWN_KEY = 'crownPieces';

export class DigScene extends Phaser.Scene {
  private state!: DigState;
  private seed = 1;
  private grade: MapGrade = 'measured';
  private tool: Tool = 'trowel';
  private showMap = true;
  private showDebug = false;
  /** The survey's map for this site, kept so Space can replay the same ground with it. */
  private surveyed: { hints: MapHint[]; mapped: MapGrade[]; day: number } | null = null;

  private views: TileView[] = [];
  private overlay!: Phaser.GameObjects.Graphics;
  private holdBar!: Phaser.GameObjects.Rectangle;
  private staminaBar!: Phaser.GameObjects.Rectangle;
  private header!: Phaser.GameObjects.Text;
  private panel!: Phaser.GameObjects.Text;
  private trayText!: Phaser.GameObjects.Text;
  private hint!: Phaser.GameObjects.Text;
  private debugPanel!: Phaser.GameObjects.Text;
  private card?: Phaser.GameObjects.Container;
  private hold: Hold | null = null;
  private hovered = -1;

  constructor() {
    super('dig');
  }

  private get tray(): FindResult[] {
    if (!this.registry.has(TRAY_KEY)) this.registry.set(TRAY_KEY, []);
    return this.registry.get(TRAY_KEY);
  }

  private get crownPieces(): Set<number> {
    if (!this.registry.has(CROWN_KEY)) this.registry.set(CROWN_KEY, new Set<number>());
    return this.registry.get(CROWN_KEY);
  }

  create(data: Partial<DigHandoff> = {}): void {
    this.views = [];
    this.hovered = -1;
    this.hold = null;
    this.card = undefined;
    this.input.mouse?.disableContextMenu();

    this.header = this.add.text(GRID_X, 22, '', { fontSize: '18px', color: INK });
    this.buildGrid();
    this.buildPanel();
    this.bindKeys();

    if (data.site) {
      // Digging starts the morning after the survey, on the surveyed map.
      const site = data.site;
      this.surveyed = {
        hints: site.hints,
        mapped: site.objects.map((b) => b.mapped),
        day: (data.day ?? 1) + 1,
      };
      this.seed = site.seed;
      site.day = this.surveyed.day;
      site.stamina = site.config.stamina;
      this.state = site;
      this.render();
    } else {
      // Straight into a dig with a fixed map grade, for comparing grades.
      this.surveyed = null;
      const fromUrl = Number(new URLSearchParams(window.location.search).get('seed'));
      this.seed = Number.isFinite(fromUrl) && fromUrl > 0 ? fromUrl : Date.now() % 100000;
      this.newSite(this.seed, true);
    }
  }

  update(time: number): void {
    if (!this.hold) return;
    const { kind, i, start } = this.hold;
    const pointer = this.input.activePointer;
    if (!pointer.isDown || this.tileAt(pointer.x, pointer.y) !== i || this.card) {
      this.stopHold();
      return;
    }
    const progress = Math.min(1, (time - start) / (kind === 'lift' ? LIFT_MS : BRUSH_MS));
    const { x, y } = this.tileOrigin(i);
    this.holdBar
      .setFillStyle(kind === 'lift' ? FIND : 0xffffff)
      .setPosition(x + 3, y + TILE - 7)
      .setSize((TILE - 6) * progress, 4)
      .setVisible(true);
    if (progress < 1) return;
    this.stopHold();
    if (kind === 'brush') this.act(i, 'brush');
    else this.liftAt(i);
  }

  // ---- setup -------------------------------------------------------------------------------

  private buildGrid(): void {
    const { cols, rows } = createDig(1, 'rough').config;
    for (let i = 0; i < cols * rows; i++) {
      const { x, y } = this.tileOrigin(i, cols);
      const soil = this.add
        .rectangle(x + TILE / 2, y + TILE / 2, TILE - 2, TILE - 2, LAYER_COLOURS[0])
        .setInteractive();
      soil.on('pointerdown', (p: Phaser.Input.Pointer) => this.press(i, p));
      const estimate = this.add.text(x + 3, y + 1, '', { fontSize: '12px', color: '#bff3fa' });
      const probe = this.add
        .text(x + TILE - 3, y + 1, '', { fontSize: '12px', color: '#ffffff', fontStyle: 'bold' })
        .setOrigin(1, 0);
      const debug = this.add.text(x + 3, y + 26, '', { fontSize: '10px', color: '#ff9ad5' });
      this.views.push({ soil, estimate, probe, debug });
    }
    this.overlay = this.add.graphics();
    this.holdBar = this.add.rectangle(0, 0, 0, 4, 0xffffff).setOrigin(0, 0).setVisible(false);

    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      const i = this.tileAt(p.x, p.y);
      if (i === this.hovered) return;
      this.hovered = i;
      this.drawOverlay();
    });
  }

  private buildPanel(): void {
    this.add.text(PANEL_X, 64, 'Stamina today', { fontSize: '14px', color: INK });
    this.add.rectangle(PANEL_X, 86, 290, 12, 0x3a352d).setOrigin(0, 0);
    this.staminaBar = this.add.rectangle(PANEL_X, 86, 290, 12, 0x7fc06a).setOrigin(0, 0);
    this.panel = this.add.text(PANEL_X, 108, '', {
      fontSize: '13px',
      color: INK,
      lineSpacing: 5,
      wordWrap: { width: 300 },
    });
    this.add.text(GRID_X, TRAY_Y, 'Finds tray', { fontSize: '14px', color: INK });
    this.trayText = this.add.text(GRID_X, TRAY_Y + 22, '', {
      fontSize: '13px',
      color: QUIET,
      lineSpacing: 4,
      wordWrap: { width: 590 },
    });
    this.hint = this.add.text(PANEL_X, 566, '', { fontSize: '13px', color: '#f2d36b' });
    this.debugPanel = this.add.text(PANEL_X, 606, '', { fontSize: '11px', color: '#ff9ad5' });
  }

  private bindKeys(): void {
    const kb = this.input.keyboard!;
    const keys = ['ONE', 'TWO', 'THREE', 'FOUR'];
    TOOLS.forEach((tool, k) => kb.on(`keydown-${keys[k]}`, () => this.setTool(tool)));
    kb.on('keydown-M', () => {
      this.grade = MAP_GRADES[(MAP_GRADES.indexOf(this.grade) + 1) % MAP_GRADES.length];
      this.surveyed = null;
      this.newSite(this.seed, false);
    });
    kb.on('keydown-H', () => {
      this.showMap = !this.showMap;
      this.render();
    });
    kb.on('keydown-BACKTICK', () => {
      this.showDebug = !this.showDebug;
      this.render();
    });
    kb.on('keydown-N', () => this.sleep());
    kb.on('keydown-SPACE', () => (this.card ? this.closeCard() : this.newSite(this.seed, false)));
    // A new site starts with surveying it.
    kb.on('keydown-R', () => {
      if (!this.card) this.scene.start('survey', { seed: Math.floor(Math.random() * 99999) + 1 });
    });
  }

  // ---- play --------------------------------------------------------------------------------

  /** Opens a site. A fresh site holds a Crown piece you haven't found yet, while any are left. */
  private newSite(seed: number, fresh: boolean): void {
    const missing = Array.from({ length: LANTERN_CROWN.pieces }, (_, k) => k + 1).filter(
      (p) => !this.crownPieces.has(p),
    );
    const keep = this.state?.objects.find((b) => b.piece !== undefined)?.piece;
    const piece = fresh || keep === undefined ? missing[seed % missing.length] : keep;
    this.seed = seed;
    this.state = createDig(seed, this.grade, { piece });
    if (this.surveyed) {
      applyMap(this.state, this.surveyed.hints, this.surveyed.mapped);
      this.state.day = this.surveyed.day;
    }
    this.stopHold();
    this.closeCard();
    this.render();
  }

  private setTool(tool: Tool): void {
    this.tool = tool;
    this.render();
  }

  private press(i: number, p: Phaser.Input.Pointer): void {
    if (this.card) return this.closeCard();
    const o = this.state.tiles[i].object;
    // Pressing an exposed find starts lifting it, whatever tool is in hand.
    if (o >= 0 && !this.state.objects[o].lifted && isExposed(this.state, o)) {
      if (canLift(this.state, o)) this.hold = { kind: 'lift', i, start: this.time.now };
      else this.float(i, 'too tired', QUIET);
      return;
    }
    const tool: Tool = p.rightButtonDown() ? 'brush' : this.tool;
    if (!canUse(this.state, i, tool)) {
      if (this.state.stamina < this.state.config.cost[tool]) this.float(i, 'too tired', QUIET);
      return;
    }
    if (tool === 'brush') this.hold = { kind: 'brush', i, start: this.time.now };
    else this.act(i, tool);
  }

  private stopHold(): void {
    this.hold = null;
    this.holdBar?.setVisible(false);
  }

  private act(i: number, tool: Tool): void {
    const events = use(this.state, i, tool);
    this.render();
    this.feedback(events, tool);
  }

  private feedback(events: TileEvent[], tool: Tool): void {
    let chipped = false;
    for (const { i, kind } of events) {
      const soil = this.views[i].soil;
      if (kind === 'removed') {
        this.tweens.add({ targets: soil, alpha: { from: 0.55, to: 1 }, duration: 140 });
      } else if (kind === 'floor' && tool !== 'pick') {
        this.float(i, 'nothing', QUIET);
      } else if (kind === 'exposed') {
        this.tweens.add({
          targets: soil,
          scale: { from: 1.25, to: 1 },
          duration: 260,
          ease: 'Back.Out',
        });
        const o = this.state.tiles[i].object;
        this.float(i, isExposed(this.state, o) ? 'free! lift it' : 'found', '#f2d36b');
      } else if (kind === 'chipped') {
        chipped = true;
        this.tweens.add({ targets: soil, angle: { from: -8, to: 0 }, duration: 200 });
        this.float(i, 'chip!', '#ff7a5c');
      } else if (kind === 'probed') {
        const label = this.views[i].probe;
        this.tweens.add({ targets: label, scale: { from: 1.6, to: 1 }, duration: 220 });
      }
    }
    if (chipped) this.cameras.main.shake(90, 0.006);
    else if (tool === 'pick' && events.length) this.cameras.main.shake(60, 0.002);
  }

  private liftAt(i: number): void {
    const s = this.state;
    const o = s.tiles[i].object;
    const damage = lift(s, o);
    const result = findResult(s, o);
    this.tray.unshift(result);
    if (result.piece !== undefined) this.crownPieces.add(result.piece);
    this.render();

    // The moment: the find rises out of its socket, then its card.
    const ghosts = s.objects[o].tiles.map((t) => {
      const { x, y } = this.tileOrigin(t);
      return this.add.rectangle(x + TILE / 2, y + TILE / 2, TILE - 2, TILE - 2, FIND);
    });
    this.tweens.add({
      targets: ghosts,
      y: '-=18',
      scale: 1.12,
      duration: 650,
      ease: 'Sine.Out',
      onComplete: () => {
        this.tweens.add({
          targets: ghosts,
          alpha: 0,
          duration: 250,
          onComplete: () => ghosts.forEach((g) => g.destroy()),
        });
        this.showCard(result, damage);
      },
    });
  }

  private sleep(): void {
    if (this.card) return;
    this.stopHold();
    this.cameras.main.fadeOut(350, 0, 0, 0);
    this.cameras.main.once('camerafadeoutcomplete', () => {
      const weathered = endDay(this.state);
      this.render();
      this.cameras.main.fadeIn(450, 0, 0, 0);
      for (const o of weathered) {
        this.float(this.state.objects[o].tiles[0], 'weathered', '#ff7a5c');
      }
    });
  }

  private float(i: number, words: string, colour: string): void {
    const { x, y } = this.tileOrigin(i);
    const t = this.add
      .text(x + TILE / 2, y, words, { fontSize: '13px', color: colour, fontStyle: 'bold' })
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
    s.tiles.forEach((t, i) => {
      const v = this.views[i];
      const b = t.object >= 0 ? s.objects[t.object] : undefined;
      let colour = LAYER_COLOURS[Math.min(t.startDepth - t.depth, LAYER_COLOURS.length - 1)];
      if (showsStain(t)) colour = STAIN;
      if (t.depth === 0) colour = !b ? FLOOR : b.lifted ? SOCKET : t.chipped ? CHIP : FIND;
      v.soil.setFillStyle(colour);

      const h = s.hints[i];
      const est = this.showMap && h.predicted && h.depthEstimate !== null && t.depth > 0;
      v.estimate.setText(est ? `${h.exact ? '' : '~'}${h.depthEstimate}` : '');
      v.probe.setText(t.probed && t.depth > 0 ? `${t.depth}${b ? '!' : ''}` : '');
      v.debug.setText(
        this.showDebug ? `${t.depth}${b ? ` ${b.kind.name[0]}` : ''}${t.stain ? ' s' : ''}` : '',
      );
    });
    this.drawOverlay();

    const done = siteDone(s);
    this.header.setText(
      `Day ${s.day}  ·  ${s.grade} map  ·  seed ${s.seed}${done ? '  ·  site finished' : ''}`,
    );
    this.staminaBar.setSize(290 * (s.stamina / s.config.stamina), 12);
    const tools = TOOLS.map(
      (t, k) => `${this.tool === t ? '▶' : '  '} ${k + 1} ${t} (${s.config.cost[t]})`,
    );
    const left = s.objects.filter((b) => !b.lifted).length;
    this.panel.setText(
      [
        `${s.stamina} / ${s.config.stamina}`,
        '',
        tools.slice(0, 2).join('     '),
        tools.slice(2).join('     '),
        TOOL_TEXT[this.tool],
        '',
        `Hold an exposed find to lift it (${s.config.liftCost}). Orange tiles: soil still packed against it; lifting now damages it.`,
        '',
        'Blue boxes: where the map says finds are.',
        'Dark green soil: often one layer above a find.',
        'A find left partly exposed overnight weathers.',
        '',
        done
          ? 'Every find is out. R for a new site.'
          : `${left} of ${s.objects.length} finds still in the ground.`,
        '',
        'N sleep  ·  M map grade  ·  H hide map',
        'Space same ground  ·  R new site  ·  ` debug',
      ].join('\n'),
    );

    const found = [...this.crownPieces].sort().join(', ');
    const crownLine =
      this.crownPieces.size === LANTERN_CROWN.pieces
        ? 'Lantern Crown: all four pieces found. Ready to assemble at camp.'
        : `Lantern Crown: pieces ${found || 'none yet'} of ${LANTERN_CROWN.pieces}. Each site holds one.`;
    const recent = this.tray
      .slice(0, 4)
      .map((r) => `${r.kind.name}${r.piece ? ` (piece ${r.piece})` : ''}: ${r.condition}`);
    this.trayText.setText([crownLine, ...recent].join('\n'));

    this.debugPanel.setText(
      this.showDebug
        ? `debug: pick ${s.actions.pick}, trowel ${s.actions.trowel}, brush ${s.actions.brush},` +
            ` probe ${s.actions.probe}, lift ${s.actions.lift}`
        : '',
    );
  }

  private drawOverlay(): void {
    const s = this.state;
    const g = this.overlay.clear();
    if (this.showMap) {
      g.lineStyle(2, MAP_LINE, 0.8);
      s.hints.forEach((h, i) => {
        if (!h.predicted || s.tiles[i].depth === 0) return;
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x + 4, y + 4, TILE - 10, TILE - 10);
      });
    }
    // Exposed finds glow gold; the soil still locking them in shows orange.
    s.objects.forEach((b, o) => {
      if (b.lifted || !isExposed(s, o)) return;
      g.lineStyle(2, FIND, 1);
      for (const i of b.tiles) {
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x, y, TILE - 2, TILE - 2);
      }
      g.lineStyle(2, LOCKED, 0.9);
      for (const i of lockedSides(s, o)) {
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x + 3, y + 3, TILE - 8, TILE - 8);
      }
    });

    let hint = '';
    if (this.hovered >= 0 && !this.card) {
      g.lineStyle(2, 0xffffff, 0.7);
      for (const i of area(s, this.hovered, this.tool)) {
        const { x, y } = this.tileOrigin(i);
        g.strokeRect(x, y, TILE - 2, TILE - 2);
      }
      const o = s.tiles[this.hovered].object;
      if (o >= 0 && !s.objects[o].lifted && isExposed(s, o)) {
        const d = liftDamage(s, o);
        hint = d ? `Lifting now would do ${d} damage.` : 'Clear all round: a clean lift.';
      }
    }
    this.hint.setText(hint);
  }

  private showCard(r: FindResult, fromLift: number): void {
    const style = CONDITION_STYLE[r.condition];
    const cx = GRID_X + (this.state.config.cols * TILE) / 2;
    const cy = GRID_Y + (this.state.config.rows * TILE) / 2;
    const name = r.piece
      ? `${r.kind.name}, piece ${r.piece} of ${r.kind.set?.pieces}`
      : r.kind.name;
    const damage =
      r.damage === 0
        ? 'Not a scratch on it.'
        : `${r.damage} damage${fromLift ? `, ${fromLift} of it from lifting it locked in` : ''}.`;
    const notes = [
      `${style.label}  ·  context: ${r.context}`,
      damage,
      '',
      siteDone(this.state) ? 'That was the last find here. R for a new site.' : 'Click to go on.',
    ];
    const bg = this.add.rectangle(0, 0, 540, 220, 0x15130f, 0.94).setStrokeStyle(2, 0x5a5243);
    const icon = this.add.rectangle(0, -66, 34, 34, FIND).setAngle(45);
    const title = this.add
      .text(0, -22, name, { fontSize: '24px', color: style.colour, fontStyle: 'bold' })
      .setOrigin(0.5);
    const body = this.add
      .text(0, 44, notes.join('\n'), {
        fontSize: '14px',
        color: INK,
        align: 'center',
        lineSpacing: 5,
      })
      .setOrigin(0.5);
    this.card = this.add.container(cx, cy, [bg, icon, title, body]).setScale(0.6).setAlpha(0);
    const pristine = r.condition === 'pristine';
    this.tweens.add({
      targets: this.card,
      scale: 1,
      alpha: 1,
      duration: pristine ? 600 : 300,
      ease: pristine ? 'Back.Out' : 'Quad.Out',
    });
    this.tweens.add({ targets: icon, angle: 405, duration: 900, ease: 'Cubic.Out' });
    if (pristine) this.sparkle(cx, cy - 66);
  }

  private closeCard(): void {
    this.card?.destroy();
    this.card = undefined;
  }

  private sparkle(x: number, y: number): void {
    for (let k = 0; k < 16; k++) {
      const angle = (k / 16) * Math.PI * 2;
      const star = this.add.rectangle(x, y, 6, 6, FIND).setAngle(45);
      this.tweens.add({
        targets: star,
        x: x + Math.cos(angle) * 150,
        y: y + Math.sin(angle) * 80,
        alpha: 0,
        duration: 900,
        ease: 'Quad.Out',
        onComplete: () => star.destroy(),
      });
    }
  }

  // ---- geometry ----------------------------------------------------------------------------

  private tileOrigin(i: number, cols = this.state?.config.cols ?? 14): { x: number; y: number } {
    return { x: GRID_X + (i % cols) * TILE, y: GRID_Y + Math.floor(i / cols) * TILE };
  }

  private tileAt(px: number, py: number): number {
    const { cols, rows } = this.state.config;
    const x = Math.floor((px - GRID_X) / TILE);
    const y = Math.floor((py - GRID_Y) / TILE);
    return x >= 0 && x < cols && y >= 0 && y < rows ? y * cols + x : -1;
  }
}
