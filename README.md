# Vidio

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Vidio is a lightweight and customizable video player library for Flutter. It provides seamless video playback with flexible APIs to build your own controls, overlays, and advanced features. Vidio is designed for performance, ease of integration, and full extensibility to suit any Flutter app’s video playback requirements.

## Features

- Supports MP4, MKV, WEBM, and HLS (M3U8) video playback
- Flexible styling for video controls and loading indicators
- Built-in widgets for overlays, quality picker, playback speed, and ambient mode
- Fullscreen and Picture-in-Picture (PIP) modes
- Video caching to local storage
- Customizable playback speed and looping
- Callbacks for various playback events (play, pause, fast forward, rewind, etc.)
- Easy integration with headers and closed captions
- Advanced menu with settings and playlist support

## Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  vidio:
    git:
      url: https://github.com/JahidHasanCO/vidio.git
      ref: 1.0.0
```

Then run:
```bash
flutter pub get
```

## Usage

Import the package:
```dart
import 'package:vidio/vidio.dart';
```

Basic example:
```dart
Vidio(
  url: 'https://your.video/url.m3u8',
  aspectRatio: 16/9,
  autoPlayVideoAfterInit: true,
  allowCacheFile: true,
  onFullScreen: (isFullScreen) {},
  onPlayButtonTap: (isPlaying) {},
  videoStyle: VideoStyle(
    // Customize controls here
  ),
  videoLoadingStyle: VideoLoadingStyle(
    // Customize loading indicator here
  ),
)
```

For more advanced usage, you can customize:
- Overlays and widgets (add your own or use built-ins)
- Quality and audio selection
- Callbacks for every playback event
- Fullscreen, PiP, ambient mode, and more

## API Overview

The `Vidio` widget supports many options:
- `url` (required): Video source URL
- `aspectRatio`: Display aspect ratio
- `videoStyle` & `videoLoadingStyle`: Customize controls and loading UI
- `autoPlayVideoAfterInit`, `allowCacheFile`, `initFullScreen`, `displayFullScreenAfterInit`
- Callbacks: `onFullScreen`, `onPlayButtonTap`, `onShowMenu`, `onCacheFileCompleted`, `onCacheFileFailed`, etc.
- Advanced: `headers`, `closedCaptionFile`, `videoPlayerOptions`, `playbackSpeed`, and more

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [JahidHasanCO](https://github.com/JahidHasanCO)
