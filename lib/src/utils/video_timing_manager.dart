import 'package:video_player/video_player.dart';
import 'package:vidio/src/utils/utils.dart';

/// Manages video timing and progress
class VideoTimingManager {
  String? videoDuration;
  String? videoSeek;
  Duration? duration;
  double? videoSeekSecond;
  double? videoDurationSecond;

  void updateTiming(VideoPlayerController? controller) {
    videoDuration = controller?.value.duration.convertDuration();
    videoSeek = controller?.value.position.convertDuration();
    videoSeekSecond = controller?.value.position.inSeconds.toDouble();
    videoDurationSecond = controller?.value.duration.inSeconds.toDouble();
  }
}
