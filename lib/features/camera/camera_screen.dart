import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import 'asl_recognition_pipeline.dart';
import 'video_frame_processor.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  HolisticLandmarker? _landmarker;
  HolisticLandmarker? _videoLandmarker;
  StreamSubscription<HolisticLandmarkerResult>? _resultSubscription;
  final Stopwatch _clock = Stopwatch();
  AslRecognitionPipeline? _recognitionPipeline;
  Future<void> _recognitionQueue = Future<void>.value();

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
  int _droppedFrames = 0;
  int _lastTimestamp = -1;
  bool _cameraSwitching = false;
  bool _showLandmarks = true;
  bool _transcriptCleared = false;
  bool _isVideoProcessing = false;
  bool _cancelVideo = false;
  int _videoFramesProcessed = 0;
  int _videoFramesTotal = 0;
  String? _videoMessage;
  bool _captureParity = false;
  final List<Map<String, Object?>> _parityFrames = [];
  List<Offset> _leftHand = const [];
  List<Offset> _rightHand = const [];
  List<Offset> _pose = const [];
  List<Offset> _face = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _cameraSwitching = false;
      });
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found.');
      }
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

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
          if (mounted) {
            setState(
              () => _status = 'MediaPipe stopped after an error: $error',
            );
          }
        },
      );

      _clock.start();
      await _startCamera(_cameras[_cameraIndex]);
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

  Future<void> _startCamera(CameraDescription description) async {
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      await controller.startImageStream(_processFrame);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cameraSwitching = false;
        _error = null;
        _status =
            'Camera active. Keep your face, upper body and both hands visible.';
      });
    } catch (_) {
      if (identical(_camera, controller)) _camera = null;
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameraSwitching || _isVideoProcessing || _cameras.length < 2) return;
    setState(() {
      _cameraSwitching = true;
      _status = 'Switching camera…';
    });
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      final current = _camera;
      _camera = null;
      if (current != null) {
        if (current.value.isStreamingImages) await current.stopImageStream();
        await current.dispose();
      }
      await _startCamera(_cameras[_cameraIndex]);
    } catch (error) {
      if (mounted) {
        setState(() {
          _cameraSwitching = false;
          _error = error.toString();
          _status = 'Could not switch camera.';
        });
      }
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
    if (task == null || !_processingEnabled || !mounted || _isVideoProcessing) {
      return;
    }
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
    final face = result.faceLandmarks
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
    setState(() {
      _frames++;
      _faceCount = face.length;
      _faceBlendshapeCount = result.faceBlendshapes?.length ?? 0;
      _poseCount = pose.length;
      _leftCount = left.length;
      _rightCount = right.length;
      _leftHand = left;
      _rightHand = right;
      _pose = pose;
      _face = face;
      _droppedFrames = _landmarker?.droppedFrames ?? 0;
      _status = left.isNotEmpty || right.isNotEmpty
          ? 'MediaPipe sees the hands. Continue signing inside the frame.'
          : pose.isNotEmpty || face.isNotEmpty
          ? 'MediaPipe sees the face/body. Show both hands clearly in frame.'
          : 'MediaPipe is receiving frames; keep face, upper body and hands visible.';
    });
    _enqueueRecognitionResult(
      result,
      result.timestampMilliseconds ?? _clock.elapsedMilliseconds,
    );
  }

  void _enqueueRecognitionResult(
    HolisticLandmarkerResult result,
    int timestamp,
  ) {
    _recognitionQueue = _recognitionQueue
        .then((_) => _processRecognitionResult(result, timestamp))
        .catchError((Object error) {
          if (mounted) {
            setState(() => _status = 'Recognition pipeline error: $error');
          }
        });
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
    _applyDecodeResult(decoded);
  }

  void _applyDecodeResult(AslEnglishDecodeResult decoded) {
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
      if (decoded.englishSentence != null) {
        _transcript = decoded.englishSentence!;
        _transcriptCleared = false;
      } else if (!_transcriptCleared) {
        _transcript = decoded.message;
      }
      _recognizedGlosses = decoded.predictedGlosses.isEmpty
          ? null
          : decoded.predictedGlosses.join(' ');
      _recognitionConfidence = decoded.confidence;
    });
  }

  Future<void> _pickAndAnalyzeVideo() async {
    if (_isVideoProcessing || _loading || _camera == null) return;
    try {
      final selected = await FilePicker.pickFile(type: FileType.video);
      if (selected == null) return;
      final path = selected.path;
      if (path == null || path.isEmpty) {
        throw StateError(
          'The selected video is not available as a local file.',
        );
      }

      final videoController = VideoPlayerController.file(File(path));
      late final int durationMs;
      try {
        await videoController.initialize();
        durationMs = videoController.value.duration.inMilliseconds;
      } finally {
        await videoController.dispose();
      }
      if (durationMs <= 0) {
        throw StateError('The selected video has no readable duration.');
      }

      final liveCamera = _camera;
      if (liveCamera?.value.isStreamingImages == true) {
        await liveCamera!.stopImageStream();
      }
      if (!mounted) return;
      setState(() {
        _isVideoProcessing = true;
        _cancelVideo = false;
        _videoFramesProcessed = 0;
        _videoFramesTotal = VideoFrameProcessor.timestampsForDuration(
          durationMs,
        ).length;
        _videoMessage = 'Preparing offline MediaPipe video analysis…';
        _status = 'Analyzing ${selected.name} at timestamped video frames.';
      });

      final videoLandmarker = await HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          model: VisionModels.holisticLandmarker,
          runningMode: RunningMode.video,
          outputFaceBlendshapes: true,
        ),
      );
      _videoLandmarker = videoLandmarker;
      final videoPipeline = await _loadRecognitionPipeline();
      final processor = VideoFrameProcessor();
      final summary = await processor.process(
        path: path,
        durationMs: durationMs,
        isCancelled: () => _cancelVideo || !mounted,
        onProgress: (processed, total) {
          if (!mounted) return;
          setState(() {
            _videoFramesProcessed = processed;
            _videoFramesTotal = total;
            _videoMessage =
                'Extracted and analyzed $processed of $total frames.';
          });
        },
        onFrame: (timestampMs, frame) async {
          if (_cancelVideo || !mounted) return;
          final result = await videoLandmarker.detectForVideo(
            VisionImage.fromPixels(
              pixels: frame.pixels,
              width: frame.width,
              height: frame.height,
              format: VisionPixelFormat.rgba,
            ),
            timestampMilliseconds: timestampMs,
          );
          if (!mounted) return;
          _updateTrackingFromResult(result, isVideo: true);
          final decoded = await videoPipeline.addLandmarks(
            result,
            timestampMs: timestampMs,
          );
          _applyDecodeResult(decoded);
        },
      );
      if (mounted) {
        setState(() {
          _videoFramesProcessed = summary.processedFrames;
          _videoMessage = summary.cancelled
              ? 'Video analysis stopped. No English sentence was produced.'
              : 'Processed ${summary.processedFrames} video frames. '
                    'English translation is unavailable because no ASL model is installed.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _videoMessage = 'Video analysis failed: $error';
          _status = 'Could not analyze the selected video.';
        });
      }
    } finally {
      final videoLandmarker = _videoLandmarker;
      _videoLandmarker = null;
      if (videoLandmarker != null) await videoLandmarker.dispose();
      final liveCamera = _camera;
      if (mounted &&
          liveCamera != null &&
          liveCamera.value.isInitialized &&
          !liveCamera.value.isStreamingImages) {
        try {
          await liveCamera.startImageStream(_processFrame);
        } catch (error) {
          if (mounted) setState(() => _status = 'Camera resume failed: $error');
        }
      }
      if (mounted) {
        setState(() {
          _isVideoProcessing = false;
          _cancelVideo = false;
        });
      }
    }
  }

  void _updateTrackingFromResult(
    HolisticLandmarkerResult result, {
    bool isVideo = false,
  }) {
    final left = result.leftHandLandmarks
        .map((point) => Offset(point.x.toDouble(), point.y.toDouble()))
        .toList(growable: false);
    final right = result.rightHandLandmarks
        .map((point) => Offset(point.x.toDouble(), point.y.toDouble()))
        .toList(growable: false);
    final pose = result.poseLandmarks
        .map((point) => Offset(point.x.toDouble(), point.y.toDouble()))
        .toList(growable: false);
    final face = result.faceLandmarks
        .map((point) => Offset(point.x.toDouble(), point.y.toDouble()))
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _frames++;
      _faceCount = face.length;
      _faceBlendshapeCount = result.faceBlendshapes?.length ?? 0;
      _poseCount = pose.length;
      _leftCount = left.length;
      _rightCount = right.length;
      _leftHand = left;
      _rightHand = right;
      _pose = pose;
      _face = face;
      _droppedFrames = isVideo ? 0 : (_landmarker?.droppedFrames ?? 0);
      if (isVideo) {
        _status = 'MediaPipe analyzed timestamped video frames.';
      }
    });
  }

  void _clearTranscript() {
    setState(() {
      _transcriptCleared = true;
      _transcript = '';
      _recognizedGlosses = null;
      _recognitionConfidence = null;
      _translationState =
          _recognitionPipeline?.model.manifest.availability ==
              AslModelAvailability.ready
          ? 'CLEARED'
          : 'MODEL UNAVAILABLE';
    });
  }

  void _cancelVideoAnalysis() {
    if (!_isVideoProcessing) return;
    setState(() => _videoMessage = 'Stopping after the current frame…');
    _cancelVideo = true;
  }

  Future<void> _disposeResources() async {
    _cancelVideo = true;
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
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewAspect = camera == null
        ? 1.0
        : portrait
        ? 1 / camera.value.aspectRatio
        : camera.value.aspectRatio;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign to Text')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cameraSwitching
          ? const Center(child: CircularProgressIndicator())
          : camera == null || _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not start camera tracking:\n${_error ?? 'Camera unavailable.'}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _initialize,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry camera'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: previewAspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(camera),
                        if (_showLandmarks)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _LandmarkPainter(
                                leftHand: _leftHand,
                                rightHand: _rightHand,
                                pose: _pose,
                                face: _face,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _StatusPill(
                            label: _isVideoProcessing
                                ? 'VIDEO ANALYSIS'
                                : 'LIVE · ${camera.description.lensDirection.name.toUpperCase()}',
                            color: Colors.black.withValues(alpha: .65),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _StatusPill(
                            label: '$_frames frames · $_droppedFrames dropped',
                            color: Colors.black.withValues(alpha: .65),
                          ),
                        ),
                        if (_cameraSwitching)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isVideoProcessing
                          ? null
                          : _pickAndAnalyzeVideo,
                      icon: const Icon(Icons.video_file_outlined),
                      label: const Text('Analyze video'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _cameras.length > 1 && !_isVideoProcessing
                          ? _switchCamera
                          : null,
                      icon: const Icon(Icons.cameraswitch_outlined),
                      label: const Text('Switch camera'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showLandmarks = !_showLandmarks),
                      icon: Icon(
                        _showLandmarks
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      label: Text(
                        _showLandmarks ? 'Hide points' : 'Show points',
                      ),
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _error == null
                              ? Icons.track_changes
                              : Icons.error_outline,
                          color: _error == null
                              ? AppConstants.secondary
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isVideoProcessing) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _videoFramesTotal == 0
                        ? null
                        : (_videoFramesProcessed / _videoFramesTotal)
                              .clamp(0, 1)
                              .toDouble(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(_videoMessage ?? 'Analyzing video…'),
                      ),
                      TextButton.icon(
                        onPressed: _cancelVideoAnalysis,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ] else if (_videoMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_videoMessage!, style: const TextStyle(fontSize: 12)),
                ],
                if (kDebugMode)
                  TextButton.icon(
                    onPressed: _isVideoProcessing
                        ? null
                        : _captureParity
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
                  onClear: _clearTranscript,
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
                    _CountChip(label: 'Dropped frames', count: _droppedFrames),
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
  const _TranscriptPanel({
    required this.transcript,
    required this.state,
    required this.onClear,
  });
  final String transcript;
  final String state;
  final VoidCallback onClear;
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
            IconButton(
              tooltip: 'Clear transcript',
              onPressed: transcript.isEmpty ? null : onClear,
              icon: const Icon(Icons.clear_all),
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
          transcript.isEmpty ? 'No transcript.' : transcript,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppConstants.muted,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'English output appears only after a compatible ASL recognition model and reviewed sentence decoder are installed.',
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
    required this.face,
  });
  final List<Offset> leftHand;
  final List<Offset> rightHand;
  final List<Offset> pose;
  final List<Offset> face;
  static const List<List<int>> _poseConnections = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
    [15, 17],
    [16, 18],
  ];
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
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _drawHand(canvas, size, leftHand, Colors.cyanAccent);
    _drawHand(canvas, size, rightHand, Colors.orangeAccent);
    final poseLine = Paint()
      ..color = Colors.white.withValues(alpha: .72)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final edge in _poseConnections) {
      if (edge[0] >= pose.length || edge[1] >= pose.length) continue;
      final first = _scaled(pose[edge[0]], size);
      final second = _scaled(pose[edge[1]], size);
      if (first != null && second != null) {
        canvas.drawLine(first, second, poseLine);
      }
    }
    _drawPoints(canvas, size, pose, Colors.white, radius: 2.2);
    _drawPoints(canvas, size, face, Colors.lightGreenAccent, radius: .8);
    canvas.restore();
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
      final first = _scaled(points[edge[0]], size);
      final second = _scaled(points[edge[1]], size);
      if (first != null && second != null) canvas.drawLine(first, second, line);
    }
    for (final p in points) {
      final scaled = _scaled(p, size);
      if (scaled != null) canvas.drawCircle(scaled, 3, dot);
    }
  }

  void _drawPoints(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color, {
    required double radius,
  }) {
    final paint = Paint()..color = color;
    for (final point in points) {
      final scaled = _scaled(point, size);
      if (scaled != null) canvas.drawCircle(scaled, radius, paint);
    }
  }

  Offset? _scaled(Offset point, Size size) {
    if (!point.dx.isFinite ||
        !point.dy.isFinite ||
        point.dx < 0 ||
        point.dx > 1 ||
        point.dy < 0 ||
        point.dy > 1) {
      return null;
    }
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter old) =>
      old.leftHand != leftHand ||
      old.rightHand != rightHand ||
      old.pose != pose ||
      old.face != face;
}
