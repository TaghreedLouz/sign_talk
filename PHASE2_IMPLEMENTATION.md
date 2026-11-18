# SignTalk Phase 2 Implementation

## What is implemented

The Text to Sign flow now uses a separate offline translation service rather than putting translation logic in the Flutter screen. It normalizes input, performs conservative surface analysis (question form, negation, pronouns, simple subject/object candidates, and time expressions), looks up an exact sentence in a local review-gated resource, requires qualified review metadata, checks the complete reviewed utterance against the ASL motion catalog and loaded avatar clip names, and only then builds playback steps.

The surface analysis is not represented as ASL translation. It is shown as review context and cannot generate a gloss. Unsupported sentences, pending translations, missing clips, and partial sign coverage do not play. QA clips are excluded by the existing catalog checks. The motion catalog now passes facial-expression and per-sign non-manual marker metadata alongside each validated sign step.

## Current coverage

All eight requested phrases are present as normalized `pending_review` source records. Each has no gloss, reviewer, source, sign IDs, or non-manual markers, and is not playback eligible. No phrase is presently supported as a completed English-to-ASL translation because this project has no qualified-reviewed translations or approved motion clips installed.

## Model/resource evaluation

- [SignBridge repository](https://github.com/AndreaUnali/SignBridge) is MIT-licensed and describes an offline Python pipeline, but it is a small university project using WLASL-derived pose data and heuristic English-to-gloss transformations, with a 2D renderer. It does not establish qualified ASL review, licensing provenance for every embedded source motion, or compatibility with this female GLB rig.
- [SignBridge T5 gloss model card](https://huggingface.co/Suyash2205/signbridge-t5-base-asl-gloss) lists Apache-2.0 and describes offline Transformers loading. Its model card explicitly warns that the ASLG-PC12 gloss targets retain English constituent order and are not ASL word order. It is therefore not suitable as the source of verified ASL output here, regardless of its reported held-out scores.
- [Linguistically Informed Transformers for Text to ASL Gloss](https://aclanthology.org/2024.loresmt-1.pdf) reports a research transformer and a domain-specific banking corpus. Its experiments use a privately hosted cloud server; it does not provide an integrated offline model and qualified review evidence for the eight target sentences and exact animation sequence needed by this app.
- [Neural Sign Actors](https://openaccess.thecvf.com/content/CVPR2024/papers/Baltatzis_Neural_Sign_Actors_A_Diffusion_Model_for_3D_Sign_Language_CVPR_2024_paper.pdf) is research on English-conditioned SMPL-X pose generation. It is not a ready-to-run Flutter model/animation set for the Bip01 rig, and the paper derives motion from How2Sign (whose dataset terms are research/noncommercial).

None was integrated. No live network API or runtime model dependency was added.

## Files changed

- `lib/features/text_to_sign/english_to_asl_service.dart` — normalizer, parser, analysis records, translation/resource validation, result types, and full-sequence builder.
- `lib/features/text_to_sign/asl_motion_catalog.dart` — validated steps now carry facial and non-manual metadata; exposes missing sign IDs when a whole utterance cannot resolve.
- `lib/features/text_to_sign/text_to_sign_screen.dart` — connects input to the offline service, displays pending/unsupported/coverage state, and only hands complete validated plans to the existing playback controller.
- `assets/translations/en_to_asl.json` and `assets/translations/en_to_asl.schema.json` — local eight-sentence pending-review resource and record schema; contains no invented glosses.
- `pubspec.yaml` — bundles `assets/translations/`.
- `test/english_to_asl_service_test.dart` — pipeline safety and sequencing tests.

## Verification

Commands run in order:

1. `flutter pub get` — passed; no dependency changes required.
2. `dart format lib test` — passed; formatter completed without remaining changes.
3. `flutter analyze` — passed with no issues.
4. `flutter test -r expanded` — passed, 11 total tests, including pending target phrases, normalization, question and negation detection, unsupported sentence handling, partial-sequence rejection, sign ordering, facial/non-manual marker propagation, empty catalog, bundled offline asset loading, and the two-screen widget check.

## Setup and blockers

No additional setup or server is needed to run the implemented pipeline. `flutter pub get` installs existing dependencies; the translation resource is bundled and used offline.

To enable a sentence, add a translation record only after qualified ASL linguistic review, including review evidence, its approved gloss and non-manual markers, and the stable `utteranceId`; add the matching reviewed source, compatible sign records, and genuine motion clips to the catalog. The catalog then checks the entire sequence and actual GLB clip names. Until the resource and clip are complete, playback remains disabled for that sentence.

Phase 2 is not complete: no qualified-reviewed English-to-ASL sentence resource or genuine ASL motion clips are available, and Phase 1 still lacks device-level visual verification.
