import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/cache/video_cache_manager.dart';
import 'package:vidio/src/utils/package_utils/file_utils.dart';

/// Utility class for video controller initialization and setup
class VideoInitializer {
  VideoInitializer._();

  /// Creates a video controller based on video format and source
  static Future<VideoPlayerController?> createVideoController({
    required String url,
    required String? videoFormat,
    required bool isOffline,
    Map<String, String>? headers,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    bool allowCacheFile = false,
    void Function(List<File>?)? onCacheFileCompleted,
    void Function(dynamic)? onCacheFileFailed,
  }) async {
    VideoPlayerController? controller;

    if (!isOffline) {
      if (videoFormat == 'MP4' || videoFormat == 'WEBM') {
        // Play MP4 and WEBM video
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          formatHint:
              videoFormat == 'MP4' ? VideoFormat.other : VideoFormat.other,
          httpHeaders: headers ?? {},
          closedCaptionFile: closedCaptionFile != null
              ? Future.value(closedCaptionFile)
              : null,
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
      // Offline video playback - check for cached content first
      final cachedFile = await _findCachedVideoFile(url, videoFormat);
      if (cachedFile != null && cachedFile.existsSync()) {
        if (kDebugMode) {
          print('DEBUG: Playing from cached file: ${cachedFile.path}');
        }
        controller = VideoPlayerController.file(cachedFile);
      } else {
        if (kDebugMode) {
          print('DEBUG: No cached file found for offline playback, trying URL as file path: $url');
        }
        // Fallback to trying the URL as a file path
        final file = File(url);
        if (file.existsSync()) {
          controller = VideoPlayerController.file(file);
        } else {
          if (kDebugMode) {
            print('DEBUG: File does not exist: $url');
          }
          controller = null; // No valid file found
        }
      }
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

  /// Finds cached video file for offline playback
  static Future<File?> _findCachedVideoFile(String url, String? videoFormat) async {
    try {
      final quality = videoFormat?.toLowerCase();
      final cachedFile = await VideoCacheManager().getCachedFile(url, quality: quality);
      return cachedFile;
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error finding cached file: $e');
      }
      return null;
    }
  }
}
