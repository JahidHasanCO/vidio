import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/constants/video_constants.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_initializer.dart';
import 'package:vidio/src/utils/video_parser.dart';
import 'package:vidio/src/widgets/action_bar.dart';
import 'package:vidio/src/widgets/ambient_mode_settings.dart';
import 'package:vidio/src/widgets/live_direct_button.dart';
import 'package:vidio/src/widgets/playback_speed_slider.dart';
import 'package:vidio/src/widgets/player_bottom_bar.dart';
import 'package:vidio/src/widgets/unlock_button.dart';
import 'package:vidio/src/widgets/video_loading.dart';
import 'package:vidio/src/widgets/video_quality_picker.dart';
import 'package:vidio/vidio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  late AnimationController controlBarAnimationController;
  Animation<double>? controlTopBarAnimation;
  VoidCallback? onFullScreenIconTap;
  Animation<double>? controlBottomBarAnimation;
  VideoPlayerController? controller;
  bool hasInitError = false;
  String? videoDuration;
  String? videoSeek;
  Duration? duration;
  double? videoSeekSecond;
  double? videoDurationSecond;
  List<M3U8Data> m3u8UrlList = [];
  List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double playbackSpeed = 1;
  List<AudioModel> audioList = [];
  String? m3u8Content;
  String? subtitleContent;
  bool isQualityPickerVisible = false;
  bool fullScreen = false;
  bool showMenu = false;
  bool showSubtitles = false;
  bool? isOffline;
  String m3u8Quality = 'Auto';
  Timer? controlHideTimer;
  OverlayEntry? overlayEntry;
  GlobalKey videoQualityKey = GlobalKey();
  Duration? lastPlayedPos;
  bool isAtLivePosition = true;
  bool hideQualityList = false;
  bool isAmbientMode = false;
  bool isLocked = false;

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
    fullScreen = widget.initFullScreen;
    isAmbientMode = widget.isAmbientMode;
    playbackSpeed = widget.playbackSpeed;
    determineVideoSource(widget.url);
    controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    controlTopBarAnimation = Tween<double>(begin: -(36.0 + 0.0 * 2), end: 0).animate(controlBarAnimationController);
    controlBottomBarAnimation = Tween<double>(begin: -(36.0 + 0.0 * 2), end: 0).animate(controlBarAnimationController);
  }

  @override
  void dispose() {
    m3u8Clean();
    controller?.removeListener(listener);
    controller?.dispose();
    controlBarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        aspectRatio: fullScreen ? 16 / 9 : widget.aspectRatio,
        child: controller?.value.isInitialized == false
            ? buildLoadingState()
            : buildVideoPlayer(),
      ),
    );
  }

  /// Builds the loading state when video is not initialized
  Widget buildLoadingState() {
    return VideoLoading(loadingStyle: widget.videoLoadingStyle);
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

        if (localPosition.dx < width / 3) {
          controller!.rewind().then(
                (value) => widget.onRewind?.call(controller!.value),
              );
        } else if (localPosition.dx > (2 * width) / 3) {
          controller!.fastForward().then(
                (value) => widget.onRewind?.call(controller!.value),
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
          color: showMenu && !isLocked ? Colors.black.withOpacity(0.35) : Colors.transparent,
        ),
        child: controller == null
            ? const SizedBox.shrink()
            : widget.allowRepaintBoundary && widget.repaintBoundaryKey != null
                ? RepaintBoundary(
                    key: widget.repaintBoundaryKey,
                    child: InteractiveViewer(
                      panEnabled: fullScreen,
                      scaleEnabled: fullScreen,
                      minScale: 1,
                      maxScale: 5,
                      child: VideoPlayer(controller!),
                    ),
                  )
                : InteractiveViewer(
                    panEnabled: fullScreen,
                    scaleEnabled: fullScreen,
                    minScale: 1,
                    maxScale: 5,
                    child: VideoPlayer(controller!),
                  ),
      ),
    );
  }

  /// Builds the controls overlay (action bar, bottom controls, etc.)
  List<Widget> buildControlsOverlay() {
    if (isLocked) {
      return [
        UnlockButton(
          isLocked: isLocked,
          showMenu: showMenu,
          onUnlock: () {
            setState(() {
              isLocked = !isLocked;
            });
          },
        ),
      ];
    }
    return videoBuiltInChildren();
  }

  List<Widget> videoBuiltInChildren() {
    return [
      ActionBar(
        showMenu: showMenu,
        fullScreen: fullScreen,
        isLocked: isLocked,
        videoStyle: widget.videoStyle,
        onSupportButtonTap: widget.onSupportButtonTap != null
            ? () {
                if (showMenu && mounted) {
                  setState(() {
                    showMenu = false;
                    removeOverlay();
                  });
                }
                widget.onSupportButtonTap?.call();
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
                widget.onVideoListTap?.call();
              }
            : null,
        onSettingsTap: () => showSettingsDialog(context),
      ),
      LiveDirectButton(
        controller: controller,
        showMenu: showMenu,
        isAtLivePosition: isAtLivePosition,
        videoStyle: widget.videoStyle,
        onLiveDirectTap: widget.onLiveDirectTap,
      ),
      backButton(),
      bottomBar(),
      _miniProgress(),
    ];
  }

  Widget _miniProgress() {
    return Visibility(
      visible: !showMenu && widget.showMiniProgress,
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
                            controller!,
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

  Widget backButton() {
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
              if (fullScreen) {
                setState(() {
                  fullScreen = !fullScreen;
                  widget.onFullScreen?.call(fullScreen);
                });
              } else {
                if (widget.onBackButtonTap != null) {
                  widget.onBackButtonTap?.call();
                }
              }
            },
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
      ),
    );
  }



  Widget bottomBar() {
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Visibility(
      visible: showMenu,
      child: Align(
        child: PlayerBottomBar(
          hideFullScreenButton: widget.hideFullScreenButton,
          fullScreen: fullScreen,
          controller: controller!,
          videoSeek: videoSeek ?? '00:00:00',
          videoDuration: videoDuration ?? '00:00:00',
          videoStyle: widget.videoStyle,
          showBottomBar: showMenu,
          onPlayButtonTap: togglePlay,
          onFastForward: (value) => widget.onFastForward?.call(value),
          onRewind: (value) => widget.onRewind?.call(value),
          onFullScreen: () => setState(() {
            fullScreen = !fullScreen;
            widget.onFullScreen?.call(fullScreen);
          }),
          onFullScreenIconTap: widget.onFullScreenIconTap,
          hidePipButton: widget.hidePIPButton ?? true,
          onPipMode: () {
            widget.onPIPIconTap?.call();
            if (showMenu && mounted) {
              setState(() {
                showMenu = false;
                removeOverlay();
              });
            }
          },
        ),
      ),
    );
  }



  Widget m3u8List() {
    final renderBox = videoQualityKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero);
    return VideoQualityPicker(
      videoData: m3u8UrlList,
      videoStyle: widget.videoStyle,
      showPicker: isQualityPickerVisible,
      positionRight: (renderBox?.size.width ?? 0.0) / 3,
      positionTop: (offset?.dy ?? 0.0) + 35.0,
      onQualitySelected: (data) {
        if (data.dataQuality != m3u8Quality) {
          setState(() {
            m3u8Quality = data.dataQuality ?? m3u8Quality;
          });
          onSelectQuality(data);
        }
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
          FileUtils.cacheFileToLocalStorage(
            url,
            fileExtension: extension,
            headers: widget.headers,
            onSaveCompleted: (file) {
              widget.onCacheFileCompleted?.call(file != null ? [file] : null);
            },
            onSaveFailed: widget.onCacheFileFailed,
          );
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
    final result = await VideoParser.parseM3U8Playlist(
      videoUrl: videoUrl,
      m3u8UrlList: m3u8UrlList,
      audioList: audioList,
      headers: widget.headers,
      allowCacheFile: widget.allowCacheFile,
      onCacheFileCompleted: widget.onCacheFileCompleted,
      onCacheFileFailed: widget.onCacheFileFailed,
    );
    
    if (mounted) {
      setState(() {
        // Update state if needed
      });
    }
    
    return result;
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

    if (controller?.value.isInitialized == true && controller?.value.isPlaying == true) {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
      }

      if (mounted) {
        setState(() {
          videoDuration = controller?.value.duration.convertDurationToString();
          videoSeek = controller?.value.position.convertDurationToString();
          videoSeekSecond = controller?.value.position.inSeconds.toDouble();
          videoDurationSecond = controller?.value.duration.inSeconds.toDouble();
        });
      }
    } else {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  void createHideControlBarTimer() {
    clearHideControlBarTimer();
    controlHideTimer = Timer(VideoConstants.kControlHideDuration, () {
      if (controller?.value.isPlaying == true) {
        if (showMenu && mounted) {
          setState(() {
            showMenu = false;
            isQualityPickerVisible = false;
            controlBarAnimationController.reverse();
            widget.onShowMenu?.call(showMenu, isQualityPickerVisible);
            removeOverlay();
          });
        }
      }
    });
  }

  void clearHideControlBarTimer() {
    controlHideTimer?.cancel();
  }

  void toggleControls() {
    clearHideControlBarTimer();

    if (!showMenu) {
      setState(() {
        showMenu = true;
      });
      widget.onShowMenu?.call(showMenu, isQualityPickerVisible);

      createHideControlBarTimer();
    } else {
      setState(() {
        isQualityPickerVisible = false;
        showMenu = false;
      });

      widget.onShowMenu?.call(showMenu, isQualityPickerVisible);
    }
    if (showMenu) {
      controlBarAnimationController.forward();
    } else {
      controlBarAnimationController.reverse();
    }
  }

  void togglePlay() {
    createHideControlBarTimer();
    if (controller?.value.isPlaying == true) {
      controller?.pause().then((_) {
        widget.onPlayButtonTap?.call(controller?.value.isPlaying ?? false);
      });
    } else {
      controller?.play().then((_) {
        widget.onPlayButtonTap?.call(controller?.value.isPlaying ?? false);
      });
    }
    setState(() {});
  }

  void videoInit(String? url) {
    controller = VideoInitializer.createVideoController(
      url: url ?? '',
      videoFormat: videoFormat,
      isOffline: isOffline ?? false,
      headers: widget.headers,
      closedCaptionFile: widget.closedCaptionFile,
      videoPlayerOptions: widget.videoPlayerOptions,
      allowCacheFile: widget.allowCacheFile,
      onCacheFileCompleted: widget.onCacheFileCompleted,
      onCacheFileFailed: widget.onCacheFileFailed,
    );

    // Initialize the controller
    controller?.initialize().then((_) {
      setState(() => hasInitError = false);
      seekToLastPlayingPosition();
    }).catchError((e) {
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
    controller?.dispose();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      closedCaptionFile: widget.closedCaptionFile,
      videoPlayerOptions: widget.videoPlayerOptions,
      httpHeaders: widget.headers ?? const <String, String>{},
    )..initialize().then((_) {
        setState(() => hasInitError = false);
        seekToLastPlayingPosition();
        controller?.play();
      }).catchError((e) {
        setState(() => hasInitError = true);
      });

    controller?.addListener(listener);
    controller?.play();
  }

  Future<void> m3u8Clean() async {
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
    try {
      audioList.clear();
    } catch (e) {
      rethrow;
    }
    audioList.clear();
    try {
      m3u8UrlList.clear();
    } catch (e) {
      rethrow;
    }
  }

  void showOverlay() {
    setState(() {
      overlayEntry = OverlayEntry(
        builder: (_) => m3u8List(),
      );
      Overlay.of(context).insert(overlayEntry!);
    });
  }

  void setPlaybackSpeed(double speed, {bool notify = true}) {
    setState(() {
      playbackSpeed = speed;
    });
    controller?.setPlaybackSpeed(speed);
    if (notify) {
      widget.onPlaybackSpeedChanged?.call(speed);
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

  Future<void> showSettingsDialog(BuildContext context) {
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
        duration = controller?.value.duration;
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
                    videoStyle: widget.videoStyle,
                    showPicker: true,
                    onQualitySelected: (data) {
                      if (data.dataQuality != m3u8Quality) {
                        setState(() {
                          m3u8Quality = data.dataQuality ?? m3u8Quality;
                        });
                        onSelectQuality(data);
                      }
                      setState(() {
                        isQualityPickerVisible = false;
                      });
                      Navigator.pop(context);
                    },
                    selectedQuality: m3u8Quality,
                  ),
                const SizedBox(height: 10),
                PlaybackSpeedSlider(
                  speeds: playbackSpeeds,
                  currentSpeed: playbackSpeed,
                  onSpeedChanged: (speed) {
                    setPlaybackSpeed(speed);
                    onPlayBackSpeedChange(speed: speed);
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

                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    // Optional: toggle also on tap (in addition to switch)
                    setState(() {
                      loop = !loop;
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

                    Navigator.pop(context);
                  },
                ),
                AmbientModeSettings(
                  value: isAmbientMode,
                  onChanged: ({bool? value}) {
                    setState(() {
                      isAmbientMode = value ?? false;
                    });
                    widget.onAmbientModeChanged?.call(value ?? false);
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

  void removeOverlay() {
    setState(() {
      overlayEntry?.remove();
      overlayEntry = null;
    });
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
}
