import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_parser.dart';
import 'package:vidio/src/video_config_manager.dart';
import 'package:vidio/src/video_error_handler.dart';
import 'package:vidio/src/video_event_manager.dart';
import 'package:vidio/src/video_managers.dart';
import 'package:vidio/src/video_performance_manager.dart';
import 'package:vidio/src/video_state_manager.dart';
import 'package:vidio/src/source/video_loading_style.dart';
import 'package:vidio/src/source/video_style.dart';
import 'package:vidio/src/video_ui_builder.dart';
import 'package:vidio/src/widgets/unlock_button.dart';
import 'package:vidio/src/widgets/video_quality_picker.dart';
import 'package:vidio/src/widgets/caching_progress_widget.dart';
import 'package:vidio/src/video_cache_manager.dart';

class Vidio extends StatefulWidget {
  const Vidio({
    required this.url,
    super.key,
    this.aspectRatio = 16 / 9,
    this.videoStyle = const VideoStyle(),
    this.videoLoadingStyle = const VideoLoadingStyle(),
    this.onFullScreen,
    this.onFullScreenIconTap,
    this.onPlayingVideo,
    this.onPlayButtonTap,
    this.onShowMenu,
    this.onFastForward,
    this.onRewind,
    this.headers,
    this.initFullScreen = false,
    this.autoPlayVideoAfterInit = true,
    this.displayFullScreenAfterInit = false,
    this.allowCacheFile = false,
    this.onCacheFileCompleted,
    this.onCacheFileFailed,
    this.onVideoInitCompleted,
    this.closedCaptionFile,
    this.videoPlayerOptions,
    this.onLiveDirectTap,
    this.onPause,
    this.onDispose,
    this.onBackButtonTap,
    this.hideFullScreenButton,
    this.onVideoListTap,
    this.hidePIPButton,
    this.onPIPIconTap,
    this.isAmbientMode = false,
    this.onAmbientModeChanged,
    this.allowRepaintBoundary = false,
    this.repaintBoundaryKey,
    this.playbackSpeed = 1.0,
    this.onPlaybackSpeedChanged,
    this.showMiniProgress = false,
    this.isShowSupportButton = false,
    this.onSupportButtonTap,
  });
  final String url;
  final VideoStyle videoStyle;
  final VideoLoadingStyle videoLoadingStyle;
  final double aspectRatio;
  final bool initFullScreen;
  final void Function(bool fullScreenTurnedOn)? onFullScreen;
  final void Function()? onBackButtonTap;
  final void Function(String videoType)? onPlayingVideo;
  final void Function(bool isPlaying)? onPlayButtonTap;
  final ValueChanged<VideoPlayerValue>? onFastForward;
  final ValueChanged<VideoPlayerValue>? onRewind;
  final ValueChanged<VideoPlayerValue>? onPause;
  final ValueChanged<VideoPlayerValue>? onDispose;
  final ValueChanged<VideoPlayerValue>? onLiveDirectTap;
  final void Function(bool showMenu, bool isQualityPickerVisible)? onShowMenu;
  final void Function(VideoPlayerController controller)? onVideoInitCompleted;
  final void Function()? onVideoListTap;
  final Map<String, String>? headers;
  final bool autoPlayVideoAfterInit;
  final bool displayFullScreenAfterInit;
  final void Function(List<File>? files)? onCacheFileCompleted;
  final void Function(dynamic error)? onCacheFileFailed;
  final bool allowCacheFile;
  final Future<ClosedCaptionFile>? closedCaptionFile;
  final VideoPlayerOptions? videoPlayerOptions;
  final VoidCallback? onFullScreenIconTap;
  final bool? hideFullScreenButton;
  final VoidCallback? onPIPIconTap;
  final bool? hidePIPButton;
  final bool isAmbientMode;
  final void Function(bool value)? onAmbientModeChanged;
  final bool allowRepaintBoundary;
  final GlobalKey? repaintBoundaryKey;
  final double playbackSpeed;
  final ValueChanged<double>? onPlaybackSpeedChanged;
  final bool showMiniProgress;
  final bool isShowSupportButton;
  final void Function()? onSupportButtonTap;

