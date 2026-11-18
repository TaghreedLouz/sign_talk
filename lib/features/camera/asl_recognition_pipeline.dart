import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Testable representation of one plane from a platform camera frame.
class CameraPixelPlane {
  const CameraPixelPlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// Converts camera planes into tightly packed RGBA pixels for MediaPipe.
class CameraFramePreprocessor {
  const CameraFramePreprocessor._();

  static Uint8List fromCameraImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final plane = image.planes.first;
      return bgraToRgba(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
      );
    }
    if (image.format.group != ImageFormatGroup.yuv420 ||
        image.planes.length < 3) {
      throw UnsupportedError(
        'Unsupported camera format: ${image.format.group}',
      );
    }
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    return yuv420ToRgba(
      width: image.width,
      height: image.height,
      y: CameraPixelPlane(
        bytes: y.bytes,
        bytesPerRow: y.bytesPerRow,
        bytesPerPixel: y.bytesPerPixel ?? 1,
      ),
      u: CameraPixelPlane(
        bytes: u.bytes,
        bytesPerRow: u.bytesPerRow,
        bytesPerPixel: u.bytesPerPixel ?? 1,
      ),
      v: CameraPixelPlane(
        bytes: v.bytes,
        bytesPerRow: v.bytesPerRow,
        bytesPerPixel: v.bytesPerPixel ?? 1,
      ),
    );
  }

  static Uint8List bgraToRgba({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    _validate(width, height);
    if (bytesPerRow < width * 4 || bytes.length < bytesPerRow * height) {
      throw ArgumentError('BGRA plane is shorter than its dimensions.');
    }
    final output = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final src = y * bytesPerRow + x * 4;
        final dst = (y * width + x) * 4;
        output[dst] = bytes[src + 2];
        output[dst + 1] = bytes[src + 1];
        output[dst + 2] = bytes[src];
        output[dst + 3] = 255;
      }
    }
    return output;
  }

  static Uint8List yuv420ToRgba({
    required int width,
    required int height,
    required CameraPixelPlane y,
    required CameraPixelPlane u,
    required CameraPixelPlane v,
  }) {
    _validate(width, height);
    final chromaWidth = (width + 1) ~/ 2;
    final chromaHeight = (height + 1) ~/ 2;
    if (y.bytesPerPixel < 1 ||
        y.bytesPerRow < (width - 1) * y.bytesPerPixel + 1 ||
        y.bytes.length <
            _requiredPlaneBytes(
              height,
              width,
              y.bytesPerRow,
              y.bytesPerPixel,
            ) ||
        u.bytesPerPixel < 1 ||
        v.bytesPerPixel < 1 ||
        u.bytesPerRow < (chromaWidth - 1) * u.bytesPerPixel + 1 ||
        v.bytesPerRow < (chromaWidth - 1) * v.bytesPerPixel + 1 ||
        u.bytes.length <
            _requiredPlaneBytes(
              chromaHeight,
              chromaWidth,
              u.bytesPerRow,
              u.bytesPerPixel,
            ) ||
        v.bytes.length <
            _requiredPlaneBytes(
              chromaHeight,
              chromaWidth,
              v.bytesPerRow,
              v.bytesPerPixel,
            )) {
      throw ArgumentError('YUV420 planes are shorter than their dimensions.');
    }
    final output = Uint8List(width * height * 4);
    for (var row = 0; row < height; row++) {
      for (var column = 0; column < width; column++) {
        final luminance = y
            .bytes[row * y.bytesPerRow + column * y.bytesPerPixel]
            .toDouble();
        final chromaRow = row >> 1;
        final chromaColumn = column >> 1;
        final uValue =
            u.bytes[chromaRow * u.bytesPerRow + chromaColumn * u.bytesPerPixel]
                .toDouble() -
            128;
        final vValue =
            v.bytes[chromaRow * v.bytesPerRow + chromaColumn * v.bytesPerPixel]
                .toDouble() -
            128;
        final c = math.max(0.0, luminance - 16.0);
        final offset = (row * width + column) * 4;
        output[offset] = (1.164 * c + 1.596 * vValue).round().clamp(0, 255);
        output[offset + 1] = (1.164 * c - 0.392 * uValue - 0.813 * vValue)
            .round()
            .clamp(0, 255);
        output[offset + 2] = (1.164 * c + 2.017 * uValue).round().clamp(0, 255);
        output[offset + 3] = 255;
      }
    }
    return output;
  }

  static void _validate(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive.');
    }
  }

  static int _requiredPlaneBytes(
    int rows,
    int columns,
    int bytesPerRow,
    int bytesPerPixel,
  ) => (rows - 1) * bytesPerRow + (columns - 1) * bytesPerPixel + 1;
}

