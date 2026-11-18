import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:sign_talk/features/camera/asl_recognition_pipeline.dart';

TemporalLandmarkFrame _frame(
  int timestamp, {
  double motion = 0,
  bool hands = true,
  bool missing = false,
}) => TemporalLandmarkFrame(
  timestampMs: timestamp,
  features: const [0, 1, 2],
  leftHandCoordinates: hands ? const [0, 0, 0] : const [],
  rightHandCoordinates: hands ? const [0, 0, 0] : const [],
  motionEnergy: motion,
  faceVisible: true,
  poseVisible: true,
  leftHandVisible: hands,
  rightHandVisible: hands,
  faceBlendshapesVisible: true,
  isMissing: missing,
);

HolisticLandmarkerResult _holisticResult({double shift = 0}) {
  final face = List.generate(
    478,
    (index) => NormalizedLandmark(
      x: (index % 20) / 20 + shift,
      y: (index % 17) / 17,
      z: 0,
      visibility: 1,
    ),
  );
  final pose = List.generate(
    33,
    (index) =>
        NormalizedLandmark(x: index / 100, y: index / 100, z: 0, visibility: 1),
  );
  final poseWorld = List.generate(
    33,
    (index) => Landmark(x: index / 100, y: index / 100, z: 0, visibility: 1),
  );
  final hand = List.generate(
    21,
    (index) => NormalizedLandmark(
      x: (index % 5) / 10 + shift,
      y: (index ~/ 5) / 10,
      z: 0,
      visibility: 1,
    ),
  );
  final handWorld = List.generate(
    21,
    (index) => Landmark(
      x: (index % 5) / 10 + shift,
      y: (index ~/ 5) / 10,
      z: 0,
      visibility: 1,
    ),
  );
  return HolisticLandmarkerResult(
    faceLandmarks: face,
    poseLandmarks: pose,
    poseWorldLandmarks: poseWorld,
    leftHandLandmarks: hand,
    rightHandLandmarks: hand,
    leftHandWorldLandmarks: handWorld,
    rightHandWorldLandmarks: handWorld,
    faceBlendshapes: [
      const MediaPipeCategory(
        index: 0,
        score: 0.8,
        categoryName: 'browDownLeft',
      ),
    ],
    imageWidth: 640,
    imageHeight: 480,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converts BGRA camera pixels to RGBA with opaque alpha', () {
    final pixels = CameraFramePreprocessor.bgraToRgba(
      bytes: Uint8List.fromList([3, 2, 1, 0]),
      width: 1,
      height: 1,
      bytesPerRow: 4,
    );
    expect(pixels, [1, 2, 3, 255]);
  });

  test('converts a YUV420 camera frame to an RGBA buffer', () {
    final pixels = CameraFramePreprocessor.yuv420ToRgba(
      width: 2,
      height: 2,
      y: CameraPixelPlane(
        bytes: Uint8List.fromList([16, 16, 16, 16]),
        bytesPerRow: 2,
      ),
      u: CameraPixelPlane(bytes: Uint8List.fromList([128]), bytesPerRow: 1),
      v: CameraPixelPlane(bytes: Uint8List.fromList([128]), bytesPerRow: 1),
    );
    expect(pixels.length, 16);
    expect(pixels, [0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255]);
  });

  test('accepts Android YUV planes without unused trailing row padding', () {
    final pixels = CameraFramePreprocessor.yuv420ToRgba(
      width: 2,
      height: 2,
      y: CameraPixelPlane(
        bytes: Uint8List.fromList([16, 16, 99, 99, 16, 16]),
        bytesPerRow: 4,
      ),
      u: CameraPixelPlane(bytes: Uint8List.fromList([128]), bytesPerRow: 2),
      v: CameraPixelPlane(bytes: Uint8List.fromList([128]), bytesPerRow: 2),
    );
    expect(pixels, [0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255]);
  });

  test('honors pixel stride for interleaved Android chroma planes', () {
    final pixels = CameraFramePreprocessor.yuv420ToRgba(
      width: 4,
      height: 2,
      y: CameraPixelPlane(
        bytes: Uint8List.fromList(List.filled(8, 16)),
        bytesPerRow: 4,
      ),
      u: CameraPixelPlane(
        bytes: Uint8List.fromList([128, 200, 128]),
        bytesPerRow: 4,
        bytesPerPixel: 2,
      ),
      v: CameraPixelPlane(
        bytes: Uint8List.fromList([128, 200, 128]),
        bytesPerRow: 4,
        bytesPerPixel: 2,
      ),
    );
    expect(pixels.length, 4 * 2 * 4);
    expect(pixels.every((value) => value == 0 || value == 255), isTrue);
  });

  test(
    'feature extraction includes both hands, body, face and blendshapes',
    () {
      final frame = const HolisticFeatureExtractor().extract(
        _holisticResult(),
        timestampMs: 10,
      );
      expect(frame.features.length, HolisticFeatureExtractor.featureDimension);
      expect(frame.features.length, 2582);
      expect(frame.faceVisible, isTrue);
      expect(frame.poseVisible, isTrue);
      expect(frame.bothHandsVisible, isTrue);
      expect(frame.faceBlendshapesVisible, isTrue);
      expect(frame.leftHandCoordinates.length, 63);
      expect(frame.leftHandOrientation.length, 6);
      expect(frame.rightHandOrientation.length, 6);
    },
  );

  test('raw exporter serializes MediaPipe inputs and final schema vector', () {
    final result = const HolisticRawFrameExporter().frameToJson(
      _holisticResult(),
      timestampMs: 1234,
    );
    expect(result['schemaVersion'], HolisticRawFrameExporter.schemaVersion);
    expect(result['featureSchema'], HolisticFeatureExtractor.featureSchema);
    expect(result['timestampMs'], 1234);
    expect((result['faceLandmarks'] as List).length, 478);
    expect((result['faceBlendshapes'] as List).first['name'], 'browDownLeft');
    expect((result['flutterFeatures'] as List).length, 2582);
    expect(result['featureCount'], 2582);
    final json = const HolisticRawFrameExporter().encodeFrames([result]);
    expect(jsonDecode(json)['frames'], hasLength(1));
  });

  test(
    'temporal buffer keeps bounded ordered frames and records missing frames',
    () {
      final buffer = TemporalFeatureBuffer(capacity: 4, maxFrameGapMs: 100);
      expect(buffer.add(_frame(0)), isTrue);
      expect(buffer.add(_frame(33)), isTrue);
      expect(buffer.addMissing(66), isTrue);
      expect(buffer.frames.last.isMissing, isTrue);
      expect(buffer.add(_frame(50)), isFalse);
      buffer.add(_frame(99));
      buffer.add(_frame(132));
      buffer.add(_frame(165));
      expect(buffer.length, 4);
      expect(buffer.window(maxFrames: 2).length, 2);
    },
  );

  test('large frame gaps become explicit missing-frame markers', () {
    final buffer = TemporalFeatureBuffer(capacity: 8, maxFrameGapMs: 100);
    buffer.add(_frame(0));
    buffer.add(_frame(250));
    expect(buffer.frames.any((frame) => frame.isMissing), isTrue);
  });

  test('activity segmenter rejects interrupted or incomplete signing', () {
    final segmenter = AslActivitySegmenter(
      motionThreshold: 0.01,
      silenceBoundaryMs: 300,
      minimumDurationMs: 150,
    );
    expect(segmenter.add(_frame(0, motion: 0.02)), isNull);
    expect(segmenter.add(_frame(80, motion: 0.03)), isNull);
    final interrupted = segmenter.add(_frame(100, hands: false));
    expect(interrupted?.status, SigningSegmentStatus.incomplete);
  });

  test(
    'decoder withholds incomplete, low-confidence and unknown sequences',
    () {
      const decoder = AslSentenceDecoder();
      const reviewed = [
        ReviewedAslSentence(
          glossSequence: ['HELLO', 'YOU'],
          englishSentence: 'Hello. How are you?',
          reviewId: 'review-1',
        ),
      ];
      AslModelHypothesis hypothesis(
        List<AslGlossPrediction> glosses, {
        double confidence = 0.9,
        bool complete = true,
      }) => AslModelHypothesis(
        glosses: glosses,
        sentenceConfidence: confidence,
        segmentComplete: complete,
      );

      final accepted = decoder.decode(
        hypothesis: hypothesis(const [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.92),
          AslGlossPrediction(gloss: 'YOU', confidence: 0.88),
        ]),
        modelAvailable: true,
        knownGlosses: {'HELLO', 'YOU'},
        reviewedSentences: reviewed,
      );
      expect(accepted.status, AslDecodeStatus.accepted);
      expect(accepted.englishSentence, 'Hello. How are you?');
      expect(accepted.confidence, 0.9);

      final incomplete = decoder.decode(
        hypothesis: hypothesis(const [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.9),
        ], complete: false),
        modelAvailable: true,
        knownGlosses: {'HELLO'},
        reviewedSentences: reviewed,
      );
      expect(incomplete.status, AslDecodeStatus.incompleteSigning);
      expect(incomplete.englishSentence, isNull);

      final lowConfidence = decoder.decode(
        hypothesis: hypothesis(const [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.95),
          AslGlossPrediction(gloss: 'YOU', confidence: 0.4),
        ]),
        modelAvailable: true,
        knownGlosses: {'HELLO', 'YOU'},
        reviewedSentences: reviewed,
      );
      expect(lowConfidence.status, AslDecodeStatus.lowConfidence);
      expect(lowConfidence.englishSentence, isNull);

      final unknown = decoder.decode(
        hypothesis: hypothesis(const [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.9),
          AslGlossPrediction(gloss: 'ALIEN', confidence: 0.9),
        ]),
        modelAvailable: true,
        knownGlosses: {'HELLO'},
        reviewedSentences: reviewed,
      );
      expect(unknown.status, AslDecodeStatus.unknownGloss);
      expect(unknown.englishSentence, isNull);

      final blankToken = decoder.decode(
        hypothesis: hypothesis(const [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.9),
          AslGlossPrediction(gloss: '', confidence: 0.9),
        ]),
        modelAvailable: true,
        knownGlosses: {'HELLO'},
        reviewedSentences: reviewed,
      );
      expect(blankToken.status, AslDecodeStatus.noGlosses);
      expect(blankToken.englishSentence, isNull);
    },
  );

  test('unknown complete sequences are never assembled from gloss words', () {
    const decoder = AslSentenceDecoder();
    final output = decoder.decode(
      hypothesis: const AslModelHypothesis(
        glosses: [
          AslGlossPrediction(gloss: 'HELLO', confidence: 0.9),
          AslGlossPrediction(gloss: 'HELP', confidence: 0.9),
        ],
        sentenceConfidence: 0.9,
        segmentComplete: true,
      ),
      modelAvailable: true,
      knownGlosses: {'HELLO', 'HELP'},
      reviewedSentences: const [],
    );
    expect(output.status, AslDecodeStatus.unsupportedSequence);
    expect(output.englishSentence, isNull);
  });

  test(
    'offline model manifest loads as unavailable and never predicts',
    () async {
      final manifest = await AslRecognitionModelManifest.load();
      expect(manifest.availability, AslModelAvailability.unavailable);
      expect(manifest.modelPath, isNull);
      expect(manifest.inputFeatureDimension, 2582);
      expect(manifest.featureSchema, HolisticFeatureExtractor.featureSchema);
      expect(manifest.isCompatibleWithPipeline, isFalse);
      final output = await UnavailableAslRecognitionModel(manifest)
          .infer([_frame(0)]);
      expect(output.available, isFalse);
      expect(output.hypothesis, isNull);
    },
  );

  test('same-width model with a different feature schema is rejected', () {
    final manifest = AslRecognitionModelManifest.fromJson(
      jsonEncode({
        'schemaVersion': 1,
        'task': 'continuous_asl_video_to_english',
        'signLanguage': 'ASL',
        'recognitionMode': 'continuous_sentence_translation',
        'availability': 'ready',
        'modelPath': 'models/checkpoint.tflite',
        'license': 'Apache-2.0',
        'runtime': 'tflite_flutter',
        'offline': true,
        'confidenceCalibrated': true,
        'weightsSha256': 'a' * 64,
        'input': {
          'featureSchema': 'unrelated.same-width.features.v1',
          'featureDimension': HolisticFeatureExtractor.featureDimension,
          'frames': {'minimum': 8, 'maximum': 64},
          'framesPerSecond': 30,
        },
        'requirements': <String>[],
      }),
    );
    expect(
      manifest.inputFeatureDimension,
      HolisticFeatureExtractor.featureDimension,
    );
    expect(manifest.isCompatibleWithPipeline, isFalse);
  });

  test(
    'offline pipeline tracks frames but does not fabricate an English sentence',
    () async {
      final manifest = await AslRecognitionModelManifest.load();
      final pipeline = AslRecognitionPipeline(
        model: UnavailableAslRecognitionModel(manifest),
        decoder: const AslSentenceDecoder(),
        knownGlosses: const {},
        reviewedSentences: const [],
      );
      var result = await pipeline.addLandmarks(
        _holisticResult(),
        timestampMs: 0,
      );
      for (var frame = 1; frame < 20; frame++) {
        final shift = frame < 7 ? frame * 0.01 : 0.06;
        result = await pipeline.addLandmarks(
          _holisticResult(shift: shift),
          timestampMs: frame * 50,
        );
      }
      expect(result.status, isNot(AslDecodeStatus.accepted));
      expect(result.englishSentence, isNull);
      expect(result.confidence, isNull);
    },
  );
}