  @override
  State<Vidio> createState() => _VidioState();
}

class _VidioState extends State<Vidio> with SingleTickerProviderStateMixin {
  String? videoFormat;
  bool loop = false;
  bool _managersInitialized = false;

  // Caching progress state
  CachingProgressData? _cachingProgress;
  bool _isCachingInProgress = false;
  final List<String> _cacheLogs = [];

  // Manager instances
  late VideoControllerManager videoControllerManager;
  late M3U8Manager m3u8Manager;
  late VideoPlaybackManager playbackManager;
  late VideoPlayerStateManager uiStateManager;
  late VideoTimingManager timingManager;
  late VideoConfigurationManager configManager;
  late VideoErrorHandler errorHandler;
  late VideoEventManager eventManager;
  late VideoPerformanceManager performanceManager;

  // Getters for manager properties
  VideoPlayerController? get controller => videoControllerManager.controller;
  List<M3U8Data> get m3u8UrlList => m3u8Manager.m3u8UrlList;
  List<AudioModel> get audioList => m3u8Manager.audioList;
  String get m3u8Quality => m3u8Manager.m3u8Quality;
  set m3u8Quality(String quality) => m3u8Manager.setQuality(quality);

  bool get fullScreen => uiStateManager.fullScreen;
  set fullScreen(bool value) => uiStateManager.fullScreen = value;
  bool get showMenu => uiStateManager.showMenu;
  set showMenu(bool value) => uiStateManager.showMenu = value;
  bool get isQualityPickerVisible => uiStateManager.isQualityPickerVisible;
  set isQualityPickerVisible(bool value) => uiStateManager.isQualityPickerVisible = value;
  bool get isLocked => uiStateManager.isLocked;
  set isLocked(bool value) => uiStateManager.isLocked = value;
  bool get isAmbientMode => uiStateManager.isAmbientMode;
  set isAmbientMode(bool value) => uiStateManager.isAmbientMode = value;
  bool get hideQualityList => uiStateManager.hideQualityList;
  set hideQualityList(bool value) => uiStateManager.hideQualityList = value;
  bool get hasInitError => uiStateManager.hasInitError;
  set hasInitError(bool value) => uiStateManager.hasInitError = value;
  OverlayEntry? get overlayEntry => uiStateManager.overlayEntry;
  set overlayEntry(OverlayEntry? value) => uiStateManager.overlayEntry = value;
  GlobalKey get videoQualityKey => uiStateManager.videoQualityKey;

  String? get videoDuration => timingManager.videoDuration;
  set videoDuration(String? value) => timingManager.videoDuration = value;
  String? get videoSeek => timingManager.videoSeek;
  set videoSeek(String? value) => timingManager.videoSeek = value;
  Duration? get duration => timingManager.duration;
  set duration(Duration? value) => timingManager.duration = value;
  double? get videoSeekSecond => timingManager.videoSeekSecond;
  set videoSeekSecond(double? value) => timingManager.videoSeekSecond = value;
  double? get videoDurationSecond => timingManager.videoDurationSecond;
  set videoDurationSecond(double? value) => timingManager.videoDurationSecond = value;

  double get playbackSpeed => playbackManager.playbackSpeed;
  set playbackSpeed(double value) => playbackManager.playbackSpeed = value;
  List<double> get playbackSpeeds => playbackManager.playbackSpeeds;
  Duration? get lastPlayedPos => playbackManager.lastPlayedPos;
  set lastPlayedPos(Duration? value) => playbackManager.lastPlayedPos = value;
  bool get isAtLivePosition => playbackManager.isAtLivePosition;
  set isAtLivePosition(bool value) => playbackManager.isAtLivePosition = value;

  // Legacy state variables (to be removed after full integration)
  bool? isOffline;
  String? m3u8Content;
  String? subtitleContent;
  bool showSubtitles = false;

