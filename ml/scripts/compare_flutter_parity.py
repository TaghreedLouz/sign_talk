import argparse,json,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"preprocessing"))
from flutter_feature_extractor import extract,SCHEMA

GROUPS=[("face",0,1912),("blendshapes",1912,1964),("pose_image",1964,2096),("pose_world",2096,2228),("left_image",2228,2312),("left_world",2312,2396),("right_image",2396,2480),("right_world",2480,2564),("presence_flags",2564,2569),("left_orientation",2569,2575),("right_orientation",2575,2581),("motion_energy",2581,2582)]
def main():
 p=argparse.ArgumentParser(); p.add_argument("fixture",type=Path); p.add_argument("--atol",type=float,default=1e-9); p.add_argument("--rtol",type=float,default=1e-7); a=p.parse_args()
 data=json.loads(a.fixture.read_text(encoding="utf-8")); assert data.get("featureSchema")==SCHEMA and data.get("schemaVersion")==1
 errors=[]; groups=set(); all_diff=[]
 for fi,f in enumerate(data["frames"]):
  ref=np.asarray(f["flutterFeatures"],dtype=np.float64); got=np.asarray(extract(f),dtype=np.float64)
  if ref.shape!=(2582,) or got.shape!=(2582,): raise SystemExit(f"frame {fi}: dimension mismatch {ref.shape} vs {got.shape}")
  if not np.isfinite(ref).all() or not np.isfinite(got).all(): raise SystemExit(f"frame {fi}: non-finite input/output")
  d=np.abs(ref-got); ids=np.flatnonzero(~np.isclose(ref,got,atol=a.atol,rtol=a.rtol)); all_diff.extend((fi,int(i),float(d[i])) for i in ids)
  for name,start,end in GROUPS:
   if np.any((ids>=start)&(ids<end)): groups.add(name)
  errors.extend(d.tolist())
 e=np.asarray(errors); print(f"frames={len(data['frames'])} dimensions=2582 max_abs={e.max(initial=0):.12g} mean_abs={e.mean() if e.size else 0:.12g} rmse={np.sqrt(np.mean(e*e)) if e.size else 0:.12g}")
 print(f"mismatched_values={len(all_diff)} groups={','.join(sorted(groups)) or 'none'}")
 for x in all_diff[:100]: print(f"frame={x[0]} index={x[1]} abs_error={x[2]:.12g}")
 if not data["frames"] or all_diff: raise SystemExit("FAIL: parity not established")
 print("PASS: fixture frames match within tolerance")
if __name__=="__main__": main()
