#!/usr/bin/env python3
"""Assign entire signers to train/validation/test; no signer leakage."""
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, type=Path)
    ap.add_argument("--annotations", required=True, type=Path)
    args = ap.parse_args()
    mpath = args.manifest.resolve()
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    rights = manifest.get("rights_review", {})
    if rights.get("status") != "approved" or not rights.get("model_training_allowed") or not rights.get("commercial_use_allowed"):
        raise SystemExit("STOP: dataset rights gate is not approved for commercial model training.")
    df = pd.read_csv(args.annotations, dtype=str).fillna("")
    required = {"clip_id", "signer_id", "gloss_sequence"}
    if required - set(df.columns):
        raise SystemExit(f"Missing columns: {sorted(required - set(df.columns))}")
    signers = np.array(sorted(df.signer_id.unique()))
    if len(signers) < 3:
        raise SystemExit("Need at least 3 signers for signer-independent train/validation/test.")
    cfg = manifest.get("split", {})
    ratios = np.array([cfg.get("train", .7), cfg.get("validation", .15), cfg.get("test", .15)], dtype=float)
    if np.any(ratios <= 0) or not np.isclose(ratios.sum(), 1.0):
        raise SystemExit("Split ratios must be positive and sum to 1.")
    rng = np.random.default_rng(int(cfg.get("seed", 42)))
    rng.shuffle(signers)
    # Ensure every split receives at least one signer, then allocate remaining by ratios.
    n = len(signers)
    counts = np.floor(ratios * n).astype(int)
    counts[counts == 0] = 1
    while counts.sum() > n:
        i = int(np.argmax(counts - ratios * n))
        if counts[i] > 1: counts[i] -= 1
        else: break
    while counts.sum() < n:
        i = int(np.argmax(ratios * n - counts))
        counts[i] += 1
    labels = ["train", "validation", "test"]
    assignments, start = {}, 0
    for label, count in zip(labels, counts):
        for signer in signers[start:start+count]:
            assignments[signer] = label
        start += count
    df["split"] = df.signer_id.map(assignments)
    # Guard against leakage.
    signer_sets = {s: set(df.loc[df.split == s, "signer_id"]) for s in labels}
    assert not (signer_sets["train"] & signer_sets["validation"])
    assert not (signer_sets["train"] & signer_sets["test"])
    assert not (signer_sets["validation"] & signer_sets["test"])
    out = args.annotations.with_name("annotations_with_signer_split.csv")
    df.to_csv(out, index=False)
    print(f"Wrote: {out}")
    for label in labels:
        part = df[df.split == label]
        print(f"{label}: {len(part)} clips, {part.signer_id.nunique()} signers")

if __name__ == "__main__":
    main()