  set videoQuality(String quality) {
    if (m3u8Quality != quality) {
      setState(() {
        m3u8Quality = quality;
      });
      final data = m3u8UrlList.firstWhere(
        (d) => d.dataQuality == quality,
        orElse: () => M3U8Data(dataQuality: quality),
      );
      onSelectQuality(data);
    }
  }

  @override
  void didUpdateWidget(covariant Vidio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackSpeed != oldWidget.playbackSpeed && widget.playbackSpeed != playbackSpeed) {
      setPlaybackSpeed(widget.playbackSpeed, notify: false);
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize all managers first
    _initializeManagers();
    _managersInitialized = true;

    // Now set initial values (managers are initialized)
    fullScreen = widget.initFullScreen;
    isAmbientMode = widget.isAmbientMode;
    playbackSpeed = widget.playbackSpeed;

    // Initialize animations and determine video source
    uiStateManager.initializeAnimations(this);
    determineVideoSource(widget.url);
  }

  /// Initialize all manager instances
  void _initializeManagers() {
    videoControllerManager = VideoControllerManager(
      headers: widget.headers,
      closedCaptionFile: widget.closedCaptionFile,
      videoPlayerOptions: widget.videoPlayerOptions,
      allowCacheFile: widget.allowCacheFile,
      onCacheFileCompleted: widget.onCacheFileCompleted,
      onCacheFileFailed: widget.onCacheFileFailed,
      onVideoInitCompleted: widget.onVideoInitCompleted,
    );

    m3u8Manager = M3U8Manager();
    playbackManager = VideoPlaybackManager();
    uiStateManager = VideoPlayerStateManager();
    timingManager = VideoTimingManager();
    configManager = VideoConfigurationManager();
    errorHandler = VideoErrorHandler();
    eventManager = VideoEventManager(
      onBackButtonTap: widget.onBackButtonTap,
      onPlayingVideo: widget.onPlayingVideo,
      onPlayButtonTap: widget.onPlayButtonTap,
      onFastForward: widget.onFastForward,
      onRewind: widget.onRewind,
      onPause: widget.onPause,
      onDispose: widget.onDispose,
      onLiveDirectTap: widget.onLiveDirectTap,
      onShowMenu: widget.onShowMenu,
      onVideoInitCompleted: widget.onVideoInitCompleted,
      onVideoListTap: widget.onVideoListTap,
      onCacheFileCompleted: widget.onCacheFileCompleted,
      onCacheFileFailed: widget.onCacheFileFailed,
      onFullScreenIconTap: widget.onFullScreenIconTap,
      onPIPIconTap: widget.onPIPIconTap,
      onAmbientModeChanged: widget.onAmbientModeChanged,
      onPlaybackSpeedChanged: widget.onPlaybackSpeedChanged,
      onSupportButtonTap: widget.onSupportButtonTap,
    );
    performanceManager = VideoPerformanceManager();
  }

  @override
  void dispose() {
    m3u8Clean();
    controller?.removeListener(listener);
    controller?.dispose();
    uiStateManager.dispose();
    errorHandler.dispose();
    performanceManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevent accessing managers before they're initialized
    if (!_managersInitialized) {
      return buildLoadingState();
    }

    return PopScope(
      onPopInvoked: (result) {
        if (fullScreen) {
          setState(() {
            fullScreen = !fullScreen;
            widget.onFullScreen?.call(fullScreen);
          });
        }
      },
      child: AspectRatio(
        aspectRatio: configManager.getAspectRatio(fullScreen, widget.aspectRatio),
        child: controller?.value.isInitialized == false
            ? buildLoadingState()
            : buildVideoPlayer(),
      ),
    );
  }

  /// Builds the loading state when video is not initialized
  Widget buildLoadingState() {
    return VideoUIBuilder.buildLoadingState(
      widget.videoLoadingStyle,
      _cachingProgress,
    );
  }

  /// Builds the main video player with controls overlay
  Widget buildVideoPlayer() {
    return Stack(
      children: <Widget>[
        buildGestureDetector(),
        ...buildControlsOverlay(),
      ],
    );
  }

