import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidio/src/source/video_style.dart';

/// Live direct button widget that allows jumping to live position
class LiveDirectButton extends StatelessWidget {
  const LiveDirectButton({
    required this.controller,
    required this.showMenu,
    required this.isAtLivePosition,
    required this.videoStyle,
    required this.onLiveDirectTap,
    super.key,
  });

  final VideoPlayerController? controller;
  final bool showMenu;
  final bool isAtLivePosition;
  final VideoStyle videoStyle;
  final void Function(VideoPlayerValue)? onLiveDirectTap;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const SizedBox.shrink();
    }
    
    return Visibility(
      visible: videoStyle.showLiveDirectButton && showMenu,
      child: Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: InkWell(
            onTap: () {
              controller?.seekTo(controller!.value.duration).then((value) {
                onLiveDirectTap?.call(controller!.value);
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
                    width: videoStyle.liveDirectButtonSize,
                    height: videoStyle.liveDirectButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAtLivePosition 
                          ? videoStyle.liveDirectButtonColor 
                          : videoStyle.liveDirectButtonDisableColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    videoStyle.liveDirectButtonText ?? 'Live',
                    style: videoStyle.liveDirectButtonTextStyle ?? 
                        const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
