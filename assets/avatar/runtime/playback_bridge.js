// SignTalk mobile bridge. Diagnostic clips are never interpreted as ASL.
(() => {
  const model = document.querySelector('model-viewer');
  let loaded = false;
  let previous = {clip: null, replay: 0};
  let pending = {playing: false, speed: 1, clip: null, durationMs: null, transitionMs: 150, replay: 0};
  const send = (type, extra = {}) => {
    const message = JSON.stringify({type, ...extra});
    if (window.SignTalkBridge) window.SignTalkBridge.postMessage(message);
    window.dispatchEvent(new CustomEvent('signtalk-status', {detail: JSON.parse(message)}));
  };
  function apply() {
    if (!loaded) return;
    const state = pending;
    const speed = Number(state.speed);
    const userSpeed = Number.isFinite(speed) ? speed : 1;
    if (!state.clip) { model.pause(); model.currentTime = 0; previous = {...state}; return; }
    if (!model.availableAnimations.includes(state.clip)) {
      model.pause(); send('error', {message: 'Animation clip is missing: ' + state.clip}); return;
    }
    const transitionMs = Number(state.transitionMs);
    model.animationCrossfadeDuration = Number.isFinite(transitionMs)
      ? Math.min(2000, Math.max(0, transitionMs))
      : 150;
    const reset = state.clip !== previous.clip || state.replay !== previous.replay;
    if (reset) { model.pause(); model.animationName = state.clip; model.currentTime = 0; }
    const requestedDuration = Number(state.durationMs);
    const naturalDuration = Number(model.duration) * 1000;
    const durationScale = requestedDuration > 0 && naturalDuration > 0
      ? naturalDuration / requestedDuration
      : 1;
    const timeScale = userSpeed * durationScale;
    if (!Number.isFinite(timeScale) || timeScale < .05 || timeScale > 20) {
      model.pause();
      send('error', {message: 'Requested sign timing is outside the supported playback range.'});
      return;
    }
    model.timeScale = timeScale;
    if (state.playing) model.play({repetitions: 1}); else model.pause();
    previous = {...state};
  }
  window.SignTalkAvatar = {setState(state) {pending = {...pending, ...state}; apply();}};
  model.addEventListener('load', () => {
    loaded = true; model.pause();
    send('ready', {clips: [...model.availableAnimations]}); apply();
  });
  model.addEventListener('progress', event => {
    const progress = Number(event.detail?.totalProgress);
    if (Number.isFinite(progress)) send('progress', {progress});
  });
  model.addEventListener('error', event => {
    loaded = false; send('error', {message: 'GLB failed to load', detail: String(event.detail?.type || '')});
  });
  model.addEventListener('finished', () => {
    pending.playing = false; send('finished', {clip: pending.clip});
  });
})();
