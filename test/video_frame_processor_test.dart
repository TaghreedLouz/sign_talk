import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_talk/features/camera/video_frame_processor.dart';

void main() {
  test(
    'video timestamps are increasing and stay inside the source duration',
    () {
      expect(
        VideoFrameProcessor.timestampsForDuration(101, frameIntervalMs: 33),
        [0, 33, 66, 99],
      );
    },
  );

  test(
    'video processor preserves source timestamps and processes in order',
    () async {
      final seen = <int>[];
      final progress = <(int, int)>[];
      final processor = VideoFrameProcessor(
        frameIntervalMs: 10,
        loadFrame: (path, timestampMs) async =>
            Uint8List.fromList([timestampMs]),
        decodeFrame: (encoded) async =>
            RgbaVideoFrame(pixels: encoded, width: 1, height: 1),
      );

      final result = await processor.process(
        path: 'local-video.mp4',
        durationMs: 25,
        isCancelled: () => false,
        onFrame: (timestampMs, frame) async {
          seen.add(timestampMs);
          expect(frame.pixels.single, timestampMs);
        },
        onProgress: (processed, total) => progress.add((processed, total)),
      );

      expect(result.processedFrames, 3);
      expect(result.cancelled, isFalse);
      expect(seen, [0, 10, 20]);
      expect(progress.last, (3, 3));
    },
  );

  test(
    'video processor stops after cancellation without scheduling later frames',
    () async {
      var cancelled = false;
      final extracted = <int>[];
      final processed = <int>[];
      final processor = VideoFrameProcessor(
        frameIntervalMs: 10,
        loadFrame: (path, timestampMs) async {
          extracted.add(timestampMs);
          return Uint8List.fromList([timestampMs]);
        },
        decodeFrame: (encoded) async =>
            RgbaVideoFrame(pixels: encoded, width: 1, height: 1),
      );

      final result = await processor.process(
        path: 'local-video.mp4',
        durationMs: 50,
        isCancelled: () => cancelled,
        onFrame: (timestampMs, _) async {
          processed.add(timestampMs);
          cancelled = true;
        },
      );

      expect(result.cancelled, isTrue);
      expect(result.processedFrames, 1);
      expect(extracted, [0]);
      expect(processed, [0]);
    },
  );

  test('rejects empty duration and invalid frame interval', () {
    expect(
      () => VideoFrameProcessor.timestampsForDuration(0),
      throwsArgumentError,
    );
    expect(
      () => VideoFrameProcessor.timestampsForDuration(100, frameIntervalMs: 0),
      throwsArgumentError,
    );
  });
}
