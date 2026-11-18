import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from preprocessing.flutter_feature_extractor import BLENDSHAPES, extract, SCHEMA

def point(x=0,y=0,z=0,visibility=None,presence=None):
    return dict(x=x,y=y,z=z,visibility=visibility,presence=presence)

def raw():
    hand=[point(i/20,(i%5)/10,(i%3)/10,1) for i in range(21)]
    return dict(featureSchema=SCHEMA,timestampMs=0,faceLandmarks=[point(visibility=1)]*478,
      faceBlendshapes=[dict(name="jawOpen",score=.75),dict(name="browDownLeft",score=.25)],
      poseImageLandmarks=[point(visibility=1)]*33,poseWorldLandmarks=[point(presence=1)]*33,
      leftHandImageLandmarks=hand,leftHandWorldLandmarks=hand,rightHandImageLandmarks=hand,
      rightHandWorldLandmarks=hand,previous=None)

class FeatureTests(unittest.TestCase):
    def test_full_width_blendshape_names_and_offsets(self):
        f=extract(raw()); self.assertEqual(len(f),2582); self.assertEqual(len(BLENDSHAPES),52)
        self.assertEqual(f[1912],.25); self.assertEqual(f[1912+24],.75)
        self.assertEqual(f[2564:2569],[1.]*5)
    def test_missing_groups_are_zero_padded_with_presence_clear(self):
        x=raw(); x.update(faceLandmarks=[],poseImageLandmarks=[],leftHandImageLandmarks=[],rightHandImageLandmarks=[],faceBlendshapes=[])
        f=extract(x); self.assertEqual(f[:1912],[0.]*1912); self.assertEqual(f[1964:2096],[0.]*132)
        self.assertEqual(f[2564:2569],[0.]*5)
    def test_nonfinite_is_sanitized(self):
        x=raw(); x['faceLandmarks'][0]=point(float('nan'),float('inf'),-float('inf'),float('nan'))
        f=extract(x); self.assertEqual(f[:4],[0.]*4); self.assertTrue(all(math.isfinite(v) for v in f))
    def test_motion_and_frame_gap_inputs(self):
        x=raw(); x['previous']={'timestampMs':0,'leftHandVisible':True,'rightHandVisible':False,'leftHandCoordinates':[0.]*63,'rightHandCoordinates':[]}
        f=extract(x); expected=sum(math.sqrt(sum((a-b)**2 for a,b in zip(fcur,fprev))) for fcur,fprev in zip([[(p['x'],p['y'],p['z']) for p in x['leftHandImageLandmarks']][i] for i in range(21)],[(0,0,0)]*21))/21
        self.assertAlmostEqual(f[2581],expected)

if __name__=='__main__': unittest.main()
