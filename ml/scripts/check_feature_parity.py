#!/usr/bin/env python3
"""Compare the same frames exported by Flutter and Python; not a substitute for code review."""
import argparse, json
from pathlib import Path
import numpy as np

SCHEMA = "signtalk.holistic.2582.v1"
WIDTH = 2582

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flutter-json", required=True, type=Path)
    ap.add_argument("--python-npz", required=True, type=Path)
    ap.add_argument("--atol", type=float, default=1e-5)
    ap.add_argument("--rtol", type=float, default=1e-4)
    args = ap.parse_args()
    ref = json.loads(args.flutter_json.read_text(encoding="utf-8"))
    if ref.get("schema") != SCHEMA:
        raise SystemExit(f"Flutter schema mismatch: {ref.get('schema')!r}")
    a = np.asarray(ref.get("frames"), dtype=np.float32)
    with np.load(args.python_npz) as z:
        if "frames" not in z:
            raise SystemExit("NPZ must contain array named 'frames'.")
        b = np.asarray(z["frames"], dtype=np.float32)
    if a.ndim != 2 or b.ndim != 2 or a.shape[1] != WIDTH or b.shape[1] != WIDTH:
        raise SystemExit(f"Both arrays must be [T,{WIDTH}]. Got {a.shape} and {b.shape}")
    if a.shape != b.shape:
        raise SystemExit(f"Frame shape mismatch: Flutter {a.shape}, Python {b.shape}")
    if not np.isfinite(a).all() or not np.isfinite(b).all():
        raise SystemExit("Non-finite values detected.")
    diff = np.abs(a - b)
    max_abs = float(diff.max(initial=0))
    mean_abs = float(diff.mean())
    print(f"max_abs_error={max_abs:.8g}; mean_abs_error={mean_abs:.8g}")
    if not np.allclose(a, b, atol=args.atol, rtol=args.rtol):
        raise SystemExit("FAIL: preprocessing parity not established.")
    print("PASS: numeric parity for this reference recording only. Validate multiple signers, poses, and lighting conditions.")

if __name__ == "__main__":
    main()
