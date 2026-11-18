# Phase 3A.3 — Flutter/Python parity

## Feature map extracted from Dart

Ranges are zero-based, inclusive. The 2,582 count reconciles exactly:

| Indices | Values |
|---|---|
| 0–1911 | Face image landmarks, 478 entries × `(x,y,z,visibility-or-presence)` |
| 1912–1963 | 52 blendshape scores in the extractor's `_blendshapeNames` order |
| 1964–2095 | Pose image landmarks, 33 × `(x,y,z,visibility-or-presence)` |
| 2096–2227 | Pose world landmarks, 33 × same four channels |
| 2228–2311 | Left hand image landmarks, 21 × four channels |
| 2312–2395 | Left hand world landmarks, 21 × four channels |
| 2396–2479 | Right hand image landmarks, 21 × four channels |
| 2480–2563 | Right hand world landmarks, 21 × four channels |
| 2564–2568 | Face, pose, left hand, right hand, blendshape presence flags as 0/1 |
| 2569–2574 | Left wrist direction xyz and palm normal xyz |
| 2575–2580 | Right wrist direction xyz and palm normal xyz |
| 2581 | Mean 3D point displacement across visible hands from prior frame |

No verticality scalar is appended. The orientation channels are the normalized wrist→middle-MCP vector and normalized cross product `(indexMCP-wrist) × (pinkyMCP-wrist)`. Dart replaces non-finite coordinate/score values with 0; missing points are zero-padded. Landmark lists retain MediaPipe order. Blendshapes are looked up by category name; missing names become 0. Image coordinates are used as delivered by the plugin, with no further normalization here. `double` values are serialized as JSON numbers; Dart calculations use double precision.

Frame timestamps are milliseconds supplied by MediaPipe result timestamps, with camera elapsed-time fallback. Camera timestamps are forced monotonic. Motion energy uses the immediately previous buffered frame's packed image-hand xyz arrays and visibility flags. A missing hand reduces/omits its terms; first frame energy is zero. Buffer gaps over 250 ms insert an explicit missing marker, and the recognition path treats that interruption as incomplete.

## Raw fixture export

`HolisticRawFrameExporter.frameToJson` serializes the full raw result and final Dart vector, including previous-frame motion inputs. In debug builds, open **Sign to Text**, tap **Capture parity fixture (debug)**, sign/hold a real recording in view, and tap **Stop and save fixture** after consecutive frames arrive. The app writes `signtalk_flutter_parity.json` to its application documents directory and displays that path. On Android, retrieve it with `adb shell run-as <applicationId> cat files/signtalk_flutter_parity.json > ml/data/parity/flutter_raw.json` (replace `<applicationId>` with the Android application ID from `android/app/build.gradle`). On desktop, copy the displayed file path to `ml/data/parity/flutter_raw.json`. This debug-only button is absent in release builds; it does not add another screen.

Activate Python and run unit tests:

```powershell
.\ml\.venv\Scripts\Activate.ps1
python -m unittest discover -s ml/tests -v
```

Run the real fixture comparison:

```powershell
python ml/scripts/compare_flutter_parity.py ml/data/parity/flutter_raw.json --atol 1e-9 --rtol 1e-7
```

The comparison fails on non-finite values, width/shape mismatch, or any tolerance mismatch; it reports error metrics and differing feature indices/groups. Tolerance is deliberately tight because both implementations consume the same serialized float values and use IEEE double precision for intermediate calculations. Capture multiple clips/conditions before treating parity as robust.

## Status

The current checkout contains no real Flutter raw export fixture. Four Python formula tests pass on synthetic landmark structures (they test equations, not ASL or Flutter parity). The exporter has a debug-only camera trigger but has not been exercised on a device recording. Feature parity is **not established** until a real Flutter fixture is captured and the comparison command passes.

## Environment / commands

`ml/.venv/Scripts/python.exe` reports Python 3.11.9; NumPy 2.4.6, Pandas 2.3.3 and PyTorch 2.15.0+cpu import successfully. Python tests cover fixed offsets/order, missing channel padding, finite-value sanitation, and motion energy. They are not parity evidence. No real recording fixture is currently present; no parity metrics are claimed.
