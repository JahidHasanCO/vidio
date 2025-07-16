import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BufferStatus extends StatelessWidget {
  const BufferStatus({required this.controller, super.key});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final bufferedMillis = controller.value.buffered.isNotEmpty == true
        ? controller.value.buffered.last.end.inMilliseconds
        : 0;
    final totalMillis = controller.value.duration.inMilliseconds;

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
}
