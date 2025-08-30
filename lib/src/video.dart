import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/cache/video_cache_manager.dart';
import 'package:vidio/src/constants/video_player_config.dart';
import 'package:vidio/src/model/model.dart';
import 'package:vidio/src/source/video_event_manager.dart';
import 'package:vidio/src/source/video_loading_style.dart';
import 'package:vidio/src/source/video_playback_manager.dart';
import 'package:vidio/src/source/video_style.dart';
import 'package:vidio/src/utils/m3u8_manager.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_error_handler.dart';
import 'package:vidio/src/utils/video_managers.dart';
import 'package:vidio/src/utils/video_parser.dart';
import 'package:vidio/src/utils/video_performance_manager.dart';
import 'package:vidio/src/utils/video_state_manager.dart';
import 'package:vidio/src/utils/video_timing_manager.dart';
import 'package:vidio/src/widgets/unlock_button.dart';
import 'package:vidio/src/widgets/video_quality_picker.dart';
import 'package:vidio/src/widgets/video_ui_builder.dart';

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

class _VidioState extends State<Vidio>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? videoFormat;
  bool loop = false;
  bool _managersInitialized = false;

  // Caching progress state
  CachingProgressData? _cachingProgress;
  final List<String> _cacheLogs = [];
  String? _currentVideoUrl;
  int _currentVideoDurationMs = 0;
  final List<CachedRange> _cachedRanges = [];
  bool _isContinuousCachingActive = false;

  // YouTube-style caching additions
  final Map<String, Uint8List> _memoryCache = {}; // Memory cache for segments
  final List<String> _prefetchQueue = []; // Queue for prefetching segments
  bool _isPrefetching = false;
  double _currentBandwidth = 0.0; // Current bandwidth estimation
  final List<double> _bandwidthHistory = []; // Bandwidth history for averaging
  Timer? _bandwidthMonitorTimer; // Timer for bandwidth monitoring
  bool _isConnected = true; // Network connectivity status

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

  set isQualityPickerVisible(bool value) =>
      uiStateManager.isQualityPickerVisible = value;

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

  set videoDurationSecond(double? value) =>
      timingManager.videoDurationSecond = value;

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
    if (widget.playbackSpeed != oldWidget.playbackSpeed &&
        widget.playbackSpeed != playbackSpeed) {
      setPlaybackSpeed(widget.playbackSpeed, notify: false);
    }
  }

  @override
  void initState() {
    super.initState();

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

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

    // Start bandwidth monitoring for adaptive quality
    _startBandwidthMonitoring();
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
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    m3u8Clean();
    controller?.removeListener(listener);
    controller?.dispose();
    uiStateManager.dispose();
    errorHandler.dispose();
    performanceManager.dispose();
    _stopContinuousCaching();
    _bandwidthMonitorTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (kDebugMode) {
      print('DEBUG: App lifecycle changed: $state');
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground
        if (controller != null &&
            controller!.value.isPlaying &&
            widget.allowCacheFile &&
            !_isContinuousCachingActive) {
          final currentUrl = controller!.dataSource;
          if (currentUrl.isNotEmpty) {
            if (kDebugMode) {
              print('DEBUG: Resuming continuous caching after app resume');
            }
            _startContinuousCaching(currentUrl);
          }
        }
      case AppLifecycleState.paused:
        // App went to background - caching should continue
        if (kDebugMode) {
          print(
            'DEBUG: App paused, continuous caching will continue in background',
          );
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is inactive or detached
        if (kDebugMode) {
          print('DEBUG: App inactive/detached, stopping continuous caching');
        }
        _stopContinuousCaching();
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
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
        aspectRatio:
            configManager.getAspectRatio(fullScreen, widget.aspectRatio),
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
        } else if (localPosition.dx >
            configManager.getFastForwardThreshold(width)) {
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
      cachedRanges: getCachedRanges(),
    );
  }

  Widget m3u8List() {
    // Only create the overlay content if it should be visible
    if (!isQualityPickerVisible) {
      return const SizedBox.shrink();
    }

    final renderBox =
        videoQualityKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero);
    return Container(
      key: videoQualityKey, // Use the GlobalKey here
      child: VideoQualityPicker(
        videoData: m3u8UrlList,
        videoStyle: widget.videoStyle,
        showPicker: isQualityPickerVisible,
        positionRight: configManager
            .getQualityPickerPositionRight(renderBox?.size.width ?? 0.0),
        positionTop:
            configManager.getQualityPickerPositionTop(offset?.dy ?? 0.0),
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
      ),
    );
  }

  void determineVideoSource(String url) {
    // Clear previous cached ranges for new video
    _cachedRanges.clear();
    _cacheLogs.clear();
    _stopContinuousCaching();

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
          if (kDebugMode) {
            print(
              'DEBUG: Starting caching for format: $detectedFormat, URL: $url',
            );
          }
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
        errorHandler.handleParsingError(
          result.error,
          null,
          'Failed to parse M3U8 playlist',
        );
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
  }

  Future<void> videoControlSetup(String? url) async {
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
    // Also continue caching even when paused (YouTube behavior)
    if (controller != null &&
        widget.allowCacheFile &&
        !_isContinuousCachingActive &&
        controller!.value.isInitialized) {
      final currentUrl = controller!.dataSource;
      if (currentUrl.isNotEmpty) {
        if (kDebugMode) {
          print('DEBUG: Starting continuous caching - Video initialized');
        }
        _startContinuousCaching(currentUrl);
      }
    }

    // Stop continuous caching when video ends
    if (controller != null &&
        controller!.value.position >= controller!.value.duration &&
        _isContinuousCachingActive) {
      if (kDebugMode) {
        print('DEBUG: Stopping continuous caching - Video ended');
      }
      _stopContinuousCaching();
    }

    // Debug: Log caching status periodically
    if (controller != null) {
      final position = controller!.value.position.inMilliseconds;
      final duration = controller!.value.duration.inMilliseconds;
      final progress = duration > 0 ? (position * 100 / duration).round() : 0;

      // Log status every 5 seconds or when caching status changes
      final shouldLog = DateTime.now().second % 5 == 0;
      if (shouldLog) {
        if (kDebugMode) {
          print(
            'DEBUG: Video status: $progress% complete, '
            'Caching active: $_isContinuousCachingActive,'
            ' Cached ranges: ${_cachedRanges.length}',
          );
        }
        if (_cachedRanges.isNotEmpty) {
          if (kDebugMode) {
            print(
              'DEBUG: Cached ranges: '
              '${_cachedRanges.map(
                    (r) => '${r.startByte}-${r.endByte} '
                        '(${(r.size / 1000000).toStringAsFixed(1)}MB)',
                  ).join(', ')}',
            );
          }
          if (kDebugMode) {
            print(
              'DEBUG: Estimated file size: '
              '${(_estimateFileSize() / 1000000).toStringAsFixed(1)}MB',
            );
          }
        }
      }
    }

    // Handle network loss: continue playing cached ranges
    if (controller != null && !_isConnected && controller!.value.isBuffering) {
      // If network is lost and buffering, pause and wait for cached content
      if (controller!.value.isPlaying) {
        controller!.pause();
        // Resume when cached content is available
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isConnected && _cachedRanges.isNotEmpty) {
            controller!.play();
          }
        });
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
            // Also hide quality picker when controls are hidden
            if (isQualityPickerVisible) {
              removeOverlay();
            }
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
    final wasPlaying = controller?.value.isPlaying ?? false;
    playbackManager.togglePlay(controller);
    final isPlaying = controller?.value.isPlaying ?? false;

    if (kDebugMode) {
      print(
        'DEBUG: Play state changed - Was playing: '
        '$wasPlaying, Now playing: $isPlaying',
      );
    }

    // If video was paused and is now playing,
    // ensure continuous caching is active
    if (!wasPlaying &&
        isPlaying &&
        widget.allowCacheFile &&
        !_isContinuousCachingActive) {
      final currentUrl = controller!.dataSource;
      if (currentUrl.isNotEmpty) {
        if (kDebugMode) {
          print('DEBUG: Resuming continuous caching after play');
        }
        _startContinuousCaching(currentUrl);
      }
    }

    eventManager.callPlayButtonTap(controller?.value.isPlaying ?? false);
    if (mounted) {
      setState(() {});
    }
  }

  void videoInit(String? url) {
    performanceManager
        .measureExecutionTime(
      () => videoControllerManager.initializeController(
        url ?? '',
        videoFormat,
        isOffline ?? false,
        playbackSpeed,
        lastPlayedPos,
      ),
      operationName: 'videoInit',
    )
        .then((result) {
      if (result.hasError) {
        errorHandler.handleInitializationError(
          result.error,
          null,
          'Failed to initialize video controller',
        );
        if (mounted) {
          setState(() => hasInitError = true);
        }
      } else {
        if (mounted) {
          setState(() => hasInitError = false);
        }
        seekToLastPlayingPosition();
        // Don't clear caching progress - let it continue in background
        // _clearCachingProgress();
      }
    }).catchError((dynamic error, StackTrace? stackTrace) {
      errorHandler.handleInitializationError(
        error,
        stackTrace,
        'Video initialization failed',
      );
      if (mounted) {
        setState(() => hasInitError = true);
      }
    });

    // Hide quality list for offline content
    if (isOffline ?? false) {
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
    performanceManager
        .measureExecutionTime(
      () => videoControllerManager.playLocalM3U8File(url),
      operationName: 'playLocalM3U8File',
    )
        .then((result) {
      if (result.hasError) {
        errorHandler.handlePlaybackError(
          result.error,
          null,
          'Failed to play local M3U8 file',
        );
        if (mounted) {
          setState(() => hasInitError = true);
        }
      } else {
        if (mounted) {
          setState(() => hasInitError = false);
        }
        seekToLastPlayingPosition();
      }
    }).catchError((dynamic error, StackTrace? stackTrace) {
      errorHandler.handlePlaybackError(
        error,
        stackTrace,
        'Local M3U8 playback failed',
      );
      if (mounted) {
        setState(() => hasInitError = true);
      }
    });
  }

  Future<void> m3u8Clean() async {
    await m3u8Manager.cleanM3U8Files();
  }

  void showOverlay() {
    // Prevent showing overlay if already visible
    if (isQualityPickerVisible) {
      return;
    }

    setState(() {
      isQualityPickerVisible = true;
    });

    uiStateManager.showOverlay(context, m3u8List());
  }

  /// Public method to show the quality picker overlay
  void showQualityPicker() {
    showOverlay();
  }

  void setPlaybackSpeed(double speed, {bool notify = true}) {
    playbackManager.setPlaybackSpeed(speed, controller);
    if (notify) {
      eventManager.callPlaybackSpeedChanged(speed);
    }
  }

  void onPlayBackSpeedChange({required double speed}) {
    setPlaybackSpeed(speed);
    if (controller?.value.isPlaying ?? false) {
      controller?.pause();
      controller?.play();
    } else {
      controller?.play();
    }
  }

  void setLoopWithController(bool val) {
    if (mounted) {
      setState(() {
        loop = val;
        if (controller?.value.isPlaying ?? false) {
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
        if (mounted) {
          setState(() {
            isAmbientMode = value;
          });
        }
        eventManager.callAmbientModeChanged(value);
      },
      setLoop: (val) {
        if (mounted) {
          setState(() {
            loop = val;
          });
        }
      },
      setLoopWithController: setLoopWithController,
    );
  }

  void removeOverlay() {
    setState(() {
      isQualityPickerVisible = false;
    });
    uiStateManager.removeOverlay();
  }

  /// Public method to hide the quality picker overlay
  void hideQualityPicker() {
    removeOverlay();
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
    if (!widget.allowCacheFile || !mounted) return;

    if (kDebugMode) {
      print(
        'DEBUG: Updating cache progress: ${(progress * 100).toInt()}%, log: $log',
      );
    }

    // Only add logs if they're meaningful (not just progress updates)
    if (log != null && !log.contains('Cache progress:')) {
      _cacheLogs.add(log);
      // Keep only last 3 logs to avoid memory issues
      if (_cacheLogs.length > 3) {
        _cacheLogs.removeAt(0);
      }
    }

    // Create more informative progress message
    final segmentInfo = _cachedRanges.isNotEmpty
        ? ' (${_cachedRanges.length} segments cached)'
        : '';
    final statusMessage = progress >= 1.0
        ? 'Segment buffered ahead$segmentInfo'
        : progress > 0.0
            ? 'Buffering segment... ${(progress * 100).toInt()}%$segmentInfo'
            : 'Preparing buffer...$segmentInfo';

    // Add status message to logs if it's meaningful
    if (statusMessage.isNotEmpty && !_cacheLogs.contains(statusMessage)) {
      _cacheLogs.add(statusMessage);
      if (_cacheLogs.length > 3) {
        _cacheLogs.removeAt(0);
      }
    }

    if (mounted) {
      setState(() {
        _cachingProgress = CachingProgressData(
          progress: progress,
          logs: List.from(_cacheLogs),
          isVisible: _isContinuousCachingActive ||
              progress > 0.0, // Show when caching is active or in progress
        );
      });
    }
  }

  /// Starts caching with progress tracking
  void _startCaching(String url, {String? quality}) {
    if (!widget.allowCacheFile) {
      if (kDebugMode) {
        print('DEBUG: Caching disabled - allowCacheFile is false');
      }
      return;
    }

    if (kDebugMode) {
      print('DEBUG: Starting caching for URL: $url with quality: $quality');
    }
    _currentVideoUrl = url;
    _cacheLogs.clear();
    _updateCachingProgress(0, 'Starting background cache...');

    VideoCacheManager().cacheVideoFile(
      url,
      quality: quality,
      headers: widget.headers,
      onProgress: (double progress) {
        if (kDebugMode) {
          print('DEBUG: Cache progress update: ${(progress * 100).toInt()}%');
        }
        _updateCachingProgress(progress);
      },
      onLog: (String log) {
        if (kDebugMode) {
          print('DEBUG: Cache log: $log');
        }
        // Only log important events, not every progress update
        if (!log.contains('Cache progress:') &&
            !log.contains('Background cache progress:')) {
          _updateCachingProgress(_cachingProgress?.progress ?? 0.0, log);
        }
      },
      onComplete: (File? file) {
        if (kDebugMode) {
          print('DEBUG: Cache completed: ${file?.path}');
        }
        if (file != null) {
          _updateCachingProgress(1, 'Cache completed');
          widget.onCacheFileCompleted?.call([file]);
          // Keep progress visible briefly then hide
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _updateCachingProgress(0); // Hide progress
            }
          });
        }
      },
      onError: (dynamic error) {
        if (kDebugMode) {
          print('DEBUG: Cache error: $error');
        }
        _updateCachingProgress(
          _cachingProgress?.progress ?? 0.0,
          'Cache failed',
        );
        widget.onCacheFileFailed?.call(error);
        // Hide progress after error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _updateCachingProgress(0);
          }
        });
      },
    );
  }

  /// Starts YouTube-style continuous caching during playback
  void _startContinuousCaching(String url) {
    if (!widget.allowCacheFile || controller == null) return;

    if (kDebugMode) {
      print('DEBUG: Starting continuous caching for: $url');
    }
    _currentVideoUrl = url;
    _cacheLogs.clear();
    _cachedRanges.clear(); // Clear previous cached ranges for new video
    _isContinuousCachingActive = true;

    // Get current playback position for smart caching ahead
    final totalDuration = controller!.value.duration.inMilliseconds;

    if (totalDuration == 0) return;

    _currentVideoDurationMs = totalDuration;

    // Start prefetching next few segments
    _prefetchSegments();
  }

  /// Caches the next segment in sequence
  void _cacheNextSegment() {
    if (!widget.allowCacheFile ||
        controller == null ||
        _currentVideoUrl == null) {
      if (kDebugMode) {
        print('DEBUG: Cannot cache next segment - missing requirements');
      }
      return;
    }

    final currentPosition = controller!.value.position.inMilliseconds;
    final totalDuration = _currentVideoDurationMs;

    if (kDebugMode) {
      print('DEBUG: Next segment calculation:');
      print(
        'DEBUG:   Current position: ${currentPosition}ms'
        ' (${Duration(milliseconds: currentPosition).inSeconds}s)',
      );
      print(
        'DEBUG:   Total duration: ${totalDuration}ms'
        ' (${Duration(milliseconds: totalDuration).inSeconds}s)',
      );
      print('DEBUG:   Caching active: $_isContinuousCachingActive');
    }
    if (totalDuration == 0) {
      if (kDebugMode) {
        print('DEBUG: Cannot cache next segment - invalid duration');
      }
      return;
    }

    // Find the next position to cache (look for gaps in cached ranges)
    final nextPositionMs =
        _findNextCachePosition(currentPosition, totalDuration);

    if (nextPositionMs >= totalDuration) {
      if (kDebugMode) {
        print('DEBUG: Reached end of video, stopping continuous cache');
      }
      _isContinuousCachingActive = false;
      return;
    }

    final startByte = _calculateCacheStartByte(nextPositionMs, totalDuration);
    final endByte = _calculateCacheEndByte(nextPositionMs, totalDuration);

    // Validate byte range
    if (startByte >= endByte || startByte < 0) {
      if (kDebugMode) {
        print(
          'DEBUG: Invalid byte range: '
          '$startByte - $endByte, trying next segment in 2 seconds',
        );
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isContinuousCachingActive) {
          _prefetchSegments();
        }
      });
      return;
    }

    // Check if this range is already cached
    if (_isRangeCached(startByte, endByte)) {
      if (kDebugMode) {
        print(
          'DEBUG: Range already cached '
          '($startByte-$endByte), trying next segment in 500ms',
        );
      }
      // Try next segment
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isContinuousCachingActive) {
          _prefetchSegments();
        }
      });
      return;
    }

    if (kDebugMode) {
      print(
        'DEBUG: Caching next segment: $startByte - $endByte '
        '(time: ${Duration(milliseconds: nextPositionMs).inSeconds}s - '
        '${Duration(milliseconds: (nextPositionMs + 30000).clamp(0, totalDuration)).inSeconds}s)',
      );
    }

    VideoCacheManager().cacheVideoFilePartial(
      _currentVideoUrl!,
      startByte: startByte,
      endByte: endByte,
      headers: widget.headers,
      onProgress: _updateCachingProgress,
      onRangeCached: (int start, int end) {
        if (kDebugMode) {
          print('DEBUG: Range cached successfully: $start - $end');
        }
        _addCachedRange(start, end);
        if (mounted) {
          setState(() {}); // Update UI to show new cached range
        }

        // Update overall progress
        final overallProgress = getOverallCachingProgress();
        if (kDebugMode) {
          print(
            'DEBUG: Overall caching progress: '
            '${(overallProgress * 100).toInt()}%',
          );
        }
      },
      onLog: (String log) {
        if (log.contains('Cache completed') ||
            log.contains('Cache failed') ||
            log.contains('Starting')) {
          if (kDebugMode) {
            print('DEBUG: Cache log: $log');
          }
        }
      },
      onComplete: (File? file) {
        if (file != null) {
          if (kDebugMode) {
            print(
              'DEBUG: Segment cache completed successfully, '
              'queuing next segment in 1 second',
            );
          }
          widget.onCacheFileCompleted?.call([file]);

          // Continue with next segment after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _isContinuousCachingActive) {
              if (kDebugMode) {
                print('DEBUG: Starting next segment after delay');
              }
              _prefetchSegments();
            } else {
              if (kDebugMode) {
                print(
                  'DEBUG: Not starting next segment - mounted: '
                  '$mounted, caching active: $_isContinuousCachingActive',
                );
              }
            }
          });
        } else {
          if (kDebugMode) {
            print(
              'DEBUG: Segment cache completed but no '
              'file returned, trying next segment in 2 seconds',
            );
          }
          // Try next segment after error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isContinuousCachingActive) {
              _prefetchSegments();
            }
          });
        }
      },
      onError: (dynamic error) {
        if (kDebugMode) {
          print(
            'DEBUG: Segment cache error: '
            '$error, trying next segment in 2 seconds',
          );
        }
        // Try next segment after error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isContinuousCachingActive) {
            if (kDebugMode) {
              print('DEBUG: Retrying after error');
            }
            _prefetchSegments();
          }
        });
      },
    );
  }

  /// Stops continuous caching
  void _stopContinuousCaching() {
    if (kDebugMode) {
      print('DEBUG: Stopping continuous caching');
    }
    _isContinuousCachingActive = false;

    // Only update progress if widget is still mounted
    if (mounted) {
      _updateCachingProgress(0); // Hide progress
    }

    // Clear current video URL to prevent accidental restarts
    _currentVideoUrl = null;
  }

  /// Finds the next position that needs to be cached
  /// (looks for gaps in cached ranges)
  int _findNextCachePosition(int currentPositionMs, int totalDurationMs) {
    // Always try to cache ahead of current position first
    const cacheAheadMs = 30000; // 30 seconds ahead
    var nextPositionMs = currentPositionMs + cacheAheadMs;

    // If we have cached ranges, look for gaps
    if (_cachedRanges.isNotEmpty) {
      // Sort cached ranges by start byte
      final sortedRanges = List<CachedRange>.from(_cachedRanges)
        ..sort((a, b) => a.startByte.compareTo(b.startByte));

      // Convert current position to byte position for comparison
      final currentBytePos =
          _calculateCacheStartByte(currentPositionMs, totalDurationMs);

      // Look for gaps in cached ranges
      for (var i = 0; i < sortedRanges.length; i++) {
        final range = sortedRanges[i];

        // If current position is before this range, cache from current position
        if (currentBytePos < range.startByte) {
          // Convert back to time position
          final timeProgress = range.startByte / _estimateFileSize();
          nextPositionMs = (timeProgress * totalDurationMs).toInt();
          break;
        }

        // Check for gap after this range (if not the last range)
        if (i < sortedRanges.length - 1) {
          final nextRange = sortedRanges[i + 1];
          final gapStart = range.endByte;
          final gapEnd = nextRange.startByte;

          // If there's a significant gap, cache it
          if (gapEnd - gapStart > 1000000) {
            // 1MB gap
            final timeProgress = gapStart / _estimateFileSize();
            nextPositionMs = (timeProgress * totalDurationMs).toInt();
            break;
          }
        }
      }
    }

    // Ensure we don't exceed video duration
    return nextPositionMs.clamp(
      0,
      totalDurationMs - 1000,
    ); // Leave 1 second margin
  }

  /// Calculates start byte for caching based on playback position
  int _calculateCacheStartByte(int currentPositionMs, int totalDurationMs) {
    // Start caching from current position + 10 seconds buffer
    const bufferMs = 10000;
    final startMs = (currentPositionMs + bufferMs).clamp(0, totalDurationMs);

    // Estimate byte position (rough approximation)
    final progressRatio = startMs / totalDurationMs;
    return (progressRatio * _estimateFileSize()).toInt();
  }

  /// Calculates end byte for caching
  int _calculateCacheEndByte(int currentPositionMs, int totalDurationMs) {
    // Cache 30 seconds ahead
    const cacheAheadMs = 30000;
    final endMs = (currentPositionMs + cacheAheadMs).clamp(0, totalDurationMs);

    final progressRatio = endMs / totalDurationMs;
    return (progressRatio * _estimateFileSize()).toInt();
  }

  /// Estimates file size based on duration and bitrate
  int _estimateFileSize() {
    if (_currentVideoDurationMs == 0) return 0;

    // More realistic estimation for video files:
    // assume 50MB per minute (typical for HD video)
    const bytesPerMinute = 50000000; // 50MB per minute
    final durationMinutes = _currentVideoDurationMs / 60000.0;
    final estimatedSize = (durationMinutes * bytesPerMinute).toInt();

    if (kDebugMode) {
      print(
        'DEBUG: Estimated file size: ${estimatedSize ~/ 1000000}MB '
        'for ${durationMinutes.toStringAsFixed(1)} minutes',
      );
    }
    return estimatedSize;
  }

  /// Adds a cached range to the list
  void _addCachedRange(int startByte, int endByte) {
    final newRange = CachedRange(
      startByte: startByte,
      endByte: endByte,
      cachedAt: DateTime.now(),
    );
    _cachedRanges.add(newRange);

    // Merge overlapping ranges
    _mergeCachedRanges();
    if (kDebugMode) {
      print(
        'DEBUG: Added cached range: '
        '$startByte - $endByte, total ranges: ${_cachedRanges.length}',
      );
    }
  }

  /// Merges overlapping cached ranges
  void _mergeCachedRanges() {
    if (_cachedRanges.length < 2) return;

    _cachedRanges.sort((a, b) => a.startByte.compareTo(b.startByte));

    final merged = <CachedRange>[];
    var current = _cachedRanges[0];

    for (var i = 1; i < _cachedRanges.length; i++) {
      final next = _cachedRanges[i];
      if (current.endByte >= next.startByte) {
        // Merge overlapping ranges
        current = CachedRange(
          startByte: current.startByte,
          endByte:
              current.endByte > next.endByte ? current.endByte : next.endByte,
          cachedAt: DateTime.now(),
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    _cachedRanges
      ..clear()
      ..addAll(merged);
  }

  /// Checks if a byte range is already cached
  bool _isRangeCached(int startByte, int endByte) {
    // Check if any significant portion of this range is already cached
    final rangeSize = endByte - startByte;
    if (rangeSize <= 0) return true; // Empty range is considered cached

    var cachedBytes = 0;
    for (final range in _cachedRanges) {
      final overlapStart =
          startByte > range.startByte ? startByte : range.startByte;
      final overlapEnd = endByte < range.endByte ? endByte : range.endByte;

      if (overlapStart < overlapEnd) {
        cachedBytes += overlapEnd - overlapStart;
      }
    }

    // Consider cached if more than 50% of the range is already cached
    final cachedRatio = cachedBytes / rangeSize;
    final isCached = cachedRatio > 0.5;

    if (kDebugMode) {
      print(
        'DEBUG: Range $startByte-$endByte: '
        '$cachedBytes cached bytes (${(cachedRatio * 100).toInt()}%),'
        ' considered cached: $isCached',
      );
    }

    return isCached;
  }

  /// Gets cached ranges as a list of progress values (0.0 to 1.0)
  List<CachedRange> getCachedRanges() {
    return List.from(_cachedRanges);
  }

  /// Gets the overall caching progress (0.0 to 1.0)
  /// based on cached ranges vs estimated total
  double getOverallCachingProgress() {
    if (_cachedRanges.isEmpty || _currentVideoDurationMs == 0) return 0;

    final estimatedTotalBytes = _estimateFileSize();
    if (estimatedTotalBytes == 0) return 0;

    var totalCachedBytes = 0;
    for (final range in _cachedRanges) {
      totalCachedBytes += range.size;
    }

    return (totalCachedBytes / estimatedTotalBytes).clamp(0.0, 1.0);
  }

  /// Starts bandwidth monitoring for adaptive quality
  void _startBandwidthMonitoring() {
    _bandwidthMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (controller != null && controller!.value.isPlaying) {
        // Simple bandwidth estimation based on buffering
        final buffered = controller!.value.buffered;
        if (buffered.isNotEmpty) {
          final bufferDuration = buffered.last.end - buffered.last.start;
          final bandwidth = bufferDuration.inMilliseconds / 5000.0; // bytes per second estimate
          _bandwidthHistory.add(bandwidth);
          if (_bandwidthHistory.length > 10) {
            _bandwidthHistory.removeAt(0);
          }
          _currentBandwidth = _bandwidthHistory.reduce((a, b) => a + b) / _bandwidthHistory.length;
          // Adaptive quality logic
          _adaptQualityBasedOnBandwidth();
        }
      }
    });
  }

  /// Adapts quality based on current bandwidth
  void _adaptQualityBasedOnBandwidth() {
    if (m3u8UrlList.isEmpty || _currentBandwidth == 0) return;

    // Simple adaptive logic: switch to lower quality if bandwidth is low
    const lowBandwidthThreshold = 100000; // 100KB/s
    const highBandwidthThreshold = 500000; // 500KB/s

    if (_currentBandwidth < lowBandwidthThreshold && m3u8Quality != '360p') {
      // Switch to lower quality
      final lowQuality = m3u8UrlList.firstWhere(
        (data) => data.dataQuality == '360p',
        orElse: () => m3u8UrlList.first,
      );
      if (lowQuality.dataURL != null) {
        onSelectQuality(lowQuality);
      }
    } else if (_currentBandwidth > highBandwidthThreshold && m3u8Quality == '360p') {
      // Switch to higher quality
      final highQuality = m3u8UrlList.firstWhere(
        (data) => data.dataQuality == '720p',
        orElse: () => m3u8UrlList.first,
      );
      if (highQuality.dataURL != null) {
        onSelectQuality(highQuality);
      }
    }
  }

  /// Store segment in memory cache
  void _storeInMemoryCache(String key, Uint8List data) {
    _memoryCache[key] = data;
    // Limit memory cache size (e.g., max 100MB)
    const maxMemorySize = 100 * 1024 * 1024; // 100MB
    var totalSize = _memoryCache.values.fold(0, (sum, data) => sum + data.length);
    while (totalSize > maxMemorySize && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      totalSize -= _memoryCache[oldestKey]!.length;
      _memoryCache.remove(oldestKey);
    }
  }

  /// Prefetch next few segments ahead of playback
  void _prefetchSegments() {
    if (_isPrefetching || controller == null) return;

    _isPrefetching = true;
    final currentPosition = controller!.value.position.inMilliseconds;
    final totalDuration = _currentVideoDurationMs;

    // Prefetch next 3 segments (e.g., 30 seconds each)
    const segmentDurationMs = 30000;
    const prefetchCount = 3;

    for (int i = 0; i < prefetchCount; i++) {
      final segmentStart = currentPosition + (i * segmentDurationMs);
      if (segmentStart >= totalDuration) break;

      final segmentEnd = segmentStart + segmentDurationMs;
      final startByte = _calculateCacheStartByte(segmentStart, totalDuration);
      final endByte = _calculateCacheEndByte(segmentEnd, totalDuration);

      if (!_isRangeCached(startByte, endByte)) {
        _prefetchQueue.add('$startByte-$endByte');
      }
    }

    // Start prefetching
    _processPrefetchQueue();
  }

  /// Process prefetch queue
  void _processPrefetchQueue() {
    if (_prefetchQueue.isEmpty) {
      _isPrefetching = false;
      return;
    }

    final range = _prefetchQueue.removeAt(0);
    final parts = range.split('-');
    final startByte = int.parse(parts[0]);
    final endByte = int.parse(parts[1]);

    VideoCacheManager().cacheVideoFilePartial(
      _currentVideoUrl!,
      startByte: startByte,
      endByte: endByte,
      onProgress: (progress) {
        // Update progress
      },
      onRangeCached: (start, end) {
        _addCachedRange(start, end);
        // Store in memory cache
        _storeInMemoryCache('$start-$end', Uint8List(0)); // Placeholder, actual data from file
        // Continue prefetching
        _processPrefetchQueue();
      },
      onLog: (log) {
        _cacheLogs.add(log);
      },
      onError: (error) {
        // Handle error
        _processPrefetchQueue();
      },
    );
  }
}
