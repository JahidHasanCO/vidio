import 'package:flutter/material.dart';
import 'package:vidio/src/model/model.dart';

/// Custom track shape that draws cached ranges
/// as white segments on grey background
class CachedProgressTrackShape extends RoundedRectSliderTrackShape {
  const CachedProgressTrackShape({
    required this.totalDuration,
    this.cachedRanges,
  });

  final List<CachedRange>? cachedRanges;
  final double totalDuration;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = true,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeTrackColor = sliderTheme.activeTrackColor!;
    final inactiveTrackColor = sliderTheme.inactiveTrackColor!;
    final trackRadius = Radius.circular(trackRect.height / 2);

    // Paint the full track with inactive color (grey)
    final paint = Paint()..color = inactiveTrackColor;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      paint,
    );

    // Paint cached ranges as white segments
    if (cachedRanges != null && cachedRanges!.isNotEmpty && totalDuration > 0) {
      final cachedPaint = Paint()..color = Colors.white.withOpacity(0.9);

      for (final range in cachedRanges!) {
        final startProgress = _byteToProgress(range.startByte, totalDuration);
        final endProgress = _byteToProgress(range.endByte, totalDuration);

        final startX = trackRect.left + (startProgress * trackRect.width);
        final endX = trackRect.left + (endProgress * trackRect.width);

        if (endX > startX) {
          final cachedRect =
              Rect.fromLTRB(startX, trackRect.top, endX, trackRect.bottom);
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(cachedRect, trackRadius),
            cachedPaint,
          );
        }
      }
    }

    // Paint the active track (played portion) in orange
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );

    if (activeRect.width > 0) {
      final activePaint = Paint()..color = activeTrackColor;
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, trackRadius),
        activePaint,
      );
    }
  }

  /// Converts byte position to progress
  /// (0.0 to 1.0) based on estimated file size
  double _byteToProgress(int bytePosition, double totalDurationMs) {
    if (totalDurationMs <= 0) return 0;

    // Estimate bytes per millisecond based on current cached ranges
    final estimatedTotalBytes = _estimateTotalBytes(totalDurationMs);

    if (estimatedTotalBytes <= 0) return 0;

    return (bytePosition / estimatedTotalBytes).clamp(0.0, 1.0);
  }

  /// Estimates total bytes based on cached ranges and duration
  int _estimateTotalBytes(double totalDurationMs) {
    if (cachedRanges == null || cachedRanges!.isEmpty) {
      // Use same estimation as video player: 50MB per minute for video files
      const bytesPerMinute = 50000000; // 50MB per minute
      return ((totalDurationMs / 60000) * bytesPerMinute).toInt();
    }

    // Use the highest byte position from cached ranges as estimation
    var maxByte = 0;
    for (final range in cachedRanges!) {
      if (range.endByte > maxByte) {
        maxByte = range.endByte;
      }
    }

    // Assume the file is at least 20% larger than the highest cached byte
    return (maxByte * 1.2).toInt();
  }
}
