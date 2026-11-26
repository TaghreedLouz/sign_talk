# SignTalk Avatar Candidate Generation Report

**Status:** Candidate generated and structurally validated; not approved as the application avatar.  
**Scope:** Text to Sign avatar asset/tooling only. The existing Flutter avatar, both functional screens, camera, MediaPipe, and video pipeline were not changed.

## Environment and storage

The user approved the separate D: drive layout before software download/installation. At the time of the latest check, available space was approximately D: 253.59 GB, F: 222.94 GB, and C: 6.86 GB. Blender, MPFB data, downloads, source scripts, and candidate exports remain on D:; the Flutter project remains at `F:\IEEE\SignTalk_working_fixes\sign_talk_two_screens`.

| Tool | Version / license | Location |
|---|---|---|
| Blender portable | 4.5.15 LTS; official Windows ZIP, checksum verified | `D:\SignTalk_Tools\Blender\portable-4.5.15\blender-4.5.15-windows-x64\blender.exe` |
| MPFB | 2.0.18; extension manifest declares GPL-3.0-or-later; Blender 4.2+ | Installed in this Blender portable profile; user data under `...\portable\extensions\.user\blender_org\mpfb\data` |
| MakeHuman system asset pack | Official pack listing says CC0 | `D:\SignTalk_Assets\AvatarCandidates\signing_female_v1\assets\makehuman_system_assets_cc0.zip` |
| Faceunits 01 | Official pack listing says CC0 (functional ARKit face units) | `D:\SignTalk_Assets\AvatarCandidates\signing_female_v1\assets\faceunits01.zip` |

Blender archive SHA-256: `52dd02fd74877fa08e74b67d7854cf32468a232c02aaa19b6844c91285574f8d`.  
MakeHuman system assets SHA-256: `B542127A8E25547C7C29C19F2D1D2ADB9A664C80396ECD694095DBC8028A0107`.  
Faceunits 01 SHA-256: `D113107BD7EB59F3AF4DF6FC0EC29BFCC593F496D0B336AEC14F086A80CE7146`.

The assets came from MakeHuman Community's official pack listings and mirrors. The source mesh/asset packs are identified as CC0 by those listings. MPFB itself and its rig/weight generation definitions are GPL-3.0-or-later; therefore this generated candidate is **not described as wholly CC0**. Before redistributing the generated GLB, retain attribution/provenance and review whether/how the GPL terms apply to the generated rig/weights and bundled outputs. The project use stated for this work is non-commercial educational/research use.

## Candidate files

The reviewed export is separate from the app's selected model:

- GLB: `D:\SignTalk_Assets\AvatarCandidates\signing_female_v1\reviewed\signing_female_v1_reviewed.glb`
- SHA-256: `440D6DE5BFB42487075D40E8841520F7BE6E88BBE1498833A0A84C87CF2D0EEC`
- Size: 24,972,864 bytes (about 23.8 MiB)
- Editable Blender file: `...\reviewed\signing_female_v1_reviewed.blend`
- Structural report: `...\reviewed\glb_validation.json`
- Candidate rig map: `...\reviewed\rig_map.json`
- Front render: `...\reviewed\preview_front.png`
- Facial-control render: `...\reviewed\preview_facial_controls.png`
- Generation and validation scripts: `...\source\generate_reviewed_candidate.py` and `...\reviewed\validate_candidate.py`

The first exploratory export remains preserved in the parent candidate directory. The reviewed export above is the candidate assessed here; neither overwrites the existing `assets/avatar/female/avatar.glb`.

## Structural and render inspection

The reviewed GLB was imported back into Blender successfully. The recorded validation reports:

- 7 mesh objects, 1 armature, 163 bones.
- 30 finger bones across both hands; every one of the 30 is weighted to the skinned body mesh.
- 23 upper-body, arm, and neck/spine controls are present in the skeleton; wrist bones are present.
- 52 named ARKit-style facial morph targets are present.
- 11 materials and 6 packed images; no external image paths. Image dimensions are 512×512 (2), 2048×2048 (3), and 4096×4096 (1).
- GLB contains 0 animation clips and 0 ASL clips, by design.

Both renders were visually inspected. The front render depicts a female, clothed character in a neutral A-pose; it reads as a stylized/game-like human rather than a photorealistic avatar. The facial diagnostic render shows the expression targets deforming the face. Visual review is recorded, but **visual acceptance is not passed**: appearance and hand readability need further review, and the current app runtime compatibility gate is not met.