  /// Builds the gesture detector for video player interactions
  Widget buildGestureDetector() {
    return GestureDetector(
      onTap: () {
        toggleControls();
        removeOverlay();
      },
      onDoubleTapDown: (TapDownDetails details) {
        if (controller == null || isLocked) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width;

        if (localPosition.dx < configManager.getRewindThreshold(width)) {
          controller!.rewind().whenComplete(
                () => eventManager.callRewind(controller!.value),
              );
        } else if (localPosition.dx > configManager.getFastForwardThreshold(width)) {
          controller!.fastForward().whenComplete(
                () => eventManager.callRewind(controller!.value),
              );
        } else {
          togglePlay();
        }
      },
      onVerticalDragUpdate: (details) {
        if (isLocked) return;

        if (details.delta.dy > 0) {
          if (fullScreen) {
            setState(() {
              fullScreen = !fullScreen;
              widget.onFullScreen?.call(fullScreen);
            });
          }
        } else {
          if (!fullScreen) {
            setState(() {
              fullScreen = !fullScreen;
              widget.onFullScreen?.call(fullScreen);
            });
          }
        }
      },
      child: Container(
        foregroundDecoration: BoxDecoration(
          color: configManager.getOverlayColor(showMenu, isLocked),
        ),
        child: controller == null
            ? const SizedBox.shrink()
            : widget.allowRepaintBoundary && widget.repaintBoundaryKey != null
                ? RepaintBoundary(
                    key: widget.repaintBoundaryKey,
                    child: InteractiveViewer(
                      panEnabled: fullScreen,
                      scaleEnabled: fullScreen,
                      minScale: VideoPlayerConfig.minScale,
                      maxScale: VideoPlayerConfig.maxScale,
                      child: VideoPlayer(controller!),
                    ),
                  )
                : InteractiveViewer(
                    panEnabled: fullScreen,
                    scaleEnabled: fullScreen,
                    minScale: VideoPlayerConfig.minScale,
                    maxScale: VideoPlayerConfig.maxScale,
                    child: VideoPlayer(controller!),
                  ),
      ),
    );
  }

  /// Builds the controls overlay (action bar, bottom controls, etc.)
  List<Widget> buildControlsOverlay() {
    return VideoUIBuilder.buildControlsOverlay(
      isLocked: isLocked,
      showMenu: showMenu,
      videoBuiltInChildren: videoBuiltInChildren(),
      unlockButton: UnlockButton(
        isLocked: isLocked,
        showMenu: showMenu,
        onUnlock: () {
          setState(() {
            isLocked = !isLocked;
          });
        },
      ),
    );
  }

  List<Widget> videoBuiltInChildren() {
    return VideoUIBuilder.buildVideoBuiltInChildren(
      showMenu: showMenu,
      fullScreen: fullScreen,
      isLocked: isLocked,
      videoStyle: widget.videoStyle,
      controller: controller,
      isAtLivePosition: isAtLivePosition,
      videoSeek: videoSeek ?? '00:00:00',
      videoDuration: videoDuration ?? '00:00:00',
      hideFullScreenButton: widget.hideFullScreenButton ?? false,
      hidePIPButton: widget.hidePIPButton,
      onSupportButtonTap: widget.onSupportButtonTap != null
          ? () {
              if (showMenu && mounted) {
                setState(() {
                  showMenu = false;
                  removeOverlay();
                });
              }
              eventManager.callSupportButtonTap();
            }
          : null,
      onLockTap: () {
        setState(() {
          isLocked = !isLocked;
        });
      },
      onVideoListTap: widget.onVideoListTap != null
          ? () {
              if (showMenu && mounted) {
                setState(() {
                  showMenu = false;
                  removeOverlay();
                });
              }
              eventManager.callVideoListTap();
            }
          : null,
      onSettingsTap: () => showSettingsDialog(context),
      onLiveDirectTap: eventManager.callLiveDirectTap,
      togglePlay: togglePlay,
      onFastForward: eventManager.callFastForward,
      onRewind: eventManager.callRewind,
      onFullScreen: () => setState(() {
        fullScreen = !fullScreen;
        widget.onFullScreen?.call(fullScreen);
      }),
      onFullScreenIconTap: eventManager.callFullScreenIconTap,
      onPIPIconTap: () {
        eventManager.callPIPIconTap();
        if (showMenu && mounted) {
          setState(() {
            showMenu = false;
            removeOverlay();
          });
        }
      },
      backButton: backButton(),
      bottomBar: bottomBar(),
      miniProgress: _miniProgress(),
    );
  }

