# SignTalk — Full Project Audit

Audit date: 2026-11-19  
Repository: `TaghreedLouz/sign_talk`  
Workspace: `F:\IEEE\SignTalk_working_fixes\sign_talk_two_screens`  
Use: non-commercial educational/research prototype.

## Executive status

The project has a working two-destination Flutter shell, a review-gated English input/resource lookup, an empty-but-safe ASL animation catalog, a structural GLB/rig audit, and a MediaPipe camera/video feature pipeline with an explicit unavailable ASL model adapter. It does **not** currently translate English to ASL or ASL to English because approved translation records, reviewed ASL motion sequences, an evaluated recognition model, and independent recordings are absent.

The code compiles for Web and the automated tests pass. The web page rendered a blank screenshot in headless Chrome, so visual rendering remains unverified. Android APK compilation currently fails while evaluating the existing `video_thumbnail 0.5.6` Android plugin against the checked-in Gradle/AGP stack. No Android device is connected. No model or replacement avatar passed the required content, licensing, and visual gates.

## Repository and environment state

- Branch: `clean-history`; HEAD: `ffbc72d11107f34565e293d20fc8e9075a248cb0` (`Clean initial history for SignTalk`). `origin/clean-history` resolved to the same commit during this audit. No branch or history operation was performed.
- The working tree was already dirty before this audit. The initial uncommitted paths were `lib/features/camera/camera_screen.dart`, `lib/features/text_to_sign/realistic_avatar_stage.dart`, `lib/features/text_to_sign/text_to_sign_screen.dart`, `pubspec.yaml`, `pubspec.lock`, `.metadata`, `FUNCTIONAL_COMPLETION_UI.md`, `lib/features/camera/video_frame_processor.dart`, `test/avatar_asset_test.dart`, `test/video_frame_processor_test.dart`, `web/`, and `TEXT_TO_SIGN_ASSET_ACQUISITION_RESEARCH.md`.
- This audit added the object-candidate guard and its test, plus these two audit documents. No commit or push was performed.
- Flutter 3.47.1; Dart 3.13.1; Python 3.11.9 through `ml/.venv`; NumPy 2.4.6; Pandas 2.3.3; PyTorch 2.15.0+cpu.
- Android SDK 37 and JDK 17 are installed. `flutter devices` reports Windows, Chrome, and Edge; no Android device is connected. One Pixel 9 emulator definition exists but was not launched. iOS builds require macOS/Xcode and could not be verified. Windows desktop builds require the missing Visual Studio C++ workload.
- Flutter commands initially stalled because the sandbox could not open `C:\flutter\bin\cache\lockfile`. With SDK-cache access granted for the requested verification, Flutter commands completed. A plain Dart formatter invocation also hit a denied `%APPDATA%\.dart-tool` telemetry timestamp; `--suppress-analytics` avoided that issue.

## Feature status matrix

Statuses describe demonstrated implementation, not the presence of a class or screen.