/// One timestamped model input frame, including all Holistic channels.
class TemporalLandmarkFrame {
  const TemporalLandmarkFrame({
    required this.timestampMs,
    required this.features,
    required this.faceVisible,
    required this.poseVisible,
    required this.leftHandVisible,
    required this.rightHandVisible,
    required this.faceBlendshapesVisible,
    this.leftHandCoordinates = const [],
    this.rightHandCoordinates = const [],
    this.leftHandOrientation = const [],
    this.rightHandOrientation = const [],
    this.motionEnergy = 0,
    this.isMissing = false,
  });

  final int timestampMs;
  final List<double> features;
  final bool faceVisible;
  final bool poseVisible;
  final bool leftHandVisible;
  final bool rightHandVisible;
  final bool faceBlendshapesVisible;
  final List<double> leftHandCoordinates;
  final List<double> rightHandCoordinates;

  /// Wrist direction and palm normal, xyz for each hand.
  final List<double> leftHandOrientation;
  final List<double> rightHandOrientation;
  final double motionEnergy;
  final bool isMissing;

  bool get bothHandsVisible => leftHandVisible && rightHandVisible;
  bool get hasCoreSigningLandmarks => poseVisible && bothHandsVisible;
}

/// Fixed feature order for this adapter: face mesh + ARKit blendshapes,
/// image/world pose, image/world hands, then group-presence masks.
/// It is intentionally separate from any external checkpoint's feature format.
class HolisticFeatureExtractor {
  const HolisticFeatureExtractor();

  static const featureSchema = 'signtalk.holistic.2582.v1';
  static const faceLandmarkCount = 478;
  static const poseLandmarkCount = 33;
  static const handLandmarkCount = 21;
  static const faceBlendshapeCount = 52;
  static const _coordinatesPerLandmark = 4; // x, y, z and visibility/presence
  static const featureDimension =
      faceLandmarkCount * _coordinatesPerLandmark +
      faceBlendshapeCount +
      poseLandmarkCount * _coordinatesPerLandmark * 2 +
      handLandmarkCount * _coordinatesPerLandmark * 4 +
      5 + // face, pose, left/right hands, blendshapes
      12 + // wrist direction and palm normal for both hands
      1; // temporal hand-motion energy

  static const _blendshapeNames = [
    'browDownLeft',
    'browDownRight',
    'browInnerUp',
    'browOuterUpLeft',
    'browOuterUpRight',
    'cheekPuff',
    'cheekSquintLeft',
    'cheekSquintRight',
    'eyeBlinkLeft',
    'eyeBlinkRight',
    'eyeLookDownLeft',
    'eyeLookDownRight',
    'eyeLookInLeft',
    'eyeLookInRight',
    'eyeLookOutLeft',
    'eyeLookOutRight',
    'eyeLookUpLeft',
    'eyeLookUpRight',
    'eyeSquintLeft',
    'eyeSquintRight',
    'eyeWideLeft',
    'eyeWideRight',
    'jawForward',
    'jawLeft',
    'jawOpen',
    'jawRight',
    'mouthClose',
    'mouthDimpleLeft',
    'mouthDimpleRight',
    'mouthFrownLeft',
    'mouthFrownRight',
    'mouthFunnel',
    'mouthLeft',
    'mouthLowerDownLeft',
    'mouthLowerDownRight',
    'mouthPressLeft',
    'mouthPressRight',
    'mouthPucker',
    'mouthRight',
    'mouthRollLower',
    'mouthRollUpper',
    'mouthShrugLower',
    'mouthShrugUpper',
    'mouthSmileLeft',
    'mouthSmileRight',
    'mouthStretchLeft',
    'mouthStretchRight',
    'mouthUpperUpLeft',
    'mouthUpperUpRight',
    'noseSneerLeft',
    'noseSneerRight',
    'tongueOut',
  ];

