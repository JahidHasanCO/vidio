import 'dart:io';

import 'package:vidio/src/model/model.dart';
import 'package:vidio/src/utils/utils.dart';
import 'package:vidio/src/utils/video_parser.dart';

/// Manages M3U8 playlist parsing and quality selection
class M3U8Manager {
  List<M3U8Data> m3u8UrlList = [];
  List<AudioModel> audioList = [];
  String m3u8Quality = 'Auto';

  Future<M3U8s?> parseM3U8Playlist(
    String? videoUrl,
    Map<String, String>? headers,
    bool allowCacheFile,
    void Function(List<File>? files)? onCacheFileCompleted,
    void Function(dynamic error)? onCacheFileFailed,
  ) async {
    final result = await VideoParser.parseM3U8Playlist(
      videoUrl: videoUrl,
      m3u8UrlList: m3u8UrlList,
      audioList: audioList,
      headers: headers,
      allowCacheFile: allowCacheFile,
      onCacheFileCompleted: onCacheFileCompleted,
      onCacheFileFailed: onCacheFileFailed,
    );
    return result;
  }

  Future<void> cleanM3U8Files() async {
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
    audioList.clear();
    m3u8UrlList.clear();
  }

  /// Sets the desired video quality
  void setQuality(String quality) {
    m3u8Quality = quality;
  }
}