| Area | Status | Files/evidence | Implemented | Missing / acceptance evidence |
|---|---|---|---|---|
| Two functional destinations | COMPLETE | `lib/app/app.dart`; `test/widget_test.dart` | Text to Sign and Sign to Text are the two navigation destinations; test asserts exactly two. | No separate mode-selection route is present in the current app shell. |
| English text input | COMPLETE | `lib/features/text_to_sign/text_to_sign_screen.dart` | Text field, keyboard submit and translate button call the same action. | Visual verification in an interactive browser/device remains incomplete because the Chrome page capture was blank. |
| Empty input handling | COMPLETE | `text_to_sign_screen.dart` | Empty input clears playback and shows a prompt. | None for the local behavior. |
| English normalization | COMPLETE | `english_to_asl_service.dart`; `test/english_to_asl_service_test.dart` | Lowercase, punctuation/spacing normalization for exact lookup. | This is not full English parsing. |
| English linguistic analysis | PARTIAL | same service and tests | Simple question, negation, pronoun, time and role-candidate annotations for review UI. The inaccurate infinitive `to` object candidate was corrected in this audit. | Not a general parser, not ASL grammar, and never used to fabricate gloss. |
| English-to-ASL translation | BLOCKED | `english_to_asl_service.dart`; `assets/translations/en_to_asl.json` | Exact, offline lookup with approval, source, reviewer, and complete-motion gates. Unsupported/pending cases reject playback. | No approved records. All eight entries remain pending review with null gloss and utterance IDs. |
| ASL gloss representation | PARTIAL | `english_to_asl_service.dart`; translation schema | Typed gloss result for a reviewed record. | No approved gloss exists in the shipped resource. |
| ASL dictionary/coverage | NOT IMPLEMENTED | `assets/dictionary/` currently has no data files | Asset folder is reserved in `pubspec.yaml`. | No approved lexical dictionary, sentence coverage, or reviewed mappings. |
| Motion catalog and licensing gate | COMPLETE (safe empty state) | `lib/features/text_to_sign/asl_motion_catalog.dart`; `assets/animations/asl/manifest.json`; tests | Schema validation, qualified-review/source gates, clip availability check, and whole-utterance resolution. | Catalog has zero signs and zero utterances; no real motion is playable. |
| Sequence playback logic | PARTIAL | `text_to_sign_screen.dart`; `realistic_avatar_stage.dart` | Supports multi-step clip plans, duration/transition parameters, pause/replay/speed, and sequential completion callbacks. Submit is gated on avatar load and structural rig validation. | No eligible plan/real ASL clips exist, so authentic sequence playback has not been exercised. |
| Motion timing/transitions | PARTIAL | `asl_motion_catalog.dart`; `realistic_avatar_stage.dart`; `assets/avatar/runtime/playback_bridge.js` | Timing and transitions are represented and passed into the model-viewer bridge. | Only diagnostic clips exist; their playback is not ASL verification. |
| Face/non-manual expression playback | BLOCKED | `rig_map.json`; GLB structural tests; diagnostic assets | GLB contains face morph targets and diagnostic weight animation; catalog can carry non-manual markers. | No reviewed ASL facial/non-manual sequence is installed or visually reviewed. |
| Empty-catalog and unsupported handling | COMPLETE | catalog/service tests | No guessed gloss, random animation, partial sequence, or fake confidence is produced. | Keep these gates intact until real reviewed assets exist. |
| Offline text lookup | PARTIAL | bundled JSON and asset lookup services | Resource lookup is local/offline. | No valid approved translation/animation is currently available offline. |
| GLB binary integrity/structure | COMPLETE (static checks) | `assets/avatar/female/avatar.glb`; `test/avatar_asset_test.dart` | Test validates GLB v2 header/length, skin weights, mapped 30 finger joints, 14 body/arm joints, 175 face target names and animation channels. File size is 44,298,300 bytes. | Static structure does not establish visible quality, source rights, or ASL quality. |
| Avatar source and license | BLOCKED | `assets/avatar/female/acceptance.json`; asset research report | Acceptance record correctly labels evaluation-only. | Source author/license provenance is not established in the project; no production distribution approval. |
| Finger/body rig structure | COMPLETE (static) | `rig_map.json`; avatar test | Required finger, wrist/arm/body names and animation channels are present structurally. | No genuine sign retarget has tested semantic pose, deformation, orientation or timing. |
| Appearance and hand detail | FAILED by current acceptance record | `acceptance.json` | Current candidate is retained for technical work. | `photorealism: FAILED`; `hand_detail: INSUFFICIENT_FOR_FINAL_REQUIREMENT`. No replacement has passed. |
| Facial shape structure | COMPLETE (static) | `rig_map.json`; avatar test | 175 targets and a GLB weight animation are structurally present. | No sign-language facial grammar/non-manual animation was validated. |
| Flutter avatar loading/rendering | UNVERIFIED | `realistic_avatar_stage.dart`; web build and run logs | Asset path and model-viewer bridge are implemented. Web debug reported model-viewer HTML and fetched GLB files. | Headless Chrome screenshot of the web app was blank; Android build failed before install. No visually verified avatar render/playback. |
| Mobile performance | UNVERIFIED | No measurements in workspace | No offline animation performance claim. | No APK built successfully in this audit and no device timing/memory measurements. |
| Camera capture | PARTIAL; READ ONLY | `lib/features/camera/camera_screen.dart`; `asl_recognition_pipeline.dart` | Camera stream/preprocessor and MediaPipe Holistic result wiring are implemented. | No current device connected; camera frame/landmark update was not verified in this audit. |
| Local video input and frame extraction | PARTIAL; READ ONLY | `video_frame_processor.dart`; `camera_screen.dart`; tests | Picker/processor stages video timestamps in order, reports progress and can cancel; unit tests use injected frame readers. | Actual file decode/platform plugin build is not verified; no local ASL recording is present. Android build currently fails at `video_thumbnail`. |
| MediaPipe landmarks | PARTIAL; READ ONLY | `asl_recognition_pipeline.dart`; `assets/mediapipe/manifest.json`; pipeline tests | Holistic face, pose, hand and blendshape extraction and 2,582-vector construction are implemented; model bundle is recorded in manifest. | Tracking landmarks does not recognize ASL. No real-device tracking was measured in this audit. |
| Feature schema/temporal buffer | PARTIAL; READ ONLY | `asl_recognition_pipeline.dart`; `ml/preprocessing/flutter_feature_extractor.py`; tests | `signtalk.holistic.2582.v1`, finite sanitation, missing-group flags, motion features and temporal/gap handling exist. Python unit tests pass. | No actual Flutter raw fixture exists; dimension/order formulas are covered by unit tests but cross-runtime numeric parity is not proved. |
| Recognition adapter/model weights | NOT IMPLEMENTED / BLOCKED; READ ONLY | `assets/models/asl_recognition.json`; `UnavailableAslRecognitionModel` in pipeline | Explicit unavailable adapter returns no invented output. The manifest records feature requirements. | No trained checkpoint, architecture, license, runtime, vocabulary, model hash, calibrated confidence or installed offline inference. |
| Gloss decoder and English output | BLOCKED; READ ONLY | recognition manifest and camera UI | Decoder interface/gates can withhold unknown/incomplete outputs. | `reviewedMappings` is empty; no recognized gloss sequence or English sentence decoder exists. |
| Confidence/unknown handling | PARTIAL; READ ONLY | `asl_recognition_pipeline.dart`; recognition tests | Generic thresholds/rejection paths and unknown/incomplete statuses are represented. | No model confidence calibration or signer-independent measurements; thresholds are not validated model performance. |
| Offline ASL inference | NOT IMPLEMENTED; READ ONLY | model manifest | Offline is an explicit future requirement. | No weights/runtime; manifest says `offline: false`. |
| Flutter/Python parity | BLOCKED; READ ONLY | `ml/PHASE3A3_FEATURE_PARITY.md`; comparison script | Export mechanism, Python reconstruction and comparison tooling are present. Four Python unit tests exercise formulas and cases. | `ml/data/parity/flutter_raw.json` is missing. Comparison command exits with `FileNotFoundError`; no metrics or parity PASS. |
| Real videos, WER and sentence accuracy | BLOCKED; READ ONLY | `ml/data/`; dataset/model reports | No synthetic real-world results claimed. | No local `.mp4/.mov/.webm/.mkv` source recordings, trained model, independent references or WER evaluation. |

