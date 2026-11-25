# Functional Completion and UI Work Log

Updated: 2026-11-18

## Scope

The existing two functional destinations remain **Text to Sign** and **Sign to Text**. No navigation destination, branch, or Git history was changed. No files or assets were deleted.

## Sign to Text

- Kept the existing camera and MediaPipe Holistic pipeline and its YUV420/BGRA preprocessing. Camera callbacks feed timestamped Holistic results into the existing feature/recognition pipeline in order.
- Added a larger portrait-oriented camera preview using the sensor aspect ratio without `BoxFit.cover`, so the preview is not deliberately cropped. Landmark overlays can be hidden and show both hand skeletons, pose connections, and face points.
- Added front/back camera switching when the device exposes more than one camera, clear tracker/frame status, dropped-frame count, and transcript clearing.
- Added local video selection and sequential timestamped frame extraction at 33 ms intervals. Frames are passed to MediaPipe `RunningMode.video`; progress and cancellation are exposed. The camera stream is stopped during analysis and resumed afterward.
- The video path depends on Android/iOS video thumbnail and video-player platform support. Desktop/web video analysis has not been verified.
- The current ASL recognition manifest still declares the model unavailable. The interface reports this and does not produce English from landmarks. Video processing is not ASL translation.

## Text to Sign

- Enter submits through the same `EnglishToAslService` as the translate button.
- If a future translation resolves to an approved sequence, playback is now blocked until the GLB has loaded and the rig audit passes. The existing catalog/player supports sequential clips and transitions.
- Current local corpus records are pending review and the ASL motion catalog is empty. Thus no ASL sequence is presently eligible to play; diagnostic GLB clips are not treated as signs.
- The current female GLB and viewer were retained. This change does not replace the licensed asset or assert that its appearance/animation has been visually verified on a connected device.

## Dependencies

Added `file_picker`, `video_player`, and `video_thumbnail` because the existing dependency set had no local video picker, duration reader, or timestamp-based frame extractor. These are used only to implement the requested video path.

## Verification performed

- `dart format` on changed Dart files — passed.
- `flutter analyze` — passed with no issues.
- `flutter test -r expanded` — passed, 29 tests.
- `ml/.venv/Scripts/python.exe -m unittest discover -s ml/tests -v` — passed, 4 tests.
- At verification time, `flutter devices` listed Windows, Chrome, and Edge only; `adb devices -l` listed no Android device. Consequently, no real-camera, Redmi Note 8 YUV, or on-device video/GLB visual verification was performed.
- `flutter build apk --debug --verbose` started Gradle configuration and entered dependency downloads from Google's Android Maven repository, but did not finish in the available run and was stopped. No APK build success is claimed; rerun once dependency resolution completes.

## No-phone workstation verification (2026-11-18)

- Added Flutter's generated Web target and the required local `model-viewer` script entry so the existing GLB widget can be compiled for Chrome. No routes or destinations were added.
- Final `flutter build web --debug --no-pub` completed successfully (`Built build/web`, 103.2 s). A `flutter run -d chrome --web-port=8765` run reported the app attached to Chrome's debug service and emitted generated `<model-viewer>` HTML. The available browser screenshot was white/blank, so visible model rendering and animation playback are **not verified**.
- `flutter pub get -v` completed with exit code 0 and regenerated a complete YAML lockfile for the current dependencies. `flutter analyze` and `flutter test -r expanded` were rerun afterward: analyzer clean, 33 tests passed.
- Automated GLB asset tests now check the actual 44,298,300-byte GLB header/length, skin weights, all 30 mapped finger joints, all 14 mapped body joints, all 175 face morph targets, corresponding animation channels, and that the two `QA_` diagnostic clips are absent from the ASL catalog.
- The female GLB has no in-project source/license record in `acceptance.json`; that file marks it technical-evaluation-only and not production-ready. The asset was not replaced or redistributed.
- No local `.mp4`, `.mov`, `.webm`, or `.mkv` ASL recordings were found in the project or ML workspace. The processor tests use injected frame-reader functions; they verify order, progress, timestamps and cancellation, not real video decoding or ASL recognition.
- Python preprocessing and parity tools remain available, but there is no actual captured Flutter parity fixture in `ml/data/parity/`; numerical Flutter↔Python parity and any genuine ASL video evaluation remain unproven.

## Remaining requirements before functional completion

1. Fix and verify the observed YUV420 short-plane error on the Redmi Note 8 using captured plane metadata/logs. The current converter rejects inconsistent plane dimensions explicitly; host tests cannot establish the phone's camera plane layout.
2. Install a legally usable continuous ASL sentence model compatible with the app feature schema/runtime, plus reviewed decoding and evaluation data. None is installed.
3. Add legally reviewed ASL clips/sequences to the animation catalog. None is approved/available now.
4. Run the debug app on an Android device and visually confirm camera framing, both hands/fingers/face overlays, avatar load, and any genuine approved ASL animation. These checks remain pending.

This work does not complete either real ASL translation direction or Phase 1 visual animation verification.

## Final classification

### Implemented and tested

- Conservative English sentence lookup and whole-utterance catalog validation; unsupported, pending-review and incomplete sequences are rejected.
- Sequential clip-plan controller and transitions already present; submission now uses the same path from keyboard and button, with avatar/rig readiness gating.
- Offline Holistic feature extraction, temporal buffering, YUV/BGRA conversion, timestamped video processor and cancellation logic.
- Structural validation of the checked-in GLB and its mapped body/finger/face animation channels.
- Flutter `analyze`, the full Flutter suite, Python preprocessing tests and Web compilation as recorded above.

### Implemented but not visually verified

- GLB rendering in its Flutter Web platform view and the 3D animation playback bridge. Chrome debug attached, but the captured page was blank; no successful visual avatar render/playback is claimed.
- Live camera permission/frame delivery, MediaPipe landmark counts, device camera switching, and local video decoding through the platform thumbnail plugin.

### Blocked by missing assets/data/model/license

- Text-to-ASL: all eight bundled entries are pending review; there are no approved glosses or motion clips/utterances. The two GLB clips are diagnostics, not signs. The avatar's source/license is not recorded in the workspace, and `acceptance.json` labels it evaluation-only.
- ASL-to-English: model manifest is unavailable, has no weights/runtime/license/training source, and reviewed sentence decoder has no mappings. No local ASL videos, parity fixture, or independent evaluation set exists. The 2,582-feature parity result and ASL WER remain unavailable.

### Requires physical Android device testing

- Redmi Note 8 YUV420 plane error reproduction/fix, actual camera frame and landmark updates, camera switching, Android picker/frame decoding, progress/cancellation/resume, and Android WebView GLB rendering/playback. No phone was connected for this work.
