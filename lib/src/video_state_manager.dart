import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/constants/video_constants.dart';

/// Manages the state of the video player UI and controls
class VideoPlayerStateManager {
  bool fullScreen = false;
  bool showMenu = false;
  bool isQualityPickerVisible = false;
  bool isLocked = false;
  bool isAmbientMode = false;
  bool hideQualityList = false;
  bool hasInitError = false;
  OverlayEntry? overlayEntry;
  Timer? controlHideTimer;
  GlobalKey videoQualityKey = GlobalKey();

  AnimationController? controlBarAnimationController;
  Animation<double>? controlTopBarAnimation;
  Animation<double>? controlBottomBarAnimation;

  void initializeAnimations(TickerProvider vsync) {
    controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );
    controlTopBarAnimation = Tween<double>(begin: -(36.0 + 0.0 * 2), end: 0).animate(controlBarAnimationController!);
    controlBottomBarAnimation = Tween<double>(begin: -(36.0 + 0.0 * 2), end: 0).animate(controlBarAnimationController!);
  }

  void toggleControls() {
    clearHideControlBarTimer();

    if (!showMenu) {
      showMenu = true;
    } else {
      isQualityPickerVisible = false;
      showMenu = false;
    }

    if (showMenu) {
      controlBarAnimationController?.forward();
    } else {
      controlBarAnimationController?.reverse();
    }
  }

  void createHideControlBarTimer(VideoPlayerController? controller, VoidCallback onHide) {
    clearHideControlBarTimer();
    controlHideTimer = Timer(VideoConstants.kControlHideDuration, () {
      if (controller?.value.isPlaying == true) {
        if (showMenu) {
          showMenu = false;
          isQualityPickerVisible = false;
          controlBarAnimationController?.reverse();
          onHide();
        }
      }
    });
  }

  void clearHideControlBarTimer() {
    controlHideTimer?.cancel();
  }

  void showOverlay(BuildContext context, Widget overlayWidget) {
    // Remove existing overlay first to prevent duplicates
    removeOverlay();

    // Ensure we have a fresh GlobalKey to prevent conflicts
    videoQualityKey = GlobalKey();

    overlayEntry = OverlayEntry(
      builder: (_) => overlayWidget,
    );

    // Only insert if context is still valid
    if (context.mounted) {
      Overlay.of(context).insert(overlayEntry!);
    }
  }

  void removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  void toggleFullScreen(void Function(bool) onFullScreenChanged) {
    fullScreen = !fullScreen;
    onFullScreenChanged(fullScreen);
  }

  void toggleLock() {
    isLocked = !isLocked;
  }

  void dispose() {
    controlBarAnimationController?.dispose();
    clearHideControlBarTimer();
    removeOverlay();
  }
}

/// Manages video timing and progress
class VideoTimingManager {
  String? videoDuration;
  String? videoSeek;
  Duration? duration;
  double? videoSeekSecond;
  double? videoDurationSecond;

  void updateTiming(VideoPlayerController? controller) {
    videoDuration = controller?.value.duration.convertDurationToString();
    videoSeek = controller?.value.position.convertDurationToString();
    videoSeekSecond = controller?.value.position.inSeconds.toDouble();
    videoDurationSecond = controller?.value.duration.inSeconds.toDouble();
  }
}

/// Extension to convert Duration to string (assuming this exists elsewhere)
extension DurationExtension on Duration {
  String convertDurationToString() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(inHours);
    final minutes = twoDigits(inMinutes.remainder(60));
    final seconds = twoDigits(inSeconds.remainder(60));
    return [if (inHours > 0) hours, minutes, seconds].join(':');
  }
}
