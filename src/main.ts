import Phaser from 'phaser';
import { DigScene } from './scenes/DigScene';

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: 960,
  height: 640,
  backgroundColor: '#1b1a17',
  pixelArt: true,
  scene: [DigScene],
});
