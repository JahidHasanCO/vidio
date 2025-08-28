import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_initializer.dart';

/// Manages video controller initialization, playback, and quality selection
class VideoControllerManager {
  VideoControllerManager({
    this.headers,
    this.closedCaptionFile,
    this.videoPlayerOptions,
    this.allowCacheFile = false,
    this.onCacheFileCompleted,
    this.onCacheFileFailed,
    this.onVideoInitCompleted,
  });

  VideoPlayerController? controller;
  final Map<String, String>? headers;
  final Future<ClosedCaptionFile>? closedCaptionFile;
  final VideoPlayerOptions? videoPlayerOptions;
  final bool allowCacheFile;
  final void Function(List<File>? files)? onCacheFileCompleted;
  final void Function(dynamic error)? onCacheFileFailed;
  final void Function(VideoPlayerController controller)? onVideoInitCompleted;

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
    await controller?.setPlaybackSpeed(playbackSpeed);
    if (lastPlayedPos != null) {
      await controller?.seekTo(lastPlayedPos);
    }
    onVideoInitCompleted?.call(controller!);
  }

  Future<void> playLocalM3U8File(String url) async {
    await controller?.dispose();
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
