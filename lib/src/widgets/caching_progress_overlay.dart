import 'package:flutter/material.dart';
import 'caching_progress_widget.dart';

/// A widget that overlays caching progress on top of the video progress bar
class CachingProgressOverlay extends StatelessWidget {
  const CachingProgressOverlay({
    super.key,
    required this.cachingProgress,
    this.height = 4.0,
    this.alignment = Alignment.bottomCenter,
    this.margin = const EdgeInsets.symmetric(horizontal: 10),
  });

  final CachingProgressData cachingProgress;
  final double height;
  final Alignment alignment;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    if (!cachingProgress.isVisible) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: margin,
        child: CachingProgressWidget(
          progress: cachingProgress.progress,
          showLogs: false, // Don't show logs in overlay mode
          logs: cachingProgress.logs,
          progressColor: Colors.blue.withOpacity(0.8),
          backgroundColor: Colors.grey.withOpacity(0.5),
          textColor: Colors.white,
          height: height,
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
    );
  }
}
