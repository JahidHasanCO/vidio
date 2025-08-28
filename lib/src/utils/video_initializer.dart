import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/utils/package_utils/file_utils.dart';

/// Utility class for video controller initialization and setup
class VideoInitializer {
  VideoInitializer._();

  /// Creates a video controller based on video format and source
  static VideoPlayerController? createVideoController({
    required String url,
    required String? videoFormat,
    required bool isOffline,
    Map<String, String>? headers,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    bool allowCacheFile = false,
    void Function(List<File>?)? onCacheFileCompleted,
    void Function(dynamic)? onCacheFileFailed,
  }) {
    VideoPlayerController? controller;

    if (!isOffline) {
      if (videoFormat == 'MP4' || videoFormat == 'WEBM') {
        // Play MP4 and WEBM video
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          formatHint: videoFormat == 'MP4' ? VideoFormat.other : VideoFormat.other,
          httpHeaders: headers ?? {},
          closedCaptionFile: closedCaptionFile != null ? Future.value(closedCaptionFile) : null,
          videoPlayerOptions: videoPlayerOptions,
        );
      } else if (videoFormat == 'MKV') {
        // Play MKV video
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          formatHint: VideoFormat.other,
          httpHeaders: headers ?? {},
         closedCaptionFile: closedCaptionFile,
          videoPlayerOptions: videoPlayerOptions,
        );
      } else if (videoFormat == 'HLS') {
        // Play HLS/M3U8 video
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          formatHint: VideoFormat.hls,
          httpHeaders: headers ?? {},
          closedCaptionFile: closedCaptionFile,
          videoPlayerOptions: videoPlayerOptions,
        );
      }

      // Handle caching for MKV format
      if (allowCacheFile && videoFormat == 'MKV') {
        FileUtils.cacheFileToLocalStorage(
          url,
          fileExtension: 'mkv',
          headers: headers,
          onSaveCompleted: (file) {
            onCacheFileCompleted?.call(file != null ? [file] : null);
          },
          onSaveFailed: onCacheFileFailed,
        );
      }
    } else {
      // Offline video playback
      controller = VideoPlayerController.file(File(url));
    }

    return controller;
  }

  /// Initializes and sets up a video controller with listeners
  static Future<VideoPlayerController?> initializeController({
    required VideoPlayerController? controller,
    required void Function() listener,
    bool displayFullScreenAfterInit = false,
    bool autoPlayVideoAfterInit = true,
    void Function(bool)? onFullScreen,
    void Function(VideoPlayerController)? onVideoInitCompleted,
  }) async {
    if (controller == null) return null;

    try {
      await controller.initialize();
      controller.addListener(listener);

      if (displayFullScreenAfterInit) {
        onFullScreen?.call(true);
      }

      if (autoPlayVideoAfterInit) {
        await controller.play();
      }

      onVideoInitCompleted?.call(controller);
      return controller;
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
      return null;
    }
  }

  /// Disposes of a video controller safely
  static Future<void> disposeController(VideoPlayerController? controller) async {
    try {
      await controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing video controller: $e');
    }
  }
}