## ASL sources and rights status

The asset findings are recorded in `TEXT_TO_SIGN_ASSET_ACQUISITION_RESEARCH.md` and the earlier `PHASE1_FINALIZATION_REPORT.md`. No dataset, video, or external avatar was downloaded during this audit.

| Source | Actual material | Recorded license/access state | Retarget/mobile conclusion |
|---|---|---|---|
| SignAvatars | Fitted SMPL-X/MANO holistic motion and text metadata; original videos are not redistributed. | Request access for non-commercial research; complete data license is not publicly verified; contact/terms required. | Motion-to-Bip01 retargeting is technically conceivable, but derivative and offline app rights are **UNKNOWN / PERMISSION REQUIRED**. Not a ready female avatar. |
| ASL Signbank | Lexical annotation, entry glosses, English equivalents and reference images/videos; no 3D motion. | Official conditions state CC BY-NC-SA 4.0 with attribution and ShareAlike; richer registered access is approved. | Video-derived motion adaptation and mobile redistribution need confirmation. Not a rigged animation clip set. |
| ASL-LEX | 60+ lexical/phonological properties for 2,723 signs plus reference videos; no motion capture. | Official download text says CC BY 4.0 excluding videos, while the page footer says CC BY-NC 4.0. Treat database redistribution license as **UNKNOWN** until clarified; videos are © ASL-LEX.org. | No motion to retarget; reference video embedding requires permission. |
| RIT LATLab ASL Motion-Capture Corpus | 98 multi-sentence passages, three signers, gloss timing, English translations, BVH/FBX motion and video. Non-dominant-hand gloss only for some videos. | Lab states non-commercial research use; no standard license ID; access by request. | Promising sentence motion source, but exact finger/face channels and bundling derived clips in the app require access and written permission. |
| How2Sign | 80+ hours of continuous multiview ASL video, English references, depth, 2D keypoints; three-hour 3D pose subset. | CC BY-NC 4.0 on the dataset site and research use only; original How2 media not redistributable by How2Sign. | Videos/pose are not ready skeletal animation. Exact gloss release coverage and 3D-subset derivative app rights need confirmation. |
| MMS-Player | GPL-3.0 Blender software that synthesizes animation from MMS gloss/timing/inflection input. | GPL-3.0 applies to software; separate dictionary and character asset terms are not verified. README calls it research prototype, not quality-approved production signing. | Output format is technically useful, but tool alone is not an ASL lexicon/translator. GLB character and clip rights and Bip01 mapping are open. |
| MakeHuman / MPFB | Character-generation tools and CC0 core graphics assets. MPFB docs describe individual finger rig API and facial shape-key packs; workflow is not a supplied tested Flutter GLB. | Official asset page states CC0 for core graphics; code is AGPL/GPL separately; third-party packs need their own licenses. | Best low-rights-risk candidate generator, but no generated avatar passed appearance, GLB, face/finger, and Flutter tests. Blender/MakeHuman are not installed. |

