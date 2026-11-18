# SignTalk — Two-screen implementation

This project intentionally exposes **two screens only**:

1. **Text to Sign** — English sentence input and the included female GLB rig viewer.
2. **Sign to Text** — front-camera capture, MediaPipe holistic landmarks, and a transcript panel.

## Important implementation status

This is a two-screen Flutter integration build, not a completed ASL translator.

- The supplied female GLB is a technical rig candidate. Its own acceptance metadata says photorealism and hand detail did not pass the requested acceptance gate.
- No male GLB is included.
- `assets/animations/asl/manifest.json` currently contains no reviewed utterances or ASL animation clips. The text screen therefore refuses to play invented gestures. It only plays a sentence when an exact, reviewed clip sequence exists in the catalog.
- MediaPipe provides hand, pose and face landmarks. The camera screen does **not** yet translate continuous ASL into English; it explicitly shows that the recognition/translation model is not connected.
- The diagnostic animation is not ASL and is not offered as a translation.

Do not present this build as accurate ASL translation until a licensed continuous-ASL recognition model, an English-to-ASL linguistic pipeline, and human-reviewed motion clips retargeted to an accepted avatar rig have been added and evaluated with Deaf ASL users/interpreters.

## Run

```powershell
flutter clean
flutter pub get
dart run mediapipe_core:bundle_models
flutter analyze
flutter test
flutter run
```

The MediaPipe model asset is already present in `assets/mediapipe/`. The bundling command may be needed if the plugin hook reports missing generated model assets.

## Camera permissions

Android camera and internet permissions are declared in `android/app/src/main/AndroidManifest.xml`. iOS camera usage text is in `ios/Runner/Info.plist`.

## Validation boundary

The archive was assembled by static source editing. Flutter SDK/Dart are not available in the packaging environment, so `flutter analyze`, `flutter test`, Android build, iOS build and on-device camera/model-viewer behavior have **not** been run here. Run the commands above on the development machine and share any output before treating the build as verified.
