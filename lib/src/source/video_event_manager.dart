import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/model/models.dart';

/// Manages all video player events and callbacks
class VideoEventManager {
  VideoEventManager({
    this.onBackButtonTap,
    this.onPlayingVideo,
    this.onPlayButtonTap,
    this.onFastForward,
    this.onRewind,
    this.onPause,
    this.onDispose,
    this.onLiveDirectTap,
    this.onShowMenu,
    this.onVideoInitCompleted,
    this.onVideoListTap,
    this.onCacheFileCompleted,
    this.onCacheFileFailed,
    this.onFullScreenIconTap,
    this.onPIPIconTap,
    this.onAmbientModeChanged,
    this.onPlaybackSpeedChanged,
    this.onSupportButtonTap,
  });

  // Event callbacks
  final VoidCallback? onBackButtonTap;
  final void Function(String videoType)? onPlayingVideo;
  final void Function(bool isPlaying)? onPlayButtonTap;
  final ValueChanged<VideoPlayerValue>? onFastForward;
  final ValueChanged<VideoPlayerValue>? onRewind;
  final ValueChanged<VideoPlayerValue>? onPause;
  final ValueChanged<VideoPlayerValue>? onDispose;
  final ValueChanged<VideoPlayerValue>? onLiveDirectTap;
  final void Function(bool showMenu, bool isQualityPickerVisible)? onShowMenu;
  final void Function(VideoPlayerController controller)? onVideoInitCompleted;
  final VoidCallback? onVideoListTap;
  final void Function(List<File>? files)? onCacheFileCompleted;
  final void Function(dynamic error)? onCacheFileFailed;
  final VoidCallback? onFullScreenIconTap;
  final VoidCallback? onPIPIconTap;
  final void Function(bool value)? onAmbientModeChanged;
  final ValueChanged<double>? onPlaybackSpeedChanged;
  final VoidCallback? onSupportButtonTap;

  /// Safely calls the back button callback
  void callBackButtonTap() {
    onBackButtonTap?.call();
  }

  /// Safely calls the playing video callback
  void callPlayingVideo(String videoType) {
    onPlayingVideo?.call(videoType);
  }

  /// Safely calls the play button callback
  void callPlayButtonTap(bool isPlaying) {
    onPlayButtonTap?.call(isPlaying);
  }

  /// Safely calls the fast forward callback
  void callFastForward(VideoPlayerValue value) {
    onFastForward?.call(value);
  }

  /// Safely calls the rewind callback
  void callRewind(VideoPlayerValue value) {
    onRewind?.call(value);
  }

  /// Safely calls the pause callback
  void callPause(VideoPlayerValue value) {
    onPause?.call(value);
  }

  /// Safely calls the dispose callback
  void callDispose(VideoPlayerValue value) {
    onDispose?.call(value);
  }

  /// Safely calls the live direct callback
  void callLiveDirectTap(VideoPlayerValue value) {
    onLiveDirectTap?.call(value);
  }

  /// Safely calls the show menu callback
  void callShowMenu(bool showMenu, bool isQualityPickerVisible) {
    onShowMenu?.call(showMenu, isQualityPickerVisible);
  }

  /// Safely calls the video init completed callback
  void callVideoInitCompleted(VideoPlayerController controller) {
    onVideoInitCompleted?.call(controller);
  }

  /// Safely calls the video list tap callback
  void callVideoListTap() {
    onVideoListTap?.call();
  }

  /// Safely calls the cache file completed callback
  void callCacheFileCompleted(List<File>? files) {
    onCacheFileCompleted?.call(files);
  }

  /// Safely calls the cache file failed callback
  void callCacheFileFailed(dynamic error) {
    onCacheFileFailed?.call(error);
  }

  /// Safely calls the full screen icon tap callback
  void callFullScreenIconTap() {
    onFullScreenIconTap?.call();
  }

  /// Safely calls the PIP icon tap callback
  void callPIPIconTap() {
    onPIPIconTap?.call();
  }

  /// Safely calls the ambient mode changed callback
  void callAmbientModeChanged(bool value) {
    onAmbientModeChanged?.call(value);
  }

  /// Safely calls the playback speed changed callback
  void callPlaybackSpeedChanged(double speed) {
    onPlaybackSpeedChanged?.call(speed);
  }

  /// Safely calls the support button tap callback
  void callSupportButtonTap() {
    onSupportButtonTap?.call();
  }

  /// Handles fullscreen toggle with callback
  void handleFullScreenToggle(bool isFullScreen, VoidCallback toggleAction) {
    toggleAction();
    // Additional fullscreen handling logic can be added here
  }

  /// Handles quality selection with callbacks
  void handleQualitySelection(
    M3U8Data data,
    String currentQuality,
    void Function(M3U8Data) onQualitySelected,
    void Function(String) onQualityChanged,
  ) {
    if (data.dataQuality != currentQuality) {
      onQualityChanged(data.dataQuality ?? currentQuality);
      onQualitySelected(data);
    }
  }

  /// Handles playback speed change with callbacks
  void handlePlaybackSpeedChange(
    double speed,
    void Function(double) onSpeedChanged,
    void Function(double) onPlaybackSpeedChanged,
  ) {
    onSpeedChanged(speed);
    onPlaybackSpeedChanged(speed);
  }
}
