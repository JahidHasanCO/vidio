import 'package:flutter/material.dart';

/// Configuration constants for the video player
class VideoPlayerConfig {
  // UI Constants
  static const double defaultAspectRatio = 16 / 9;
  static const double minScale = 1;
  static const double maxScale = 5;
  static const double overlayOpacity = 0.35;
  static const Duration controlsHideDelay = Duration(seconds: 3);
  static const Duration snackBarDuration = Duration(seconds: 2);

  // Gesture Constants
  static const double rewindThreshold = 1 / 3;
  static const double fastForwardThreshold = 2 / 3;

  // Animation Constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeInOut;

  // Quality Picker Constants
  static const double qualityPickerPositionOffset = 35;
  static const double qualityPickerWidthDivider = 3;

  // Progress Indicator Constants
  static const double miniProgressHeight = 1;
  static const Color playedColor = Color.fromARGB(255, 241, 0, 0);
  static const Color bufferedColor = Colors.grey;
  static const Color backgroundColor = Colors.grey;

  // Layout Constants
  static const double backButtonMargin = 10;
  static const double backButtonSize = 50;
}

/// Manages video player configuration and settings
class VideoConfigurationManager {
  /// Get the aspect ratio based on fullscreen state
  double getAspectRatio(bool isFullScreen, double defaultAspectRatio) {
    return isFullScreen
        ? VideoPlayerConfig.defaultAspectRatio
        : defaultAspectRatio;
  }

  /// Get the rewind/fast forward threshold positions
  double getRewindThreshold(double width) =>
      width * VideoPlayerConfig.rewindThreshold;

  double getFastForwardThreshold(double width) =>
      width * VideoPlayerConfig.fastForwardThreshold;

  /// Get overlay background color
  Color getOverlayColor(bool showMenu, bool isLocked) {
    return showMenu && !isLocked
        ? Colors.black.withOpacity(VideoPlayerConfig.overlayOpacity)
        : Colors.transparent;
  }

  /// Get back button margin based on fullscreen state
  EdgeInsets getBackButtonMargin(bool isFullScreen) {
    return EdgeInsets.only(
      top: isFullScreen
          ? VideoPlayerConfig.backButtonMargin
          : VideoPlayerConfig.backButtonMargin / 2,
      left: isFullScreen
          ? VideoPlayerConfig.backButtonMargin
          : VideoPlayerConfig.backButtonMargin / 2,
    );
  }

  /// Get quality picker position
  double getQualityPickerPositionRight(double width) =>
      width / VideoPlayerConfig.qualityPickerWidthDivider;

  double getQualityPickerPositionTop(double offset) =>
      offset + VideoPlayerConfig.qualityPickerPositionOffset;
}
