import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vidio/src/enum/video_error_type.dart';
import 'package:vidio/src/model/video_error.dart';

/// Manages error handling and reporting for the video player
class VideoErrorHandler {
  final List<VideoError> _errors = [];
  final StreamController<VideoError> _errorStreamController =
      StreamController<VideoError>.broadcast();

  /// Stream of errors for external listeners
  Stream<VideoError> get errorStream => _errorStreamController.stream;

  /// Get all errors that have occurred
  List<VideoError> get errors => List.unmodifiable(_errors);

  /// Get the latest error
  VideoError? get latestError => _errors.isNotEmpty ? _errors.last : null;

  /// Handle initialization errors
  void handleInitializationError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.initialization,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Video controller initialization failed',
    );
    _addError(videoError);
  }

  /// Handle playback errors
  void handlePlaybackError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.playback,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Video playback failed',
    );
    _addError(videoError);
  }

  /// Handle network errors
  void handleNetworkError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.network,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Network error occurred',
    );
    _addError(videoError);
  }

  /// Handle parsing errors
  void handleParsingError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.parsing,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Failed to parse video data',
    );
    _addError(videoError);
  }

  /// Handle caching errors
  void handleCachingError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.caching,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Video caching failed',
    );
    _addError(videoError);
  }

  /// Handle unknown errors
  void handleUnknownError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
  ]) {
    final videoError = VideoError(
      type: VideoErrorType.unknown,
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'An unknown error occurred',
    );
    _addError(videoError);
  }

  /// Add an error to the collection and notify listeners
  void _addError(VideoError error) {
    _errors.add(error);
    _errorStreamController.add(error);

    // Log error in debug mode
    if (kDebugMode) {
      debugPrint('VideoError: $error');
      if (error.stackTrace != null) {
        debugPrint('StackTrace: ${error.stackTrace}');
      }
    }
  }

  /// Clear all errors
  void clearErrors() {
    _errors.clear();
  }

  /// Get errors of a specific type
  List<VideoError> getErrorsByType(VideoErrorType type) {
    return _errors.where((error) => error.type == type).toList();
  }

  /// Get errors within a time range
  List<VideoError> getErrorsInRange(DateTime start, DateTime end) {
    return _errors
        .where(
          (error) =>
              error.timestamp.isAfter(start) && error.timestamp.isBefore(end),
        )
        .toList();
  }

  /// Check if there are any errors
  bool hasErrors() => _errors.isNotEmpty;

  /// Check if there are errors of a specific type
  bool hasErrorsOfType(VideoErrorType type) {
    return _errors.any((error) => error.type == type);
  }

  /// Get error count
  int getErrorCount() => _errors.length;

  /// Dispose of resources
  void dispose() {
    _errorStreamController.close();
  }

  /// Execute a function with error handling
  Future<T?> executeWithErrorHandling<T>(
    Future<T> Function() function,
    VideoErrorType errorType, [
    String? context,
  ]) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      _handleErrorByType(errorType, error, stackTrace, context);
      return null;
    }
  }

  /// Execute a synchronous function with error handling
  T? executeSyncWithErrorHandling<T>(
    T Function() function,
    VideoErrorType errorType, [
    String? context,
  ]) {
    try {
      return function();
    } catch (error, stackTrace) {
      _handleErrorByType(errorType, error, stackTrace, context);
      return null;
    }
  }

  /// Handle error based on type
  void _handleErrorByType(
    VideoErrorType type,
    dynamic error,
    StackTrace stackTrace,
    String? context,
  ) {
    switch (type) {
      case VideoErrorType.initialization:
        handleInitializationError(error, stackTrace, context);
      case VideoErrorType.playback:
        handlePlaybackError(error, stackTrace, context);
      case VideoErrorType.network:
        handleNetworkError(error, stackTrace, context);
      case VideoErrorType.parsing:
        handleParsingError(error, stackTrace, context);
      case VideoErrorType.caching:
        handleCachingError(error, stackTrace, context);
      case VideoErrorType.unknown:
        handleUnknownError(error, stackTrace, context);
    }
  }
}
