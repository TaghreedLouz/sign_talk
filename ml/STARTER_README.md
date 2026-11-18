# SignTalk Phase 3A — ML workspace starter

This is an isolated ML workspace. It does **not** modify the Flutter app and does
not claim to provide an ASL recognizer. It prepares a reproducible path from
legally approved continuous-ASL recordings to a first gloss-recognition baseline.

## Critical boundary

The Flutter contract reported for the app is:

- schema: `signtalk.holistic.2582.v1`
- one frame: 2,582 ordered float features
- camera adapter input: `List<TemporalLandmarkFrame>`

The exact 2,582-feature ordering and normalization implementation are **not included
in this starter**. Do not extract training features with a different MediaPipe
pipeline and label them as compatible. First export a few reference clips from
Flutter (or port the exact implementation) and pass parity checks.

This starter trains **gloss sequences**, not English translations. A separate,
linguistically reviewed ASL-to-English translation component is still required.
It intentionally refuses to use a dataset until its rights review is explicitly
recorded in the dataset manifest.

## Workspace

- `configs/feature_contract.json` — declared Flutter feature contract.
- `configs/dataset_manifest.template.json` — dataset and rights metadata template.
- `schemas/annotations.csv.schema.json` — annotation CSV schema.
- `scripts/validate_dataset.py` — checks metadata, files, signer IDs, and rights gate.
- `scripts/make_signer_split.py` — deterministic signer-independent split.
- `scripts/check_feature_parity.py` — compares Flutter-exported reference arrays
  with Python arrays; checks dimensions and numeric parity only.
- `training/train_gru_ctc.py` — compact GRU + CTC gloss baseline.
- `training/README.md` — expected prepared-data format and training notes.

## Windows setup (PowerShell)

Use a real Python 3.11 installation, not the Microsoft Store `WindowsApps` alias:

```powershell
py -0p
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python --version
```

If `py -3.11` is not found, install Python 3.11 from python.org and enable the
Python Launcher. In Windows Settings → Apps → Advanced app settings → App execution
aliases, turn off the `python.exe` and `python3.exe` Store aliases if they intercept
the command. Open a new terminal and retry.

## Required annotation CSV

Create `data/annotations.csv` with these columns:

`clip_id,signer_id,video_path,transcript,gloss_sequence,split`

- `clip_id`: unique recording identifier.
- `signer_id`: stable pseudonymous signer identifier.
- `video_path`: path relative to the dataset root.
- `transcript`: verified English reference, if available.
- `gloss_sequence`: space-separated gloss tokens, if reviewed annotations exist.
- `split`: leave blank; the split script fills it.

Do not infer glosses from English transcripts. Have qualified ASL annotators review
glosses, grammar, non-manual markers, and translations.

## Rights gate

Edit `configs/dataset_manifest.json` from the template. Set
`rights_review.status` to `approved` only after a human has checked the exact
dataset, media, annotations, model-training rights, intended distribution, and
commercial-use restrictions. Record the source URL, reviewer, date, and notes.
The scripts refuse to proceed while the status is not `approved`.

A research-only/non-commercial license is not sufficient for a commercial app.
Do not assume a dataset license covers videos hosted by third parties.

## Commands

```powershell
python scripts/validate_dataset.py --manifest configs/dataset_manifest.json
python scripts/make_signer_split.py --manifest configs/dataset_manifest.json --annotations data/annotations.csv
python scripts/check_feature_parity.py --flutter-json data/parity/flutter_reference.json --python-npz data/parity/python_reference.npz
```

The parity files must represent the **same source recording and same timestamps**.
The Flutter JSON format expected by the checker is:

```json
{"schema":"signtalk.holistic.2582.v1","frames":[[0.0, 0.1], [0.2, 0.3]]}
```

Each frame must contain exactly 2,582 values. The NPZ must contain an array named
`frames` with shape `[T, 2582]`.

Only after exact preprocessing parity is established should feature extraction
be run over the approved training videos.

## Training baseline

The GRU-CTC baseline expects `.npz` files containing:
- `features`: float32 array `[T, 2582]`
- `gloss_ids`: int64 array `[U]`

It is a research baseline for gloss recognition, not sentence translation.
See `training/README.md`. Use signer-independent splits and report gloss WER
separately from English sentence WER.
