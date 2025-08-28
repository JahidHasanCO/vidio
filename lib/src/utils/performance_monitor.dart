/// Utility class for performance monitoring
class PerformanceMonitor {
  static final Map<String, List<Duration>> _measurements = {};

  /// Record a performance measurement
  static void recordMeasurement(String operation, Duration duration) {
    _measurements.putIfAbsent(operation, () => []).add(duration);

    // Keep only last 100 measurements per operation
    if (_measurements[operation]!.length > 100) {
      _measurements[operation]!.removeAt(0);
    }
  }

  /// Get average execution time for an operation
  static Duration getAverageTime(String operation) {
    final measurements = _measurements[operation];
    if (measurements == null || measurements.isEmpty) {
      return Duration.zero;
    }

    final total = measurements.fold<Duration>(
      Duration.zero,
          (sum, duration) => sum + duration,
    );
    return Duration(microseconds: total.inMicroseconds ~/ measurements.length);
  }

  /// Get performance report
  static String getPerformanceReport() {
    final buffer = StringBuffer()
      ..writeln('Performance Report:')
      ..writeln('==================');

    for (final entry in _measurements.entries) {
      final avg = getAverageTime(entry.key);
      buffer.writeln(
        '${entry.key}: ${avg.inMilliseconds}ms '
            '(avg of ${entry.value.length} measurements)',
      );
    }

    return buffer.toString();
  }

  /// Clear all measurements
  static void clearMeasurements() {
    _measurements.clear();
  }
}