  TemporalLandmarkFrame extract(
    HolisticLandmarkerResult result, {
    required int timestampMs,
    TemporalLandmarkFrame? previous,
  }) {
    final face = _packNormalized(result.faceLandmarks, faceLandmarkCount);
    final pose = _packNormalized(result.poseLandmarks, poseLandmarkCount);
    final poseWorld = _packWorld(result.poseWorldLandmarks, poseLandmarkCount);
    final left = _packNormalized(result.leftHandLandmarks, handLandmarkCount);
    final leftWorld = _packWorld(
      result.leftHandWorldLandmarks,
      handLandmarkCount,
    );
    final right = _packNormalized(result.rightHandLandmarks, handLandmarkCount);
    final rightWorld = _packWorld(
      result.rightHandWorldLandmarks,
      handLandmarkCount,
    );
    final blendshapes = _packBlendshapes(result.faceBlendshapes);
    final hasFace = result.faceLandmarks.isNotEmpty;
    final hasPose = result.poseLandmarks.isNotEmpty;
    final hasLeft = result.leftHandLandmarks.isNotEmpty;
    final hasRight = result.rightHandLandmarks.isNotEmpty;
    final hasBlendshapes = result.faceBlendshapes?.isNotEmpty == true;
    final leftCoordinates = _packCoordinates(result.leftHandLandmarks);
    final rightCoordinates = _packCoordinates(result.rightHandLandmarks);
    final leftOrientation = _handOrientation(result.leftHandLandmarks);
    final rightOrientation = _handOrientation(result.rightHandLandmarks);
    final motionEnergy = _motionEnergy(
      previous,
      leftCoordinates,
      rightCoordinates,
    );
    final features = <double>[
      ...face,
      ...blendshapes,
      ...pose,
      ...poseWorld,
      ...left,
      ...leftWorld,
      ...right,
      ...rightWorld,
      _flag(hasFace),
      _flag(hasPose),
      _flag(hasLeft),
      _flag(hasRight),
      _flag(hasBlendshapes),
      ...leftOrientation,
      ...rightOrientation,
      motionEnergy,
    ];
    assert(features.length == featureDimension);
    return TemporalLandmarkFrame(
      timestampMs: timestampMs,
      features: List.unmodifiable(features),
      leftHandCoordinates: List.unmodifiable(leftCoordinates),
      rightHandCoordinates: List.unmodifiable(rightCoordinates),
      leftHandOrientation: List.unmodifiable(leftOrientation),
      rightHandOrientation: List.unmodifiable(rightOrientation),
      motionEnergy: motionEnergy,
      faceVisible: hasFace,
      poseVisible: hasPose,
      leftHandVisible: hasLeft,
      rightHandVisible: hasRight,
      faceBlendshapesVisible: hasBlendshapes,
    );
  }

  List<double> _packNormalized(List<NormalizedLandmark> landmarks, int count) {
    final values = <double>[];
    for (var index = 0; index < count; index++) {
      if (index < landmarks.length) {
        final point = landmarks[index];
        values.addAll([
          _finite(point.x),
          _finite(point.y),
          _finite(point.z),
          _finite(point.visibility ?? point.presence ?? 0),
        ]);
      } else {
        values.addAll(const [0, 0, 0, 0]);
      }
    }
    return values;
  }

  List<double> _packWorld(List<Landmark> landmarks, int count) {
    final values = <double>[];
    for (var index = 0; index < count; index++) {
      if (index < landmarks.length) {
        final point = landmarks[index];
        values.addAll([
          _finite(point.x),
          _finite(point.y),
          _finite(point.z),
          _finite(point.visibility ?? point.presence ?? 0),
        ]);
      } else {
        values.addAll(const [0, 0, 0, 0]);
      }
    }
    return values;
  }

  List<double> _packBlendshapes(List<MediaPipeCategory>? categories) {
    final byName = <String, double>{};
    for (final category in categories ?? const <MediaPipeCategory>[]) {
      final name = category.categoryName;
      if (name != null) byName[name] = _finite(category.score);
    }
    return _blendshapeNames.map((name) => byName[name] ?? 0).toList();
  }

  List<double> _packCoordinates(List<NormalizedLandmark> landmarks) => landmarks
      .take(handLandmarkCount)
      .expand((point) => [_finite(point.x), _finite(point.y), _finite(point.z)])
      .toList(growable: false);

  List<double> _handOrientation(List<NormalizedLandmark> points) {
    if (points.length <= 17) return List<double>.filled(6, 0);
    final wrist = _xyz(points[0]);
    final middleMcp = _xyz(points[9]);
    final indexMcp = _xyz(points[5]);
    final pinkyMcp = _xyz(points[17]);
    final wristDirection = _unit(_subtract(middleMcp, wrist));
    final palmNormal = _unit(
      _cross(_subtract(indexMcp, wrist), _subtract(pinkyMcp, wrist)),
    );
    return [...wristDirection, ...palmNormal];
  }

  List<double> _xyz(NormalizedLandmark point) => [
    _finite(point.x),
    _finite(point.y),
    _finite(point.z),
  ];

  List<double> _subtract(List<double> a, List<double> b) => [
    a[0] - b[0],
    a[1] - b[1],
    a[2] - b[2],
  ];

