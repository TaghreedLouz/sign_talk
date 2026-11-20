import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewController;

import 'asl_motion_catalog.dart';

/// Static GLB/rig-map evidence. This verifies structure, not visual quality or
/// that any motion is linguistically correct.
class AvatarRigAudit {
  const AvatarRigAudit({
    required this.isStructurallyValid,
    required this.fingerJointsFound,
    required this.fingerJointCount,
    required this.bodyJointsFound,
    required this.bodyJointCount,
    required this.fingerJointsAnimated,
    required this.bodyJointsAnimated,
    required this.faceTargetsFound,
    required this.faceTargetCount,
    required this.hasFaceAnimationTrack,
    required this.hasSkinWeights,
    required this.diagnosticAnimations,
    required this.issues,
  });

  final bool isStructurallyValid;
  final int fingerJointsFound;
  final int fingerJointCount;
  final int bodyJointsFound;
  final int bodyJointCount;
  final int fingerJointsAnimated;
  final int bodyJointsAnimated;
  final int faceTargetsFound;
  final int faceTargetCount;
  final bool hasFaceAnimationTrack;
  final bool hasSkinWeights;
  final List<String> diagnosticAnimations;
  final List<String> issues;

  factory AvatarRigAudit.failed(String issue) => AvatarRigAudit(
    isStructurallyValid: false,
    fingerJointsFound: 0,
    fingerJointCount: 0,
    bodyJointsFound: 0,
    bodyJointCount: 0,
    fingerJointsAnimated: 0,
    bodyJointsAnimated: 0,
    faceTargetsFound: 0,
    faceTargetCount: 0,
    hasFaceAnimationTrack: false,
    hasSkinWeights: false,
    diagnosticAnimations: const [],
    issues: [issue],
  );
}

/// Mobile GLB renderer. Ready means the GLB parsed, not that it is ASL approved.
class RealisticAvatarStage extends StatefulWidget {
  const RealisticAvatarStage({
    super.key,
    required this.playing,
    required this.speed,
    required this.replayToken,
    this.animationName,
    this.durationMs,
    this.transitionMs = 150,
    this.onModelReady,
    this.onClipsReady,
    this.onRigAudit,
    this.onFinished,
    this.onError,
  });
  final bool playing;
  final double speed;
  final int replayToken;
  final String? animationName;
  final int? durationMs;
  final int transitionMs;
  final ValueChanged<bool>? onModelReady;
  final ValueChanged<List<String>>? onClipsReady;
  final ValueChanged<AvatarRigAudit>? onRigAudit;
  final VoidCallback? onFinished;
  final ValueChanged<String>? onError;

  @override
  State<RealisticAvatarStage> createState() => _RealisticAvatarStageState();
}

