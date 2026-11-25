const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

class MockModelViewer {
  constructor() {
    this.availableAnimations = ['reviewed_clip_a', 'reviewed_clip_b'];
    this.duration = 2;
    this.currentTime = 0;
    this.animationName = '';
    this.animationCrossfadeDuration = 0;
    this.timeScale = 1;
    this.listeners = new Map();
    this.playCalls = [];
    this.pauseCalls = 0;
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  emit(type, detail = {}) {
    for (const listener of this.listeners.get(type) ?? []) {
      listener({ detail });
    }
  }

  play(options) {
    this.playCalls.push(options);
  }

  pause() {
    this.pauseCalls += 1;
  }
}

const model = new MockModelViewer();
const messages = [];
const modelElement = { postMessage: (message) => messages.push(JSON.parse(message)) };
const window = {
  SignTalkBridge: modelElement,
  dispatchEvent() {},
};
const document = { querySelector: (selector) => {
  assert.equal(selector, 'model-viewer');
  return model;
} };
const scriptPath = path.join(__dirname, '..', 'assets', 'avatar', 'runtime', 'playback_bridge.js');
const source = fs.readFileSync(scriptPath, 'utf8');
vm.runInNewContext(source, { document, window, CustomEvent: class {} });

model.emit('load');
assert.equal(messages.at(-1).type, 'ready');
assert.deepEqual(messages.at(-1).clips, ['reviewed_clip_a', 'reviewed_clip_b']);

window.SignTalkAvatar.setState({
  clip: 'reviewed_clip_a', playing: true, speed: 1, durationMs: 1000,
  transitionMs: 250, replay: 1,
});
assert.equal(model.animationName, 'reviewed_clip_a');
assert.equal(model.currentTime, 0);
assert.equal(model.animationCrossfadeDuration, 250);
assert.equal(model.timeScale, 2);
assert.equal(model.playCalls.at(-1).repetitions, 1);

window.SignTalkAvatar.setState({ playing: false });
assert.ok(model.pauseCalls >= 1, 'pause command reaches model-viewer');
window.SignTalkAvatar.setState({ playing: true });
assert.equal(model.playCalls.length, 2, 'resume restarts the current clip');

window.SignTalkAvatar.setState({
  clip: 'reviewed_clip_b', playing: true, speed: 1, durationMs: 2000,
  transitionMs: 150, replay: 2,
});
assert.equal(model.animationName, 'reviewed_clip_b');
model.emit('finished');
assert.equal(messages.at(-1).type, 'finished');
assert.equal(messages.at(-1).clip, 'reviewed_clip_b');

window.SignTalkAvatar.setState({ clip: null, playing: false, durationMs: null });
assert.equal(model.currentTime, 0, 'stop clears and resets the model timeline');

window.SignTalkAvatar.setState({ clip: 'missing_clip', playing: true });
assert.equal(messages.at(-1).type, 'error');
assert.match(messages.at(-1).message, /Animation clip is missing/);

console.log('Playback bridge mock tests passed: load, named clips, timing, pause/resume, sequence finish, stop, and missing clip.');
