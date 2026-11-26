# SignTalk local patch: video_thumbnail 0.5.6

This is the existing `video_thumbnail` 0.5.6 package, copied from the resolved Pub cache to make the Android build reproducible with this project's Gradle 9 / AGP 9 toolchain. Its Dart, Android, and iOS implementation is unchanged.

Local changes:

- Replaced the two obsolete `jcenter()` repository declarations in `android/build.gradle` with `mavenCentral()`.
- Raised the plugin's compile SDK from 33 to 36 to satisfy its resolved AndroidX AAR metadata and match the Flutter app's compile SDK; target and minimum SDK behavior are unchanged.
- Widened the SDK upper bound from `<3.0.0` to `<4.0.0`; the package's existing API and implementation use no Dart 3-incompatible language features.
- The root `pubspec.yaml` uses a path dependency override so clean builds use this checked-in patch instead of a developer's mutable Pub cache.

The upstream package is MIT licensed; the original `LICENSE` file is retained. The upstream build failure and same repository replacement workaround are documented at https://github.com/justsoft/video_thumbnail/issues/189. Revisit and remove this local override if a compatible upstream release is published.
