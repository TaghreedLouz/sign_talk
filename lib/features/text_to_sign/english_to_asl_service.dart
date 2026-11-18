import 'dart:convert';

import 'package:flutter/services.dart';

import 'asl_motion_catalog.dart';

enum AslTranslationStatus {
  ready,
  pendingReview,
  unsupported,
  incompleteMotion,
}

/// Normalizes punctuation/spacing for lookup without changing sentence meaning.
class EnglishInputNormalizer {
  const EnglishInputNormalizer();

  String normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

enum EnglishQuestionType { none, yesNo, wh }

/// Conservative surface analysis for review context. This is not an ASL
/// translation and is never used to manufacture a gloss.
class EnglishLinguisticAnalysis {
  const EnglishLinguisticAnalysis({
    required this.questionType,
    required this.isNegated,
    required this.pronouns,
    required this.timeExpressions,
    required this.subjectCandidate,
    required this.objectCandidate,
    required this.contentWords,
  });

  final EnglishQuestionType questionType;
  final bool isNegated;
  final List<String> pronouns;
  final List<String> timeExpressions;
  final String? subjectCandidate;
  final String? objectCandidate;
  final List<String> contentWords;

  List<String> get detectedFeatures => [
    if (questionType == EnglishQuestionType.yesNo) 'yes_no_question',
    if (questionType == EnglishQuestionType.wh) 'wh_question',
    if (isNegated) 'negation',
    if (pronouns.isNotEmpty) 'pronouns',
    if (timeExpressions.isNotEmpty) 'time_expression',
    if (subjectCandidate != null) 'subject_candidate',
    if (objectCandidate != null) 'object_candidate',
  ];
}

class EnglishSentenceParser {
  const EnglishSentenceParser();

  static const _pronouns = {
    'i',
    'me',
    'my',
    'mine',
    'we',
    'us',
    'our',
    'you',
    'your',
    'he',
    'him',
    'his',
    'she',
    'her',
    'they',
    'them',
    'their',
    'it',
    'its',
  };
  static const _times = {
    'today',
    'tomorrow',
    'yesterday',
    'now',
    'later',
    'before',
    'after',
    'morning',
    'afternoon',
    'evening',
    'tonight',
    'recently',
  };
  static const _whWords = {'who', 'what', 'when', 'where', 'why', 'how'};
  static const _yesNoOpeners = {
    'am',
    'is',
    'are',
    'was',
    'were',
    'do',
    'does',
    'did',
    'can',
    'could',
    'will',
    'would',
    'have',
    'has',
    'had',
    'should',
  };
  static const _commonVerbs = {
    'want',
    'need',
    'like',
    'love',
    'help',
    'see',
    'know',
    'understand',
    'go',
    'give',
    'tell',
    'find',
    'visit',
    'call',
  };

  EnglishLinguisticAnalysis analyze(String input, String normalized) {
    final words = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    final first = words.isEmpty ? '' : words.first;
    final hasQuestionMark = input.trimRight().endsWith('?');
    final hasWhWord = words.any(_whWords.contains);
    final questionType = hasWhWord
        ? EnglishQuestionType.wh
        : hasQuestionMark || _yesNoOpeners.contains(first)
        ? EnglishQuestionType.yesNo
        : EnglishQuestionType.none;
    final pronouns = words.where(_pronouns.contains).toSet().toList();
    final times = words.where(_times.contains).toSet().toList();
    final isNegated = words.any(
      (word) =>
          word == 'not' ||
          word == 'never' ||
          word == 'no' ||
          word.endsWith("n't"),
    );

    // This only annotates a simple English surface candidate for a human
    // reviewer. It does not claim to parse English syntax generally.
    String? subjectCandidate;
    if (words.isNotEmpty && _pronouns.contains(words.first)) {
      subjectCandidate = words.first;
    } else if (words.length > 1 &&
        _yesNoOpeners.contains(first) &&
        _pronouns.contains(words[1])) {
      subjectCandidate = words[1];
    }
    String? objectCandidate;
    for (var index = 1; index < words.length - 1; index++) {
      if (_commonVerbs.contains(words[index]) &&
          (_pronouns.contains(words[index + 1]) || index + 1 < words.length)) {
        objectCandidate = words[index + 1];
        break;
      }
    }
    final contentWords = words
        .where(
          (word) =>
              !_pronouns.contains(word) &&
              !_times.contains(word) &&
              !_whWords.contains(word) &&
              !_yesNoOpeners.contains(word) &&
              !{
                'a',
                'an',
                'the',
                'to',
                'is',
                'am',
                'are',
                'not',
                'no',
                'do',
              }.contains(word),
        )
        .toList();
    return EnglishLinguisticAnalysis(
      questionType: questionType,
      isNegated: isNegated,
      pronouns: List.unmodifiable(pronouns),
      timeExpressions: List.unmodifiable(times),
      subjectCandidate: subjectCandidate,
      objectCandidate: objectCandidate,
      contentWords: List.unmodifiable(contentWords),
    );
  }
}

/// Only populated from an explicitly reviewed local translation resource.
class AslGloss {
  const AslGloss({required this.text, required this.tokens});

