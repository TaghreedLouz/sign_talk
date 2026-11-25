import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> gltf;
  late Map<String, dynamic> rig;

  setUpAll(() async {
    final bytes = await rootBundle.load('assets/avatar/female/avatar.glb');
    expect(bytes.lengthInBytes, greaterThan(20));
    expect(bytes.getUint32(0, Endian.little), 0x46546c67);
    expect(bytes.getUint32(4, Endian.little), 2);
    expect(bytes.getUint32(8, Endian.little), bytes.lengthInBytes);
    final jsonLength = bytes.getUint32(12, Endian.little);
    expect(bytes.getUint32(16, Endian.little), 0x4e4f534a);
    final jsonBytes = Uint8List.sublistView(
      bytes.buffer.asUint8List(bytes.offsetInBytes),
      20,
      20 + jsonLength,
    );
    gltf = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    rig = jsonDecode(
      await rootBundle.loadString('assets/avatar/female/rig_map.json'),
    ) as Map<String, dynamic>;
  });

  test('female GLB is valid glTF 2 with a skinned weighted mesh', () {
    final nodes = List<Map<String, dynamic>>.from(gltf['nodes'] as List);
    final skinJointNames = (gltf['skins'] as List)
        .whereType<Map<String, dynamic>>()
        .expand((skin) => skin['joints'] as List)
        .whereType<int>()
        .map((index) => nodes[index]['name'])
        .whereType<String>()
        .toSet();
    final primitives = (gltf['meshes'] as List)
        .whereType<Map<String, dynamic>>()
        .expand((mesh) => mesh['primitives'] as List)
        .whereType<Map<String, dynamic>>();

    expect(skinJointNames, isNotEmpty);
    expect(
      primitives.every((primitive) {
        final attributes = primitive['attributes'] as Map<String, dynamic>;
        return attributes.containsKey('JOINTS_0') &&
            attributes.containsKey('WEIGHTS_0');
      }),
      isTrue,
    );
  });

  test('mapped finger and body joints exist and have animation channels', () {
    final nodes = List<Map<String, dynamic>>.from(gltf['nodes'] as List);
    final jointNames = (gltf['skins'] as List)
        .whereType<Map<String, dynamic>>()
        .expand((skin) => skin['joints'] as List)
        .whereType<int>()
        .map((index) => nodes[index]['name'])
        .whereType<String>()
        .toSet();
    final fingerNames = <String>{};
    for (final hand
        in (rig['fingers'] as Map<String, dynamic>).values
            .whereType<Map<String, dynamic>>()) {
      for (final chain in hand.values.whereType<List>()) {
        fingerNames.addAll(chain.whereType<String>());
      }
    }
    final bodyNames = (rig['body_joints'] as List).whereType<String>().toSet();
    final animatedRotationNames = <String>{};
    for (final animation
        in (gltf['animations'] as List).whereType<Map<String, dynamic>>()) {
      for (final channel
          in (animation['channels'] as List)
              .whereType<Map<String, dynamic>>()) {
        final target = channel['target'] as Map<String, dynamic>;
        final node = target['node'];
        if (target['path'] == 'rotation' && node is int) {
          animatedRotationNames.add(nodes[node]['name'] as String);
        }
      }
    }

    expect(fingerNames, hasLength(30));
    expect(fingerNames.difference(jointNames), isEmpty);
    expect(fingerNames.difference(animatedRotationNames), isEmpty);
    expect(bodyNames.difference(jointNames), isEmpty);
    expect(bodyNames.difference(animatedRotationNames), isEmpty);
  });

  test('face morph map is present and GLB contains a weight animation', () {
    final faceNames = (rig['face_shapes'] as List).whereType<String>().toSet();
    final meshes = (gltf['meshes'] as List).whereType<Map<String, dynamic>>();
    final targets = meshes
        .expand(
          (mesh) =>
              (mesh['extras'] as Map<String, dynamic>)['targetNames'] as List,
        )
        .whereType<String>()
        .toSet();
    final nodes = List<Map<String, dynamic>>.from(gltf['nodes'] as List);
    final hasWeightTrack = (gltf['animations'] as List)
        .whereType<Map<String, dynamic>>()
        .expand((animation) => animation['channels'] as List)
        .whereType<Map<String, dynamic>>()
        .any((channel) {
          final target = channel['target'] as Map<String, dynamic>;
          final index = target['node'];
          return target['path'] == 'weights' &&
              index is int &&
              nodes[index].containsKey('mesh');
        });

    expect(faceNames, hasLength(175));
    expect(faceNames.difference(targets), isEmpty);
    expect(hasWeightTrack, isTrue);
  });

  test(
    'diagnostic animation clips are not presented as ASL catalog signs',
    () async {
      final manifest = jsonDecode(
        await rootBundle.loadString('assets/animations/asl/manifest.json'),
      ) as Map<String, dynamic>;
      final animations = (gltf['animations'] as List)
          .whereType<Map<String, dynamic>>()
          .map((animation) => animation['name'] as String)
          .toSet();
      final catalogClipIds = (manifest['signs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((sign) => sign['clipId'])
          .whereType<String>()
          .toSet();

      expect(animations.where((name) => name.startsWith('QA_')), hasLength(2));
      expect(catalogClipIds, isEmpty);
      expect(catalogClipIds.intersection(animations), isEmpty);
    },
  );
}
