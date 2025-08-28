import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages video playback state and controls
class VideoPlaybackManager {
  bool isPlaying = false;
  bool loop = false;
  double playbackSpeed = 1;
  List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  Duration? lastPlayedPos;
  bool isAtLivePosition = true;

  void togglePlay(VideoPlayerController? controller) {
    if (controller?.value.isPlaying ?? false) {
      controller?.pause();
    } else {
      controller?.play();
    }
  }

  void setPlaybackSpeed(double speed, VideoPlayerController? controller) {
    playbackSpeed = speed;
    controller?.setPlaybackSpeed(speed);
  }

  void setLooping(bool loop, VideoPlayerController? controller) {
    this.loop = loop;
    controller?.setLooping(loop);
  }

  Future<void> manageWakelock(VideoPlayerController? controller) async {
    if ((controller?.value.isInitialized ?? false) &&
        (controller?.value.isPlaying ?? false)) {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
      }
    } else {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
      }
    }
  }
}
