# SignTalk MVP assets

Replace or add your own licensed assets in these folders.

- `images/` - onboarding, illustrations and backgrounds.
- `icons/` - custom app icons and feature icons.
- `fonts/` - licensed font files.
- `avatar/female/` - female 3D avatar files (e.g. `.glb` / `.gltf` plus textures).
- `avatar/male/` - male 3D avatar files.
- `animations/asl/` - licensed, qualified-reviewed ASL motion records and compatible animation clips; validate records against `manifest.schema.json`.
- `models/` - offline ML models and metadata.
- `dictionary/` - dictionary media and metadata.

Important:
1. Do not use unlicensed avatar models, sign videos or datasets.
2. An avatar model is not an ASL animation. It needs a compatible rig and validated motion data.
3. The Flutter app renders the bundled female GLB through `model_viewer_plus`. It is a technical candidate and is not visually approved. Its `QA_` animations are diagnostics and are rejected by the ASL catalog. No approved ASL motion clips are bundled.
4. For an actual offline release, bundle the model and all required media locally and test with airplane mode enabled.
