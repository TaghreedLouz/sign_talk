import 'dart:convert';

import 'package:flutter/services.dart';

/// One playback item produced only after the catalog validates the reviewed
/// utterance and every referenced sign against the loaded avatar clips.
class AslMotionStep {
  const AslMotionStep({
    required this.signId,
    required this.gloss,
    required this.clipId,
    required this.durationMs,
    required this.transitionMs,
    required this.facialExpression,
    required this.nonManualMarkers,
  });

  final String signId;
  final String gloss;
  final String clipId;
  final int durationMs;
  final int transitionMs;
  final String facialExpression;
  final List<String> nonManualMarkers;
}

/// Validated playback plan. Construction is restricted to this catalog.
class AslMotionPlan {
  const AslMotionPlan._({
    required this.utteranceId,
    required this.gloss,
    required this.rigId,
    required this.steps,
  });

  final String utteranceId;
  final String gloss;
  final String rigId;
  final List<AslMotionStep> steps;
}

/// Catalog of licensed, reviewed ASL sign motions for one compatible avatar.
/// It deliberately has no English sentence lookup or gloss-generation logic.
class AslMotionCatalog {
  AslMotionCatalog._(this._signs, this._utterances);

  static const rigId = 'rocketbox-bip01-female-adult-07-v1';
  final Map<String, Map<String, dynamic>> _signs;
  final Map<String, Map<String, dynamic>> _utterances;

  static Future<AslMotionCatalog> load() async {
    final text = await rootBundle.loadString(
      'assets/animations/asl/manifest.json',
    );
    return AslMotionCatalog.fromJson(text);
  }

