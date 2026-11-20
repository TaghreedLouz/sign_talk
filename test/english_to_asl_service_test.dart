import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_talk/features/text_to_sign/asl_motion_catalog.dart';
import 'package:sign_talk/features/text_to_sign/english_to_asl_service.dart';

const _review = {
  'status': 'approved',
  'reviewerRole': 'qualified_asl_reviewer',
  'reviewer': 'reviewer-1',
  'reviewerAffiliation': 'review panel',
  'reviewScope': 'linguistic_and_motion',
  'reviewedAt': '2026-01-01',
  'evidenceUri': 'https://example.org/review/1',
};

const _source = {
  'url': 'https://example.org/asl-resource',
  'license': 'CC BY 4.0',
};

Map<String, Object?> _sign(String id, String gloss, String clip) => {
  'signId': id,
  'englishMeaning': 'fixture meaning',
  'gloss': gloss,
  'rigId': AslMotionCatalog.rigId,
  'compatibilityStatus': 'approved',
  'source': _source,
  'review': _review,
  'animation': {'clipId': clip, 'durationMs': 800},
  'articulation': {
    'handConfiguration': {'left': 'shape', 'right': 'shape'},
    'palmOrientation': {'left': 'orientation', 'right': 'orientation'},
    'wristOrientation': {'left': 'orientation', 'right': 'orientation'},
    'movement': {'direction': 'forward', 'trajectory': 'straight'},
    'bodyMovement': 'neutral',
    'facialExpression': 'brow raise',
    'nonManualMarkers': ['brow_raise'],
  },
};

Map<String, Object?> _utterance() => {
  'utteranceId': 'phrase-1',
  'language': 'ASL',
  'aslGloss': 'FIRST SECOND',
  'rigId': AslMotionCatalog.rigId,
  'compatibilityStatus': 'approved',
  'source': _source,
  'review': _review,
  'signSequence': [
    {'signId': 'sign-first', 'durationMs': 800, 'transitionMs': 90},
    {'signId': 'sign-second', 'durationMs': 900, 'transitionMs': 120},
  ],
};

AslMotionCatalog _catalog({
  bool includeSigns = true,
  bool includeFirstOnly = false,
}) => AslMotionCatalog.fromJson(
  jsonEncode({
    'schemaVersion': 2,
    'language': 'ASL',
    'rigId': AslMotionCatalog.rigId,
    'status': 'test fixture',
    'signs': !includeSigns
        ? []
        : [
            _sign('sign-first', 'FIRST', 'CLIP_FIRST'),
            if (!includeFirstOnly)
              _sign('sign-second', 'SECOND', 'CLIP_SECOND'),
          ],
    'utterances': [_utterance()],
  }),
);

Map<String, Object?> _approvedTranslation({
  String gloss = 'FIRST SECOND',
  List<String> markers = const ['yes_no_question'],
}) => {
  'originalEnglish': 'Please help.',
  'normalizedEnglish': 'please help',
  'translationStatus': 'approved',
  'reviewStatus': 'approved',
  'translationSource': _source,
  'review': _review,
  'aslGloss': gloss,
  'utteranceId': 'phrase-1',
  'availableSignIds': ['sign-first', 'sign-second'],
  'missingSignIds': [],
  'nonManualMarkers': markers,
  'playbackEligible': true,
};

