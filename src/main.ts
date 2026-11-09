import Phaser from 'phaser';
import { DigScene } from './scenes/DigScene';
import { SurveyScene } from './scenes/SurveyScene';

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: 960,
  height: 640,
  backgroundColor: '#1b1a17',
  pixelArt: true,
  // Scale the fixed 960 × 640 play area to fit the window, keeping its shape.
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  // A site starts with surveying it; D hands the survey's map to the dig.
  scene: [SurveyScene, DigScene],
});