Previously documented 3D-LEX, Studio Galt, WLASL and ASL Citizen candidates are not integrated. This audit did not retrieve restricted data or independently re-open those datasets; rely on the older report only as recorded research, not as evidence that any clip is presently licensed/approved for the app.

## Verification run in this audit

All commands were run individually where builds or package resolution were stateful.

| Command | Result | What it establishes |
|---|---|---|
| `flutter --version` | PASS — Flutter 3.47.1, Dart 3.13.1 | Tool versions. It initially stalled until SDK cache access was granted. |
| `flutter doctor -v` | PASS for Android SDK, Chrome, network resources; one Windows Visual Studio category missing | Toolchain availability. Not app functionality. |
| `flutter devices` | PASS — Windows, Chrome, Edge; no Android device | Device enumeration only. |
| `flutter pub get` | PASS — dependencies resolved; 14 package updates are outside current constraints | Dependency resolution. |
| `dart format --output=none --set-exit-if-changed .` | BLOCKED — formatter encountered a missing path inside `build/flutter_plugin_android_lifecycle/.transforms/...` while walking generated output | The project-wide traversal is unsuitable while generated build output exists. |
| `dart --suppress-analytics format --output=none --set-exit-if-changed lib test` | PASS — 17 files, zero formatting changes | Dart source/test formatting check without rewriting Sign to Text files. |
| `flutter analyze` (after Text to Sign fix) | PASS — no issues found (62.7 s) | Static analysis only. |
| `flutter test -r expanded` | PASS — all 33 tests passed | Includes safe empty catalog, translation gates, GLB structure, two destinations, camera/pipeline and video processor unit tests. Does not prove real ASL. |
| `ml/.venv/Scripts/python.exe -m unittest discover -s ml/tests -v` | PASS — 4 tests | Python feature formula/preprocessing unit tests only. |
| `ml/.venv/Scripts/python.exe ml/scripts/compare_flutter_parity.py ml/data/parity/flutter_raw.json --atol 1e-9 --rtol 1e-7` | BLOCKED — `FileNotFoundError` for fixture | No Flutter/Python parity comparison was performed. |
| `flutter build web --debug` | PASS — `build/web` produced (65.7 s) | Compilation/bundle generation only. |
| `flutter run -d chrome --web-port=8765` | PARTIAL — attached to Chrome debug service and emitted `<model-viewer>` markup with local GLB path | Debug service and widget markup, not visual correctness. |
| Headless Chrome screenshot of Web bundle | FAIL/UNVERIFIED — screenshot is a blank white page; local server logs confirmed HTML, Flutter JS, bundled fonts and assets were fetched. | Reproduces the recorded blank-screen symptom. Cause is not conclusively identified; CDN use was suspected and a local-resource build attempted, but no valid second screenshot was captured. Do not claim Web UI/avatar visually verified. |
| `flutter build web --debug --no-web-resources-cdn` | PASS — `build/web` produced (116 s) | Local Flutter static resources compile. It does not by itself prove that the blank page is fixed. |
| `flutter build apk --debug` | FAIL after 189.9 s in `assembleDebug` | Immediate errors: package `video_thumbnail-0.5.6/android/build.gradle` calls removed `jcenter()`; its Kotlin plugin also reports missing Android Gradle plugin after project evaluation. Project uses AGP 9.1.0 / Gradle 9.3.1; Flutter emitted an AGP 9 new-DSL compatibility warning. APK/device verification is blocked. This audit did not modify the Sign to Text dependency/configuration. |
| `flutter emulators` | PASS — one Pixel 9 AVD definition found, not launched | Emulator is available but not evidence of an app run. |
| `git diff --check` | PASS — no whitespace errors; Git displayed line-ending normalization warnings | Diff hygiene only. |

