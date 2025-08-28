import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/constants/video_constants.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/source/video_loading_style.dart';
import 'package:vidio/src/source/video_style.dart';
import 'package:vidio/src/widgets/action_bar.dart';
import 'package:vidio/src/widgets/live_direct_button.dart';
import 'package:vidio/src/widgets/playback_speed_slider.dart';
import 'package:vidio/src/widgets/player_bottom_bar.dart';
import 'package:vidio/src/widgets/unlock_button.dart';
import 'package:vidio/src/widgets/video_loading.dart';
import 'package:vidio/src/widgets/video_quality_picker.dart';

import 'widgets/ambient_mode_settings.dart';

/// Builds UI components for the video player
class VideoUIBuilder {
  /// Builds the loading state widget
  static Widget buildLoadingState(VideoLoadingStyle loadingStyle) {
    return VideoLoading(loadingStyle: loadingStyle);
  }

  /// Builds the main video player stack
  static Widget buildVideoPlayer({
    required Widget gestureDetector,
    required List<Widget> controlsOverlay,
  }) {
    return Stack(
      children: <Widget>[
        gestureDetector,
        ...controlsOverlay,
      ],
    );
  }

  /// Builds the gesture detector for video interactions
  static Widget buildGestureDetector({
    required VideoPlayerController? controller,
    required bool isLocked,
    required bool showMenu,
    required bool fullScreen,
    required bool allowRepaintBoundary,
    required GlobalKey? repaintBoundaryKey,
    required void Function() onTap,
    required void Function(TapDownDetails) onDoubleTapDown,
    required void Function(DragUpdateDetails) onVerticalDragUpdate,
    required void Function() togglePlay,
    required void Function(VideoPlayerValue) onRewind,
    required void Function(VideoPlayerValue) onFastForward,
  }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTapDown: onDoubleTapDown,
      onVerticalDragUpdate: onVerticalDragUpdate,
      child: Container(
        foregroundDecoration: BoxDecoration(
          color: showMenu && !isLocked ? Colors.black.withOpacity(0.35) : Colors.transparent,
        ),
        child: controller == null
            ? const SizedBox.shrink()
            : allowRepaintBoundary && repaintBoundaryKey != null
                ? RepaintBoundary(
                    key: repaintBoundaryKey,
                    child: InteractiveViewer(
                      panEnabled: fullScreen,
                      scaleEnabled: fullScreen,
                      minScale: 1,
                      maxScale: 5,
                      child: VideoPlayer(controller),
                    ),
                  )
                : InteractiveViewer(
                    panEnabled: fullScreen,
                    scaleEnabled: fullScreen,
                    minScale: 1,
                    maxScale: 5,
                    child: VideoPlayer(controller),
                  ),
      ),
    );
  }

  /// Builds the controls overlay
  static List<Widget> buildControlsOverlay({
    required bool isLocked,
    required bool showMenu,
    required List<Widget> videoBuiltInChildren,
    required UnlockButton unlockButton,
  }) {
    if (isLocked) {
      return [unlockButton];
    }
    return videoBuiltInChildren;
  }

  /// Builds the built-in children widgets
  static List<Widget> buildVideoBuiltInChildren({
    required bool showMenu,
    required bool fullScreen,
    required bool isLocked,
    required VideoStyle videoStyle,
    required VideoPlayerController? controller,
    required bool isAtLivePosition,
    required String videoSeek,
    required String videoDuration,
    required bool hideFullScreenButton,
    required bool? hidePIPButton,
    required void Function()? onSupportButtonTap,
    required void Function() onLockTap,
    required void Function()? onVideoListTap,
    required void Function() onSettingsTap,
    required void Function(VideoPlayerValue)? onLiveDirectTap,
    required void Function() togglePlay,
    required void Function(VideoPlayerValue)? onFastForward,
    required void Function(VideoPlayerValue)? onRewind,
    required void Function() onFullScreen,
    required void Function()? onFullScreenIconTap,
    required void Function()? onPIPIconTap,
    required Widget backButton,
    required Widget bottomBar,
    required Widget miniProgress,
  }) {
    return [
      ActionBar(
        showMenu: showMenu,
        fullScreen: fullScreen,
        isLocked: isLocked,
        videoStyle: videoStyle,
        onSupportButtonTap: onSupportButtonTap,
        onLockTap: onLockTap,
        onVideoListTap: onVideoListTap,
        onSettingsTap: onSettingsTap,
      ),
      LiveDirectButton(
        controller: controller,
        showMenu: showMenu,
        isAtLivePosition: isAtLivePosition,
        videoStyle: videoStyle,
        onLiveDirectTap: onLiveDirectTap,
      ),
      backButton,
      bottomBar,
      miniProgress,
    ];
  }

  /// Builds the back button
  static Widget buildBackButton({
    required bool showMenu,
    required bool fullScreen,
    required void Function() onBackButtonTap,
    required void Function() onFullScreen,
  }) {
    return Visibility(
      visible: showMenu,
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: fullScreen ? 10.0 : 5,
            left: fullScreen ? 10.0 : 5,
          ),
          height: 50,
          width: 50,
          alignment: Alignment.center,
          child: InkWell(
            onTap: () {
              onFullScreen();
              onBackButtonTap();
            },
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Builds the bottom bar
  static Widget buildBottomBar({
    required VideoPlayerController? controller,
    required bool showMenu,
    required String videoSeek,
    required String videoDuration,
    required VideoStyle videoStyle,
    required bool hideFullScreenButton,
    required bool? hidePIPButton,
    required void Function() togglePlay,
    required void Function(VideoPlayerValue)? onFastForward,
    required void Function(VideoPlayerValue)? onRewind,
    required void Function() onFullScreen,
    required void Function()? onFullScreenIconTap,
    required void Function()? onPIPIconTap,
  }) {
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Visibility(
      visible: showMenu,
      child: Align(
        child: PlayerBottomBar(
          hideFullScreenButton: hideFullScreenButton,
          fullScreen: false, // Will be passed from state
          controller: controller,
          videoSeek: videoSeek,
          videoDuration: videoDuration,
          videoStyle: videoStyle,
          showBottomBar: showMenu,
          onPlayButtonTap: togglePlay,
          onFastForward: onFastForward,
          onRewind: onRewind,
          onFullScreen: onFullScreen,
          onFullScreenIconTap: onFullScreenIconTap,
          hidePipButton: hidePIPButton ?? true,
          onPipMode: onPIPIconTap,
        ),
      ),
    );
  }

  /// Builds the mini progress indicator
  static Widget buildMiniProgress({
    required bool showMenu,
    required bool fullScreen,
    required bool showMiniProgress,
    required VideoPlayerController? controller,
  }) {
    return Visibility(
      visible: !showMenu && showMiniProgress,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              if (fullScreen)
                const SizedBox.shrink()
              else
                controller != null
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 1,
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: false,
                            colors: VideoProgressColors(
                              playedColor: const Color.fromARGB(255, 241, 0, 0),
                              bufferedColor: Colors.grey[400] ?? Colors.grey,
                              backgroundColor: Colors.grey[100] ?? Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the unlock button
  static Widget buildUnlockButton({
    required bool isLocked,
    required bool showMenu,
    required void Function() onUnlock,
  }) {
    return UnlockButton(
      isLocked: isLocked,
      showMenu: showMenu,
      onUnlock: onUnlock,
    );
  }

  /// Builds the settings dialog
  static Future<void> showSettingsDialog({
    required BuildContext context,
    required Duration? duration,
    required VideoPlayerController? controller,
    required List<M3U8Data> m3u8UrlList,
    required VideoStyle videoStyle,
    required String m3u8Quality,
    required bool hideQualityList,
    required bool loop,
    required bool isAmbientMode,
    required List<double> playbackSpeeds,
    required double playbackSpeed,
    required void Function(M3U8Data) onQualitySelected,
    required void Function(double) onPlaybackSpeedChanged,
    required void Function(bool) onAmbientModeChanged,
    required void Function(bool) setLoop,
    required void Function(bool) setLoopWithController,
  }) {
    return showModalBottomSheet(
      backgroundColor: Colors.red,
      isDismissible: true,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      builder: (context) {
        return Material(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: Colors.grey[100],
                  height: 1,
                ),
                const SizedBox(height: 10),
                if (!hideQualityList)
                  VideoQualityPicker(
                    videoData: m3u8UrlList,
                    videoStyle: videoStyle,
                    showPicker: true,
                    onQualitySelected: (data) {
                      onQualitySelected(data);
                      Navigator.pop(context);
                    },
                    selectedQuality: m3u8Quality,
                  ),
                const SizedBox(height: 10),
                PlaybackSpeedSlider(
                  speeds: playbackSpeeds,
                  currentSpeed: playbackSpeed,
                  onSpeedChanged: (speed) {
                    onPlaybackSpeedChanged(speed);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    loop ? Icons.repeat_one : Icons.repeat,
                    size: 20,
                    color: Colors.black87,
                  ),
                  title: const Text(
                    'Loop Video',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  trailing: Switch(
                    value: loop,
                    activeColor: VideoConstants.kPrimaryColor,
                    onChanged: (val) {
                      setLoopWithController(val);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setLoopWithController(!loop);
                    Navigator.pop(context);
                  },
                ),
                // AmbientModeSettings would need to be imported or defined
                AmbientModeSettings(
                  value: isAmbientMode,
                  onChanged: ({bool? value}) {
                    onAmbientModeChanged(value ?? false);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
