"""Reproduce HolisticFeatureExtractor for version-1 raw Flutter JSON frames."""
import math

SCHEMA = "signtalk.holistic.2582.v1"
BLENDSHAPES = """browDownLeft browDownRight browInnerUp browOuterUpLeft browOuterUpRight cheekPuff cheekSquintLeft cheekSquintRight eyeBlinkLeft eyeBlinkRight eyeLookDownLeft eyeLookDownRight eyeLookInLeft eyeLookInRight eyeLookOutLeft eyeLookOutRight eyeLookUpLeft eyeLookUpRight eyeSquintLeft eyeSquintRight eyeWideLeft eyeWideRight jawForward jawLeft jawOpen jawRight mouthClose mouthDimpleLeft mouthDimpleRight mouthFrownLeft mouthFrownRight mouthFunnel mouthLeft mouthLowerDownLeft mouthLowerDownRight mouthPressLeft mouthPressRight mouthPucker mouthRight mouthRollLower mouthRollUpper mouthShrugLower mouthShrugUpper mouthSmileLeft mouthSmileRight mouthStretchLeft mouthStretchRight mouthUpperUpLeft mouthUpperUpRight noseSneerLeft noseSneerRight tongueOut""".split()

def finite(value):
    try:
        value = float(value)
    except (TypeError, ValueError):
        return 0.0
    return value if math.isfinite(value) else 0.0

def pack(points, count):
    out=[]
    for i in range(count):
        p=points[i] if i < len(points) else {}
        visibility=p.get("visibility")
        if visibility is None: visibility=p.get("presence")
        out.extend((finite(p.get("x")),finite(p.get("y")),finite(p.get("z")),finite(visibility)))
    return out

def orientation(points):
    if len(points) <= 17: return [0.0]*6
    xyz=lambda i:[finite(points[i].get(k)) for k in ("x","y","z")]
    sub=lambda a,b:[x-y for x,y in zip(a,b)]
    wrist=xyz(0); mid=sub(xyz(9),wrist); idx=sub(xyz(5),wrist); pink=sub(xyz(17),wrist)
    cross=[idx[1]*pink[2]-idx[2]*pink[1],idx[2]*pink[0]-idx[0]*pink[2],idx[0]*pink[1]-idx[1]*pink[0]]
    def unit(v):
        n=math.sqrt(sum(x*x for x in v))
        return [x/n for x in v] if n>1e-8 and math.isfinite(n) else [0.0]*3
    return unit(mid)+unit(cross)

def extract(frame):
    face=frame.get("faceLandmarks",[]); pose=frame.get("poseImageLandmarks",[])
    pw=frame.get("poseWorldLandmarks",[]); left=frame.get("leftHandImageLandmarks",[])
    lw=frame.get("leftHandWorldLandmarks",[]); right=frame.get("rightHandImageLandmarks",[])
    rw=frame.get("rightHandWorldLandmarks",[])
    cats={c.get("name"):finite(c.get("score")) for c in frame.get("faceBlendshapes",[]) if c.get("name") is not None}
    flags=[bool(face),bool(pose),bool(left),bool(right),bool(frame.get("faceBlendshapes",[]))]
    lcoords=[finite(p.get(k)) for p in left[:21] for k in ("x","y","z")]
    rcoords=[finite(p.get(k)) for p in right[:21] for k in ("x","y","z")]
    prev=frame.get("previous"); ds=[]
    if prev:
        for visible,key,cur in ((prev.get("leftHandVisible"),"leftHandCoordinates",lcoords),(prev.get("rightHandVisible"),"rightHandCoordinates",rcoords)):
            before=prev.get(key,[])
            if visible and cur:
                for i in range(0,min(len(before),len(cur))-2,3):
                    ds.append(math.sqrt(sum((cur[i+j]-finite(before[i+j]))**2 for j in range(3))))
    motion=sum(ds)/len(ds) if ds else 0.0
    out=pack(face,478)+[cats.get(n,0.0) for n in BLENDSHAPES]+pack(pose,33)+pack(pw,33)+pack(left,21)+pack(lw,21)+pack(right,21)+pack(rw,21)+[1.0 if f else 0.0 for f in flags]+orientation(left)+orientation(right)+[motion]
    return out