## Current blockers and acceptance requirements

1. **Approved translation:** replace none of the eight pending entries until a qualified ASL linguist/native signer supplies reviewed whole-sentence gloss/non-manual decisions and traceable source evidence.
2. **Motion:** obtain assets with terms allowing research use, derivative retargeting, and bundling in an offline application; inspect exact skeleton/finger/face channels; obtain per-sign qualified review; bake and visually review at least one authentic sequence.
3. **Avatar:** obtain actual asset-specific redistribution terms or generate a MakeHuman/MPFB model using the official CC0 core assets; verify visual quality, hand mesh, three-joint fingers, face morphs, GLB round-trip, Flutter load, and retarget fit before replacing anything.
4. **Web:** reproduce blank page with browser console evidence and verify a nonblank render. Headless screenshot currently provides a failure observation, not a root cause.
5. **Android:** address the `video_thumbnail`/AGP9 Gradle blocker when Sign to Text scope is permitted; then build/install on an emulator/device and verify real camera frames, GLB playback and performance.
6. **Recognition:** source/train a legally usable continuous ASL model with signer-independent validation, compatible 2,582 feature input, offline Android runtime, calibrated rejection, reviewed gloss/English decoding and independent WER/sentence evaluation. No such model is installed.
7. **Parity:** capture genuine Flutter raw MediaPipe frames to `ml/data/parity/flutter_raw.json`, then run the comparison to tolerance; until then schema parity is unproven.

## Phase map

| Project phase | Status | Completion evidence required |
|---|---|---|
| 1. Foundation and architecture | PARTIAL | Existing two-function shell and explicit adapters; complete mobile build and production dependency validation. |
| 2. UI and input workflow | PARTIAL | Text field/submit and camera/video UI exist; visually verified Web/Android rendering and platform input flows. |
| 3. Translation and linguistic data | BLOCKED | Qualified reviewed translation records, gloss/non-manual representation, sufficient coverage, tests using approved records. |
| 4. ASL motion acquisition and licensing | BLOCKED | Asset-specific permission for derived/offline app use, traceable provenance and qualified sign review. |
| 5. Avatar selection and rig validation | PARTIAL/BLOCKED | Existing rig structurally maps, but appearance/license gate failed; replacement must pass visual/rights/GLB validation. |
| 6. Motion retargeting and playback | PARTIAL | Player path exists; needs genuine reviewed clip retargeted, sequence-tested and visually reviewed. |
| 7. Complete sentence validation | BLOCKED | Approved end-to-end sentence-to-gloss-to-all-clips sequence and ASL review. |
| 8. Offline and mobile performance | BLOCKED | Licensed local resources/model, working APK, device latency/memory and offline tests. |
| 9. Final QA and release readiness | BLOCKED | Android/iOS device QA, web render fix, legal notices, independent ASL evaluation and all release acceptance criteria. |

## Changes made during this audit

- `lib/features/text_to_sign/english_to_asl_service.dart`: the surface analyzer no longer treats any word following a common verb as an object; it only marks a following pronoun. This avoids presenting “to” as the object in “I want to go home.” Translation, gloss and playback gates are unchanged.
- `test/english_to_asl_service_test.dart`: added a regression assertion for the infinitive example; existing pronoun-object example remains covered.
- `docs/SIGNTALK_FULL_PROJECT_AUDIT.md`: this audit.
- `docs/SIGNTALK_NEXT_STEPS.md`: prioritized continuation plan.

No Sign to Text source was modified in this audit. No asset, screen, branch, or Git history was deleted or replaced. No dataset or third-party contact action was made.