  Widget _miniProgress() {
    return VideoUIBuilder.buildMiniProgress(
      showMenu: showMenu,
      fullScreen: fullScreen,
      showMiniProgress: widget.showMiniProgress,
      controller: controller,
      cachingProgress: _cachingProgress,
    );
  }

  Widget backButton() {
    return VideoUIBuilder.buildBackButton(
      showMenu: showMenu,
      fullScreen: fullScreen,
      onBackButtonTap: () {
        if (!fullScreen && widget.onBackButtonTap != null) {
          eventManager.callBackButtonTap();
        }
      },
      onFullScreen: () {
        if (fullScreen) {
          setState(() {
            fullScreen = !fullScreen;
            widget.onFullScreen?.call(fullScreen);
          });
        }
      },
    );
  }



  Widget bottomBar() {
    return VideoUIBuilder.buildBottomBar(
      controller: controller,
      showMenu: showMenu,
      videoSeek: videoSeek ?? '00:00:00',
      videoDuration: videoDuration ?? '00:00:00',
      videoStyle: widget.videoStyle,
      hideFullScreenButton: widget.hideFullScreenButton ?? false,
      hidePIPButton: widget.hidePIPButton,
      togglePlay: togglePlay,
      onFastForward: eventManager.callFastForward,
      onRewind: eventManager.callRewind,
      onFullScreen: () => setState(() {
        fullScreen = !fullScreen;
        widget.onFullScreen?.call(fullScreen);
      }),
      onFullScreenIconTap: eventManager.callFullScreenIconTap,
      onPIPIconTap: () {
        eventManager.callPIPIconTap();
        if (showMenu && mounted) {
          setState(() {
            showMenu = false;
            removeOverlay();
          });
        }
      },
      cachingProgress: _cachingProgress,
    );
  }



