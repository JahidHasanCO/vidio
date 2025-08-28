import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/model/model.dart';
import 'package:vidio/src/widgets/bordered_thumb_shape.dart';
import 'package:vidio/src/widgets/cached_progress_track_shape.dart';

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
    final rangesKey = widget.cachedRanges
            ?.map((r) => '${r.startByte}-${r.endByte}')
            .join(',') ??
        '';

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
        key: ValueKey('slider_$rangesKey'),
        // Force rebuild when ranges change
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