  List<double> _cross(List<double> a, List<double> b) => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];

  List<double> _unit(List<double> vector) {
    final length = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (length <= 1e-8 || !length.isFinite) return const [0, 0, 0];
    return vector.map((value) => value / length).toList(growable: false);
  }

  double _motionEnergy(
    TemporalLandmarkFrame? previous,
    List<double> left,
    List<double> right,
  ) {
    if (previous == null) return 0;
    final deltas = <double>[];
    void collect(List<double> before, List<double> after) {
      final length = math.min(before.length, after.length);
      for (var index = 0; index + 2 < length; index += 3) {
        final dx = after[index] - before[index];
        final dy = after[index + 1] - before[index + 1];
        final dz = after[index + 2] - before[index + 2];
        deltas.add(math.sqrt(dx * dx + dy * dy + dz * dz));
      }
    }

    if (previous.leftHandVisible && left.isNotEmpty) {
      collect(previous.leftHandCoordinates, left);
    }
    if (previous.rightHandVisible && right.isNotEmpty) {
      collect(previous.rightHandCoordinates, right);
    }
    if (deltas.isEmpty) return 0;
    return deltas.reduce((a, b) => a + b) / deltas.length;
  }

  double _flag(bool visible) => visible ? 1 : 0;
  double _finite(double value) => value.isFinite ? value : 0;
}

/// Debug-only raw capture serializer for parity fixtures. The caller supplies
/// consecutive MediaPipe results from one recording and writes the returned
/// JSON string to a local fixture. It does not alter the camera pipeline.
class HolisticRawFrameExporter {
  const HolisticRawFrameExporter();

  static const schemaVersion = 1;

  Map<String, Object?> frameToJson(
    HolisticLandmarkerResult result, {
    required int timestampMs,
    TemporalLandmarkFrame? previous,
  }) {
    List<Map<String, Object?>> normalized(List<NormalizedLandmark> points) =>
        points
            .map(
              (p) => {
                'x': p.x,
                'y': p.y,
                'z': p.z,
                'visibility': p.visibility,
                'presence': p.presence,
              },
            )
            .toList(growable: false);
    List<Map<String, Object?>> world(List<Landmark> points) => points
        .map(
          (p) => {
            'x': p.x,
            'y': p.y,
            'z': p.z,
            'visibility': p.visibility,
            'presence': p.presence,
          },
        )
        .toList(growable: false);
    final extracted = const HolisticFeatureExtractor().extract(
      result,
      timestampMs: timestampMs,
      previous: previous,
    );
    return {
      'schemaVersion': schemaVersion,
      'featureSchema': HolisticFeatureExtractor.featureSchema,
      'timestampMs': timestampMs,
      'imageWidth': result.imageWidth,
      'imageHeight': result.imageHeight,
      'faceLandmarks': normalized(result.faceLandmarks),
      'faceBlendshapes': (result.faceBlendshapes ?? const <MediaPipeCategory>[])
          .map(
            (c) => {'name': c.categoryName, 'score': c.score, 'index': c.index},
          )
          .toList(growable: false),
      'poseImageLandmarks': normalized(result.poseLandmarks),
      'poseWorldLandmarks': world(result.poseWorldLandmarks),
      'leftHandImageLandmarks': normalized(result.leftHandLandmarks),
      'leftHandWorldLandmarks': world(result.leftHandWorldLandmarks),
      'rightHandImageLandmarks': normalized(result.rightHandLandmarks),
      'rightHandWorldLandmarks': world(result.rightHandWorldLandmarks),
      'previous': previous == null
          ? null
          : {
              'timestampMs': previous.timestampMs,
              'leftHandVisible': previous.leftHandVisible,
              'rightHandVisible': previous.rightHandVisible,
              'leftHandCoordinates': previous.leftHandCoordinates,
              'rightHandCoordinates': previous.rightHandCoordinates,
            },
      'flags': {
        'faceVisible': extracted.faceVisible,
        'poseVisible': extracted.poseVisible,
        'leftHandVisible': extracted.leftHandVisible,
        'rightHandVisible': extracted.rightHandVisible,
        'faceBlendshapesVisible': extracted.faceBlendshapesVisible,
      },
      'flutterFeatures': extracted.features,
      'featureCount': extracted.features.length,
    };
  }

  String encodeFrames(List<Map<String, Object?>> frames) =>
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': schemaVersion,
        'featureSchema': HolisticFeatureExtractor.featureSchema,
        'frames': frames,
      });
}

