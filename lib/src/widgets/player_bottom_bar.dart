import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/utils/extensions/video_controller_extensions.dart';
import 'package:vidio/src/widgets/play_pause_icon.dart';
import 'package:vidio/src/widgets/seek_button.dart';
import 'package:vidio/src/widgets/seek_slider.dart';
import 'package:vidio/vidio.dart';

class PlayerBottomBar extends StatefulWidget {
  const PlayerBottomBar({
    required this.controller,
    required this.showBottomBar,
    required this.fullScreen,
    required this.onFullScreenIconTap,
    super.key,
    this.onPlayButtonTap,
    this.videoDuration = '00:00:00',
    this.videoSeek = '00:00:00',
    this.videoStyle = const VideoStyle(),
    this.onFastForward,
    this.onRewind,
    this.onPipMode,
    this.hidePipButton,
    this.onFullScreen,
    this.hideFullScreenButton,
  });
  final VideoPlayerController controller;
  final VoidCallback? onFullScreenIconTap;
  final bool fullScreen;
  final bool showBottomBar;
  final String videoSeek;
  final String videoDuration;
  final void Function()? onPlayButtonTap;
  final VoidCallback? onPipMode;
  final bool? hidePipButton;
  final VoidCallback? onFullScreen;
  final bool? hideFullScreenButton;
  final VideoStyle videoStyle;
  final ValueChanged<VideoPlayerValue>? onRewind;
  final ValueChanged<VideoPlayerValue>? onFastForward;

  @override
  State<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends State<PlayerBottomBar> {
  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.showBottomBar,
      child: Padding(
        padding: widget.fullScreen
            ? const EdgeInsets.symmetric(horizontal: 20)
            : widget.videoStyle.bottomBarPadding,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Align(
                child: Padding(
                  padding: widget.videoStyle.videoDurationsPadding ??
                      const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: widget.fullScreen
                        ? MediaQuery.of(context).size.width / 3
                        : MediaQuery.of(context).size.width / 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: SeekButton(
                            isForward: false,
                            icon: widget.videoStyle.backwardIcon ??
                                SvgPicture.asset(
                                  'packages/vidio/assets/icons/rewind.svg',
                                  width: widget
                                      .videoStyle.forwardAndBackwardBtSize,
                                  height: widget
                                      .videoStyle.forwardAndBackwardBtSize,
                                  fit: BoxFit.scaleDown,
                                  colorFilter: ColorFilter.mode(
                                    widget.videoStyle.backwardIconColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
                            onTap: () => widget.controller.rewind().then(
                                  (value) => widget.onRewind
                                      ?.call(widget.controller.value),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: widget.controller.value.isBuffering &&
                                  !widget.controller.value.isCompleted
                              ? Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: SizedBox(
                                    width: widget.videoStyle.playButtonIconSize,
                                    height:
                                        widget.videoStyle.playButtonIconSize,
                                    child: const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: widget.onPlayButtonTap,
                                  child: PlayPauseIcon(
                                    controller: widget.controller,
                                    videoStyle: widget.videoStyle,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: SeekButton(
                            isForward: true,
                            icon: widget.videoStyle.forwardIcon ??
                                SvgPicture.asset(
                                  'packages/vidio/assets/icons/forward.svg',
                                  width: widget
                                      .videoStyle.forwardAndBackwardBtSize,
                                  height: widget
                                      .videoStyle.forwardAndBackwardBtSize,
                                  fit: BoxFit.scaleDown,
                                  colorFilter: ColorFilter.mode(
                                    widget.videoStyle.forwardIconColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
                            onTap: () => widget.controller.fastForward().then(
                                  (value) => widget.onFastForward
                                      ?.call(widget.controller.value),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            widget.videoSeek,
                            style: widget.videoStyle.videoSeekStyle ??
                                const TextStyle(color: Colors.white),
                          ),
                        ),
                        Expanded(
                          child: SeekSlider(
                            controller: widget.controller,
                            colors: widget.videoStyle.progressIndicatorColors,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            widget.videoDuration,
                            style: widget.videoStyle.videoDurationStyle ??
                                const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (widget.hidePipButton == false && !widget.fullScreen)
                          InkWell(
                            onTap: widget.onPipMode,
                            child: Container(
                              color: Colors.transparent,
                              padding: const EdgeInsets.only(right: 10),
                              child: SvgPicture.asset(
                                'packages/vidio/assets/icons/pip.svg',
                                width: 26,
                                height: 26,
                                colorFilter: ColorFilter.mode(
                                  widget.videoStyle.fullScreenIconColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        if (widget.hideFullScreenButton != true)
                          InkWell(
                            onTap: widget.onFullScreen,
                            child: Container(
                              color: Colors.transparent,
                              padding: const EdgeInsets.only(right: 14),
                              child: widget.videoStyle.fullscreenIcon ??
                                  SvgPicture.asset(
                                    widget.fullScreen
                                        ? 'packages/vidio/assets/icons/minimize.svg'
                                        : 'packages/vidio/assets/icons/maximize.svg',
                                    width: widget.videoStyle.fullScreenIconSize,
                                    height:
                                        widget.videoStyle.fullScreenIconSize,
                                    fit: BoxFit.scaleDown,
                                    colorFilter: ColorFilter.mode(
                                      widget.videoStyle.fullScreenIconColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
