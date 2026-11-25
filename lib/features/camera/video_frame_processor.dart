import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:video_thumbnail/video_thumbnail.dart';

typedef VideoFrameLoader = Future<Uint8List?> Function(
  String path,
  int timestampMs,
);
typedef VideoFrameDecoder = Future<RgbaVideoFrame> Function(Uint8List encoded);
typedef VideoFrameHandler = Future<void> Function(
  int timestampMs,
  RgbaVideoFrame frame,
);
typedef VideoProgressHandler = void Function(int processed, int total);

class RgbaVideoFrame {
  const RgbaVideoFrame({
    required this.pixels,
    required this.width,
    required this.height,
  });

  final Uint8List pixels;
  final int width;
  final int height;
}

class VideoProcessingSummary {
  const VideoProcessingSummary({
    required this.processedFrames,
    required this.cancelled,
  });

  final int processedFrames;
  final bool cancelled;
}

/// Sequentially extracts timestamped frames. The default interval is 33 ms
/// (about 30 samples/second) so video inference has stable, increasing times.
class VideoFrameProcessor {
  const VideoFrameProcessor({
    this.loadFrame = _loadVideoFrame,
    this.decodeFrame = decodeJpegToRgba,
    this.frameIntervalMs = 33,
  });

  final VideoFrameLoader loadFrame;
  final VideoFrameDecoder decodeFrame;
  final int frameIntervalMs;

  static List<int> timestampsForDuration(
    int durationMs, {
    int frameIntervalMs = 33,
  }) {
    if (durationMs <= 0 || frameIntervalMs <= 0) {
      throw ArgumentError('Duration and frame interval must be positive.');
    }
    return List<int>.generate(
      (durationMs + frameIntervalMs - 1) ~/ frameIntervalMs,
      (index) => index * frameIntervalMs,
      growable: false,
    );
  }

  Future<VideoProcessingSummary> process({
    required String path,
    required int durationMs,
    required bool Function() isCancelled,
    required VideoFrameHandler onFrame,
    VideoProgressHandler? onProgress,
  }) async {
    if (path.trim().isEmpty) throw ArgumentError('Video path is empty.');
    final timestamps = timestampsForDuration(
      durationMs,
      frameIntervalMs: frameIntervalMs,
    );
    var processed = 0;
    for (final timestampMs in timestamps) {
      if (isCancelled()) {
        return VideoProcessingSummary(
          processedFrames: processed,
          cancelled: true,
        );
      }
      final encoded = await loadFrame(path, timestampMs);
      if (encoded == null || encoded.isEmpty) {
        throw StateError('Could not extract a frame at ${timestampMs}ms.');
      }
      if (isCancelled()) {
        return VideoProcessingSummary(
          processedFrames: processed,
          cancelled: true,
        );
      }
      final frame = await decodeFrame(encoded);
      await onFrame(timestampMs, frame);
      processed++;
      onProgress?.call(processed, timestamps.length);
    }
    return VideoProcessingSummary(processedFrames: processed, cancelled: false);
  }

  static Future<Uint8List?> _loadVideoFrame(String path, int timestampMs) =>
      VideoThumbnail.thumbnailData(
        video: path,
        timeMs: timestampMs,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 90,
      );

  static Future<RgbaVideoFrame> decodeJpegToRgba(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    try {
      final decoded = await codec.getNextFrame();
      final image = decoded.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) throw StateError('Could not decode a video frame.');
        return RgbaVideoFrame(
          pixels: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          width: image.width,
          height: image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
