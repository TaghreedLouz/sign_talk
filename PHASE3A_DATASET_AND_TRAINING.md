# Phase 3A: Dataset and Training Preparation

## Current contract

Flutter `HolisticFeatureExtractor.extract(result, timestampMs, previous)` returns `TemporalLandmarkFrame`, with fixed-order `features` length 2,582 under `signtalk.holistic.2582.v1`; it also exposes timestamps, visibility, hand coordinates/orientation, motion energy, and missing-frame status. The pipeline segments frames then calls `AslContinuousRecognitionModel.infer(List<TemporalLandmarkFrame>)`. See [pipeline](lib/features/camera/asl_recognition_pipeline.dart), [manifest](assets/models/asl_recognition.json), and [tests](test/asl_recognition_pipeline_test.dart). Python MediaPipe version, image orientation, normalization, absent-landmark fill, and feature order must be proven identical before producing training arrays.

## Dataset review (2026-11-18)

| Dataset | Content/labels/splits | Access, resolution and use |
|---|---|---|
| How2Sign | Official continuous ASL multiview corpus, about 80 hours; English transcripts, gloss annotations, signer metadata; 11 signers. Official downloads and metadata are linked from [project site](https://how2sign.github.io/). Use provided train/dev/test signer split; inspect actual manifests before extraction. | ELRA catalogue reports 30 fps MPEG and CC BY-NC 4.0. Noncommercial only absent separate rights. Suitable for research training, not commercial app deployment on that license alone. [ELRA entry](https://catalog.elda.org/en-us/repository/browse/ELRA-S0416/). |
| OpenASL | Continuous open-domain ASL-English online video corpus; sentence text and signer/video metadata where available. Official repository provides TSV and download script; use its split files and audit signer overlap. | CC BY-NC-ND 4.0 in repository. No-derivatives terms create material uncertainty for feature extraction/model training and distribution; do not use for this app until rights holder grants explicit permission. Video resolution/FPS varies by source. [Repository/license](https://github.com/chevalierNoir/OpenASL). |
| YouTube-ASL | Continuous ASL videos with English captions; roughly 984 hours and 2,500+ signers in paper. Public release is video IDs. | No blanket rights to YouTube media are conveyed by releasing IDs; terms, creator rights, download availability, and captions must be assessed per source. Research use cannot be presumed commercial. Variable source resolution/FPS. [Google Research data page](https://github.com/google-research/google-research/tree/master/youtube_asl), [paper](https://arxiv.org/abs/2306.15162). |
| ASL Citizen | 84k videos, 2.7k isolated signs, 52 Deaf/HoH signers; isolated labels, not sentence references or continuous gloss streams. | Microsoft research license; recommended for isolated dictionary retrieval, explicitly cautions against tokenizing it into continuous translation. Not a sentence training corpus. [License](https://www.microsoft.com/en-us/research/project/asl-citizen/dataset-license/), [recommended use](https://www.microsoft.com/en-us/research/project/asl-citizen/recommended-use/). |

## Preparation and training plan

1. Obtain explicit rights for the intended commercial/noncommercial model use. Preserve original corpus splits; group by signer when creating any new split and assert zero signer overlap.
2. Parse official metadata/annotations; validate file presence, decodeability, dimensions, timestamps, FPS, signer ID, sentence reference and gloss availability. Emit a machine-readable quality report; exclude records only with logged reasons.
3. Extract Holistic features at the same sampling rate and mapping as Flutter. Store schema ID, MediaPipe model/version, transforms, timestamps, visibility and masks with every record. Create golden-frame tests comparing Python output against Flutter fixture outputs. Do not train until parity passes.
4. Normalize using training-set statistics only; retain missingness masks. Bucket variable sequences, pad with explicit masks, and retain gloss-to-time alignment where provided.
5. Start with compact temporal convolution/GRU encoder. Train a CTC gloss recognizer only where gloss labels exist. Train English translation as a separate sequence-to-sequence task from continuous video/features and verified sentence references; never mechanically convert unreviewed gloss order into English.
6. Evaluate gloss WER separately from English WER and exact sentence accuracy on untouched signer-independent test data. Report unknown/incomplete rejection, confidence calibration, latency and peak memory. No metrics exist yet.
7. Export with ONNX, compare framework and ONNX outputs numerically, then benchmark Android CPU/NNAPI. Generate a manifest with dataset/model terms and checkpoint SHA-256. Do not enable Flutter inference until parity, license, evaluation and device tests pass.

## Runtime choice

ONNX is the first export target for a compact temporal network because Android ONNX Runtime supports offline local inference, but this is a target, not a verified app integration. TensorFlow Lite is an alternative only after graph conversion and numerical parity. Neither runtime can resolve dataset rights or input-schema mismatch. No model was trained, exported, or evaluated in Phase 3A.

## Scaffold status

The `ml/` directories are reserved for dataset manifests, preprocessing, training, evaluation, export, and configs. Python 3.11 is unavailable in the current environment, so runnable scripts and dependency installation remain blocked. No media was downloaded.