  factory AslMotionCatalog.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['schemaVersion'] != 2 ||
        data['language'] != 'ASL' ||
        data['rigId'] != rigId ||
        data['signs'] is! List ||
        data['utterances'] is! List) {
      throw const FormatException(
        'Unsupported ASL motion catalog schema or rig.',
      );
    }
    return AslMotionCatalog._(
      _indexById(data['signs'] as List, 'signId'),
      _indexById(data['utterances'] as List, 'utteranceId'),
    );
  }

  static Map<String, Map<String, dynamic>> _indexById(List values, String key) {
    final result = <String, Map<String, dynamic>>{};
    for (final value in values) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Catalog records must be JSON objects.');
      }
      final id = value[key];
      if (id is! String || id.trim().isEmpty || result.containsKey(id)) {
        throw FormatException('Missing or duplicate $key in ASL catalog.');
      }
      result[id] = value;
    }
    return Map.unmodifiable(result);
  }

  int approvedClipCount(Set<String> availableClips) => _signs.values
      .where((sign) => _isApprovedSign(sign, availableClips))
      .length;

  int approvedUtteranceCount(Set<String> availableClips) => _utterances.keys
      .where((id) => resolveUtterance(id, availableClips) != null)
      .length;

  /// Resolve a reviewed utterance by stable ID, never by English text.
  AslMotionPlan? resolveUtterance(
    String utteranceId,
    Set<String> availableClips,
  ) {
    final utterance = _utterances[utteranceId];
    if (utterance == null ||
        utterance['language'] != 'ASL' ||
        utterance['rigId'] != rigId ||
        utterance['compatibilityStatus'] != 'approved' ||
        !_hasQualifiedReview(utterance['review']) ||
        !_hasSource(utterance['source'])) {
      return null;
    }

    final sequence = utterance['signSequence'];
    if (sequence is! List || sequence.isEmpty) return null;
    final steps = <AslMotionStep>[];
    for (final value in sequence) {
      if (value is! Map<String, dynamic>) return null;
      final signId = value['signId'];
      final durationMs = value['durationMs'];
      final transitionMs = value['transitionMs'] ?? 150;
      if (signId is! String ||
          durationMs is! int ||
          durationMs < 100 ||
          durationMs > 30000 ||
          transitionMs is! int ||
          transitionMs < 0 ||
          transitionMs > 2000) {
        return null;
      }
      final sign = _signs[signId];
      if (sign == null || !_isApprovedSign(sign, availableClips)) return null;
      final animation = sign['animation'] as Map<String, dynamic>;
      steps.add(
        AslMotionStep(
          signId: signId,
          gloss: sign['gloss'] as String,
          clipId: animation['clipId'] as String,
          durationMs: durationMs,
          transitionMs: transitionMs,
          facialExpression:
              (sign['articulation'] as Map<String, dynamic>)['facialExpression']
                  as String,
          nonManualMarkers: List.unmodifiable(
            ((sign['articulation'] as Map<String, dynamic>)['nonManualMarkers']
                    as List)
                .cast<String>(),
          ),
        ),
      );
    }

    final declaredGloss = utterance['aslGloss'];
    if (declaredGloss is! String ||
        declaredGloss.trim().isEmpty ||
        declaredGloss.trim() != steps.map((step) => step.gloss).join(' ')) {
      return null;
    }
    return AslMotionPlan._(
      utteranceId: utteranceId,
      gloss: declaredGloss,
      rigId: rigId,
      steps: List.unmodifiable(steps),
    );
  }

  /// Sign IDs that prevent the whole utterance from being played. A missing,
  /// unreviewed, incompatible, or unavailable clip is treated as unavailable.
  List<String> missingSignIds(String utteranceId, Set<String> availableClips) {
    final utterance = _utterances[utteranceId];
    final sequence = utterance?['signSequence'];
    if (sequence is! List) return const [];
    final missing = <String>[];
    for (final value in sequence) {
      if (value is! Map<String, dynamic>) continue;
      final id = value['signId'];
      if (id is! String) continue;
      final sign = _signs[id];
      if (sign == null || !_isApprovedSign(sign, availableClips)) {
        missing.add(id);
      }
    }
    return List.unmodifiable(missing.toSet());
  }

  List<String> availableSignIds(
    String utteranceId,
    Set<String> availableClips,
  ) {
    final utterance = _utterances[utteranceId];
    final sequence = utterance?['signSequence'];
    if (sequence is! List) return const [];
    final available = <String>[];
    for (final value in sequence) {
      if (value is! Map<String, dynamic>) continue;
      final id = value['signId'];
      if (id is! String) continue;
      final sign = _signs[id];
      if (sign != null && _isApprovedSign(sign, availableClips)) {
        available.add(id);
      }
    }
    return List.unmodifiable(available.toSet());
  }

  bool _isApprovedSign(Map<String, dynamic> sign, Set<String> availableClips) {
    if (sign['rigId'] != rigId ||
        sign['compatibilityStatus'] != 'approved' ||
        !_hasQualifiedReview(sign['review']) ||
        !_hasSource(sign['source'])) {
      return false;
    }
    final gloss = sign['gloss'];
    final englishMeaning = sign['englishMeaning'];
    final animation = sign['animation'];
    final articulation = sign['articulation'];
    if (gloss is! String ||
        gloss.trim().isEmpty ||
        englishMeaning is! String ||
        englishMeaning.trim().isEmpty ||
        animation is! Map<String, dynamic> ||
        articulation is! Map<String, dynamic>) {
      return false;
    }
    final clipId = animation['clipId'];
    final durationMs = animation['durationMs'];
    final hands = articulation['handConfiguration'];
    final palms = articulation['palmOrientation'];
    final wrists = articulation['wristOrientation'];
    final bodyMovement = articulation['bodyMovement'];
    final facialExpression = articulation['facialExpression'];
    final movement = articulation['movement'];
    final nonManual = articulation['nonManualMarkers'];
    bool hasBothHands(dynamic value) =>
        value is Map<String, dynamic> &&
        ['left', 'right'].every(
          (side) =>
              value[side] is String &&
              (value[side] as String).trim().isNotEmpty,
        );
    if (clipId is! String ||
        clipId.trim().isEmpty ||
        clipId.startsWith('QA_') ||
        !availableClips.contains(clipId) ||
        durationMs is! int ||
        durationMs < 100 ||
        durationMs > 30000 ||
        !hasBothHands(hands) ||
        !hasBothHands(palms) ||
        !hasBothHands(wrists) ||
        bodyMovement is! String ||
        bodyMovement.trim().isEmpty ||
        facialExpression is! String ||
        facialExpression.trim().isEmpty ||
        movement is! Map<String, dynamic> ||
        movement['direction'] is! String ||
        (movement['direction'] as String).trim().isEmpty ||
        movement['trajectory'] is! String ||
        (movement['trajectory'] as String).trim().isEmpty ||
        nonManual is! List ||
        nonManual.any((marker) => marker is! String)) {
      return false;
    }
    return true;
  }

  static bool _hasQualifiedReview(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    return value['status'] == 'approved' &&
        value['reviewerRole'] == 'qualified_asl_reviewer' &&
        (value['reviewer'] as String? ?? '').trim().isNotEmpty &&
        (value['reviewerAffiliation'] as String? ?? '').trim().isNotEmpty &&
        value['reviewScope'] == 'linguistic_and_motion' &&
        DateTime.tryParse(value['reviewedAt'] as String? ?? '') != null &&
        (value['evidenceUri'] as String? ?? '').trim().isNotEmpty;
  }

  static bool _hasSource(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    final locator = value['url'] ?? value['datasetId'];
    return locator is String &&
        locator.trim().isNotEmpty &&
        (value['license'] as String? ?? '').trim().isNotEmpty;
  }
}
