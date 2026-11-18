# GRU-CTC gloss baseline

This baseline is deliberately limited to **gloss sequence recognition**. It does
not translate ASL into English and must not be presented as a sentence translator.

## Prepared feature data

Create `data/features/<clip_id>.npz` for each clip with:
- `features`: float32 `[T, 2582]` using the exact Flutter-compatible feature order.
- `gloss_ids`: int64 `[U]`, token IDs from a reviewed vocabulary.

The `gloss_ids` sequence must contain gloss annotations, not English word tokens.
Build and freeze one vocabulary from the training split only; save it as JSON and
reuse it for validation/test.

## Run

```powershell
python training/train_gru_ctc.py --data-dir data/features --annotations data/annotations_with_signer_split.csv --vocab data/gloss_vocab.json --output-dir outputs/gru_ctc --epochs 30
```

The script trains on rows whose split is `train`, validates on `validation`, and
reports token error rate on validation. A held-out `test` split should be evaluated
only after model selection. Do not report validation results as test results.

## Limitations

- CTC assumes monotonic alignment and is only a baseline.
- Gloss annotations can omit non-manual markers and ASL grammar.
- WER on gloss tokens is not English sentence WER.
- The model is not mobile-exported here; ONNX export, numerical parity, quantization,
  latency, memory, and Android execution are separate gates.
