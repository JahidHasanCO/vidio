/// A model class for caching progress data
class CachingProgressData {
  const CachingProgressData({
    required this.progress,
    this.logs = const [],
    this.isVisible = true,
  });

  final double progress;
  final List<String> logs;
  final bool isVisible;

  CachingProgressData copyWith({
    double? progress,
    List<String>? logs,
    bool? isVisible,
  }) {
    return CachingProgressData(
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}
