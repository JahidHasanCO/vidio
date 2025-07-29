import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/responses/regex_response.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/widgets/ambient_mode_settings.dart';
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
  final void Function(bool showMenu, bool m3u8Show)? onShowMenu;
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
  String? playType;
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
  bool m3u8Show = false;
  bool fullScreen = false;
  bool showMenu = false;
  bool showSubtitles = false;
  bool? isOffline;
  String m3u8Quality = 'Auto';
  Timer? showTime;
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
    urlCheck(widget.url);
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
            ? VideoLoading(loadingStyle: widget.videoLoadingStyle)
            : Stack(
                children: <Widget>[
                  GestureDetector(
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
                  ),
                  if (!isLocked) ...videoBuiltInChildren(),
                  if (isLocked)
                    UnlockButton(
                      isLocked: isLocked,
                      showMenu: showMenu,
                      onUnlock: () {
                        setState(() {
                          isLocked = !isLocked;
                        });
                      },
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> videoBuiltInChildren() {
    return [
      actionBar(),
      liveDirectButton(),
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

  Widget actionBar() {
    return Visibility(
      visible: showMenu,
      child: Align(
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: widget.videoStyle.actionBarPadding ?? EdgeInsets.zero,
            alignment: Alignment.topRight,
            color: widget.videoStyle.actionBarBgColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (fullScreen) ...[
                  InkWell(
                    onTap: () {
                      if (widget.onSupportButtonTap != null) {
                        if (showMenu && mounted) {
                          setState(() {
                            showMenu = false;
                            removeOverlay();
                          });
                        }
                        widget.onSupportButtonTap?.call();
                      }
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                      child: const Icon(
                        Icons.support_agent,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        isLocked = !isLocked;
                      });
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                      child: const Icon(
                        Icons.lock_open_sharp,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (widget.onVideoListTap != null) {
                        if (showMenu && mounted) {
                          setState(() {
                            showMenu = false;
                            removeOverlay();
                          });
                        }
                        widget.onVideoListTap?.call();
                      }
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                      child: SvgPicture.asset(
                        'packages/vidio/assets/icons/playlist.svg',
                        width: 24,
                        height: 24,
                        fit: BoxFit.scaleDown,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
                InkWell(
                  onTap: () => showSettingsDialog(context),
                  child: Container(
                    height: 50,
                    width: 50,
                    margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                SizedBox(
                  width: widget.videoStyle.qualityButtonAndFullScrIcoSpace,
                ),
              ],
            ),
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

  Widget liveDirectButton() {
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Visibility(
      visible: widget.videoStyle.showLiveDirectButton && showMenu,
      child: Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: InkWell(
            onTap: () {
              controller?.seekTo(controller!.value.duration).then((value) {
                widget.onLiveDirectTap?.call(controller!.value);
                controller!.play();
              });
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              margin: const EdgeInsets.only(left: 9),
              child: Row(
                children: [
                  Container(
                    width: widget.videoStyle.liveDirectButtonSize,
                    height: widget.videoStyle.liveDirectButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAtLivePosition ? widget.videoStyle.liveDirectButtonColor : widget.videoStyle.liveDirectButtonDisableColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.videoStyle.liveDirectButtonText ?? 'Live',
                    style: widget.videoStyle.liveDirectButtonTextStyle ?? const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
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
      showPicker: m3u8Show,
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
          m3u8Show = false;
        });
        removeOverlay();
      },
      selectedQuality: m3u8Quality,
    );
  }

  void urlCheck(String url) {
    final netRegex = RegExp(RegexResponse.regexHTTP);
    final isNetwork = netRegex.hasMatch(url);
    final uri = Uri.parse(url);
    if (isNetwork) {
      setState(() {
        isOffline = false;
      });
      if (uri.pathSegments.last.endsWith('mkv')) {
        setState(() {
          playType = 'MKV';
        });
        widget.onPlayingVideo?.call('MKV');

        videoControlSetup(url);

        if (widget.allowCacheFile) {
          FileUtils.cacheFileToLocalStorage(
            url,
            fileExtension: 'mkv',
            headers: widget.headers,
            onSaveCompleted: (file) {
              widget.onCacheFileCompleted?.call(file != null ? [file] : null);
            },
            onSaveFailed: widget.onCacheFileFailed,
          );
        }
      } else if (uri.pathSegments.last.endsWith('mp4')) {
        setState(() {
          playType = 'MP4';
        });
        widget.onPlayingVideo?.call('MP4');

        videoControlSetup(url);

        if (widget.allowCacheFile) {
          FileUtils.cacheFileToLocalStorage(
            url,
            fileExtension: 'mp4',
            headers: widget.headers,
            onSaveCompleted: (file) {
              widget.onCacheFileCompleted?.call(file != null ? [file] : null);
            },
            onSaveFailed: widget.onCacheFileFailed,
          );
        }
      } else if (uri.pathSegments.last.endsWith('webm')) {
        setState(() {
          playType = 'WEBM';
        });
        widget.onPlayingVideo?.call('WEBM');

        videoControlSetup(url);

        if (widget.allowCacheFile) {
          FileUtils.cacheFileToLocalStorage(
            url,
            fileExtension: 'webm',
            headers: widget.headers,
            onSaveCompleted: (file) {
              widget.onCacheFileCompleted?.call(file != null ? [file] : null);
            },
            onSaveFailed: widget.onCacheFileFailed,
          );
        }
      } else if (uri.pathSegments.last.endsWith('m3u8')) {
        setState(() {
          playType = 'HLS';
        });
        widget.onPlayingVideo?.call('M3U8');
        videoControlSetup(url);
        getM3U8(url);
      } else {
        videoControlSetup(url);
        getM3U8(url);
      }
    } else {
      setState(() {
        isOffline = true;
      });

      videoControlSetup(url);
    }
  }

  void getM3U8(String videoUrl) {
    if (m3u8UrlList.isNotEmpty) {
      m3u8Clean();
    }
    m3u8Video(videoUrl);
  }

  Future<M3U8s?> m3u8Video(String? videoUrl) async {
    m3u8UrlList.add(M3U8Data(dataQuality: 'Auto', dataURL: videoUrl));

    final regExp = RegExp(
      RegexResponse.regexM3U8Resolution,
      caseSensitive: false,
      multiLine: true,
    );

    if (m3u8Content != null) {
      setState(() {
        m3u8Content = null;
      });
    }

    try {
      if (m3u8Content == null && videoUrl != null) {
        final response = await http
            .get(
              Uri.parse(videoUrl),
              headers: widget.headers,
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          m3u8Content = utf8.decode(response.bodyBytes);

          final cachedFiles = <File>[];
          var index = 0;

          final matches = regExp.allMatches(m3u8Content ?? '').toList();

          for (final regExpMatch in matches) {
            final quality = regExpMatch.group(1).toString();
            final sourceURL = regExpMatch.group(3).toString();
            final netRegex = RegExp(RegexResponse.regexHTTP);
            final netRegex2 = RegExp(RegexResponse.regexURL);
            final isNetwork = netRegex.hasMatch(sourceURL);
            final match = netRegex2.firstMatch(videoUrl);
            String url;
            if (isNetwork) {
              url = sourceURL;
            } else {
              final dataURL = match?.group(0);
              url = '$dataURL$sourceURL';
            }
            for (final regExpMatch2 in matches) {
              final audioURL = regExpMatch2.group(1).toString();
              final isNetwork = netRegex.hasMatch(audioURL);
              final match = netRegex2.firstMatch(videoUrl);
              var auURL = audioURL;

              if (!isNetwork) {
                final auDataURL = match!.group(0);
                auURL = '$auDataURL$audioURL';
              }

              audioList.add(AudioModel(url: auURL));
            }

            var audio = '';
            if (audioList.isNotEmpty) {
              audio = '''#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-medium",NAME="audio",AUTOSELECT=YES,DEFAULT=YES,CHANNELS="2",
                  URI="${audioList.last.url}"\n''';
            } else {
              audio = '';
            }

            if (widget.allowCacheFile) {
              try {
                final file = await FileUtils.cacheFileUsingWriteAsString(
                  contents: '''#EXTM3U\n#EXT-X-INDEPENDENT-SEGMENTS\n$audio#EXT-X-STREAM-INF:CLOSED-CAPTIONS=NONE,BANDWIDTH=1469712,
                  RESOLUTION=$quality,FRAME-RATE=30.000\n$url''',
                  quality: quality,
                  videoUrl: url,
                );

                cachedFiles.add(file);

                if (index < matches.length) {
                  index++;
                }

                if (widget.allowCacheFile && index == matches.length) {
                  widget.onCacheFileCompleted?.call(cachedFiles.isEmpty ? null : cachedFiles);
                }
              } catch (e) {
                widget.onCacheFileFailed?.call(e);
              }
            }
            //need to add the video quality to the list by the quality order.and auto quality should be the first one.
            //  var orderBasedSerializedList = m3u8UrlList.map((e) => e.dataQuality).toList();
            m3u8UrlList.add(M3U8Data(dataQuality: quality, dataURL: url));
          }
          final m3u8s = M3U8s(m3u8s: m3u8UrlList);

          return m3u8s;
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout while fetching M3U8: $e');
    } on SocketException catch (e) {
      debugPrint('Socket error: $e');
    } catch (e) {
      debugPrint('Unexpected error: $e');
    }
    return null;
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
    showTime = Timer(const Duration(milliseconds: 5000), () {
      if (controller?.value.isPlaying == true) {
        if (showMenu && mounted) {
          setState(() {
            showMenu = false;
            m3u8Show = false;
            controlBarAnimationController.reverse();
            widget.onShowMenu?.call(showMenu, m3u8Show);
            removeOverlay();
          });
        }
      }
    });
  }

  void clearHideControlBarTimer() {
    showTime?.cancel();
  }

  void toggleControls() {
    clearHideControlBarTimer();

    if (!showMenu) {
      setState(() {
        showMenu = true;
      });
      widget.onShowMenu?.call(showMenu, m3u8Show);

      createHideControlBarTimer();
    } else {
      setState(() {
        m3u8Show = false;
        showMenu = false;
      });

      widget.onShowMenu?.call(showMenu, m3u8Show);
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
    if (isOffline == false) {
      if (playType == 'MP4' || playType == 'WEBM') {
        // Play MP4 and WEBM video
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url!),
          formatHint: VideoFormat.other,
          httpHeaders: widget.headers ?? const <String, String>{},
          closedCaptionFile: widget.closedCaptionFile,
          videoPlayerOptions: widget.videoPlayerOptions,
        )..initialize().then((value) => seekToLastPlayingPosition);
      } else if (playType == 'MKV') {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url!),
          formatHint: VideoFormat.dash,
          httpHeaders: widget.headers ?? const <String, String>{},
          closedCaptionFile: widget.closedCaptionFile,
          videoPlayerOptions: widget.videoPlayerOptions,
        )..initialize().then((value) => seekToLastPlayingPosition);
      } else if (playType == 'HLS') {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url!),
          formatHint: VideoFormat.hls,
          httpHeaders: widget.headers ?? const <String, String>{},
          closedCaptionFile: widget.closedCaptionFile,
          videoPlayerOptions: widget.videoPlayerOptions,
        )..initialize().then((_) {
            setState(() => hasInitError = false);
            seekToLastPlayingPosition();
          }).catchError((e) {
            setState(() => hasInitError = true);
          });
      }
    } else {
      hideQualityList = true;
      controller = VideoPlayerController.file(
        File(url!),
        closedCaptionFile: widget.closedCaptionFile,
        videoPlayerOptions: widget.videoPlayerOptions,
      )..initialize().then((value) {
          setState(() => hasInitError = false);
          seekToLastPlayingPosition();
        }).catchError((e) {
          setState(() => hasInitError = true);
        });
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
                        m3u8Show = false;
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
                    activeColor: const Color(0xfff70808),
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