  Widget m3u8List() {
    final renderBox = videoQualityKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero);
    return VideoQualityPicker(
      videoData: m3u8UrlList,
      videoStyle: widget.videoStyle,
      showPicker: isQualityPickerVisible,
      positionRight: configManager.getQualityPickerPositionRight(renderBox?.size.width ?? 0.0),
      positionTop: configManager.getQualityPickerPositionTop(offset?.dy ?? 0.0),
      onQualitySelected: (data) {
        eventManager.handleQualitySelection(
          data,
          m3u8Quality,
          onSelectQuality,
          (quality) {
            if (mounted) {
              setState(() {
                m3u8Quality = quality;
              });
            }
          },
        );
        setState(() {
          isQualityPickerVisible = false;
        });
        removeOverlay();
      },
      selectedQuality: m3u8Quality,
    );
  }

  void determineVideoSource(String url) {
    final isNetwork = VideoParser.isNetworkUrl(url);
    final detectedFormat = VideoParser.determineVideoFormat(url);
    
    setState(() {
      isOffline = !isNetwork;
      videoFormat = detectedFormat;
    });

    if (isNetwork && detectedFormat != null) {
      widget.onPlayingVideo?.call(detectedFormat);
      
      if (detectedFormat == 'HLS') {
        videoControlSetup(url);
        getM3U8(url);
      } else {
        videoControlSetup(url);
        
        // Handle caching for non-HLS formats
        if (widget.allowCacheFile) {
          final extension = detectedFormat.toLowerCase();
          print('DEBUG: Starting caching for format: $detectedFormat, URL: $url');
          // Start caching immediately and also start background caching
          _startCaching(url, quality: extension);
        }
      }
    } else {
      // Offline or unknown format
      videoControlSetup(url);
      if (detectedFormat == null) {
        // Try to parse as M3U8 if format is unknown
        getM3U8(url);
      }
    }
  }

  void getM3U8(String videoUrl) {
    if (m3u8UrlList.isNotEmpty) {
      m3u8Clean();
    }
    parseM3U8Playlist(videoUrl);
  }

  Future<M3U8s?> parseM3U8Playlist(String? videoUrl) async {
    try {
      final result = await performanceManager.measureExecutionTime(
        () => m3u8Manager.parseM3U8Playlist(
          videoUrl,
          widget.headers,
          widget.allowCacheFile,
          widget.onCacheFileCompleted,
          widget.onCacheFileFailed,
        ),
        operationName: 'parseM3U8Playlist',
      );

      if (result.hasError) {
        errorHandler.handleParsingError(result.error, null, 'Failed to parse M3U8 playlist');
        return null;
      }

      if (mounted) {
        setState(() {
          // Update state if needed
        });
      }

      return result.result;
    } catch (error, stackTrace) {
      errorHandler.handleParsingError(error, stackTrace, 'M3U8 parsing failed');
      return null;
    }
  }  Future<void> videoControlSetup(String? url) async {
    videoInit(url);
    if (controller == null) return;
    controller?.addListener(listener);
    if (widget.displayFullScreenAfterInit) {
      setState(() {
        fullScreen = true;
      });
      widget.onFullScreen?.call(fullScreen);
    }
    if (widget.autoPlayVideoAfterInit) {
      await controller?.play();
    }
    widget.onVideoInitCompleted?.call(controller!);
  }

  Future<void> listener() async {
    if (widget.videoStyle.showLiveDirectButton) {
      if (controller?.value.position != controller?.value.duration) {
        if (isAtLivePosition) {
          if (mounted) {
            setState(() {
              isAtLivePosition = true;
            });
          }
        }
      } else {
        if (!isAtLivePosition) {
          if (mounted) {
            setState(() {
              isAtLivePosition = false;
            });
          }
        }
      }
    }

    // Update timing
    timingManager.updateTiming(controller);

    // Manage wakelock with performance monitoring
    await performanceManager.measureExecutionTime(
      () => playbackManager.manageWakelock(controller),
      operationName: 'manageWakelock',
    );

    // Start background caching when video starts playing (YouTube-style)
    if (controller != null &&
        controller!.value.isPlaying &&
        widget.allowCacheFile &&
        _cachingProgress == null) {
      final currentUrl = controller!.dataSource;
      if (currentUrl.isNotEmpty) {
        _startBackgroundCaching(currentUrl);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void createHideControlBarTimer() {
    uiStateManager.createHideControlBarTimer(
      controller,
      () {
        if (mounted) {
          setState(() {
            widget.onShowMenu?.call(showMenu, isQualityPickerVisible);
            removeOverlay();
          });
        }
      },
    );
  }

  void clearHideControlBarTimer() {
    uiStateManager.clearHideControlBarTimer();
  }

  void toggleControls() {
    uiStateManager.toggleControls();

    if (!showMenu) {
      widget.onShowMenu?.call(showMenu, isQualityPickerVisible);
      createHideControlBarTimer();
    } else {
      widget.onShowMenu?.call(showMenu, isQualityPickerVisible);
    }
  }

  void togglePlay() {
    createHideControlBarTimer();
    playbackManager.togglePlay(controller);
    eventManager.callPlayButtonTap(controller?.value.isPlaying ?? false);
    setState(() {});
  }

  void videoInit(String? url) {
    performanceManager.measureExecutionTime(
      () => videoControllerManager.initializeController(
        url ?? '',
        videoFormat,
        isOffline ?? false,
        playbackSpeed,
        lastPlayedPos,
      ),
      operationName: 'videoInit',
    ).then((result) {
      if (result.hasError) {
        errorHandler.handleInitializationError(result.error, null, 'Failed to initialize video controller');
        setState(() => hasInitError = true);
      } else {
        setState(() => hasInitError = false);
        seekToLastPlayingPosition();
        // Don't clear caching progress - let it continue in background
        // _clearCachingProgress();
      }
    }).catchError((dynamic error, StackTrace? stackTrace) {
      errorHandler.handleInitializationError(error, stackTrace, 'Video initialization failed');
      setState(() => hasInitError = true);
    });

    // Hide quality list for offline content
    if (isOffline == true) {
      hideQualityList = true;
    }
  }

  Future<void> onSelectQuality(M3U8Data data) async {
    lastPlayedPos = await controller?.position;
    if (data.dataQuality == 'Auto') {
      await videoControlSetup(data.dataURL);
    } else {
      try {
        if (data.dataURL != null) {
          playLocalM3U8File(data.dataURL!);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        }
      }
    }
  }

  void playLocalM3U8File(String url) {
    performanceManager.measureExecutionTime(
      () => videoControllerManager.playLocalM3U8File(url),
      operationName: 'playLocalM3U8File',
    ).then((result) {
      if (result.hasError) {
        errorHandler.handlePlaybackError(result.error, null, 'Failed to play local M3U8 file');
        setState(() => hasInitError = true);
      } else {
        setState(() => hasInitError = false);
        seekToLastPlayingPosition();
      }
    }).catchError((dynamic error, StackTrace? stackTrace) {
      errorHandler.handlePlaybackError(error, stackTrace, 'Local M3U8 playback failed');
      setState(() => hasInitError = true);
    });
  }

  Future<void> m3u8Clean() async {
    await m3u8Manager.cleanM3U8Files();
  }

  void showOverlay() {
    uiStateManager.showOverlay(context, m3u8List());
  }

  void setPlaybackSpeed(double speed, {bool notify = true}) {
    playbackManager.setPlaybackSpeed(speed, controller);
    if (notify) {
      eventManager.callPlaybackSpeedChanged(speed);
    }
  }

  void onPlayBackSpeedChange({required double speed}) {
    setPlaybackSpeed(speed);
    if (controller?.value.isPlaying == true) {
      controller?.pause();
      controller?.play();
    } else {
      controller?.play();
    }
  }

  void setLoopWithController(bool val) {
    setState(() {
      loop = val;
      if (controller?.value.isPlaying == true) {
        controller?.pause();
        controller?.setLooping(loop);
        controller?.play();
      } else {
        controller?.setLooping(loop);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Video loop is ${loop ? 'on' : 'off'}"),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> showSettingsDialog(BuildContext context) {
    return VideoUIBuilder.showSettingsDialog(
      context: context,
      duration: controller?.value.duration,
      controller: controller,
      m3u8UrlList: m3u8UrlList,
      videoStyle: widget.videoStyle,
      m3u8Quality: m3u8Quality,
      hideQualityList: hideQualityList,
      loop: loop,
      isAmbientMode: isAmbientMode,
      playbackSpeeds: playbackSpeeds,
      playbackSpeed: playbackSpeed,
      onQualitySelected: (data) {
        eventManager.handleQualitySelection(
          data,
          m3u8Quality,
          onSelectQuality,
          (quality) {
            if (mounted) {
              setState(() {
                m3u8Quality = quality;
              });
            }
          },
        );
        setState(() {
          isQualityPickerVisible = false;
        });
      },
      onPlaybackSpeedChanged: (speed) {
        eventManager.handlePlaybackSpeedChange(
          speed,
          setPlaybackSpeed,
          eventManager.callPlaybackSpeedChanged,
        );
        onPlayBackSpeedChange(speed: speed);
      },
      onAmbientModeChanged: (value) {
        setState(() {
          isAmbientMode = value;
        });
        eventManager.callAmbientModeChanged(value);
      },
      setLoop: (val) {
        setState(() {
          loop = val;
        });
      },
      setLoopWithController: setLoopWithController,
    );
  }

  void removeOverlay() {
    uiStateManager.removeOverlay();
  }

  void seekToLastPlayingPosition() {
    controller?.setPlaybackSpeed(playbackSpeed);
    if (controller == null) return;
    if (lastPlayedPos != null) {
      controller?.seekTo(lastPlayedPos ?? Duration.zero);
      widget.onVideoInitCompleted?.call(controller!);
      lastPlayedPos = null;
    }
  }

  /// Updates caching progress and notifies UI
  void _updateCachingProgress(double progress, [String? log]) {
    if (!widget.allowCacheFile) return;

    print('DEBUG: Updating cache progress: ${(progress * 100).toInt()}%, log: $log');

    // Only add logs if they're meaningful (not just progress updates)
    if (log != null && !log.contains('Cache progress:')) {
      _cacheLogs.add(log);
      // Keep only last 3 logs to avoid memory issues
      if (_cacheLogs.length > 3) {
        _cacheLogs.removeAt(0);
      }
    }

    setState(() {
      _cachingProgress = CachingProgressData(
        progress: progress,
        logs: List.from(_cacheLogs),
        isVisible: progress < 1.0 && progress > 0.0, // Show when actively caching
      );
      _isCachingInProgress = progress < 1.0 && progress > 0.0;
    });
  }

  /// Starts caching with progress tracking
  void _startCaching(String url, {String? quality}) {
    if (!widget.allowCacheFile) {
      print('DEBUG: Caching disabled - allowCacheFile is false');
      return;
    }

    print('DEBUG: Starting caching for URL: $url with quality: $quality');
    _cacheLogs.clear();
    _updateCachingProgress(0.0, 'Starting background cache...');

    VideoCacheManager().cacheVideoFile(
      url,
      quality: quality,
      headers: widget.headers,
      onProgress: (double progress) {
        print('DEBUG: Cache progress update: ${(progress * 100).toInt()}%');
        _updateCachingProgress(progress);
      },
      onLog: (String log) {
        print('DEBUG: Cache log: $log');
        // Only log important events, not every progress update
        if (!log.contains('Cache progress:') &&
            !log.contains('Background cache progress:')) {
          _updateCachingProgress(_cachingProgress?.progress ?? 0.0, log);
        }
      },
      onComplete: (File? file) {
        print('DEBUG: Cache completed: ${file?.path}');
        if (file != null) {
          _updateCachingProgress(1.0, 'Cache completed');
          widget.onCacheFileCompleted?.call([file]);
          // Keep progress visible briefly then hide
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _updateCachingProgress(0.0); // Hide progress
            }
          });
        }
      },
      onError: (dynamic error) {
        print('DEBUG: Cache error: $error');
        _updateCachingProgress(_cachingProgress?.progress ?? 0.0, 'Cache failed');
        widget.onCacheFileFailed?.call(error);
        // Hide progress after error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _updateCachingProgress(0.0);
          }
        });
      },
    );
  }

  /// Starts background caching during video playback (YouTube-style)
  void _startBackgroundCaching(String url) {
    if (!widget.allowCacheFile) return;

    _cacheLogs.clear();
    _updateCachingProgress(0.0, 'Buffering ahead...');

    VideoCacheManager().cacheVideoFile(
      url,
      headers: widget.headers,
      onProgress: (double progress) {
        _updateCachingProgress(progress);
      },
      onLog: (String log) {
        // Only log important events during background caching
        if (log.contains('Cache completed') ||
            log.contains('Cache failed') ||
            log.contains('Starting background')) {
          _updateCachingProgress(_cachingProgress?.progress ?? 0.0, log);
        }
      },
      onComplete: (File? file) {
        if (file != null) {
          _updateCachingProgress(1.0, 'Buffered successfully');
          widget.onCacheFileCompleted?.call([file]);
          // Hide progress after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _cachingProgress = null;
                _isCachingInProgress = false;
              });
            }
          });
        }
      },
      onError: (dynamic error) {
        _updateCachingProgress(_cachingProgress?.progress ?? 0.0, 'Buffering failed');
        widget.onCacheFileFailed?.call(error);
        // Hide progress after error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _cachingProgress = null;
              _isCachingInProgress = false;
            });
          }
        });
      },
    );
  }
}
