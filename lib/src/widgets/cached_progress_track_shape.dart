import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        print('DEBUG: CachedProgressTrackShape painting ${cachedRanges!.length} ranges');
      }
      final cachedPaint = Paint()..color = Colors.white.withOpacity(0.9);

      for (final range in cachedRanges!) {
        final startProgress = _byteToProgress(range.startByte, totalDuration);
        final endProgress = _byteToProgress(range.endByte, totalDuration);

        if (kDebugMode) {
          print('DEBUG: Painting range ${range.startByte}-${range.endByte} '
              'as progress $startProgress to $endProgress');
        }

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

    // Use the estimated total bytes from cached ranges or fallback estimation
    final estimatedTotalBytes = _estimateTotalBytes(totalDurationMs);

    if (estimatedTotalBytes <= 0) return 0;

    // Clamp the result to ensure it's within valid range
    final progress = (bytePosition / estimatedTotalBytes).clamp(0.0, 1.0);

    if (kDebugMode && progress > 0) {
      print('DEBUG: Byte $bytePosition -> Progress $progress (total bytes: $estimatedTotalBytes)');
    }

    return progress;
  }

  /// Estimates total bytes based on cached ranges and duration
  int _estimateTotalBytes(double totalDurationMs) {
    if (cachedRanges == null || cachedRanges!.isEmpty) {
      // Use same estimation as video player: 50MB per minute for video files
      const bytesPerMinute = 50000000; // 50MB per minute
      return ((totalDurationMs / 60000) * bytesPerMinute).toInt();
    }

    // Find the maximum byte position from all cached ranges
    var maxByte = 0;
    var totalCachedBytes = 0;

    for (final range in cachedRanges!) {
      if (range.endByte > maxByte) {
        maxByte = range.endByte;
      }
      totalCachedBytes += range.size;
    }

    // If we have significant cached data, use it to estimate total file size
    if (totalCachedBytes > 1000000) { // More than 1MB cached
      // Assume the file is 2-3x larger than what's been cached so far
      final estimatedTotal = (maxByte * 2.5).toInt();
      if (kDebugMode) {
        print('DEBUG: Estimated total bytes from cache: $estimatedTotal (max byte: $maxByte)');
      }
      return estimatedTotal;
    }

    // Fallback to duration-based estimation
    const bytesPerMinute = 50000000; // 50MB per minute
    return ((totalDurationMs / 60000) * bytesPerMinute).toInt();
  }
}
