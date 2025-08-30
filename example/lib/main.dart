import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:vidio/vidio.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool fullscreen = false;

  @override
  void initState() {
    super.initState();
    // Ensure overlays are visible initially
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _handleFullScreen(bool value) {
    setState(() {
      fullscreen = value;
      if (fullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        // landscape mode
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // portrait mode
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vidio Example',
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: fullscreen ? null : AppBar(title: const Text('Vidio Example')),
        body: Center(
          child: Vidio(
            aspectRatio: 16 / 9,
            url:
                "https://stream-fastly.castr.com/5b9352dbda7b8c769937e459/live_2361c920455111ea85db6911fe397b9e/index.fmp4.m3u8",
            headers: const {
              "User-Agent":
                  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.106 Safari/537.36 OPR/38.0.2220.41"
            },
            allowCacheFile: true,
            autoPlayVideoAfterInit: true,
            onCacheFileCompleted: (files) {
              if (kDebugMode) {
                print('Cached file length ::: ${files?.length}');
              }
              if (files != null && files.isNotEmpty) {
                for (var file in files) {
                  if (kDebugMode) {
                    print('File path ::: ${file.path}');
                  }
                }
              }
            },
            onCacheFileFailed: (error) {
              if (kDebugMode) {
                print('Cache file error ::: $error');
              }
            },
            videoStyle:  const VideoStyle(
              qualityStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              progressIndicatorColors: VideoProgressColors(
                playedColor: Colors.red,
                backgroundColor: Colors.grey,
                bufferedColor: Colors.white,
              ),
              forwardAndBackwardBtSize: 32,
              playButtonIconSize: 32,
              fullScreenIconSize: 22,
              videoQualityPadding: EdgeInsets.all(5),
            ),
            videoLoadingStyle: VideoLoadingStyle(
              loading: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: SizedBox(
                    height: 50,
                    width: 50,
                    child: CircularProgressIndicator(
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      color: Colors.grey[700] ?? Colors.grey,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
              ),
            ),
            onFullScreen: _handleFullScreen, // Use the new handler
          ),
        ),
      ),
    );
  }
}
