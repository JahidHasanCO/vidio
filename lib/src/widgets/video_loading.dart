import 'package:flutter/material.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/widgets/caching_progress_widget.dart';
import 'package:vidio/vidio.dart';

/// A widget for loading UI that use while waiting for the video to load.
class VideoLoading extends StatelessWidget {
  /// Constructor
  const VideoLoading({
    super.key,
    this.loadingStyle,
    this.cachingProgress,
  });

  /// A model class to provide the custom style for the loading widget.
  final VideoLoadingStyle? loadingStyle;

  /// Caching progress data to display when allowCacheFile is enabled
  final CachingProgressData? cachingProgress;

  @override
  Widget build(BuildContext context) {
    return loadingStyle?.loading ??
        ColoredBox(
          color: loadingStyle?.loadingBackgroundColor ?? Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    loadingStyle?.loadingIndicatorValueColor ?? Colors.amber,
                  ),
                  backgroundColor: loadingStyle?.loadingIndicatorBgColor,
                  color: loadingStyle?.loadingIndicatorColor,
                  strokeWidth: loadingStyle?.loadingIndicatorWidth ?? 4.0,
                  semanticsLabel: loadingStyle?.indicatorSemanticsLabel,
                  semanticsValue: loadingStyle?.indicatorSemanticsValue,
                  value: loadingStyle?.indicatorInitialValue,
                ),
                SizedBox(
                  height: loadingStyle?.spaceBetweenIndicatorAndText ?? 8.0,
                ),
                Visibility(
                  visible: loadingStyle?.showLoadingText ?? true,
                  child: Text(
                    loadingStyle?.loadingText ?? 'Loading...',
                    style: loadingStyle?.loadingTextStyle,
                  ),
                ),
                // Show caching progress if available
                if (cachingProgress != null && cachingProgress!.isVisible) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: CachingProgressWidget(
                      progress: cachingProgress!.progress,
                      logs: cachingProgress!.logs,
                      height: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  }
}
