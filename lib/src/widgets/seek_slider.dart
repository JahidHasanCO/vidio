import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/widgets/bordered_thumb_shape.dart';
import 'package:vidio/src/widgets/caching_progress_widget.dart';
import 'package:vidio/src/video_cache_manager.dart';

class SeekSlider extends StatefulWidget {
  const SeekSlider({
    required this.controller,
    super.key,
    this.colors,
    this.cachingProgress,
    this.cachedRanges,
  });
  final VideoPlayerController controller;
  final VideoProgressColors? colors;
  final CachingProgressData? cachingProgress;
  final List<CachedRange>? cachedRanges;

  @override
  State<SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<SeekSlider> {
  double _currentValue = 0;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();

    // Update slider position as video plays
    widget.controller.addListener(listener);
  }

  void listener() {
    if (!_isUserInteracting && widget.controller.value.isInitialized) {
      final duration =
          widget.controller.value.duration.inMilliseconds.toDouble();
      final position =
          widget.controller.value.position.inMilliseconds.toDouble();
      if (!mounted) return;
      setState(() {
        _currentValue = position.clamp(0.0, duration);
      });
    }
  }

  @override
  void didUpdateWidget(SeekSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild when cached ranges change
    if (oldWidget.cachedRanges?.length != widget.cachedRanges?.length) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration.inMilliseconds.toDouble();
    if (duration <= 0) return const SizedBox();

    // Create a key based on cached ranges to force rebuild when ranges change
    final rangesKey = widget.cachedRanges?.map((r) => '${r.startByte}-${r.endByte}').join(',') ?? '';

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 10,
        trackShape: CachedProgressTrackShape(
          cachedRanges: widget.cachedRanges,
          totalDuration: duration,
        ),
        activeTrackColor: widget.colors?.playedColor ?? const Color(0xffff6600),
        inactiveTrackColor: widget.colors?.backgroundColor ?? Colors.grey[400],
        secondaryActiveTrackColor:
            widget.colors?.bufferedColor ?? Colors.grey[600],
        thumbShape: BorderedThumbShape(
          centerColor: widget.colors?.playedColor ?? const Color(0xffff6600),
          borderWidth: 6,
        ),
        thumbColor: widget.colors?.playedColor ?? const Color(0xffff6600),
        overlayColor: (widget.colors?.playedColor ?? const Color(0xffff6600))
            .withOpacity(0.2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        tickMarkShape: const RoundSliderTickMarkShape(),
        activeTickMarkColor: Colors.pinkAccent,
        inactiveTickMarkColor: Colors.white,
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: Colors.black,
        valueIndicatorTextStyle:
            const TextStyle(color: Colors.white, fontSize: 16),
      ),
      child: Slider(
        key: ValueKey('slider_$rangesKey'), // Force rebuild when ranges change
        max: duration,
        value: _currentValue,
        label: _formatDuration(Duration(milliseconds: _currentValue.round())),
        onChangeStart: (_) {
          _isUserInteracting = true;
        },
        onChanged: (value) {
          if (mounted) {
            setState(() {
              _currentValue = value;
            });
          }
        },
        onChangeEnd: (value) {
          _isUserInteracting = false;
          widget.controller.seekTo(Duration(milliseconds: value.round()));
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Custom track shape that draws cached ranges as white segments on grey background
class CachedProgressTrackShape extends RoundedRectSliderTrackShape {
  final List<CachedRange>? cachedRanges;
  final double totalDuration;

  const CachedProgressTrackShape({
    this.cachedRanges,
    required this.totalDuration,
  });

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
    final Rect trackRect = getPreferredRect(
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
    final Paint paint = Paint()..color = inactiveTrackColor;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      paint,
    );

    // Paint cached ranges as white segments
    if (cachedRanges != null && cachedRanges!.isNotEmpty && totalDuration > 0) {
      final Paint cachedPaint = Paint()..color = Colors.white.withOpacity(0.9);

      for (final range in cachedRanges!) {
        final startProgress = _byteToProgress(range.startByte, totalDuration);
        final endProgress = _byteToProgress(range.endByte, totalDuration);

        final startX = trackRect.left + (startProgress * trackRect.width);
        final endX = trackRect.left + (endProgress * trackRect.width);

        if (endX > startX) {
          final cachedRect = Rect.fromLTRB(startX, trackRect.top, endX, trackRect.bottom);
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
      final Paint activePaint = Paint()..color = activeTrackColor;
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, trackRadius),
        activePaint,
      );
    }
  }

  /// Converts byte position to progress (0.0 to 1.0) based on estimated file size
  double _byteToProgress(int bytePosition, double totalDurationMs) {
    if (totalDurationMs <= 0) return 0.0;

    // Estimate bytes per millisecond based on current cached ranges
    final estimatedTotalBytes = _estimateTotalBytes(totalDurationMs);

    if (estimatedTotalBytes <= 0) return 0.0;

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