/// Bounded, timestamp-ordered temporal feature store. Time gaps and missing
/// detections remain explicit so an adapter can reject incomplete signing.
class TemporalFeatureBuffer {
  TemporalFeatureBuffer({this.capacity = 90, this.maxFrameGapMs = 250})
    : assert(capacity >= 2),
      assert(maxFrameGapMs > 0);

  final int capacity;
  final int maxFrameGapMs;
  final Queue<TemporalLandmarkFrame> _frames = Queue();
  List<TemporalLandmarkFrame> get frames => List.unmodifiable(_frames);
  int get length => _frames.length;
  TemporalLandmarkFrame? get latest => _frames.isEmpty ? null : _frames.last;

  bool add(TemporalLandmarkFrame frame) {
    final previous = latest;
    if (previous != null && frame.timestampMs <= previous.timestampMs) {
      return false;
    }
    if (previous != null &&
        frame.timestampMs - previous.timestampMs > maxFrameGapMs) {
      addMissing(previous.timestampMs + maxFrameGapMs);
    }
    _frames.add(frame);
    _trim();
    return true;
  }

  bool addMissing(int timestampMs) {
    final previous = latest;
    if (previous != null && timestampMs <= previous.timestampMs) return false;
    _frames.add(
      TemporalLandmarkFrame(
        timestampMs: timestampMs,
        features: const [],
        faceVisible: false,
        poseVisible: false,
        leftHandVisible: false,
        rightHandVisible: false,
        faceBlendshapesVisible: false,
        leftHandCoordinates: const [],
        rightHandCoordinates: const [],
        isMissing: true,
      ),
    );
    _trim();
    return true;
  }

  List<TemporalLandmarkFrame> window({int maxFrames = 64}) {
    if (maxFrames <= 0) throw ArgumentError.value(maxFrames, 'maxFrames');
    return List.unmodifiable(
      _frames.skip(math.max(0, _frames.length - maxFrames)),
    );
  }

  void clear() => _frames.clear();

  void _trim() {
    while (_frames.length > capacity) {
      _frames.removeFirst();
    }
  }
}

enum SigningSegmentStatus { complete, incomplete }

class SigningSegment {
  const SigningSegment({
    required this.frames,
    required this.status,
    required this.reason,
  });

  final List<TemporalLandmarkFrame> frames;
  final SigningSegmentStatus status;
  final String reason;
}

/// Groups active signing into an utterance-sized window using motion and a
/// silence boundary. This is a conservative boundary heuristic, not ASL
/// segmentation learned from data; the actual recognition model must validate
/// or replace these thresholds.
class AslActivitySegmenter {
  AslActivitySegmenter({
    this.motionThreshold = 0.004,
    this.silenceBoundaryMs = 450,
    this.minimumDurationMs = 350,
    this.maximumDurationMs = 8000,
  });

  final double motionThreshold;
  final int silenceBoundaryMs;
  final int minimumDurationMs;
  final int maximumDurationMs;
  final List<TemporalLandmarkFrame> _active = [];
  int? _lastMotionMs;
  bool get isActive => _active.isNotEmpty;

  SigningSegment? add(TemporalLandmarkFrame frame) {
    if (frame.isMissing || !frame.hasCoreSigningLandmarks) {
      if (_active.isEmpty) return null;
      _active.add(frame);
      return _finish(
        SigningSegmentStatus.incomplete,
        'Missing hand or body landmarks interrupted signing.',
      );
    }

    if (_active.isEmpty) {
      if (frame.motionEnergy < motionThreshold) {
        return null;
      }
      _active.add(frame);
      _lastMotionMs = frame.timestampMs;
      return null;
    }

    _active.add(frame);
    if (frame.motionEnergy >= motionThreshold) {
      _lastMotionMs = frame.timestampMs;
    }
    if (frame.timestampMs - _active.first.timestampMs > maximumDurationMs) {
      return _finish(
        SigningSegmentStatus.incomplete,
        'Signing exceeded the maximum segment duration.',
      );
    }
    final lastMotion = _lastMotionMs ?? frame.timestampMs;
    if (frame.timestampMs - lastMotion >= silenceBoundaryMs) {
      final duration = frame.timestampMs - _active.first.timestampMs;
      if (duration < minimumDurationMs) {
        return _finish(
          SigningSegmentStatus.incomplete,
          'Signing segment was too short.',
        );
      }
      return _finish(
        SigningSegmentStatus.complete,
        'Signing segment ended at a pause.',
      );
    }
    return null;
  }

  SigningSegment flushIncomplete(String reason) =>
      _finish(SigningSegmentStatus.incomplete, reason);

  void reset() {
    _active.clear();
    _lastMotionMs = null;
  }