String _resource(List<Map<String, Object?>> entries) => jsonEncode({
  'schemaVersion': 1,
  'language': 'ASL',
  'mode': 'offline_reviewed_resource_lookup',
  'status': 'fixture',
  'entries': entries,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes punctuation and whitespace without changing word order', () {
    const normalizer = EnglishInputNormalizer();
    expect(
      normalizer.normalize('  Hello,   HOW are you? '),
      'hello how are you',
    );
  });

  test(
    'detects question, negation, pronouns, time and simple role candidates',
    () {
      const parser = EnglishSentenceParser();
      final normalizer = const EnglishInputNormalizer();
      const input = 'Can you help me today?';
      final analysis = parser.analyze(input, normalizer.normalize(input));
      expect(analysis.questionType, EnglishQuestionType.yesNo);
      expect(analysis.isNegated, isFalse);
      expect(analysis.pronouns, ['you', 'me']);
      expect(analysis.timeExpressions, ['today']);
      expect(analysis.subjectCandidate, 'you');
      expect(analysis.objectCandidate, 'me');

      const infinitive = 'I want to go home.';
      final infinitiveAnalysis = parser.analyze(
        infinitive,
        normalizer.normalize(infinitive),
      );
      expect(infinitiveAnalysis.objectCandidate, isNull);

      const negative = 'I do not understand.';
      final negativeAnalysis = parser.analyze(
        negative,
        normalizer.normalize(negative),
      );
      expect(negativeAnalysis.isNegated, isTrue);
      expect(negativeAnalysis.subjectCandidate, 'i');
    },
  );

  test(
    'requested phrases remain pending and do not invent gloss or playback',
    () {
      final catalog = AslMotionCatalog.fromJson('''
      {"schemaVersion":2,"language":"ASL","rigId":"${AslMotionCatalog.rigId}","signs":[],"utterances":[],"status":"empty"}
    ''');
      final service = EnglishToAslService.fromJson(
        _resource([
          {
            'originalEnglish': 'I do not understand.',
            'normalizedEnglish': 'i do not understand',
            'translationStatus': 'pending_review',
            'reviewStatus': 'pending_review',
          },
        ]),
        catalog: catalog,
      );
      final result = service.translate(
        ' I DO NOT understand! ',
        availableClips: {'QA_FINGER_JOINTS_NOT_ASL'},
      );
      expect(result.status, AslTranslationStatus.pendingReview);
      expect(result.analysis.isNegated, isTrue);
      expect(result.gloss, isNull);
      expect(result.playbackPlan, isNull);
      expect(result.isPlaybackEligible, isFalse);
    },
  );

  test(
    'rejects unsupported complete sentences and identifies unseen words',
    () {
      final service = EnglishToAslService.fromJson(
        _resource([
          {
            'originalEnglish': 'I want to go home.',
            'normalizedEnglish': 'i want to go home',
            'translationStatus': 'pending_review',
            'reviewStatus': 'pending_review',
          },
        ]),
        catalog: _catalog(),
      );
      final result = service.translate(
        'Please take me to the airport.',
        availableClips: const {},
      );
      expect(result.status, AslTranslationStatus.unsupported);
      expect(result.message, contains('airport'));
      expect(result.playbackPlan, isNull);
    },
  );

  test('rejects partial sign coverage instead of dropping missing signs', () {
    final service = EnglishToAslService.fromJson(
      _resource([_approvedTranslation()]),
      catalog: _catalog(includeFirstOnly: true),
    );
    final result = service.translate(
      'please help',
      availableClips: {'CLIP_FIRST'},
    );
    expect(result.status, AslTranslationStatus.incompleteMotion);
    expect(result.availableSignIds, ['sign-first']);
    expect(result.missingSignIds, ['sign-second']);
    expect(result.playbackPlan, isNull);
    expect(result.isPlaybackEligible, isFalse);
  });

  test(
    'validates full sequence order and carries non-manual markers offline',
    () {
      final catalog = _catalog();
      final service = EnglishToAslService.fromJson(
        _resource([_approvedTranslation()]),
        catalog: catalog,
      );
      final result = service.translate(
        'Please, help!',
        availableClips: {'CLIP_FIRST', 'CLIP_SECOND'},
      );
      expect(result.status, AslTranslationStatus.ready);
      expect(result.availableSignIds, ['sign-first', 'sign-second']);
      expect(result.nonManualMarkers, ['yes_no_question']);

      final plan = AslSequenceBuilder(catalog)
          .build(result, availableClips: {'CLIP_FIRST', 'CLIP_SECOND'});
      expect(plan?.steps.map((step) => step.clipId), [
        'CLIP_FIRST',
        'CLIP_SECOND',
      ]);
      expect(plan?.steps.first.transitionMs, 90);
      expect(plan?.steps.first.facialExpression, 'brow raise');
      expect(plan?.steps.first.nonManualMarkers, ['brow_raise']);
    },
  );

  test('empty catalog rejects even a reviewed translation', () {
    final emptyCatalog = _catalog(includeSigns: false);
    final service = EnglishToAslService.fromJson(
      _resource([_approvedTranslation()]),
      catalog: emptyCatalog,
    );
    final result = service.translate('please help', availableClips: const {});
    expect(result.status, AslTranslationStatus.incompleteMotion);
    expect(result.isPlaybackEligible, isFalse);
    expect(
      AslSequenceBuilder(emptyCatalog).build(result, availableClips: const {}),
      isNull,
    );
  });

  test(
    'bundled offline corpus contains all eight targets as pending review',
    () async {
      final catalog = AslMotionCatalog.fromJson('''
      {"schemaVersion":2,"language":"ASL","rigId":"${AslMotionCatalog.rigId}","signs":[],"utterances":[],"status":"empty"}
    ''');
      final service = await EnglishToAslService.load(catalog);
      const targets = [
        'HELLO, HOW ARE YOU?',
        'MY NAME IS AHMED.',
        'I WANT TO GO HOME.',
        'THANK YOU FOR YOUR HELP.',
        'WHERE IS THE HOSPITAL?',
        'I DO NOT UNDERSTAND.',
        'CAN YOU HELP ME?',
        'I AM HAPPY TODAY.',
      ];
      for (final target in targets) {
        final result = service.translate(target, availableClips: const {});
        expect(result.status, AslTranslationStatus.pendingReview);
        expect(result.gloss, isNull);
        expect(result.isPlaybackEligible, isFalse);
      }
    },
  );
}