  final String text;
  final List<String> tokens;
}

class AslTranslationResult {
  const AslTranslationResult({
    required this.originalEnglish,
    required this.normalizedEnglish,
    required this.analysis,
    required this.status,
    required this.translationSource,
    required this.reviewStatus,
    required this.gloss,
    required this.utteranceId,
    required this.availableSignIds,
    required this.missingSignIds,
    required this.nonManualMarkers,
    required this.playbackPlan,
    required this.message,
  });

  final String originalEnglish;
  final String normalizedEnglish;
  final EnglishLinguisticAnalysis analysis;
  final AslTranslationStatus status;
  final String? translationSource;
  final String reviewStatus;
  final AslGloss? gloss;
  final String? utteranceId;
  final List<String> availableSignIds;
  final List<String> missingSignIds;
  final List<String> nonManualMarkers;
  final AslMotionPlan? playbackPlan;
  final String message;

  bool get isPlaybackEligible =>
      status == AslTranslationStatus.ready && playbackPlan != null;
}

/// Offline lookup of complete, reviewed translations. It intentionally does
/// not generate gloss with word substitution or an unvalidated language model.
class EnglishToAslService {
  EnglishToAslService._({
    required this._entries,
    required this.catalog,
    required this.normalizer,
    required this.parser,
  });

  static const assetPath = 'assets/translations/en_to_asl.json';
  final Map<String, Map<String, dynamic>> _entries;
  final AslMotionCatalog catalog;
  final EnglishInputNormalizer normalizer;
  final EnglishSentenceParser parser;

  static Future<EnglishToAslService> load(AslMotionCatalog catalog) async {
    final source = await rootBundle.loadString(assetPath);
    return EnglishToAslService.fromJson(source, catalog: catalog);
  }