  SigningSegment _finish(SigningSegmentStatus status, String reason) {
    final frames = List<TemporalLandmarkFrame>.unmodifiable(_active);
    reset();
    return SigningSegment(frames: frames, status: status, reason: reason);
  }
}

enum AslModelAvailability { ready, unavailable }

class AslRecognitionModelManifest {
  const AslRecognitionModelManifest({
    required this.availability,
    required this.task,
    required this.modelPath,
    required this.license,
    required this.inputFeatureDimension,
    required this.minimumFrames,
    required this.maximumFrames,
    required this.framesPerSecond,
    required this.requirements,
    required this.featureSchema,
    required this.signLanguage,
    required this.recognitionMode,
    required this.runtime,
    required this.offline,
    required this.confidenceCalibrated,
    required this.weightsSha256,
  });

  final AslModelAvailability availability;
  final String task;
  final String? modelPath;
  final String? license;
  final int inputFeatureDimension;
  final int minimumFrames;
  final int maximumFrames;
  final int framesPerSecond;
  final List<String> requirements;
  final String featureSchema;
  final String signLanguage;
  final String recognitionMode;
  final String runtime;
  final bool offline;
  final bool confidenceCalibrated;
  final String? weightsSha256;

  /// Dimension equality alone is insufficient: channel ordering, normalization
  /// and derived features must also match the installed checkpoint contract.
  bool get isCompatibleWithPipeline =>
      availability == AslModelAvailability.ready &&
      task == 'continuous_asl_video_to_english' &&
      signLanguage == 'ASL' &&
      recognitionMode == 'continuous_sentence_translation' &&
      featureSchema == HolisticFeatureExtractor.featureSchema &&
      inputFeatureDimension == HolisticFeatureExtractor.featureDimension &&
      minimumFrames >= 1 &&
      maximumFrames >= minimumFrames &&
      framesPerSecond > 0 &&
      offline &&
      confidenceCalibrated &&
      (runtime == 'onnxruntime_flutter' || runtime == 'tflite_flutter') &&
      modelPath != null &&
      license != null &&
      weightsSha256 != null &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(weightsSha256!);

  static Future<AslRecognitionModelManifest> load() async =>
      AslRecognitionModelManifest.fromJson(
        await rootBundle.loadString('assets/models/asl_recognition.json'),
      );

  factory AslRecognitionModelManifest.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != 1 ||
        decoded['task'] != 'continuous_asl_video_to_english' ||
        decoded['input'] is! Map<String, dynamic> ||
        decoded['requirements'] is! List) {
      throw const FormatException('Invalid ASL recognition model manifest.');
    }
    final input = decoded['input'] as Map<String, dynamic>;
    final frames = input['frames'] as Map<String, dynamic>?;
    if (frames == null ||
        input['featureDimension'] is! int ||
        frames['minimum'] is! int ||
        frames['maximum'] is! int ||
        input['framesPerSecond'] is! int) {
      throw const FormatException('Invalid ASL recognition input contract.');
    }
    return AslRecognitionModelManifest(
      availability: decoded['availability'] == 'ready'
          ? AslModelAvailability.ready
          : AslModelAvailability.unavailable,
      task: decoded['task'] as String,
      modelPath: decoded['modelPath'] as String?,
      license: decoded['license'] as String?,
      inputFeatureDimension: input['featureDimension'] as int,
      minimumFrames: frames['minimum'] as int,
      maximumFrames: frames['maximum'] as int,
      framesPerSecond: input['framesPerSecond'] as int,
      requirements: List.unmodifiable(
        (decoded['requirements'] as List).whereType<String>(),
      ),
      featureSchema: input['featureSchema'] as String? ?? '',
      signLanguage: decoded['signLanguage'] as String? ?? '',
      recognitionMode: decoded['recognitionMode'] as String? ?? '',
      runtime: decoded['runtime'] as String? ?? '',
      offline: decoded['offline'] == true,
      confidenceCalibrated: decoded['confidenceCalibrated'] == true,
      weightsSha256: decoded['weightsSha256'] as String?,
    );
  }
}

class AslGlossPrediction {
  const AslGlossPrediction({required this.gloss, required this.confidence});
  final String gloss;
  final double confidence;
}

class AslModelHypothesis {
  const AslModelHypothesis({
    required this.glosses,
    required this.sentenceConfidence,
    required this.segmentComplete,
  });

  final List<AslGlossPrediction> glosses;
  final double sentenceConfidence;
  final bool segmentComplete;
}

