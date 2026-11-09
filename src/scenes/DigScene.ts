// Gray-box dig: placeholder shapes only, to find out whether the core verb is fun (FEEL_DIG.md).
// All rules live in src/engine/dig.ts; this scene only draws them and turns input into actions.
import Phaser from 'phaser';
import {
  canDig,
  createDig,
  dig,
  endDig,
  MAP_GRADES,
  result,
  showsStain,
  toolCost,
  type DigEvent,
  type DigState,
  type MapGrade,
  type Tool,
} from '../engine/dig';

const TILE = 48;
const GRID_X = 32;
const GRID_Y = 80;
const PANEL_X = 640;
/** How long the brush must be held to lift one layer. */
const BRUSH_MS = 450;

// Soil darkens toward lighter, sandier tones the deeper you go. Colour shows layers removed,
// never layers remaining, so the ground alone doesn't give the answer away.
const LAYER_COLOURS = [0x7d5d3e, 0x8f6c48, 0x9e7a50, 0xab8758, 0xb79464];
const STAIN = 0x5f6136;
const FLOOR = 0xd2c194;
const FIND = 0xe3c35a;
const CHIP = 0xc0503a;
const MAP_LINE = 0x5fd0e0;

const CONDITION_STYLE = {
  pristine: { label: 'Pristine', colour: '#f2d36b' },
  intact: { label: 'Intact', colour: '#e8e2cf' },
  worn: { label: 'Worn', colour: '#b9a77f' },
  fragment: { label: 'Fragment', colour: '#8a8172' },
} as const;

interface TileView {
  soil: Phaser.GameObjects.Rectangle;
  estimate: Phaser.GameObjects.Text;
  debug: Phaser.GameObjects.Text;
}

export class DigScene extends Phaser.Scene {
  private state!: DigState;
  private seed = 1;
  private grade: MapGrade = 'measured';
  private tool: Tool = 'trowel';
  private showMap = true;
  private showDebug = false;

  private views: TileView[] = [];
  private mapLayer!: Phaser.GameObjects.Graphics;
  private hover!: Phaser.GameObjects.Rectangle;
  private brushBar!: Phaser.GameObjects.Rectangle;
  private staminaBar!: Phaser.GameObjects.Rectangle;
  private panel!: Phaser.GameObjects.Text;
  private header!: Phaser.GameObjects.Text;
  private debugPanel!: Phaser.GameObjects.Text;
  private endLayer?: Phaser.GameObjects.Container;
  private brushing: { i: number; start: number } | null = null;

  constructor() {
    super('dig');
  }

  create(): void {
    const fromUrl = Number(new URLSearchParams(window.location.search).get('seed'));
    this.seed = Number.isFinite(fromUrl) && fromUrl > 0 ? fromUrl : Date.now() % 100000;
    this.input.mouse?.disableContextMenu();

    this.header = this.add.text(GRID_X, 24, '', { fontSize: '18px', color: '#e8e2cf' });
    this.buildGrid();
    this.buildPanel();
    this.bindKeys();
    this.newDig(this.seed);
  }

  update(time: number): void {
    if (!this.brushing) return;
    const { i, start } = this.brushing;
    const pointer = this.input.activePointer;
    if (!pointer.isDown || this.tileAt(pointer.x, pointer.y) !== i || this.state.ended) {
      this.stopBrushing();
      return;
    }
    const progress = Math.min(1, (time - start) / BRUSH_MS);
    const { x, y } = this.tileOrigin(i);
    this.brushBar
      .setPosition(x + 4, y + TILE - 8)
      .setSize((TILE - 8) * progress, 4)
      .setVisible(true);
    if (progress >= 1) {
      this.stopBrushing();
      this.act(i, 'brush');
    }
  }

  // ---- setup -------------------------------------------------------------------------------

