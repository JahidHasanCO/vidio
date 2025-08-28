/// Result of a performance measurement
class PerformanceResult<T> {
  PerformanceResult({
    required this.result,
    required this.executionTime,
    this.operationName,
    this.error,
  });

  final T? result;
  final Duration executionTime;
  final String? operationName;
  final dynamic error;

  bool get hasError => error != null;

  @override
  String toString() {
    return 'PerformanceResult(operation: $operationName, '
        'time: $executionTime, hasError: $hasError)';
  }
}
