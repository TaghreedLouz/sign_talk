# SignTalk Phase 1 Finalization Report

Date: 2026-11-17

## Outcome

Flutter analysis and tests pass. Flutter's Android toolchain check passes after SDK metadata/license initialization. ADB starts when permitted to access the Android SDK/daemon but finds no attached Android device. No external avatar or ASL motion asset was downloaded or integrated: the available candidates do not currently satisfy both rights and qualified ASL review requirements. Phase 1 remains incomplete pending a visually reviewed avatar and sign animation on a running device.

## Build and test verification

Commands were executed sequentially, not concurrently. Full command output is in `verification_logs/`.

| Command | Result | Findings |
| --- | --- | --- |
| `flutter doctor -v` | First run stalled, then completed with Android check timeout at 4:30; rerun passed Android toolchain in 6.7s | Initial run coincided with Android SDK package metadata/license fetching. `sdkmanager --licenses` logged IO exceptions and waited for remote manifests, then accepted licenses. After SDK metadata was initialized, doctor completed. Windows desktop support still reports missing Visual Studio C++ workload; that does not block this Android/mobile project. |
| `flutter devices -v` | Exit 0 | ADB ran but reported an empty device list. Flutter found Windows, Chrome, Edge only. |
| `flutter pub get -v` | Exit 0 | Dependencies resolved in 12.3s. |
| `flutter analyze` | Initial run found 2 info-level brace style lints; rerun clean | Added braces to the two reported conditionals in `lib/features/camera/camera_screen.dart`; no behavior change. |
| `flutter test -r expanded` | Exit 0 | 3 tests passed, including empty-catalog safety and two-destination widget coverage. |

Environment diagnosis:

- The first silent Flutter stall was SDK cache locking: Flutter's `shared.bat` waits for `C:\flutter\bin\cache\flutter.bat.lock`; the sandbox cannot write to the SDK outside the workspace. With permitted SDK access, Flutter commands run normally. This is an environment permission boundary, not a project code defect.
- Dart analysis had separately reported an inability to write its telemetry session under `%APPDATA%\.dart-tool`; running with the required SDK/user-cache access avoided the telemetry permission issue.
- ADB daemon startup failed in the restricted sandbox because the Android SDK daemon/socket operation is outside the workspace. `adb start-server` succeeds with SDK access. No Android device or emulator is currently attached/booted, so on-device visual verification cannot proceed.
- `sdkmanager` also reports a duplicate `emulator.backup` package directory. It was left untouched because there is no evidence it causes the current result; sdkmanager did accept all licenses. The first doctor timeout appears related to remote SDK manifest fetching, but that is an inference from the logged waits and the successful warmed rerun.

## Female avatar candidates

| Candidate | License and technical fit | Decision |
| --- | --- | --- |
| Existing `assets/avatar/female/avatar.glb` | 44,298,300 bytes, 80 skin joints, 5,443 vertices, 175 morph targets. All mapped finger joints have positive skin weights and the QA clip animates all 30 mapped finger joints. `rig_map.json` describes the Bip01 body and finger skeleton. `acceptance.json` records visual photorealism as failed and hand detail as insufficient. Only QA clips are embedded; they are explicitly not ASL. Source author/license provenance is not established by the files inspected. | Retain for structural loader/rig testing; it does not satisfy the appearance/hand or licensed-content acceptance criteria. |
| MakeHuman / MPFB generated female | Official asset license separates GPLv3 tooling from CC0 1.0 bundled graphics (base mesh, targets, textures, rigs, poses, expressions); output assets can be used commercially without attribution under that asset license. MPFB supports export-copy facial targets (including ARKit units) and external rig/export workflows. Detailed hands/finger rig and glTF output still need validation on the exact generated character; CC0 does not certify photorealism. Third-party clothes/hair/skin packs need their own license review. | Strongest low-friction rights candidate, but no particular realistic, application-ready model has yet been generated and inspected. |
| Daz Genesis (including Genesis 9) | Daz says the standard content license covers rendered 2D output, while distributing/manipulating 3D content in an app requires an Interactive License, available only for products whose pages offer it. A specific figure, morph, skin, hair, clothing, and export pipeline must each be checked. | Potentially high realism, but not verified or licensed for this app as an actual selected asset. |
| MetaHuman | High realism and facial rig capability, but Epic's content terms include UE-only restrictions for applicable MetaHuman content; the existing Flutter/model-viewer GLB pipeline is not a direct supported target. | Not a compatible license/format choice for this project without a separate rights pathway. |