class _RealisticAvatarStageState extends State<RealisticAvatarStage> {
  WebViewController? _controller;
  String? _bridge;
  String? _error;
  bool _checking = true;
  bool _loaded = false;
  double? _loadProgress;
  Timer? _loadTimeout;
  int _generation = 0;
  static const _modelPath = 'assets/avatar/female/avatar.glb';
  String get _viewerModelPath =>
      kIsWeb ? 'assets/assets/avatar/female/avatar.glb' : _modelPath;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(covariant RealisticAvatarStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.speed != widget.speed ||
        oldWidget.replayToken != widget.replayToken ||
        oldWidget.animationName != widget.animationName ||
        oldWidget.durationMs != widget.durationMs ||
        oldWidget.transitionMs != widget.transitionMs) {
      unawaited(_apply());
    }
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    final path = _modelPath;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final bytes = await rootBundle.load(path);
      if (bytes.lengthInBytes < 20 ||
          bytes.getUint32(0, Endian.little) != 0x46546c67) {
        throw const FormatException('Invalid GLB header');
      }
      late final AvatarRigAudit rigAudit;
      try {
        rigAudit = await _inspectRig(bytes);
      } catch (error) {
        rigAudit = AvatarRigAudit.failed(
          'Rig structure inspection failed: $error',
        );
      }
      final bridge = await rootBundle.loadString(
        'assets/avatar/runtime/playback_bridge.js',
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _bridge = bridge;
      });
      widget.onRigAudit?.call(rigAudit);
      widget.onModelReady?.call(false);
      // A broken local WebView/WebGL context otherwise leaves a blank viewer forever.
      if (!kIsWeb) {
        _loadTimeout?.cancel();
        _loadTimeout = Timer(const Duration(seconds: 90), () {
          if (!mounted || generation != _generation || _loaded) return;
          setState(
            () => _error = 'The avatar did not finish loading. Check WebView/WebGL support and try again.',
          );
          widget.onModelReady?.call(false);
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _error = 'Model unavailable: $path\n$error';
      });
      widget.onModelReady?.call(false);
    }
  }

  Future<AvatarRigAudit> _inspectRig(ByteData bytes) async {
    final issues = <String>[];
    if (bytes.getUint32(8, Endian.little) != bytes.lengthInBytes) {
      issues.add('GLB declared length does not match the asset length.');
    }
    final jsonLength = bytes.getUint32(12, Endian.little);
    final jsonType = bytes.getUint32(16, Endian.little);
    if (jsonType != 0x4e4f534a || 20 + jsonLength > bytes.lengthInBytes) {
      throw const FormatException('Invalid GLB JSON chunk.');
    }
    final jsonBytes = Uint8List.sublistView(
      bytes.buffer.asUint8List(bytes.offsetInBytes),
      20,
      20 + jsonLength,
    );
    final gltf = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    final rig = jsonDecode(
      await rootBundle.loadString('assets/avatar/female/rig_map.json'),
    ) as Map<String, dynamic>;
    if (rig['rig'] != AslMotionCatalog.rigId) {
      issues.add('Rig map ID does not match the ASL catalog rig ID.');
    }

    final nodes = List<Map<String, dynamic>>.from(gltf['nodes'] as List);
    final nodeNames = nodes
        .map((node) => node['name'])
        .whereType<String>()
        .toSet();
    final skinJointIndices = (gltf['skins'] as List)
        .whereType<Map<String, dynamic>>()
        .expand(
          (skin) => (skin['joints'] as List? ?? const []).whereType<int>(),
        )
        .toSet();
    final skinJointNames = skinJointIndices
        .where((index) => index >= 0 && index < nodes.length)
        .map((index) => nodes[index]['name'])
        .whereType<String>()
        .toSet();

    final fingerMap = rig['fingers'] as Map<String, dynamic>? ?? const {};
    final fingerNames = <String>[];
    for (final hand in fingerMap.values.whereType<Map<String, dynamic>>()) {
      for (final finger in hand.values.whereType<List>()) {
        fingerNames.addAll(finger.whereType<String>());
      }
    }
    final foundFingerNames = fingerNames
        .where(
          (name) => nodeNames.contains(name) && skinJointNames.contains(name),
        )
        .toSet();
    if (foundFingerNames.length != fingerNames.length) {
      issues.add('Some mapped finger joints are missing from the GLB skin.');
    }

    final bodyNames = (rig['body_joints'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final foundBodyNames = bodyNames
        .where(
          (name) => nodeNames.contains(name) && skinJointNames.contains(name),
        )
        .toSet();
    if (foundBodyNames.length != bodyNames.length) {
      issues.add(
        'Some mapped body or arm joints are missing from the GLB skin.',
      );
    }

    final animations = (gltf['animations'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final animatedRotations = <String>{};
    for (final animation in animations) {
      for (final channel
          in (animation['channels'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()) {
        final target = channel['target'] as Map<String, dynamic>? ?? const {};
        final nodeIndex = target['node'];
        if (target['path'] == 'rotation' &&
            nodeIndex is int &&
            nodeIndex >= 0 &&
            nodeIndex < nodes.length &&
            nodes[nodeIndex]['name'] is String) {
          animatedRotations.add(nodes[nodeIndex]['name'] as String);
        }
      }
    }
    final fingerJointsAnimated = foundFingerNames.intersection(
      animatedRotations,
    );
    final bodyJointsAnimated = foundBodyNames.intersection(animatedRotations);
    if (fingerJointsAnimated.length != foundFingerNames.length) {
      issues.add(
        'Some mapped finger joints have no rotation animation channel.',
      );
    }
    if (bodyJointsAnimated.length != foundBodyNames.length) {
      issues.add(
        'Some mapped body or arm joints have no rotation animation channel.',
      );
    }

    final faceNames = (rig['face_shapes'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final meshes = (gltf['meshes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final meshTargets = meshes
        .expand(
          (mesh) =>
              (mesh['extras'] as Map<String, dynamic>? ??
                      const {})['targetNames']
                  as List? ??
              const [],
        )
        .whereType<String>()
        .toSet();
    final primitives = meshes
        .expand(
          (mesh) => (mesh['primitives'] as List? ?? const [])
              .whereType<Map<String, dynamic>>(),
        )
        .toList();
    final hasMorphTargets =
        primitives.isNotEmpty &&
        primitives.every((primitive) {
          final targets = primitive['targets'] as List?;
          return targets != null && targets.length == meshTargets.length;
        });
    final foundFaceNames = faceNames.intersection(meshTargets);
    if (foundFaceNames.length != faceNames.length || !hasMorphTargets) {
      issues.add(
        'Facial target map is incomplete or does not match mesh morph targets.',
      );
    }
    final hasFaceAnimationTrack = animations.any(
      (animation) => (animation['channels'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .any((channel) {
            final target =
                channel['target'] as Map<String, dynamic>? ?? const {};
            final nodeIndex = target['node'];
            return target['path'] == 'weights' &&
                nodeIndex is int &&
                nodeIndex >= 0 &&
                nodeIndex < nodes.length &&
                nodes[nodeIndex]['mesh'] is int;
          }),
    );
    if (!hasFaceAnimationTrack) {
      issues.add('No animation channel targets the facial morph weights.');
    }

    final hasSkinWeights =
        primitives.isNotEmpty &&
        primitives.every((primitive) {
          final attributes =
              primitive['attributes'] as Map<String, dynamic>? ?? const {};
          return attributes.containsKey('JOINTS_0') &&
              attributes.containsKey('WEIGHTS_0');
        });
    if (!hasSkinWeights || skinJointNames.isEmpty) {
      issues.add('Skinned mesh joint or weight attributes are missing.');
    }
    final diagnostics = animations
        .map((animation) => animation['name'])
        .whereType<String>()
        .where((name) => name.startsWith('QA_'))
        .toList(growable: false);

    return AvatarRigAudit(
      isStructurallyValid: issues.isEmpty,
      fingerJointsFound: foundFingerNames.length,
      fingerJointCount: fingerNames.length,
      bodyJointsFound: foundBodyNames.length,
      bodyJointCount: bodyNames.length,
      fingerJointsAnimated: fingerJointsAnimated.length,
      bodyJointsAnimated: bodyJointsAnimated.length,
      faceTargetsFound: foundFaceNames.length,
      faceTargetCount: faceNames.length,
      hasFaceAnimationTrack: hasFaceAnimationTrack,
      hasSkinWeights: hasSkinWeights,
      diagnosticAnimations: List.unmodifiable(diagnostics),
      issues: List.unmodifiable(issues),
    );
  }

  Future<void> _apply() async {
    final controller = _controller;
    if (!_loaded || controller == null) return;
    final payload = jsonEncode({
      'playing': widget.playing,
      'speed': widget.speed.isFinite ? widget.speed : 1,
      'clip': widget.animationName,
      'durationMs': widget.durationMs,
      'transitionMs': widget.transitionMs,
      'replay': widget.replayToken,
    });
    try {
      await controller.runJavaScript(
        'window.SignTalkAvatar?.setState($payload);',
      );
    } catch (error) {
      if (mounted) widget.onError?.call('Playback command failed: $error');
    }
  }

  void _receive(String message, int generation) {
    if (!mounted || generation != _generation) return;
    try {
      final event = jsonDecode(message) as Map<String, dynamic>;
      switch (event['type']) {
        case 'ready':
          _loadTimeout?.cancel();
          _loaded = true;
          _loadProgress = 1;
          if (mounted) setState(() {});
          widget.onClipsReady?.call(List<String>.from(event['clips'] as List));
          widget.onModelReady?.call(true);
          unawaited(_apply());
        case 'progress':
          final progress = event['progress'];
          if (progress is num) {
            _loadProgress = progress.toDouble().clamp(0, 1).toDouble();
            if (mounted) setState(() {});
          }
        case 'finished':
          widget.onFinished?.call();
        case 'error':
          _loadTimeout?.cancel();
          _loaded = false;
          final error = event['message'] as String? ?? 'Viewer error';
          setState(() => _error = error);
          widget.onModelReady?.call(false);
          widget.onError?.call(error);
      }
    } catch (error) {
      widget.onError?.call('Invalid viewer event: $error');
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final generation = _generation;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModelViewer(
            key: ValueKey(_modelPath),
            src: _viewerModelPath,
            alt: 'Female avatar evaluation candidate. Visual and ASL acceptance pending.',
            backgroundColor: const Color(0xFFE8EDF2),
            cameraControls: true,
            autoRotate: false,
            autoPlay: false,
            cameraOrbit: '0deg 85deg auto',
            fieldOfView: '35deg',
            minCameraOrbit: 'auto auto 0.2m',
            maxCameraOrbit: 'auto auto 8m',
            shadowIntensity: .6,
            animationCrossfadeDuration: 150,
            relatedJs: _bridge,
            javascriptChannels: {
              JavascriptChannel(
                'SignTalkBridge',
                onMessageReceived: (message) =>
                    _receive(message.message, generation),
              ),
            },
            onWebViewCreated: (controller) {
              if (generation == _generation) _controller = controller;
            },
          ),
          if (!_loaded && !kIsWeb)
            IgnorePointer(
              child: ColoredBox(
                color: const Color(0x99E8EDF2),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _loadProgress == null
                            ? 'Loading 3D avatar…'
                            : 'Loading 3D avatar… ${(_loadProgress! * 100).round()}%',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
