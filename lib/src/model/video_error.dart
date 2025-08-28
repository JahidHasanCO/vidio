import 'package:vidio/src/enum/video_error_type.dart';

/// Represents a video player error with context
class VideoError {
  VideoError({
    required this.type,
    required this.error,
    this.stackTrace,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final VideoErrorType type;
  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final DateTime timestamp;

  @override
  String toString() {
    return 'VideoError(type: $type, error: $error,'
        ' context: $context, timestamp: $timestamp)';
  }
}