Sources: [MakeHuman/MPFB asset license](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md), [MPFB export docs](https://static.makehumancommunity.org/mpfb/docs/exporting/index.html), [Daz Interactive License](https://www.daz3d.com/daz-licenses#interactive), [Epic Content License](https://www.unrealengine.com/eula/content).

## Genuine ASL motion resources

| Resource | License/source | Contents and retarget fit | Suitability |
| --- | --- | --- | --- |
| 3D-LEX v1.0 | Dataset data is stated as CC BY 4.0 (attribution required); the paper itself is CC BY-NC 4.0. OSF file endpoint returned 403 in this environment. | 1,000 isolated ASL signs plus NGT. It provides StretchSense glove finger bend/splay/joint data and FBX, Vicon body pose and FBX, ARKit/Live Link Face blendshapes, and a combined retargeted body+hand FBX. Both hands are considered. Facial signals are a separate capture modality; the paper does not establish that all signs have synchronized face tracks in the combined export. Isolated signs, not complete phrases. FBX could be retargeted by a Blender conversion/bake step. | Best technical match and CC BY 4.0 data terms, but actual files could not be inspected/retrieved and ASL authenticity limitations are material: only one of five signers had ASL as a primary language. Not used as a verified product clip. |
| Studio Galt Sign Language Mocap Archive | Repository states all motions are CC0; source [repository and FAQ](https://github.com/StudioGalt/Sign-Language-Mocap-Archive). | Around 2,700 motions / 2,100+ signs and fingerspelling; FBX for full, Mixamo, Rigify, and Unreal skeletons; catalog has per-motion face-animation availability; direct retargeting is expressly encouraged. Both hands/finger detail are represented by the mocap rig. Primarily isolated dictionary signs; not complete ASL sentence sequences. | Real motion data with permissive license and the most practical technical retarget route. The creator explicitly states they are hearing and their ASL knowledge is incomplete, and recommends professional translation. Without independent Deaf/native ASL review of a specific sign and its meaning, it cannot be marked verified for this app. No clip imported. |
| How2Sign | CC BY-NC 4.0; research purposes only, noncommercial. [Official site](https://how2sign.github.io/). | 80+ hours of continuous multi-view ASL video, transcripts, depth, and a three-hour Panoptic 3D-pose subset. Videos/pose annotations, not ready-to-play skinned animation clips; no verified joint-level finger animation or facial blendshape tracks packaged as a retargetable avatar clip. Contains continuous phrases. | Useful research source, disallowed for commercial app use under stated license and not directly retargetable to current rig. |
| WLASL | [Official repository](https://github.com/dxli94/WLASL). | Word-level video dataset; not 3D skeletal animation or rigged clip data. Isolated signs, not complete sentences. Underlying video rights/terms must be checked per source; repository availability does not grant app redistribution rights. | Not a ready-to-play animation source. |
| ASL Citizen | [Microsoft code/release repository](https://github.com/microsoft/ASL-citizen-code). | Videos and recognition baseline/checkpoints, not skeletal motion/animation. Isolated signs. Dataset use is research-restricted per dataset terms and cannot be assumed commercially redistributable. | Not suitable for app animation integration. |

The 3D-LEX paper specifically documents its modalities and limitations: [3D-LEX v1.0 paper](https://aclanthology.org/2024.signlang-1.33.pdf). Its data license is referenced in the paper, but the data host refused access during this investigation; therefore no individual sample was checked. [MediaPipe Holistic documentation](https://developers.google.com/edge/mediapipe/solutions/vision/holistic_landmarker) describes landmark extraction, not a temporal ASL recognition/translation model; it cannot itself supply ASL semantics or animation clips.

## Retargeting feasibility

The current target is the Rocketbox Bip01 female GLB, defined in `assets/avatar/female/rig_map.json`:

- Torso and arms: `Bip01 Pelvis`, `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`, then left/right `Clavicle`, `UpperArm`, `Forearm`, `Hand`.
- Both hands: 5 digits each (`thumb`, `index`, `middle`, `ring`, `little`) and 3 joints per digit, named `Bip01 [L|R] Finger0..4`, then `01/02`, `11/12`, `21/22`, `31/32`, `41/42`.
- Face: 175 morph targets in the GLB; the rig map contains ARKit `AK_01...AK_52` plus visemes and other shape systems.

Static inspection confirms mapped finger joints have skin weights and QA rotation tracks. But the current clip names are `QA_FINGER_JOINTS_NOT_ASL` and `QA_FACE_NOT_ASL`; they are not real sign animation. Retargeting 3D-LEX would need its source FBX bone hierarchy and coordinate convention, calibrated body/hand mapping into Bip01, quaternion transforms for the 30 target finger joints, timing/root-motion handling, then a face ARKit coefficient mapping into available GLB morph names, and a baked animation track re-exported into the GLB for the current runtime.

No integration proof was added because the 3D-LEX files could not be reviewed and Studio Galt does not provide qualified sign verification. Mapping an unreviewed animation as a known ASL gloss would violate the project's requirement against incorrect sign output. A fully licensed sample plus Deaf/native ASL reviewer confirmation is the exact missing input for a defensible single-sign proof.

## Changed files and remaining blockers

- `lib/features/camera/camera_screen.dart`: style-only braces added for analyzer lints.
- `verification_logs/`: complete command logs listed below.
- Existing avatar/manifest implementation was not replaced. The ASL manifest remains empty by design until licensed and reviewed clips exist.

Remaining blockers: (1) obtain/inspect a specifically licensed high-detail female avatar or improve and visually approve the existing one; (2) retrieve a sign motion source and obtain qualified per-sign review; (3) connect and run on an Android device/emulator for visual verification. Phase 1 is not complete.

### Logs

- `verification_logs/flutter_doctor_v.log`
- `verification_logs/flutter_doctor_after_sdk_cache.log`
- `verification_logs/flutter_devices_v.log`
- `verification_logs/flutter_pub_get_v.log`
- `verification_logs/flutter_analyze.log`
- `verification_logs/flutter_analyze_after_fix.log`
- `verification_logs/flutter_test_expanded.log`
