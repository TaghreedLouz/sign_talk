# ASL review and clip acceptance

The approved motion catalog remains empty until a genuine sign clip and its linguistic mapping pass all gates below. Diagnostic rig animations are never eligible content.

## Required evidence for every sign

### Provenance and permission

- Stable sign ID, original source locator, source creator/dataset, acquisition date, and exact license identifier/version.
- Written permission where the source license is absent, ambiguous, or does not clearly permit modification, offline bundling, redistribution, and the project's educational/research use.
- Attribution text and any redistribution, notice, or share-alike obligations preserved in-app or in bundled notices as required.
- SHA-256 for the source and the derived clip; description of transformations and retargeting.
- No downloaded or generated motion is accepted solely because it is publicly reachable.

### Linguistic review

- ASL gloss and English meaning reviewed by a qualified ASL reviewer; reviewer identity/affiliation, scope, date, and evidence reference recorded.
- Handshape for both hands, palm orientation, wrist orientation, signing location, movement direction/trajectory, and two-handed relationship reviewed.
- Lexical meaning, inflection, role shift, classifier use, and contextual limits recorded where relevant.
- Non-manual markers and facial expression reviewed and mapped to actual exported channels when required. A textual marker without an animated channel is insufficient for a clip that requires that marker.
- Sentence/utterance order independently reviewed. Do not derive ASL syntax by rearranging English words or infer a phrase from isolated sign clips without review.

### Technical playback

- GLB parses with the supported renderer offline and names the exact intended clip.
- Clip targets the selected rig and has bilateral hands, individual fingers, wrist/arm/body channels required by the sign; no missing-joint retargeting is silently accepted.
- Duration, timestamp range, keyframe continuity, transition behavior, and stop/pause/resume are checked.
- Required facial morph channels for that specific clip are enumerated and verified. Model-level presence of morph targets is not enough.
- Full clip is watched at normal speed and slow speed by a technical reviewer and ASL reviewer. Record screen capture or signed review evidence; do not rely on GLB metadata alone.
- Performance budget is measured on a supported Android device for the actual bundled avatar and clip.

## Utterance acceptance

An utterance record must reference a complete ordered sign sequence, reviewed sentence meaning and ASL structure, its source/permission, per-step timing/transitions, and review evidence for the sequence as a whole. Every referenced sign must independently pass the sign checklist. The app plays no partial sequence if any required clip is unavailable, unreviewed, unlicensed, or rig-incompatible.

## Catalog promotion gates

The current schema's `review.status`, `reviewerRole`, `reviewScope`, `reviewedAt`, `evidenceUri`, source license, rig ID, compatibility status, articulation fields, and available clip name are necessary checks. They are not sufficient to establish the visual/linguistic gates above. Catalog maintainers must verify the evidence before changing an entry to `approved`. Keep diagnostic clips outside `assets/animations/asl/manifest.json`.

## Rejection / quarantine

Use a pending or rejected state for missing permission, unknown source, unclear translation, unreviewed gloss, absent finger/face channels, retargeting defects, or failed playback. Store the reason without exposing a fabricated user-facing translation. Never populate missing fields with estimated confidence, generic motion, or unreviewed text.
