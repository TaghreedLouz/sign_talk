# SignTalk — Prioritized Next Steps

Scope for the next implementation cycle: Text to Sign, unless a separate request expands scope. Do not add guessed ASL data or weaken the empty-catalog gate.

## Priority 1 — Acquire and review one usable signing motion source

**Status:** blocked on rights and qualified review.  
**Candidates:** RIT ASL Motion-Capture Corpus (BVH/FBX, multi-sentence gloss timing and English translation; non-commercial research access by request) or SignAvatars (SMPL-X/MANO annotations; request-gated research license). MMS-Player may help synthesize only after a licensed dictionary and reviewed MMS annotations are obtained.

**Dependencies:**

- Written terms that explicitly cover non-commercial research, creating/retargeting derivatives, and embedding the derived clip in the offline app.
- Access grant and actual motion sample with both-hand/finger channels, coordinate/frame/skeleton metadata and timestamping.
- Qualified Deaf/native ASL review of the exact sign/utterance, gloss, timing and facial/non-manual content.
- Permission to distribute the retargeted animation in the app; access for research alone is not enough.

**Acceptance:** source/provenance/license record, no unresolved restrictions, full target bone/morph mapping, unit tests for catalog integrity, one real clip baked to GLB, visually reviewed sequence, and a test proving unsupported/incomplete sequences remain blocked.

## Priority 2 — Produce a replacement avatar candidate without replacing the current asset

**Status:** MakeHuman/MPFB core assets are the clearest rights path, but no model has been generated or validated. Blender/MakeHuman are absent in this environment. Amara is a paid candidate with unreviewed delivered license text and no documented face morph inventory. Gloria's character terms are not established by MMS-Player's GPL code license.

**Dependencies:** install/use Blender and MPFB, use only individually verified CC0 packs, or obtain an avatar with asset-specific written app redistribution rights. No restricted avatar/model download should be bundled before its terms are reviewed.

**Acceptance:** separate candidate GLB, source/license manifest, human visual review, detailed hand/finger deformation check, all finger bones and face morph targets verified after GLB export, app viewer load and camera/scale/light fit tested, and retarget compatibility test against `assets/avatar/female/rig_map.json`. Replace the current GLB only after all gates pass.

## Priority 3 — Add approved translation records and whole-sentence sequences

**Status:** eight existing phrases are pending; zero approved glosses/utterances.

**Dependencies:** qualified ASL linguistic review, traceable translation source, approved gloss and non-manual markers, and all component sign clips present and approved.

**Acceptance:** resource schema validates, every sequence is complete, source/reviewer fields are non-empty, UI identifies provenance/status, sentence playback runs each clip exactly once with recorded timing, and incomplete sequence tests block all playback.

## Priority 4 — Fix visual Web verification

**Status:** Web debug bundle builds, but headless Chrome produced a white page. A no-CDN bundle builds, but a second screenshot was not captured successfully; no root cause is claimed.

**Local work:** reproduce with browser console/network errors and a normal Chrome window or supported browser automation; check Flutter renderer initialization, service worker cache, CanvasKit source, custom-element registration and platform-view composition. Keep any fix within Text to Sign/Web hosting and do not alter camera behavior.

**Acceptance:** nonblank screenshot showing text input and avatar stage, GLB load/error state visible, and a documented browser run. Do not equate a successful compile or model-viewer HTML log with visible rendering.

## Priority 5 — Android build and device verification (outside the current task's edit scope)

**Status:** APK build fails in `video_thumbnail 0.5.6` (`jcenter()` unavailable) plus Gradle/AGP9 plugin evaluation errors. No device is connected; a Pixel 9 AVD is defined but not booted.

**Dependencies:** permission to modify the Sign to Text dependency/build integration in its own task; update/replace the plugin or compatible Gradle/AGP settings; then launch emulator or connect a device.

**Acceptance:** `flutter build apk --debug` succeeds, app installs and opens, camera and video paths are tested on Android, and avatar load/sequence is visibly verified. This must be separate from the Text to Sign-only audit to respect the current source boundary.

## Priority 6 — Continuous ASL recognition and English decoding (later phase)

**Status:** unavailable adapter only; no weights, decoder mappings, model license or independent data.

**Dependencies:** legally usable continuous ASL video/reference data, signer-independent splits, actual temporal model compatible with `signtalk.holistic.2582.v1`, offline mobile runtime, rights for checkpoint and training data, reviewed gloss/English sentence decoder, and separate signer-independent evaluation.

**Acceptance:** genuine independent video predictions with WER and sentence accuracy, confidence calibration/unknown rejection, model checksum/license manifest, offline Android inference and memory/latency benchmarks. MediaPipe landmark output alone does not meet this requirement.

## Available local work

- Maintain the Text to Sign parser/resource/catalog test suite and clear review states.
- Keep assets/license metadata and schema validation strict.
- Capture a browser console trace for the existing Web blank-page symptom.
- Once a verified asset is available, build a conversion/audit script for the destination rig; do not populate it with guessed movements.

## Human or permission-dependent work

- Obtain dataset and derived mobile clip permissions from SignAvatars/RIT or another source.
- Obtain a qualified ASL signer/linguist to approve gloss, sentence translation, clip meaning, non-manual features and visual naturalness.
- Review any purchased avatar's actual license and delivered asset files before integration.

## Recommended next phase

**Phase 4 — ASL motion acquisition and licensing**, starting with written access/derivative/offline redistribution terms for a real motion source. It is the gating dependency for both reviewed translation playback and retargeting. In parallel, use a separately authorized workstation setup to generate a MakeHuman/MPFB avatar candidate, but keep the current avatar in place until the candidate passes the full appearance, license, GLB, rig and visual tests.
