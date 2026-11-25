# Text to Sign motion playback architecture

Scope: Text to Sign only. The camera, Sign to Text, MediaPipe, video processing, and their tests are outside this document and were not changed.

## Existing offline path

1. `TextToSignScreen` submits entered English to `EnglishToAslService` using bundled translation records. A record pending review does not yield a playable gloss.
2. `AslSequenceBuilder` accepts only a complete approved utterance plan resolved by `AslMotionCatalog`. The catalog checks the stable utterance ID, language, rig ID, reviewer role/evidence, source/license metadata, compatibility, sign articulation metadata, clip presence, and full sequence gloss. It rejects `QA_` diagnostic clips.
3. The screen also requires the avatar to finish loading and the current GLB's structural rig audit to pass before it starts a plan.
4. `RealisticAvatarStage` loads the bundled GLB and local JavaScript bridge. `model-viewer` reports its available animation names. There is no network-hosted avatar or sign data in this path.
5. The bridge selects a named clip, applies speed and duration scaling, configures crossfade duration, and plays once. Flutter advances to the next validated step only after the viewer reports `finished`.
6. Pause/resume are sent to the same active clip. Replay resets to step zero. **Explicit stop is now provided** in the screen controls: it clears the active clip and sequence; the bridge pauses and resets the model timeline.
7. Missing clips and viewer errors stop playback and surface an error. A null clip pauses/resets. No fallback or random clip is selected.

## Facial/non-manual channels

The renderer can play glTF animation channels that target morph weights, when exported and supported by the loaded model. The current rig audit only establishes that facial morph targets exist and that at least one animation in the GLB targets weights; it does **not** prove that every named sign clip animates the required facial markers. The catalog's `facialExpression` and `nonManualMarkers` are metadata, not a runtime facial controller. Before a sign can be accepted, validate the specific clip's face channels and compare them with the reviewed non-manual articulation. Do not claim face animation for a clip based on the model-wide audit alone.

## Sequence timing and transitions

Each accepted utterance supplies per-step duration and optional transition duration (default 150 ms; bounded by catalog and bridge). The viewer's natural clip duration is scaled to requested duration and user playback speed, with an error if the resulting scale falls outside supported bounds. The viewer's `finished` event is the sequencing boundary. Actual transition quality depends on source animation tracks and must be visually checked; a crossfade setting does not make unrelated clips linguistically continuous.

## Current content and verification limits

- ASL catalog: zero signs and zero utterances. Translation resource: eight records pending review. Therefore the current app correctly has no complete English-to-ASL-to-avatar sequence to play.
- Embedded avatar QA clips are structural diagnostics only; they are never catalog content and are not ASL.
- Asset parsing, schema checks, and playback bridge code inspection do not establish visual playback quality. A prior headless Web capture returned a blank viewer; no successful visual animation playback on a running device is established here.
- Current avatar remains technical-evaluation-only and is 42.25 MiB. Replacement and on-device optimization remain pending.
- `node scripts/test_playback_bridge.cjs` exercises the bridge with a mock `model-viewer` to verify load, named clips, duration/speed scaling, pause/resume, completion signaling, stop/reset, and missing-clip errors. This checks command behavior only; it does not render the GLB, prove a sign clip's channels, or substitute for visual/device verification.

## Next interfaces

Keep English translation and motion playback separate. Add new content only as reviewed catalog records referencing local named clips. Each clip must declare its rig, license/provenance, source, gloss, handshape/orientation/location/movement review, non-manual review, expected facial channels, duration, and reviewer evidence. A future renderer capability audit should inspect animation channels per clip rather than infer them from the set of all animations.

## Verification run (2026-11-19)

- `dart --suppress-analytics format lib/features/text_to_sign/text_to_sign_screen.dart`: passed, zero files changed by formatter.
- `flutter --suppress-analytics analyze`: passed, no issues.
- Targeted catalog/translation/avatar tests: 14 passed.
- `flutter --suppress-analytics test -r expanded`: 33 passed.
- `node scripts/test_playback_bridge.cjs`: passed against a mocked model-viewer.

Flutter's SDK lockfile under `C:\flutter\bin\cache` was not writable in the default sandbox. The verification commands were run after granting the command access to the SDK cache; no Android Gradle files or Sign to Text code were changed in this phase. Results establish code and mock-bridge behavior, not actual GLB visual playback or ASL correctness.
