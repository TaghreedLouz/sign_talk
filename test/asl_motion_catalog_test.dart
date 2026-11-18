import 'package:flutter_test/flutter_test.dart';
import 'package:sign_talk/features/text_to_sign/asl_motion_catalog.dart';

void main() {
  test('empty ASL catalog cannot produce a playback plan', () {
    final catalog = AslMotionCatalog.fromJson('''
      {
        "schemaVersion": 2,
        "language": "ASL",
        "rigId": "rocketbox-bip01-female-adult-07-v1",
        "signs": [],
        "utterances": [],
        "status": "No reviewed motion installed"
      }
    ''');

    expect(catalog.approvedClipCount({'QA_FINGER_JOINTS_NOT_ASL'}), 0);
    expect(catalog.approvedUtteranceCount({'QA_FINGER_JOINTS_NOT_ASL'}), 0);
    expect(
      catalog.resolveUtterance('missing', {'QA_FINGER_JOINTS_NOT_ASL'}),
      isNull,
    );
  });

  test('rejects the previous unstructured catalog schema', () {
    expect(
      () => AslMotionCatalog.fromJson('''
        {"schemaVersion":1,"language":"ASL","utterances":[]}
      '''),
      throwsFormatException,
    );
  });
}
