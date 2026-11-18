# SignTalk ASL training workspace

Python 3.11 workspace for a future continuous ASL research pipeline. No dataset or weights are included. Do not download corpus media until its terms and intended use have been approved.

## Status

Scaffolding only. The Flutter input contract is `signtalk.holistic.2582.v1`, 2,582 ordered features per frame. A Python extractor must be parity-tested against Flutter MediaPipe output before any training. Python 3.11 is not available in the current environment (`python.exe` resolves to an inaccessible WindowsApps alias), so training code and dependency lock are not claimed as tested.

Priority corpus: How2Sign, continuous ASL with English transcripts and gloss annotations. Its listed terms are CC BY-NC 4.0, which excludes commercial use absent separate permission. OpenASL is ASL-English continuous data but CC BY-NC-ND 4.0, so derivatives/training deployment rights require legal review. YouTube-ASL releases video IDs, not owned video files; source video terms still govern and availability can change. ASL Citizen is isolated signs and is not a sentence corpus.

See `../PHASE3A_DATASET_AND_TRAINING.md` for source-based findings and the staged training/export plan.
