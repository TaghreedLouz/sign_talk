# Self-owned avatar pipeline

Status: **candidate generation not started**. This document captures a reproducible path to a separately evaluated avatar; it does not designate an avatar as production-ready.

## Environment inspection

On 2026-11-19, PowerShell `Get-Command blender,makehuman,mpfb -ErrorAction SilentlyContinue` and the corresponding `Blender.exe`/`makehuman.exe` lookup returned no executable. No MPFB add-on can be used without Blender. Consequently, no candidate GLB was generated and the existing `assets/avatar/female/avatar.glb` was left untouched.

The existing GLB is 44,298,300 bytes (42.25 MiB). Its accompanying `acceptance.json` explicitly records `photorealism: FAILED`, `hand_detail: INSUFFICIENT_FOR_FINAL_REQUIREMENT`, `asl_review: NOT_DONE`, and `production_ready: false`. Structural rig evidence is useful for engineering tests only; it does not satisfy visual or signing acceptance.

## Tool and asset licensing findings

- MakeHuman Community documents its core graphical assets (base mesh, targets, skins) as CC0. CC0 permits reuse without attribution as a license condition, although a voluntary credit is appropriate. This finding applies only to the identified core assets, not third-party packs. See [MPFB's asset FAQ](https://static.makehumancommunity.org/mpfb/faq/is_it_really_free.html), [model resale FAQ](https://static.makehumancommunity.org/mpfb/faq/can_i_sell_models.html), and [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/deed.en).
- MPFB is Blender add-on software, separately licensed from the generated character assets. Verify the exact license in the chosen release before installing or redistributing the add-on; do not treat the add-on code license as the character license. Repository: [MPFB2](https://github.com/makehumancommunity/mpfb2).
- Every downloaded third-party skin, hair, garment, face-unit, pose, or other pack needs its own provenance and license record. The official FAQ expressly leaves compliance with the third-party asset license to the user.
- MPFB documents a GameEngine rig for use in external applications and offers individual finger helpers / FK finger controls. These are candidate-building capabilities, not evidence that an exported avatar has signing-quality hands. See [rig selection](https://static.makehumancommunity.org/mpfb/docs/characters/rig.html) and [finger helpers](https://static.makehumancommunity.org/mpfb/docs/rigging_posing/rig_helpers.html).
- MPFB's export guide describes preparing external assets and exporting FBX from Blender. It does not establish a verified one-click GLB pipeline. The final glTF/GLB conversion and all morph, skeleton, material, and animation behavior must be checked in the app renderer. See [MPFB export guidance](https://static.makehumancommunity.org/mpfb/docs/exporting.html).

Non-commercial educational/research use does not remove third-party license restrictions. Keep a `licenses/` record and source URL for every non-core asset. If any source is unclear, omit the asset until written permission is obtained.

## Reproducible candidate workflow

1. Install Blender from its official distribution and record the exact version. Install MPFB2 using the official MPFB documentation for that Blender version. No installation was performed in this phase.
2. Create a new female character in a separate working directory. Keep the original project avatar unchanged.
3. Select the GameEngine humanoid rig for external runtime use. Confirm bilateral clavicles, upper arms, forearms, wrists/hands, and separate joints for all three segments of each finger. Add individual finger controls for authoring, but export only required deform bones.
4. Inspect hand mesh topology and weights in close-up: five distinct digits per hand, visible thumb opposition, clean bends at each finger joint, no hand/finger intersections through the full signing range. Reject gloves or accessories that obscure finger shape.
5. Add only licensed core facial targets or individually verified face assets. Ensure required brow, eye, cheek, jaw, and mouth shapes survive export as glTF morph targets.
6. Use export-friendly PBR materials and reduce geometry with a proxy where needed. The official docs describe FBX export; test conversion through Blender's glTF exporter as a separate step. Do not assume export parity.
7. Export to a new candidate path such as `assets/avatar/candidates/mhfb_female_candidate.glb`; do not point the app at it until technical and visual gates pass.
8. Validate GLB v2 structure, skin weights, joint hierarchy, both hands, individual finger channels, facial morph names, and animation channels. Load the candidate using the existing `RealisticAvatarStage` only after documenting the required rig map. Perform side/front/close-up render review and on-device performance capture.
9. Record source, license IDs, attribution, modifications, tool versions, export settings, SHA-256, size, triangle count, joint count, morph count, screenshots, and reviewer sign-off in a candidate-specific manifest.

## Acceptance gates

The candidate must pass the technical checklist in [ASL review and clip acceptance](ASL_REVIEW_AND_CLIP_ACCEPTANCE.md) and the budgets in [avatar mobile performance budget](AVATAR_MOBILE_PERFORMANCE_BUDGET.md). A technically valid GLB does not prove realism, correct signing, or license completeness. No replacement is selected until all gates pass and the app has been visually checked on a supported device.

Current result: **no new avatar generated; current model remains technical-evaluation-only.**
