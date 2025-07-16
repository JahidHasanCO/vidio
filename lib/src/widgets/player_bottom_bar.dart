import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vidio/vidio.dart';
import 'package:vidio/src/utils/extensions/video_controller_extensions.dart';
import 'package:vidio/src/widgets/seek_button.dart';
import 'package:vidio/src/widgets/seek_slider.dart';
import 'package:video_player/video_player.dart';

class PlayerBottomBar extends StatefulWidget {
  const PlayerBottomBar({
    super.key,
    required this.controller,
    required this.showBottomBar,
    required this.fullScreen,
    this.onPlayButtonTap,
    this.videoDuration = "00:00:00",
    this.videoSeek = "00:00:00",
    this.videoStyle = const VideoStyle(),
    this.onFastForward,
    this.onRewind,
    required this.onFullScreenIconTap,
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
                alignment: Alignment.center,
                child: Padding(
                  padding: widget.videoStyle.videoDurationsPadding ??
                      const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    width: widget.fullScreen
                        ? MediaQuery.of(context).size.width / 3
                        : MediaQuery.of(context).size.width / 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                      BlendMode.srcIn),
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
                                  widget.controller.value.isCompleted == false
                              ? Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: SizedBox(
                                    width: widget.videoStyle.playButtonIconSize,
                                    height:
                                        widget.videoStyle.playButtonIconSize,
                                    child: const CircularProgressIndicator(
                                      value: null,
                                      strokeWidth: 4.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: widget.onPlayButtonTap,
                                  // onTap: widget.onFullScreen,
                                  child: () {
                                    var defaultIcon = Container(
                                        padding: const EdgeInsets.all(4),
                                        child: SvgPicture.asset(
                                          widget.controller.value.isPlaying
                                              ? 'packages/vidio/assets/icons/pause.svg'
                                              : 'packages/vidio/assets/icons/play.svg',
                                          width: widget
                                              .videoStyle.playButtonIconSize,
                                          height: widget
                                              .videoStyle.playButtonIconSize,
                                          fit: BoxFit.scaleDown,
                                          colorFilter: ColorFilter.mode(
                                              widget.videoStyle
                                                      .playButtonIconColor ??
                                                  Colors.white,
                                              BlendMode.srcIn),
                                        ));
                                    if (widget.videoStyle.playIcon != null &&
                                        widget.videoStyle.pauseIcon == null) {
                                      return widget.controller.value.isPlaying
                                          ? defaultIcon
                                          : widget.videoStyle.playIcon;
                                    } else if (widget.videoStyle.pauseIcon !=
                                            null &&
                                        widget.videoStyle.playIcon == null) {
                                      return widget.controller.value.isPlaying
                                          ? widget.videoStyle.pauseIcon
                                          : defaultIcon;
                                    } else if (widget.videoStyle.playIcon !=
                                            null &&
                                        widget.videoStyle.pauseIcon != null) {
                                      return widget.controller.value.isPlaying
                                          ? widget.videoStyle.pauseIcon
                                          : widget.videoStyle.playIcon;
                                    }
                                    return defaultIcon;
                                  }(),
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
                                      BlendMode.srcIn),
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
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: SvgPicture.asset(
                                  'packages/vidio/assets/icons/pip.svg',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                  colorFilter: ColorFilter.mode(
                                      widget.videoStyle.fullScreenIconColor,
                                      BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        if (!(widget.hideFullScreenButton == true))
                          InkWell(
                            onTap: widget.onFullScreen,
                            child: Container(
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14.0),
                                child: widget.videoStyle.fullscreenIcon ??
                                    SvgPicture.asset(
                                      widget.fullScreen
                                          ? 'packages/vidio/assets/icons/minimize.svg'
                                          : 'packages/vidio/assets/icons/maximize.svg',
                                      width:
                                          widget.videoStyle.fullScreenIconSize,
                                      height:
                                          widget.videoStyle.fullScreenIconSize,
                                      fit: BoxFit.scaleDown,
                                      colorFilter: ColorFilter.mode(
                                          widget.videoStyle.fullScreenIconColor,
                                          BlendMode.srcIn),
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

  Widget bufferStatus() {
    final bufferedMillis = widget.controller.value.buffered.isNotEmpty == true
        ? widget.controller.value.buffered.last.end.inMilliseconds
        : 0;
    final totalMillis = widget.controller.value.duration.inMilliseconds;

    final bufferPercent = totalMillis > 0 ? bufferedMillis / totalMillis : 0.0;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          FractionallySizedBox(
            heightFactor: bufferPercent.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Duration durationRangeToDuration(List<DurationRange> durationRange) {
    if (durationRange.isEmpty) {
      return Duration.zero;
    }
    return durationRange.first.end;
  }
}