  factory EnglishToAslService.fromJson(
    String source, {
    required AslMotionCatalog catalog,
  }) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> ||
        data['schemaVersion'] != 1 ||
        data['language'] != 'ASL' ||
        data['entries'] is! List) {
      throw const FormatException('Unsupported English-to-ASL resource.');
    }
    final entries = <String, Map<String, dynamic>>{};
    for (final item in data['entries'] as List) {
      if (item is! Map<String, dynamic> ||
          item['normalizedEnglish'] is! String ||
          item['translationStatus'] is! String) {
        throw const FormatException('Invalid translation resource entry.');
      }
      final key = item['normalizedEnglish'] as String;
      if (key.isEmpty || entries.containsKey(key)) {
        throw const FormatException('Empty or duplicate English source.');
      }
      entries[key] = item;
    }
    return EnglishToAslService._(
      entries: Map.unmodifiable(entries),
      catalog: catalog,
      normalizer: const EnglishInputNormalizer(),
      parser: const EnglishSentenceParser(),
    );
  }

  AslTranslationResult translate(
    String english, {
    required Set<String> availableClips,
  }) {
    final normalized = normalizer.normalize(english);
    final analysis = parser.analyze(english, normalized);
    final entry = _entries[normalized];
    if (normalized.isEmpty) {
      return _result(
        english,
        normalized,
        analysis,
        AslTranslationStatus.unsupported,
        reviewStatus: 'not_found',
        message: 'Enter an English sentence to check the reviewed resource.',
      );
    }
    if (entry == null) {
      final words = normalized.split(' ').toSet();
      final knownWords = _entries.keys
          .expand((sentence) => sentence.split(' '))
          .toSet();
      final unsupported = words.difference(knownWords).toList()..sort();
      return _result(
        english,
        normalized,
        analysis,
        AslTranslationStatus.unsupported,
        reviewStatus: 'not_found',
        message: unsupported.isEmpty
            ? 'This complete sentence has no reviewed ASL translation in the installed offline resource.'
            : 'No reviewed sentence translation is installed. Unrecognized words: ${unsupported.join(', ')}.',
      );
    }

    final reviewStatus = entry['reviewStatus'] as String? ?? 'pending_review';
    if (entry['translationStatus'] != 'approved' ||
        reviewStatus != 'approved' ||
        !_hasQualifiedReview(entry['review']) ||
        !_hasSource(entry['translationSource'])) {
      return _result(
        english,
        normalized,
        analysis,
        AslTranslationStatus.pendingReview,
        translationSource: _sourceLabel(entry['translationSource']),
        reviewStatus: reviewStatus,
        message: 'This sentence is recognized, but its ASL translation is pending qualified review. No gloss or animation will be guessed.',
      );
    }

    final glossValue = entry['aslGloss'];
    final utteranceId = entry['utteranceId'];
    final markers = entry['nonManualMarkers'];
    if (glossValue is! String ||
        glossValue.trim().isEmpty ||
        utteranceId is! String ||
        utteranceId.trim().isEmpty ||
        markers is! List ||
        markers.any((value) => value is! String)) {
      return _result(
        english,
        normalized,
        analysis,
        AslTranslationStatus.pendingReview,
        translationSource: _sourceLabel(entry['translationSource']),
        reviewStatus: 'invalid_reviewed_record',
        message: 'The reviewed translation record is incomplete; playback is blocked.',
      );
    }

    final plan = catalog.resolveUtterance(utteranceId, availableClips);
    if (plan == null || plan.gloss != glossValue.trim()) {
      return _result(
        english,
        normalized,
        analysis,
        AslTranslationStatus.incompleteMotion,
        translationSource: _sourceLabel(entry['translationSource']),
        reviewStatus: reviewStatus,
        gloss: AslGloss(
          text: glossValue.trim(),
          tokens: List.unmodifiable(glossValue.trim().split(RegExp(r'\s+'))),
        ),
        utteranceId: utteranceId,
        availableSignIds: catalog.availableSignIds(utteranceId, availableClips),
        missingSignIds: catalog.missingSignIds(utteranceId, availableClips),
        nonManualMarkers: List.unmodifiable(markers.cast<String>()),
        message: 'The reviewed sentence is not fully covered by approved, available sign clips. The sentence will not be partially played.',
      );
    }

    return _result(
      english,
      normalized,
      analysis,
      AslTranslationStatus.ready,
      translationSource: _sourceLabel(entry['translationSource']),
      reviewStatus: reviewStatus,
      gloss: AslGloss(
        text: glossValue.trim(),
        tokens: List.unmodifiable(glossValue.trim().split(RegExp(r'\s+'))),
      ),
      utteranceId: utteranceId,
      availableSignIds: List.unmodifiable(
        plan.steps.map((step) => step.signId),
      ),
      nonManualMarkers: List.unmodifiable(markers.cast<String>()),
      playbackPlan: plan,
      message: 'Complete reviewed ASL sequence is ready for playback.',
    );
  }

  AslTranslationResult _result(
    String english,
    String normalized,
    EnglishLinguisticAnalysis analysis,
    AslTranslationStatus status, {
    String? translationSource,
    String reviewStatus = 'pending_review',
    AslGloss? gloss,
    String? utteranceId,
    List<String> availableSignIds = const [],
    List<String> missingSignIds = const [],
    List<String> nonManualMarkers = const [],
    AslMotionPlan? playbackPlan,
    required String message,
  }) => AslTranslationResult(
    originalEnglish: english,
    normalizedEnglish: normalized,
    analysis: analysis,
    status: status,
    translationSource: translationSource,
    reviewStatus: reviewStatus,
    gloss: gloss,
    utteranceId: utteranceId,
    availableSignIds: List.unmodifiable(availableSignIds),
    missingSignIds: List.unmodifiable(missingSignIds),
    nonManualMarkers: List.unmodifiable(nonManualMarkers),
    playbackPlan: playbackPlan,
    message: message,
  );

  static String? _sourceLabel(dynamic source) {
    if (source is! Map<String, dynamic>) return null;
    return source['title'] as String? ??
        source['url'] as String? ??
        source['resourceId'] as String?;
  }

  static bool _hasQualifiedReview(dynamic value) =>
      value is Map<String, dynamic> &&
      value['status'] == 'approved' &&
      value['reviewerRole'] == 'qualified_asl_reviewer' &&
      (value['reviewer'] as String? ?? '').trim().isNotEmpty &&
      (value['reviewerAffiliation'] as String? ?? '').trim().isNotEmpty &&
      value['reviewScope'] == 'linguistic_and_motion' &&
      DateTime.tryParse(value['reviewedAt'] as String? ?? '') != null &&
      (value['evidenceUri'] as String? ?? '').trim().isNotEmpty;

  static bool _hasSource(dynamic value) =>
      value is Map<String, dynamic> &&
      (value['url'] is String && (value['url'] as String).trim().isNotEmpty ||
          value['resourceId'] is String &&
              (value['resourceId'] as String).trim().isNotEmpty) &&
      (value['license'] as String? ?? '').trim().isNotEmpty;
}

/// The only path from translation output to motion is a catalog-validated,
/// complete utterance plan.
class AslSequenceBuilder {
  const AslSequenceBuilder(this.catalog);
  final AslMotionCatalog catalog;

  AslMotionPlan? build(
    AslTranslationResult translation, {
    required Set<String> availableClips,
  }) {
    final utteranceId = translation.utteranceId;
    if (translation.status != AslTranslationStatus.ready ||
        utteranceId == null ||
        translation.gloss == null) {
      return null;
    }
    final validated = catalog.resolveUtterance(utteranceId, availableClips);
    if (validated == null || validated.gloss != translation.gloss!.text) {
      return null;
    }
    return validated;
  }
}
