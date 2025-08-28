import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/widgets/bordered_thumb_shape.dart';
import 'package:vidio/src/widgets/uniform_rounded_track_shape.dart';
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
  void dispose() {
    widget.controller.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration.inMilliseconds.toDouble();
    if (duration <= 0) return const SizedBox();

    // Create a key based on cached ranges to force rebuild when ranges change
    final rangesKey = widget.cachedRanges?.map((r) => '${r.startByte}-${r.endByte}').join(',') ?? '';

    return Stack(
      alignment: Alignment.center,
      children: [
        // Cached ranges background
        if (widget.cachedRanges != null && widget.cachedRanges!.isNotEmpty)
          _buildCachedRangesOverlay(duration),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            trackShape: const UniformRoundedTrackShape(),
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
              setState(() {
                _currentValue = value;
              });
            },
            onChangeEnd: (value) {
              _isUserInteracting = false;
              widget.controller.seekTo(Duration(milliseconds: value.round()));
            },
          ),
        ),
        // Caching progress overlay
        if (widget.cachingProgress != null && widget.cachingProgress!.isVisible)
          Positioned(
            bottom: -8,
            left: 0,
            right: 0,
            child: CachingProgressWidget(
              progress: widget.cachingProgress!.progress,
              showLogs: false, // Don't show logs in progress bar overlay
              logs: widget.cachingProgress!.logs,
              progressColor: Colors.blue.withOpacity(0.8),
              backgroundColor: Colors.grey.withOpacity(0.3),
              textColor: Colors.white,
              height: 3.0,
              showPercentage: true,
              percentageTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Builds overlay showing cached ranges as segments
  Widget _buildCachedRangesOverlay(double totalDuration) {
    if (widget.cachedRanges == null || widget.cachedRanges!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = 10.0; // Match slider track height

          return Stack(
            children: widget.cachedRanges!.map((range) {
              // Convert byte ranges to time-based progress
              final startProgress = _byteToProgress(range.startByte, totalDuration);
              final endProgress = _byteToProgress(range.endByte, totalDuration);

              final left = startProgress * width;
              final rangeWidth = (endProgress - startProgress) * width;

              return Positioned(
                left: left,
                top: 0,
                width: rangeWidth,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.4), // Light blue for cached portions
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
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
    if (widget.cachedRanges == null || widget.cachedRanges!.isEmpty) {
      // Rough estimation: assume 500KB per minute (typical for video)
      const bytesPerMinute = 30000000; // 30MB per minute
      return ((totalDurationMs / 60000) * bytesPerMinute).toInt();
    }

    // Use the highest byte position from cached ranges as estimation
    var maxByte = 0;
    for (final range in widget.cachedRanges!) {
      if (range.endByte > maxByte) {
        maxByte = range.endByte;
      }
    }

    // Assume the file is at least 20% larger than the highest cached byte
    return (maxByte * 1.2).toInt();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
