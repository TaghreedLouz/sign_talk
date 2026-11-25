# SignTalk Text to Sign: ASL Source and Avatar Asset Review

Research snapshot: 2026-11-19  
Project use stated by owner: non-commercial educational and research use.

## Decision

No asset was downloaded or added. No replacement avatar met the current acceptance gate with verified source, reuse rights, a signing-capable rig, and visual/technical validation. Therefore `assets/avatar/female/avatar.glb` remains untouched and the safe empty-catalog behavior remains in place.

Current project state inspected:

- `assets/animations/asl/manifest.json`: zero signs and zero utterances; status says no licensed, qualified-reviewed clips are installed.
- `assets/translations/en_to_asl.json`: eight records, all pending review and without glosses or utterance IDs.
- `assets/avatar/female/acceptance.json`: technical-evaluation-only; photorealism failed, hand detail insufficient, ASL review not done, production readiness false.
- `assets/avatar/female/rig_map.json`: declares 14 body joints, 30 finger joints (three joints for each finger on both hands), and face-shape names. These structural entries do not establish that an ASL clip is available, visually intelligible, or licensed.

The requested message ended mid-sentence at “mark it UNKNOWN or PERMISSION…”. This review treats every unverified right as **UNKNOWN / PERMISSION REQUIRED**.

## Source review

### SignAvatars website and repository