class AslRecognitionModelOutput {
  const AslRecognitionModelOutput({
    required this.available,
    this.hypothesis,
    this.reason,
  });

  final bool available;
  final AslModelHypothesis? hypothesis;
  final String? reason;
}

/// Contract for a locally installed temporal ASL model. Adapters must return
/// model-produced confidence values and must never synthesize predictions.
abstract interface class AslContinuousRecognitionModel {
  AslRecognitionModelManifest get manifest;

  Future<AslRecognitionModelOutput> infer(List<TemporalLandmarkFrame> frames);
}

class UnavailableAslRecognitionModel implements AslContinuousRecognitionModel {
  const UnavailableAslRecognitionModel(this.manifest);

  @override
  final AslRecognitionModelManifest manifest;

  @override
  Future<AslRecognitionModelOutput> infer(
    List<TemporalLandmarkFrame> frames,
  ) async => const AslRecognitionModelOutput(
    available: false,
    reason: 'No compatible continuous-ASL model weights are installed.',
  );
}

enum AslDecodeStatus {
  accepted,
  modelUnavailable,
  incompleteSigning,
  noGlosses,
  lowConfidence,
  unknownGloss,
  unsupportedSequence,
}

class ReviewedAslSentence {
  const ReviewedAslSentence({
    required this.glossSequence,
    required this.englishSentence,
    required this.reviewId,
  });

  final List<String> glossSequence;
  final String englishSentence;
  final String reviewId;
}

class AslEnglishDecodeResult {
  const AslEnglishDecodeResult({
    required this.status,
    required this.predictedGlosses,
    required this.message,
    this.englishSentence,
    this.confidence,
    this.reviewId,
  });

  final AslDecodeStatus status;
  final List<String> predictedGlosses;
  final String? englishSentence;
  final double? confidence;
  final String? reviewId;
  final String message;
}

/// Converts only a whole, reviewed gloss sequence into English. It does not
/// assemble English by concatenating gloss labels or calling an LLM.
class AslSentenceDecoder {
  const AslSentenceDecoder({
    this.minimumTokenConfidence = 0.70,
    this.minimumSentenceConfidence = 0.75,
  });

  final double minimumTokenConfidence;
  final double minimumSentenceConfidence;

  AslEnglishDecodeResult decode({
    required AslModelHypothesis? hypothesis,
    required bool modelAvailable,
    required Set<String> knownGlosses,
    required List<ReviewedAslSentence> reviewedSentences,
  }) {
    if (!modelAvailable || hypothesis == null) {
      return _rejected(
        AslDecodeStatus.modelUnavailable,
        'Continuous ASL recognition is unavailable; no English words were produced.',
      );
    }
    if (hypothesis.glosses.any((item) => item.gloss.trim().isEmpty)) {
      return _rejected(
        AslDecodeStatus.noGlosses,
        'The model returned an empty sign token; sentence output was withheld.',
      );
    }
    final tokens = hypothesis.glosses
        .map((item) => item.gloss.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList();
    if (!hypothesis.segmentComplete) {
      return _rejected(
        AslDecodeStatus.incompleteSigning,
        'Signing segment was incomplete; sentence output was withheld.',
        tokens: tokens,
      );
    }
    if (tokens.isEmpty) {
      return _rejected(
        AslDecodeStatus.noGlosses,
        'No sign sequence was recognized.',
      );
    }
    if (hypothesis.glosses.any(
          (item) =>
              !item.confidence.isFinite ||
              item.confidence < minimumTokenConfidence ||
              item.confidence > 1,
        ) ||
        !hypothesis.sentenceConfidence.isFinite ||
        hypothesis.sentenceConfidence < minimumSentenceConfidence ||
        hypothesis.sentenceConfidence > 1) {
      return _rejected(
        AslDecodeStatus.lowConfidence,
        'Recognition confidence is below the sentence threshold; sentence output was withheld.',
        tokens: tokens,
        confidence: hypothesis.sentenceConfidence.isFinite
            ? hypothesis.sentenceConfidence
            : null,
      );
    }
    final normalizedKnownGlosses = knownGlosses
        .map((token) => token.toUpperCase())
        .toSet();
    final unknown = tokens.where(
      (token) => !normalizedKnownGlosses.contains(token),
    );
    if (unknown.isNotEmpty) {
      return _rejected(
        AslDecodeStatus.unknownGloss,
        'Unknown sign labels were detected; sentence output was withheld.',
        tokens: tokens,
        confidence: hypothesis.sentenceConfidence,
      );
    }
    final reviewed = reviewedSentences.where(
      (sentence) =>
          sentence.englishSentence.trim().isNotEmpty &&
          sentence.reviewId.trim().isNotEmpty &&
          sentence.glossSequence.isNotEmpty &&
          _sameSequence(sentence.glossSequence, tokens),
    );
    if (reviewed.length != 1) {
      return _rejected(
        AslDecodeStatus.unsupportedSequence,
        'The complete gloss sequence has no unique reviewed English sentence.',
        tokens: tokens,
        confidence: hypothesis.sentenceConfidence,
      );
    }
    final sentence = reviewed.single;
    return AslEnglishDecodeResult(
      status: AslDecodeStatus.accepted,
      predictedGlosses: List.unmodifiable(tokens),
      englishSentence: sentence.englishSentence,
      confidence: hypothesis.sentenceConfidence,
      reviewId: sentence.reviewId,
      message: 'Complete reviewed sentence recognized.',
    );
  }

  bool _sameSequence(List<String> expected, List<String> actual) =>
      expected.length == actual.length &&
      List.generate(
        expected.length,
        (index) => index,
      ).every((index) => expected[index].toUpperCase() == actual[index]);

  AslEnglishDecodeResult _rejected(
    AslDecodeStatus status,
    String message, {
    List<String> tokens = const [],
    double? confidence,
  }) => AslEnglishDecodeResult(
    status: status,
    predictedGlosses: List.unmodifiable(tokens),
    confidence: confidence,
    message: message,
  );
}

class AslRecognitionPipeline {
  AslRecognitionPipeline({
    required this.model,
    required this.decoder,
    required this.knownGlosses,
    required this.reviewedSentences,
    TemporalFeatureBuffer? buffer,
    HolisticFeatureExtractor? extractor,
    AslActivitySegmenter? segmenter,
  }) : buffer = buffer ?? TemporalFeatureBuffer(),
       extractor = extractor ?? const HolisticFeatureExtractor(),
       segmenter = segmenter ?? AslActivitySegmenter();

