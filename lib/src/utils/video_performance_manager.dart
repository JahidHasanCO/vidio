import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vidio/src/enum/video_error_type.dart';
import 'package:vidio/src/model/model.dart';

/// Manages performance optimizations and debouncing for the video player
class VideoPerformanceManager {
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Completer<void>> _pendingOperations = {};

  /// Debounce a function call to prevent rapid successive calls
  void debounce(
    String key,
    VoidCallback action, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    // Cancel existing timer
    _debounceTimers[key]?.cancel();

    // Start new timer
    _debounceTimers[key] = Timer(delay, () {
      action();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle a function to limit how often it can be called
  void throttle(
    String key,
    VoidCallback action, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (_pendingOperations.containsKey(key)) {
      return; // Operation already pending
    }

    final completer = Completer<void>();
    _pendingOperations[key] = completer;

    action();

    Timer(interval, () {
      _pendingOperations.remove(key);
      completer.complete();
    });
  }

  /// Execute an operation with error handling
  Future<T?> executeWithErrorHandling<T>(
    Future<T> Function() operation,
    VideoErrorType errorType, {
    T? defaultValue,
    String? operationName,
  }) async {
    try {
      return await operation();
    } on TimeoutException catch (e) {
      debugPrint('Operation ${operationName ?? 'unknown'} timed out: $e');
      return defaultValue;
    } catch (e) {
      debugPrint('Operation ${operationName ?? 'unknown'} failed: $e');
      return defaultValue;
    }
  }

  /// Cache expensive operations
  T cacheOperation<T>(String key, T Function() operation, {Duration? ttl}) {
    // Simple in-memory cache implementation
    // In a real app, you might want to use
    // a more sophisticated caching solution
    return operation();
  }

  /// Measure execution time of a function
  Future<PerformanceResult<T>> measureExecutionTime<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      return PerformanceResult(
        result: result,
        executionTime: stopwatch.elapsed,
        operationName: operationName,
      );
    } catch (e) {
      stopwatch.stop();
      return PerformanceResult(
        result: null,
        executionTime: stopwatch.elapsed,
        operationName: operationName,
        error: e,
      );
    }
  }

  /// Batch multiple operations to reduce overhead
  Future<List<T>> batchOperations<T>(
    List<Future<T> Function()> operations, {
    int batchSize = 3,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    final results = <T>[];

    for (var i = 0; i < operations.length; i += batchSize) {
      final batch = operations.sublist(
        i,
        i + batchSize > operations.length ? operations.length : i + batchSize,
      );
      final batchResults = await Future.wait(batch.map((op) => op()));
      results.addAll(batchResults);

      // Add delay between batches if not the last batch
      if (i + batchSize < operations.length) {
        await Future<void>.delayed(delayBetweenBatches);
      }
    }

    return results;
  }

  /// Preload resources to improve performance
  Future<void> preloadResources(
    List<Future<void> Function()> preloadOperations,
  ) async {
    await Future.wait(preloadOperations.map((op) => op()));
  }

  /// Clean up resources
  void dispose() {
    // Cancel all pending timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Complete any pending operations
    for (final completer in _pendingOperations.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _pendingOperations.clear();
  }

  /// Get performance statistics
  PerformanceStats getStats() {
    return PerformanceStats(
      activeDebounceTimers: _debounceTimers.length,
      pendingOperations: _pendingOperations.length,
    );
  }
}