Sources: [project site](https://signavatars.github.io/), [repository](https://github.com/ZhengdiYu/SignAvatars), [repository README](https://github.com/ZhengdiYu/SignAvatars/blob/main/README.md).

- **What it provides:** the authors describe 70,000 sequences / 8.34 million frames with fitted SMPL-X holistic body, hand, and face parameters; MANO hand annotations are also supplied. The corpus includes isolated and continuous signing with multiple prompt types. The ASL portion is related to How2Sign; the overall resource also includes other languages/subsets.
- **Media and labels:** it does not redistribute source RGB videos because of their separate licenses. Its released annotations include 182-value SMPL-X parameters (body, both 45-value hand poses, jaw, shape, expression, camera translation) and text annotations. This is genuine fitted motion data, not a ready-to-play female GLB clip library. Text prompts/translations are not equivalent to linguistically reviewed ASL gloss segmentation for every sequence.
- **License identifier:** **UNKNOWN** from the public repository. README asks users to contact `shaolihuang@tencent.com` for the license. The data access form is specifically for non-commercial research and says the applicant agrees to the data license, but the full operative terms were not verified before access.
- **Non-commercial research:** access is request-gated for non-commercial research. This does not itself establish permission for this app’s redistribution or deployment.
- **Retargeting / offline embedding:** **UNKNOWN / PERMISSION REQUIRED**. Retargeting SMPL-X to the current `Bip01` rig requires conversion and validation. The right to create derivative motion clips and bundle them in an offline application is not verified.
- **Attribution:** cite Yu et al., ECCV 2024, as listed in the repository. Any additional attribution/data terms are **UNKNOWN** until the data license is obtained.
- **Redistribution:** original RGB videos are expressly not redistributed by the project. Annotation redistribution and derived animation redistribution terms are **UNKNOWN / PERMISSION REQUIRED**.
- **Access:** submit the official non-commercial access form and obtain/read the data license; contact the listed license contact for reuse/derivative/mobile distribution terms. No form was submitted and no contact was made.
- **Avatar suitability:** SMPL-X includes female parameter/model variants in its ecosystem, but this is not a verified, finished realistic female GLB avatar. SMPL-X model-file rights are separate and must also be cleared. Not selected as the replacement avatar.

### Yale ASL Signbank

Sources: [ASL Signbank](https://aslsignbank.haskins.yale.edu/), [conditions of use](https://aslsignbank.haskins.yale.edu/about/conditions/).

- **What it provides:** a lexical/annotation resource with sign entries, ID glosses, English equivalents/keywords, and sign-reference images/videos. It is not 3D motion capture and does not provide retargetable skeletal animation.
- **License identifier:** **CC BY-NC-SA 4.0** for the shared information/images/videos according to the official conditions page.
- **Non-commercial research:** allowed subject to attribution and ShareAlike conditions; commercial reuse is disallowed under the stated license.
- **Retargeting:** **UNKNOWN / PERMISSION REQUIRED** for making 3D motion derivatives from the reference videos. A video is not a license-cleared animation clip for a different avatar merely because it can be viewed or downloaded.
- **Offline embedding:** original video reuse is allowed subject to the published terms, but bundling video has attribution/link requirements and the ShareAlike condition. Whether a derived 3D animation is covered as an adaptation should be confirmed with the rights holder before bundling; mark **PERMISSION REQUIRED** for this use.
- **Attribution:** use “(ASL Signbank, 2026)” at first use or retain the logo; include the full Hochgesang, Crasborn, and Lillo-Martin reference/DOI; link directly to the entry when sharing a video; do not disseminate draft, non-teal-background media.
- **Redistribution/access:** the conditions page describes reuse of images/videos subject to those terms; registered access to richer annotation information is manually approved. High-quality videos may be requested from the project. Do not redistribute without following the conditions.
- **Use here:** may support a future human review workflow, but is not ready-to-play ASL motion.

### ASL-LEX

Sources: [ASL-LEX](https://asl-lex.org/), [download and license page](https://asl-lex.org/download.html).

- **What it provides:** ASL-LEX 2.0 provides 60+ lexical/phonological properties for 2,723 signs, cross-references, and sign reference videos. It provides neither 3D motion nor animation clips, and is not a continuous sentence corpus.
- **License identifier:** the download page states database and visualization, **excluding reference videos**, are **CC BY 4.0**. The page footer simultaneously says “database and visualization CC BY-NC 4.0.” This is an official-page conflict; treat metadata reuse as **UNKNOWN / PERMISSION REQUIRED** for redistribution in this app until ASL-LEX confirms which license governs the current data release. Reference videos are marked © ASL-LEX.org and are not included in the stated CC license.
- **Non-commercial research:** likely allowed by either cited license, but the conflicting statements need resolution before app distribution. Video use beyond viewing is **PERMISSION REQUIRED**.
- **Retargeting / offline embedding:** no motion to retarget. Reference video embedding/repackaging is **PERMISSION REQUIRED**; do not assume the database license covers it.
- **Attribution:** cite both Sevcikova Sehyr et al. (2021), DOI 10.1093/deafed/enaa038, and Caselli et al. (2017), DOI 10.3758/s13428-016-0742-0.
- **Redistribution/access:** database downloads are offered from the official page, but the license conflict needs clarification; reference videos remain copyrighted. No dataset was downloaded.
- **Use here:** potentially useful lexical metadata for a separately reviewed translation workflow, not avatar motion.

### RIT LATLab ASL Motion-Capture Corpus

Sources: [corpus/download details](https://latlab.ist.rit.edu/downloads.html), [project and use statement](https://latlab.ist.rit.edu/projects.html).

- **What it provides:** the first release is 98 unscripted multi-sentence passages from three signers (about 30 seconds–4 minutes each), with per-sign gloss start/end keyframes, English passage translations, referent/spatial-reference annotations, BVH and FBX motion-capture files, and front/side/face MOV videos. Non-dominant-hand gloss files exist only for some videos.
- **License identifier:** no standard license identifier was found. The lab states the corpus is available for **non-commercial use by the research community**. Treat exact terms as **UNKNOWN** until access is granted.
- **Non-commercial research:** expressly stated as allowed by the lab, subject to its access terms.
- **Retargeting:** BVH/FBX is actual motion data and is technically promising for retargeting. Actual bone list, finger-channel coverage, handedness/conventions, frame rate, and mapping to this app’s `Bip01` rig cannot be checked before access. Full finger articulation and face/blendshape channels are **UNKNOWN**; face-view video is not facial motion capture.
- **Offline embedding:** **PERMISSION REQUIRED**. Research access does not establish permission to publish or bundle derived animation clips in a mobile app.
- **Attribution:** cite Lu & Huenerfauth, “CUNY ASL Motion-Capture Corpus: First Release” (2012), and any access agreement instructions.
- **Redistribution/access:** request access by contacting the lab at `matt.huenerfauth@rit.edu`; sample excerpts may also be requested. No email was sent and no files were acquired.
- **Use here:** strongest candidate for real sentence-level captured motion, but currently blocked by access, terms, and unverified finger/face-channel compatibility.

### How2Sign

Sources: [official dataset site](https://how2sign.github.io/), [dataset paper](https://openaccess.thecvf.com/content/CVPR2021/html/Duarte_How2Sign_A_Large-Scale_Multimodal_Dataset_for_Continuous_American_Sign_Language_CVPR_2021_paper.html).

- **What it provides:** over 80 hours of continuous, multiview ASL video with speech/audio, English transcripts, and depth; the official page identifies a three-hour Panoptic subset for detailed 3D pose. It also lists downloadable 2D keypoint clips and English translation metadata. It is not a ready-to-play animation set. Although the headline mentions gloss annotation, the currently listed download sections do not make the release/schema/coverage of a gloss file clear; exact gloss availability is **UNKNOWN**.
- **License identifier:** dataset material on the page is **CC BY-NC 4.0**. The original How2 data is expressly not redistributable by How2Sign for copyright reasons.
- **Non-commercial research:** permitted under CC BY-NC 4.0 with attribution, license link, and change indication. The site also says publicly available for research purposes only.
- **Retargeting:** video/2D keypoints/3D pose are not bone animation clips. Retargeting a released 3D pose sequence may be technically possible, but the exact 3D pose channel release and hand/finger completeness are not established by the listed downloads. **UNKNOWN / PERMISSION REQUIRED** for a derived avatar animation until its source modality and rights are confirmed.
- **Offline embedding:** **PERMISSION REQUIRED** for any motion derived from the Panoptic subset until its specific release terms and model/performer rights are confirmed. Do not bundle original How2 instructional videos; the source explicitly says it cannot redistribute them.
- **Attribution:** credit How2Sign, link CC BY-NC 4.0, identify changes; also cite the dataset paper. Follow any original-source terms for linked underlying material.
- **Redistribution/access:** official page offers split video/keypoint/translation downloads; original How2 data must be separately obtained from its source and cannot be redistributed by How2Sign. No data was downloaded.
- **Use here:** useful video/translation research corpus, not a verified source of deployable female-avatar animation.

### DFKI MMS-Player

Sources: [repository](https://github.com/DFKI-SignLanguage/MMS-Player), [README and prototype disclaimer](https://github.com/DFKI-SignLanguage/MMS-Player/blob/main/README.md), [license file](https://github.com/DFKI-SignLanguage/MMS-Player/blob/main/LICENSE.txt).

- **What it provides:** software that turns MMS (gloss sequence + timing + spatial inflections) into animation, with MP4, FBX, BVH, Blender scene, or JSON bone-transform/facial-blendshape output. It is an animation-generation tool, not itself a verified ASL motion dataset or an English-to-ASL translator. It depends on a separately distributed sign dictionary. README labels it a research prototype and explicitly says it is not production-ready for intelligible/quality-approved sign-language videos; facial animation is still under improvement.
- **License identifier:** software is **GPL-3.0**. This does not automatically license the separately distributed dictionary, character GLB, generated motion, or example assets.
- **Non-commercial research:** use of GPL-3.0 software is permitted, including non-commercial research. If distributing the GPL software or a derivative, comply with GPL source and notice obligations.
- **Retargeting:** project JSON can drive the project’s own exported glTF character; mapping to this project’s `Bip01` rig is not established and requires per-bone and morph-target mapping and visual review. The tool’s examples/dictionary language coverage and ASL validity need per-entry review.
- **Offline embedding:** generated output rights are **UNKNOWN** until the dictionary and character asset terms are checked; GPL code alone does not grant those rights. Bundling a derived clip requires permission/license confirmation for every input asset and review of whether GPL obligations apply to any included code.
- **Attribution:** academic use asks for citation of the MMS Player papers, including Nunnari, Mishra & Gebhard (2025), as listed in the README. Follow GPL notices for software redistribution.
- **Redistribution/access:** source code is public under GPL-3.0; the sign dictionary is a separate release/download; its exact license and export rights were not verified. No software, character, or dictionary files were downloaded.
- **Use here:** technically interesting future synthesis path, but cannot be treated as verified ASL clips or as an approved replacement avatar.

## Candidate comparison and current rig feasibility

| Candidate | Actual motion | Language coverage | Current compatibility | Rights state for offline app | Decision |
|---|---|---|---|---|---|
| SignAvatars | Fitted whole-body SMPL-X/MANO sequences | Multiple language subsets; ASL subset; isolated + continuous | Requires SMPL-X/MANO-to-`Bip01` retargeting, coordinate/scale calibration, face mapping, and visual validation | Non-commercial request gate; full license and derivative redistribution terms not verified | Request license/terms first |
| RIT corpus | BVH/FBX mocap, per-sign gloss timings, English passages | ASL continuous multi-sentence discourse | Potentially strongest retarget source; actual skeleton/finger channels and conventions are inaccessible until granted | Non-commercial research stated; app embedding/derivative clip rights unknown | Request access and written clip rights |
| How2Sign | Video, metadata, 2D keypoints, 3-hour 3D pose subset | Continuous ASL with English references | Pose-to-`Bip01` conversion would need substantial reconstruction; finger and facial channels not verified | CC BY-NC 4.0 for site data; underlying How2 cannot be redistributed; exact 3D subset derivative rights need checking | Not a ready animation source |
| ASL Signbank | Reference videos/images and lexical information | Isolated lexical entries | Video-to-motion reconstruction would require manual capture/annotation, not retargeting | CC BY-NC-SA 4.0; derived media needs ShareAlike and permission review | Linguistic review aid only |
| ASL-LEX | Lexical/phonological metadata and copyrighted reference videos | Isolated lexical entries | No motion | Metadata CC BY 4.0; videos excluded | Linguistic metadata only |
| MMS-Player | Procedurally synthesized animation output | Depends on external dictionary and reviewed MMS sequence | Potential JSON/FBX export, but mapping and current app support unverified | Code GPL-3.0; dictionary, avatar, and clip rights unknown | Do not integrate yet |

### Exact retarget mapping still required

The app rig manifest names the destination as `rocketbox-bip01-female-adult-07-v1` and lists 14 body joints plus 30 finger joints. A usable motion source must provide or allow the following mapping, with transforms and units verified:

1. Source root/pelvis and spine chain → `Bip01 Pelvis`, `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`.
2. Bilateral clavicle/upper arm/forearm/wrist → `L/R Clavicle`, `UpperArm`, `Forearm`, `Hand`.
3. Each thumb/index/middle/ring/little source chain, including three articulated joints per finger, → the 30 explicit `Bip01` finger names in `rig_map.json`.
4. Source face/jaw and any non-manual facial channels → semantically matched morph targets; names alone are not semantic proof.
5. Coordinate handedness, local-vs-world transforms, units, rest pose, frame rate, missing-channel behavior, interpolation, and signer-to-avatar retarget offsets.

No candidate’s actual animation files were available for inspecting its bone names/channels against this mapping. Therefore no mapping was implemented and no sign clip was integrated.

## Avatar replacement gate

No replacement avatar has been acquired or validated. The requested sources are ASL data/software resources, not an independently verified licensed female avatar download. MMS Player mentions its Gloria character GLB, but the repository’s GPL-3.0 code license does not establish the character/asset license; the asset source and redistribution terms must be checked. SignAvatars’ SMPL-X/MANO models are research data/model assets with separate, unverified rights and are not a finished female GLB. Thus neither qualifies for replacement now.

Additional avatar asset candidates researched:

| Candidate | Verified source/terms | Technical evidence available | Remaining gate | Decision |
|---|---|---|---|---|
| MakeHuman / MPFB generated character | Official MakeHuman Community says core graphics assets and derivatives are CC0; generator/source code is AGPL (separate from exported graphics). See [license](https://www.makehumancommunity.org/about/license.html) and [asset packs](https://static.makehumancommunity.org/assets/assetpacks.html). | Official MPFB docs describe a GameEngine rig, three joints per finger in its rig API, and export-copy options for 52 ARKit face units or visemes. The docs explain exporting to external apps and discuss FBX, but do not document a direct GLB acceptance path for this app. | Generate a model, establish GLB export settings, visually assess realism and hand topology, verify actual exported finger-bone hierarchy and facial morph preservation, and test load/retarget in this Flutter viewer. No Blender/MakeHuman executable is installed in the current workspace. | Strongest low-rights-risk prototype path, but realism, GLB export, and exported rig/morph compatibility remain unvalidated; no replacement now. |
| Amara by Plainwork | Seller page advertises a €29 standard license and says GLB/FBX/Blend plus README and LICENSE are delivered; seller says it is based on MakeHuman CC0 assets. See [product page](https://www.hiddenway.info/shop/rigged-human-avatar-amara/). | Seller describes realistic female appearance, 53-bone Unreal-style skeleton with finger bones/weights, and GLB. Only idle and wave clips are advertised. | Actual delivered `LICENSE.txt` is not available before purchase in the public page; facial morph targets are not specified. Need seller terms and actual file inspection before deciding. | Candidate merits review if purchase and local evaluation are authorized; does not currently pass licensing/morph-target/visual gates. |
| DFKI MMS Player “Gloria” | MMS-Player source code is GPL-3.0, but the character GLB's own terms are not shown as covered by that code license. See [README](https://github.com/DFKI-SignLanguage/MMS-Player). | Project documents preview JSON for local bone transforms and blendshape weights and a GLB export workflow. | Character asset license/redistribution, actual rig compatibility, model appearance, and mobile load test remain unverified. | Do not extract or bundle Gloria until asset-specific rights are verified. |

MakeHuman is the only candidate with a verified permissive core-asset license from the official source and documented support for individual finger rig channels and facial shape-key packs. The license and feature docs are [here](https://www.makehumancommunity.org/about/license.html), [here](https://static.makehumancommunity.org/mpfb/docs/characters/rig.html), [here](https://github.com/makehumancommunity/mpfb2/blob/master/docs/entities/rigging/rigifyhelpers.md), and [here](https://static.makehumancommunity.org/mpfb/docs/ui/operations/faceops.html). This narrows the remaining blocker: an actual generated female asset must still be checked for signing-hand detail, convincing appearance, direct GLB export fidelity, Flutter loading, and the project rig mapping. This environment has no `blender` or `makehuman` executable, so no model was generated or tested in this pass.

Before replacement, require all of the following:

- Direct source and complete asset-specific license permitting this non-commercial app use and offline redistribution.
- GLB/glTF that loads in the existing Flutter viewer.
- Visually acceptable human appearance and detailed, separable finger joints.
- Rig and face morph audit against the app’s required hand/body/face channels.
- At least one genuine ASL motion clip with traceable source, permitted derivative/mobile redistribution, and qualified ASL review.
- Retarget test rendered and visually reviewed in the app. Until this is done the phase is not visually verified.

## Work performed in this change

- Added this research and compatibility report only.
- No runtime code, screens, camera code, model assets, translation records, or motion catalog were changed.
- No files were downloaded, no accounts/forms were submitted, and no one was contacted.
- Branch and Git history were not changed.

## Sources

- [SignAvatars project site](https://signavatars.github.io/)
- [SignAvatars repository README and access/license contact](https://github.com/ZhengdiYu/SignAvatars)
- [ASL Signbank conditions](https://aslsignbank.haskins.yale.edu/about/conditions/)
- [ASL-LEX license/download](https://asl-lex.org/download.html)
- [RIT LATLab corpus formats/access](https://latlab.ist.rit.edu/downloads.html)
- [RIT LATLab non-commercial use statement](https://latlab.ist.rit.edu/projects.html)
- [How2Sign dataset and copyright](https://how2sign.github.io/)
- [MMS-Player repository and README](https://github.com/DFKI-SignLanguage/MMS-Player)
- [MMS-Player GPL-3.0 license file](https://github.com/DFKI-SignLanguage/MMS-Player/blob/main/LICENSE.txt)
