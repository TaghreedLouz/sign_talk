import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import 'asl_recognition_pipeline.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _camera;
  HolisticLandmarker? _landmarker;
  StreamSubscription<HolisticLandmarkerResult>? _resultSubscription;
  final Stopwatch _clock = Stopwatch();
  AslRecognitionPipeline? _recognitionPipeline;

  bool _loading = true;
  final bool _processingEnabled = true;
  String? _error;
  String _status = 'Preparing camera and on-device tracking…';
  String _transcript = 'No English transcript: ASL model unavailable.';
  String _translationState = 'MODEL UNAVAILABLE';
  String? _recognizedGlosses;
  double? _recognitionConfidence;
  int _frames = 0;
  int _faceCount = 0;
  int _poseCount = 0;
  int _leftCount = 0;
  int _rightCount = 0;
  int _faceBlendshapeCount = 0;
  int _lastTimestamp = -1;
  bool _captureParity = false;
  final List<Map<String, Object?>> _parityFrames = [];
  List<Offset> _leftHand = const [];
  List<Offset> _rightHand = const [];
  List<Offset> _pose = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found.');
      }
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _landmarker = await HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          model: VisionModels.holisticLandmarker,
          runningMode: RunningMode.liveStream,
          outputFaceBlendshapes: true,
        ),
      );
      _recognitionPipeline = await _loadRecognitionPipeline();

      // MediaPipe requires the result listener before the first frame.
      _resultSubscription = _landmarker!.results.listen(
        _onLandmarks,
        onError: (Object error) {
          if (mounted) setState(() => _status = 'Tracking error: $error');
        },
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _clock.start();
      await controller.startImageStream(_processFrame);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status =
            'Camera active. Keep your face, upper body and both hands visible.';
      });
    } catch (error) {
      await _disposeResources();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _status = 'Could not initialize camera tracking.';
      });
    }
  }

  Future<AslRecognitionPipeline> _loadRecognitionPipeline() async {
    AslRecognitionModelManifest manifest;
    try {
      manifest = await AslRecognitionModelManifest.load();
    } catch (_) {
      manifest = AslRecognitionModelManifest.fromJson('''
        {"schemaVersion":1,"task":"continuous_asl_video_to_english","availability":"unavailable","modelPath":null,"license":null,"input":{"featureDimension":2582,"frames":{"minimum":8,"maximum":64},"framesPerSecond":30},"requirements":[]}
      ''');
    }
    return AslRecognitionPipeline(
      model: UnavailableAslRecognitionModel(manifest),
      decoder: const AslSentenceDecoder(),
      knownGlosses: const {},
      reviewedSentences: const [],
    );
  }

  void _processFrame(CameraImage image) {
    final task = _landmarker;
    if (task == null || !_processingEnabled || !mounted) return;
    try {
      final rgba = CameraFramePreprocessor.fromCameraImage(image);
      final now = _clock.elapsedMilliseconds;
      _lastTimestamp = now > _lastTimestamp ? now : _lastTimestamp + 1;
      task.detectAsync(
        VisionImage.fromPixels(
          pixels: rgba,
          width: image.width,
          height: image.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: _lastTimestamp,
        rotationDegrees: _camera?.description.sensorOrientation ?? 0,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not process camera frame: $error');
      }
    }
  }

  void _onLandmarks(HolisticLandmarkerResult result) {
    if (!mounted) return;
    if (kDebugMode && _captureParity) {
      final pipeline = _recognitionPipeline;
      if (pipeline != null) {
        _parityFrames.add(
          const HolisticRawFrameExporter().frameToJson(
            result,
            timestampMs:
                result.timestampMilliseconds ?? _clock.elapsedMilliseconds,
            previous: pipeline.buffer.latest,
          ),
        );
        if (_parityFrames.length >= 60) unawaited(_saveParityCapture());
      }
    }
    final left = result.leftHandLandmarks
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
    final right = result.rightHandLandmarks
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
    final pose = result.poseLandmarks
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
    setState(() {
      _frames++;
      _faceCount = result.faceLandmarks.length;
      _faceBlendshapeCount = result.faceBlendshapes?.length ?? 0;
      _poseCount = pose.length;
      _leftCount = left.length;
      _rightCount = right.length;
      _leftHand = left;
      _rightHand = right;
      _pose = pose;
      _status = left.isNotEmpty || right.isNotEmpty
          ? 'Hands detected. Keep signing inside the frame.'
          : 'Show both hands clearly inside the camera frame.';
    });
    unawaited(
      _processRecognitionResult(
        result,
        result.timestampMilliseconds ?? _clock.elapsedMilliseconds,
      ),
    );
  }

  Future<void> _saveParityCapture() async {
    if (!kDebugMode || !_captureParity || _parityFrames.isEmpty) return;
    _captureParity = false;
    final frames = List<Map<String, Object?>>.of(_parityFrames);
    _parityFrames.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/signtalk_flutter_parity.json');
      await file.writeAsString(
        const HolisticRawFrameExporter().encodeFrames(frames),
        flush: true,
      );
      if (mounted) {
        setState(() => _status = 'Parity fixture saved: ${file.path}');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Parity export failed: $error');
    }
  }

  Future<void> _processRecognitionResult(
    HolisticLandmarkerResult result,
    int timestamp,
  ) async {
    final pipeline = _recognitionPipeline;
    if (pipeline == null) return;
    final decoded = await pipeline.addLandmarks(result, timestampMs: timestamp);
    if (!mounted) return;
    setState(() {
      _translationState = switch (decoded.status) {
        AslDecodeStatus.accepted => 'REVIEWED SENTENCE',
        AslDecodeStatus.modelUnavailable => 'MODEL UNAVAILABLE',
        AslDecodeStatus.incompleteSigning => 'COLLECTING / INCOMPLETE',
        AslDecodeStatus.noGlosses => 'NO SIGNS DETECTED',
        AslDecodeStatus.lowConfidence => 'NOT SURE',
        AslDecodeStatus.unknownGloss => 'UNKNOWN SIGN',
        AslDecodeStatus.unsupportedSequence => 'UNSUPPORTED SEQUENCE',
      };
      _transcript = decoded.englishSentence ?? decoded.message;
      _recognizedGlosses = decoded.predictedGlosses.isEmpty
          ? null
          : decoded.predictedGlosses.join(' ');
      _recognitionConfidence = decoded.confidence;
    });
  }

  Future<void> _disposeResources() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } catch (_) {}
      await camera.dispose();
    }
    final task = _landmarker;
    _landmarker = null;
    if (task != null) {
      await task.dispose();
      await _resultSubscription?.cancel();
      _resultSubscription = null;
    }
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign to Text')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not start camera tracking:\n$_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: camera!.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(camera),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _LandmarkPainter(
                              leftHand: _leftHand,
                              rightHand: _rightHand,
                              pose: _pose,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _StatusPill(
                            label: 'LIVE CAMERA',
                            color: Colors.black.withValues(alpha: .65),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _StatusPill(
                            label: '$_frames frames',
                            color: Colors.black.withValues(alpha: .65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _status,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (kDebugMode)
                  TextButton.icon(
                    onPressed: _captureParity
                        ? _saveParityCapture
                        : () => setState(() {
                            _parityFrames.clear();
                            _captureParity = true;
                            _status = 'Capturing 60 consecutive raw frames…';
                          }),
                    icon: Icon(
                      _captureParity ? Icons.save : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      _captureParity
                          ? 'Stop and save fixture'
                          : 'Capture parity fixture (debug)',
                    ),
                  ),
                const SizedBox(height: 14),
                _TranscriptPanel(
                  transcript: _transcript,
                  state: _translationState,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Live body tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(label: 'Face', count: _faceCount),
                    _CountChip(label: 'Pose', count: _poseCount),
                    _CountChip(label: 'Left hand', count: _leftCount),
                    _CountChip(label: 'Right hand', count: _rightCount),
                    _CountChip(
                      label: 'Face blendshapes',
                      count: _faceBlendshapeCount,
                    ),
                  ],
                ),
                if (_recognizedGlosses != null ||
                    _recognitionConfidence != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Candidate glosses: ${_recognizedGlosses ?? '—'}'
                      '${_recognitionConfidence == null ? '' : ' · model confidence ${(_recognitionConfidence! * 100).toStringAsFixed(1)}%'}',
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'MediaPipe tracks both hands, face blendshapes, and body landmarks. No continuous ASL model or reviewed sentence decoder is installed, so English output remains unavailable. No words or confidence scores are fabricated.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF79521B),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({required this.transcript, required this.state});
  final String transcript;
  final String state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppConstants.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'English transcript',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            _StatusPill(
              label: state,
              color: const Color(0xFFEAF2FF),
              textColor: AppConstants.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          transcript,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppConstants.muted,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Uncertain words will be marked when the ASL translation model is connected.',
          style: TextStyle(fontSize: 11, color: AppConstants.muted),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });
  final String label;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(
      Icons.check_circle_outline,
      size: 16,
      color: AppConstants.secondary,
    ),
    label: Text('$label  $count'),
    backgroundColor: Colors.white,
    side: const BorderSide(color: AppConstants.border),
  );
}

class _LandmarkPainter extends CustomPainter {
  const _LandmarkPainter({
    required this.leftHand,
    required this.rightHand,
    required this.pose,
  });
  final List<Offset> leftHand;
  final List<Offset> rightHand;
  final List<Offset> pose;
  static const List<List<int>> _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    _drawHand(canvas, size, leftHand, Colors.cyanAccent);
    _drawHand(canvas, size, rightHand, Colors.orangeAccent);
    final paint = Paint()..color = Colors.white;
    for (final point in pose) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        2.2,
        paint,
      );
    }
  }

  void _drawHand(Canvas canvas, Size size, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    for (final edge in _connections) {
      if (edge[0] >= points.length || edge[1] >= points.length) {
        continue;
      }
      canvas.drawLine(
        Offset(
          points[edge[0]].dx * size.width,
          points[edge[0]].dy * size.height,
        ),
        Offset(
          points[edge[1]].dx * size.width,
          points[edge[1]].dy * size.height,
        ),
        line,
      );
    }
    for (final p in points) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter old) =>
      old.leftHand != leftHand ||
      old.rightHand != rightHand ||
      old.pose != pose;
}
