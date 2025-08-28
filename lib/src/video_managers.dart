import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_initializer.dart';
import 'package:vidio/src/utils/video_parser.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages video controller initialization, playback, and quality selection
class VideoControllerManager {
  VideoPlayerController? controller;
  final Map<String, String>? headers;
  final Future<ClosedCaptionFile>? closedCaptionFile;
  final VideoPlayerOptions? videoPlayerOptions;
  final bool allowCacheFile;
  final void Function(List<File>? files)? onCacheFileCompleted;
  final void Function(dynamic error)? onCacheFileFailed;
  final void Function(VideoPlayerController controller)? onVideoInitCompleted;

  VideoControllerManager({
    this.headers,
    this.closedCaptionFile,
    this.videoPlayerOptions,
    this.allowCacheFile = false,
    this.onCacheFileCompleted,
    this.onCacheFileFailed,
    this.onVideoInitCompleted,
  });

  Future<void> initializeController(
    String url,
    String? videoFormat,
    bool? isOffline,
    double playbackSpeed,
    Duration? lastPlayedPos,
  ) async {
    controller = VideoInitializer.createVideoController(
      url: url,
      videoFormat: videoFormat,
      isOffline: isOffline ?? false,
      headers: headers,
      closedCaptionFile: closedCaptionFile,
      videoPlayerOptions: videoPlayerOptions,
      allowCacheFile: allowCacheFile,
      onCacheFileCompleted: onCacheFileCompleted,
      onCacheFileFailed: onCacheFileFailed,
    );

    await controller?.initialize();
    controller?.setPlaybackSpeed(playbackSpeed);
    if (lastPlayedPos != null) {
      await controller?.seekTo(lastPlayedPos);
    }
    onVideoInitCompleted?.call(controller!);
  }

  Future<void> playLocalM3U8File(String url) async {
    controller?.dispose();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      closedCaptionFile: closedCaptionFile,
      videoPlayerOptions: videoPlayerOptions,
      httpHeaders: headers ?? const <String, String>{},
    );
    await controller?.initialize();
    await controller?.play();
  }

  void setPlaybackSpeed(double speed) {
    controller?.setPlaybackSpeed(speed);
  }

  void setLooping(bool loop) {
    controller?.setLooping(loop);
  }

  Future<void> play() async {
    await controller?.play();
  }

  Future<void> pause() async {
    await controller?.pause();
  }

  Future<void> seekTo(Duration position) async {
    await controller?.seekTo(position);
  }

  Future<void> rewind() async {
    await controller?.rewind();
  }

  Future<void> fastForward() async {
    await controller?.fastForward();
  }

  void addListener(VoidCallback listener) {
    controller?.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    controller?.removeListener(listener);
  }

  void dispose() {
    controller?.dispose();
  }
}

/// Manages M3U8 playlist parsing and quality selection
class M3U8Manager {
  List<M3U8Data> m3u8UrlList = [];
  List<AudioModel> audioList = [];
  String m3u8Quality = 'Auto';

  Future<M3U8s?> parseM3U8Playlist(
    String? videoUrl,
    Map<String, String>? headers,
    bool allowCacheFile,
    void Function(List<File>? files)? onCacheFileCompleted,
    void Function(dynamic error)? onCacheFileFailed,
  ) async {
    final result = await VideoParser.parseM3U8Playlist(
      videoUrl: videoUrl,
      m3u8UrlList: m3u8UrlList,
      audioList: audioList,
      headers: headers,
      allowCacheFile: allowCacheFile,
      onCacheFileCompleted: onCacheFileCompleted,
      onCacheFileFailed: onCacheFileFailed,
    );
    return result;
  }

  Future<void> cleanM3U8Files() async {
    for (var i = 2; i < m3u8UrlList.length; i++) {
      try {
        final file = await FileUtils.readFileFromPath(
          videoUrl: m3u8UrlList[i].dataURL ?? '',
          quality: m3u8UrlList[i].dataQuality ?? '',
        );
        final exists = file?.existsSync();
        if (exists ?? false) {
          await file?.delete();
        }
      } catch (e) {
        rethrow;
      }
    }
    audioList.clear();
    m3u8UrlList.clear();
  }

  void setQuality(String quality) {
    m3u8Quality = quality;
  }
}

/// Manages video playback state and controls
class VideoPlaybackManager {
  bool isPlaying = false;
  bool loop = false;
  double playbackSpeed = 1.0;
  List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  Duration? lastPlayedPos;
  bool isAtLivePosition = true;

  void togglePlay(VideoPlayerController? controller) {
    if (controller?.value.isPlaying == true) {
      controller?.pause();
    } else {
      controller?.play();
    }
  }

  void setPlaybackSpeed(double speed, VideoPlayerController? controller) {
    playbackSpeed = speed;
    controller?.setPlaybackSpeed(speed);
  }

  void setLooping(bool loop, VideoPlayerController? controller) {
    this.loop = loop;
    controller?.setLooping(loop);
  }

  Future<void> manageWakelock(VideoPlayerController? controller) async {
    if (controller?.value.isInitialized == true && controller?.value.isPlaying == true) {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
      }
    } else {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
      }
    }
  }
}