  private buildGrid(): void {
    const { cols, rows } = createDig(1, 'rough').config;
    for (let i = 0; i < cols * rows; i++) {
      const { x, y } = this.tileOrigin(i);
      const soil = this.add
        .rectangle(x + TILE / 2, y + TILE / 2, TILE - 2, TILE - 2, LAYER_COLOURS[0])
        .setInteractive();
      soil.on('pointerdown', (p: Phaser.Input.Pointer) => this.press(i, p));
      const estimate = this.add.text(x + 4, y + 2, '', { fontSize: '13px', color: '#bff3fa' });
      const debug = this.add.text(x + 4, y + 28, '', { fontSize: '11px', color: '#ff9ad5' });
      this.views.push({ soil, estimate, debug });
    }
    this.mapLayer = this.add.graphics();
    this.hover = this.add
      .rectangle(0, 0, TILE - 2, TILE - 2)
      .setStrokeStyle(2, 0xffffff, 0.7)
      .setVisible(false);
    this.brushBar = this.add.rectangle(0, 0, 0, 4, 0xffffff).setOrigin(0, 0).setVisible(false);

    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      const i = this.tileAt(p.x, p.y);
      if (i < 0) return void this.hover.setVisible(false);
      const { x, y } = this.tileOrigin(i);
      this.hover.setPosition(x + TILE / 2, y + TILE / 2).setVisible(true);
    });
  }

  private buildPanel(): void {
    this.add.text(PANEL_X, 80, 'Stamina', { fontSize: '14px', color: '#e8e2cf' });
    this.add.rectangle(PANEL_X, 102, 280, 14, 0x3a352d).setOrigin(0, 0);
    this.staminaBar = this.add.rectangle(PANEL_X, 102, 280, 14, 0x7fc06a).setOrigin(0, 0);
    this.panel = this.add.text(PANEL_X, 130, '', {
      fontSize: '14px',
      color: '#e8e2cf',
      lineSpacing: 6,
      wordWrap: { width: 300 },
    });
    this.debugPanel = this.add.text(GRID_X, 540, '', { fontSize: '12px', color: '#ff9ad5' });
  }

  private bindKeys(): void {
    const kb = this.input.keyboard!;
    kb.on('keydown-ONE', () => this.setTool('trowel'));
    kb.on('keydown-TWO', () => this.setTool('brush'));
    kb.on('keydown-M', () => {
      this.grade = MAP_GRADES[(MAP_GRADES.indexOf(this.grade) + 1) % MAP_GRADES.length];
      this.newDig(this.seed);
    });
    kb.on('keydown-H', () => {
      this.showMap = !this.showMap;
      this.render();
    });
    kb.on('keydown-BACKTICK', () => {
      this.showDebug = !this.showDebug;
      this.render();
    });
    kb.on('keydown-E', () => {
      if (this.state.ended) return;
      endDig(this.state);
      this.render();
      this.showResult();
    });
    kb.on('keydown-SPACE', () => this.newDig(this.seed));
    kb.on('keydown-R', () => this.newDig(Math.floor(Math.random() * 100000) + 1));
  }

  // ---- play --------------------------------------------------------------------------------

  private newDig(seed: number): void {
    this.seed = seed;
    this.state = createDig(seed, this.grade);
    this.stopBrushing();
    this.endLayer?.destroy();
    this.endLayer = undefined;
    this.render();
  }

  private setTool(tool: Tool): void {
    this.tool = tool;
    this.render();
  }

  private press(i: number, p: Phaser.Input.Pointer): void {
    const tool: Tool = p.rightButtonDown() ? 'brush' : this.tool;
    if (!canDig(this.state, i, tool)) {
      if (!this.state.ended && this.state.tiles[i].depth > 0) this.float(i, 'too tired', '#c9b9a0');
      return;
    }
    if (tool === 'trowel') this.act(i, 'trowel');
    else this.brushing = { i, start: this.time.now };
  }

  private stopBrushing(): void {
    this.brushing = null;
    this.brushBar?.setVisible(false);
  }

  private act(i: number, tool: Tool): void {
    const event = dig(this.state, i, tool);
    this.render();
    this.feedback(i, event);
    if (this.state.ended) this.time.delayedCall(450, () => this.showResult());
  }

  private feedback(i: number, event: DigEvent): void {
    const soil = this.views[i].soil;
    if (event === 'removed') {
      this.tweens.add({ targets: soil, alpha: { from: 0.55, to: 1 }, duration: 140 });
    } else if (event === 'floor') {
      this.float(i, 'nothing', '#9c927d');
    } else if (event === 'exposed') {
      this.tweens.add({
        targets: soil,
        scale: { from: 1.25, to: 1 },
        duration: 260,
        ease: 'Back.Out',
      });
      this.float(i, 'found', '#f2d36b');
    } else if (event === 'chipped') {
      this.cameras.main.shake(90, 0.006);
      this.tweens.add({ targets: soil, angle: { from: -8, to: 0 }, duration: 200 });
      this.float(i, 'chip!', '#ff7a5c');
    }
  }

  private float(i: number, words: string, colour: string): void {
    const { x, y } = this.tileOrigin(i);
    const t = this.add
      .text(x + TILE / 2, y, words, { fontSize: '14px', color: colour, fontStyle: 'bold' })
      .setOrigin(0.5, 1);
    this.tweens.add({
      targets: t,
      y: y - 24,
      alpha: 0,
      duration: 700,
      onComplete: () => t.destroy(),
    });
  }

  // ---- drawing -----------------------------------------------------------------------------

  private render(): void {
    const s = this.state;
    s.tiles.forEach((t, i) => {
      const v = this.views[i];
      let colour = LAYER_COLOURS[Math.min(t.startDepth - t.depth, LAYER_COLOURS.length - 1)];
      if (showsStain(t)) colour = STAIN;
      if (t.depth === 0) colour = !t.isFind ? FLOOR : t.chipped ? CHIP : FIND;
      v.soil.setFillStyle(colour);

      const h = s.hints[i];
      const est = this.showMap && h.predicted && h.depthEstimate !== null && t.depth > 0;
      const prefix = s.grade === 'measured' ? '~' : '';
      v.estimate.setText(est ? `${prefix}${h.depthEstimate}` : '');

      v.debug.setText(
        this.showDebug ? `${t.depth}${t.isFind ? ' F' : ''}${t.stain ? ' s' : ''}` : '',
      );
    });

    this.mapLayer.clear();
    if (this.showMap) {
      this.mapLayer.lineStyle(2, MAP_LINE, 0.85);
      s.hints.forEach((h, i) => {
        if (!h.predicted) return;
        const { x, y } = this.tileOrigin(i);
        this.mapLayer.strokeRect(x + 4, y + 4, TILE - 10, TILE - 10);
      });
    }

    this.header.setText(`Gray-box dig  ·  seed ${s.seed}  ·  ${s.grade} map`);
    this.staminaBar.setSize(280 * (s.stamina / s.config.stamina), 14);
    const tool = (t: Tool, key: string) =>
      `${this.tool === t ? '▶' : '  '} ${key}  ${t} (${toolCost(s, t)} stamina)`;
    this.panel.setText(
      [
        `${s.stamina} / ${s.config.stamina}`,
        '',
        tool('trowel', '1'),
        tool('brush', '2'),
        'Trowel: one click, one layer. Breaking through onto the find chips it.',
        'Brush: hold for one layer. Safe. Right-click always brushes.',
        '',
        'Blue boxes: where your map says the find is.',
        s.grade === 'fine'
          ? 'Numbers: layers above it.'
          : s.grade === 'measured'
            ? 'Numbers: the map’s guess at layers above it.'
            : 'A rough map gives no depths.',
        'Dark green soil: a stain, often one layer above something.',
        '',
        'M map grade  ·  H hide map  ·  E end and lift',
        'Space same ground  ·  R new ground  ·  ` debug',
      ].join('\n'),
    );

    if (this.showDebug) {
      const r = result(s);
      this.debugPanel.setText(
        [
          `debug: exposed ${r.exposed}/${r.total}, chips ${r.chips}`,
          `actions: trowel ${s.actions.trowel}, brush ${s.actions.brush}`,
          `condition now: ${r.condition}`,
        ].join('\n'),
      );
    } else this.debugPanel.setText('');
  }

  private showResult(): void {
    if (this.endLayer) return;
    const r = result(this.state);
    const style = CONDITION_STYLE[r.condition];
    const cx = GRID_X + (this.state.config.cols * TILE) / 2;
    const cy = GRID_Y + (this.state.config.rows * TILE) / 2;

    const bg = this.add.rectangle(0, 0, 540, 230, 0x15130f, 0.92).setStrokeStyle(2, 0x5a5243);
    const title = this.add
      .text(0, -70, style.label, { fontSize: '40px', color: style.colour, fontStyle: 'bold' })
      .setOrigin(0.5);
    const lines = this.add
      .text(
        0,
        20,
        [
          `Exposed ${r.exposed} of ${r.total}  ·  chips ${r.chips}`,
          `Context: ${r.context}  ·  stamina left ${r.staminaLeft}`,
          '',
          'Space: same ground  ·  R: new ground  ·  M: map grade',
        ].join('\n'),
        { fontSize: '15px', color: '#e8e2cf', align: 'center', lineSpacing: 6 },
      )
      .setOrigin(0.5);

    this.endLayer = this.add.container(cx, cy, [bg, title, lines]).setScale(0.6).setAlpha(0);
    this.tweens.add({
      targets: this.endLayer,
      scale: 1,
      alpha: 1,
      duration: r.condition === 'pristine' ? 600 : 300,
      ease: r.condition === 'pristine' ? 'Back.Out' : 'Quad.Out',
    });
    if (r.condition === 'pristine') this.sparkle(cx, cy - 70);
  }

  private sparkle(x: number, y: number): void {
    for (let k = 0; k < 14; k++) {
      const angle = (k / 14) * Math.PI * 2;
      const star = this.add.rectangle(x, y, 6, 6, FIND).setAngle(45);
      this.tweens.add({
        targets: star,
        x: x + Math.cos(angle) * 130,
        y: y + Math.sin(angle) * 70,
        alpha: 0,
        duration: 900,
        ease: 'Quad.Out',
        onComplete: () => star.destroy(),
      });
    }
  }

  // ---- geometry ----------------------------------------------------------------------------

  private tileOrigin(i: number): { x: number; y: number } {
    const cols = this.state?.config.cols ?? 12;
    return { x: GRID_X + (i % cols) * TILE, y: GRID_Y + Math.floor(i / cols) * TILE };
  }

  private tileAt(px: number, py: number): number {
    const { cols, rows } = this.state.config;
    const x = Math.floor((px - GRID_X) / TILE);
    const y = Math.floor((py - GRID_Y) / TILE);
    return x >= 0 && x < cols && y >= 0 && y < rows ? y * cols + x : -1;
  }
}
