/// Performance statistics
class PerformanceStats {
  PerformanceStats({
    required this.activeDebounceTimers,
    required this.pendingOperations,
  });

  final int activeDebounceTimers;
  final int pendingOperations;

  @override
  String toString() {
    return 'PerformanceStats(debounceTimers: '
        '$activeDebounceTimers, pendingOps: $pendingOperations)';
  }
}
