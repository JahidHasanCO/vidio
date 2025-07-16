import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/source/video_style.dart';

class PlayPauseIcon extends StatelessWidget {
  const PlayPauseIcon({
    required this.controller,
    required this.videoStyle,
    super.key,
  });

  final VideoPlayerController controller;
  final VideoStyle videoStyle;

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.value.isPlaying;
    final playIcon = videoStyle.playIcon;
    final pauseIcon = videoStyle.pauseIcon;
    final defaultIcon = Container(
      padding: const EdgeInsets.all(4),
      child: SvgPicture.asset(
        isPlaying
            ? 'packages/vidio/assets/icons/pause.svg'
            : 'packages/vidio/assets/icons/play.svg',
        width: videoStyle.playButtonIconSize,
        height: videoStyle.playButtonIconSize,
        fit: BoxFit.scaleDown,
        colorFilter: ColorFilter.mode(
          videoStyle.playButtonIconColor ?? Colors.white,
          BlendMode.srcIn,
        ),
      ),
    );

    if (playIcon != null && pauseIcon == null) {
      return isPlaying ? defaultIcon : playIcon;
    } else if (pauseIcon != null && playIcon == null) {
      return isPlaying ? pauseIcon : defaultIcon;
    } else if (playIcon != null && pauseIcon != null) {
      return isPlaying ? pauseIcon : playIcon;
    }
    return defaultIcon;
  }
}