  final AslContinuousRecognitionModel model;
  final AslSentenceDecoder decoder;
  final Set<String> knownGlosses;
  final List<ReviewedAslSentence> reviewedSentences;
  final TemporalFeatureBuffer buffer;
  final HolisticFeatureExtractor extractor;
  final AslActivitySegmenter segmenter;

  Future<AslEnglishDecodeResult> addLandmarks(
    HolisticLandmarkerResult result, {
    required int timestampMs,
  }) async {
    final previous = buffer.latest;
    if (previous != null &&
        timestampMs - previous.timestampMs > buffer.maxFrameGapMs) {
      final missingAt = previous.timestampMs + buffer.maxFrameGapMs;
      buffer.addMissing(missingAt);
      final missing = buffer.latest!;
      segmenter.add(missing);
      final afterGap = extractor.extract(
        result,
        timestampMs: timestampMs,
        previous: missing,
      );
      buffer.add(afterGap);
      segmenter.add(afterGap);
      return _incomplete('Camera frame gap interrupted the signing segment.');
    }
    final frame = extractor.extract(
      result,
      timestampMs: timestampMs,
      previous: buffer.latest,
    );
    if (!buffer.add(frame)) {
      return decoder.decode(
        hypothesis: null,
        modelAvailable: false,
        knownGlosses: knownGlosses,
        reviewedSentences: reviewedSentences,
      );
    }
    final segment = segmenter.add(frame);
    if (segment == null) {
      return _incomplete('Collecting a complete signing segment.');
    }
    if (segment.status == SigningSegmentStatus.incomplete) {
      return _incomplete(segment.reason);
    }
    final window = segment.frames.length <= model.manifest.maximumFrames
        ? segment.frames
        : segment.frames.sublist(
            segment.frames.length - model.manifest.maximumFrames,
          );
    if (window.length < model.manifest.minimumFrames ||
        window.any((item) => item.isMissing || !item.hasCoreSigningLandmarks)) {
      return _incomplete('Signing segment has missing or insufficient frames.');
    }
    if (!model.manifest.isCompatibleWithPipeline) {
      return decoder.decode(
        hypothesis: null,
        modelAvailable: false,
        knownGlosses: knownGlosses,
        reviewedSentences: reviewedSentences,
      );
    }
    final output = await model.infer(window);
    return decoder.decode(
      hypothesis: output.hypothesis,
      modelAvailable: output.available,
      knownGlosses: knownGlosses,
      reviewedSentences: reviewedSentences,
    );
  }

  AslEnglishDecodeResult _incomplete(String message) => AslEnglishDecodeResult(
    status: AslDecodeStatus.incompleteSigning,
    predictedGlosses: const [],
    message: message,
  );
}