Generation emitted MPFB node/socket warnings and glTF exporter warnings about shader image-node selection and influences beyond four joints. The candidate nevertheless rendered, exported, re-imported, and passed the structural checks listed above. Those warnings remain relevant for material appearance and runtime deformation QA.

## Flutter compatibility assessment

The current viewer at `lib/features/text_to_sign/realistic_avatar_stage.dart` selects `assets/avatar/female/avatar.glb` and reads `assets/avatar/female/rig_map.json`. The app rig map targets Rocketbox-style `Bip01 ...` bone names and expects a larger face-shape/viseme set (175 names per the current app rig metadata), as well as animation channels. The candidate uses MPFB bone names, contains 52 ARKit-style face morphs, and has no animations. Therefore it is valid GLB but **not a drop-in compatible replacement**. No Flutter asset registration or runtime mapping was changed, and candidate loading in the Flutter viewer has not been demonstrated.

To proceed with a future compatibility proof, implement a candidate-specific bone/morph mapping in an isolated test path, verify the Flutter renderer can load its packed materials and morph targets, and validate joint/morph deformation using non-ASL diagnostics. Only then consider app selection. Actual ASL motion still requires separately sourced, reviewed, licensed animation clips and must not be inferred from this model.

## Acceptance result

| Gate | Result |
|---|---|
| Valid GLB export and Blender re-import | Pass |
| Humanoid body/armature structure | Structural pass |
| Articulated, weighted finger joints | Structural pass (30/30) |
| Facial expression controls | Structural and render-diagnostic pass (52 morphs) |
| Packed textures/no external texture files | Structural pass |
| Realistic visual appearance accepted | Not passed; rendered and reviewed, but stylized and not yet accepted |
| Compatible with current Flutter viewer | Not passed; rig/morph naming and expected channels differ; app integration not attempted |
| Actual ASL animation | Blocked; no reviewed/licensed ASL clips available, and candidate has zero animations |
| Replace current avatar | No; original remains selected and untouched |

## Reproduction

From PowerShell, run the portable Blender executable with the saved project or generation script. Paths are kept on D::

```powershell
$blender = 'D:\SignTalk_Tools\Blender\portable-4.5.15\blender-4.5.15-windows-x64\blender.exe'
$candidateRoot = 'D:\SignTalk_Assets\AvatarCandidates\signing_female_v1'
& $blender --background --python "$candidateRoot\source\generate_reviewed_candidate.py"
& $blender --background --python "$candidateRoot\reviewed\validate_candidate.py"
Get-FileHash "$candidateRoot\reviewed\signing_female_v1_reviewed.glb" -Algorithm SHA256
```

Generation depends on the installed MPFB 2.0.18 extension and the two verified packs being present in that portable profile's MPFB data directory. Review `generation_inventory.json` and the validation JSON alongside each regenerated artifact.

The validation JSON included with the candidate records a successful Blender re-import and the structural measurements above. A fresh validation launch was attempted on 2026-11-20, but Windows returned process exit code `-1073741790` (`0xC0000022`, access denied) even for `blender.exe --version`; the saved validation report was not regenerated by that attempt. Re-run the commands above after Blender process execution is available again.

## Official source and license references

- [Blender 4.5 LTS download](https://www.blender.org/download/lts/4-5/) and official [download checksum manifest](https://download.blender.org/release/blender-4.5/).
- [MPFB getting started](https://static.makehumancommunity.org/mpfb/docs/getting_started.html) and [MPFB Blender extension listing](https://extensions.blender.org/add-ons/mpfb/).
- [MakeHuman System Assets pack](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html), [Faceunits 01 pack](https://static.makehumancommunity.org/assets/assetpacks/faceunits01.html), [asset pack index](https://static.makehumancommunity.org/assets/assetpacks.html), and [MakeHuman license information](https://static.makehumancommunity.org/about/license.html).
- Official pack downloads: [MakeHuman system assets CC0 ZIP](https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip) and [Faceunits 01 ZIP](https://files2.makehumancommunity.org/functional/faceunits01.zip).

## Remaining blockers

1. The candidate does not match the Flutter viewer's current bone and facial target names; no runtime compatibility proof has been run.
2. The reviewed model is structurally usable for signing experiments, but is not visually accepted as the requested realistic replacement.
3. No genuine reviewed ASL motion clips are available, so animation playback cannot demonstrate actual ASL signing.
4. Android/device performance, materials, and deformation have not been checked. No Android test is claimed.
5. Confirm GPL obligations for the generated rig/weights and distribution package before publishing or redistributing this candidate.
