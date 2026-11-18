#!/usr/bin/env python3
"""Validate dataset metadata and enforce the human-reviewed rights gate."""
import argparse
import json
from pathlib import Path
import sys
import pandas as pd

REQUIRED_COLUMNS = {"clip_id", "signer_id", "video_path", "transcript", "gloss_sequence"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, type=Path)
    args = ap.parse_args()
    manifest_path = args.manifest.resolve()
    if not manifest_path.exists():
        raise SystemExit(f"Manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rights = manifest.get("rights_review", {})
    if rights.get("status") != "approved":
        raise SystemExit("STOP: rights_review.status is not 'approved'. Do not ingest media.")
    if not all(rights.get(k) is True for k in
               ("model_training_allowed", "commercial_use_allowed")):
        raise SystemExit("STOP: manifest does not explicitly allow model training and commercial use.")
    for key in ("reviewer", "review_date", "license_identifier", "notes"):
        if not str(rights.get(key, "")).strip():
            raise SystemExit(f"STOP: rights_review.{key} is required.")
    root = (manifest_path.parent / manifest["dataset_root"]).resolve()
    csv_path = (manifest_path.parent / manifest["annotations_csv"]).resolve()
    if not csv_path.exists():
        raise SystemExit(f"Annotations CSV not found: {csv_path}")
    df = pd.read_csv(csv_path, dtype=str).fillna("")
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise SystemExit(f"Missing CSV columns: {sorted(missing)}")
    for col in ("clip_id", "signer_id", "video_path"):
        if (df[col].str.strip() == "").any():
            raise SystemExit(f"Empty required values in column: {col}")
    if df["clip_id"].duplicated().any():
        raise SystemExit("Duplicate clip_id values found.")
    missing_files = [p for p in df["video_path"] if not (root / p).is_file()]
    print(f"Dataset: {manifest.get('dataset_name')}")
    print(f"Rows: {len(df)} | unique signers: {df.signer_id.nunique()}")
    print(f"Video files found: {len(df) - len(missing_files)} / {len(df)}")
    if missing_files:
        print("First missing paths:")
        for p in missing_files[:20]:
            print(f"  - {p}")
        raise SystemExit("Dataset validation failed: missing media.")
    if df.signer_id.nunique() < 3:
        raise SystemExit("At least 3 distinct signers are required for a 3-way signer split.")
    print("Metadata and rights gate: PASS. This does not verify annotation quality or ASL correctness.")

if __name__ == "__main__":
    main()
