import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vidio/src/constants/video_constants.dart';
import 'package:vidio/src/model/models.dart';
import 'package:vidio/src/responses/regex_response.dart';
import 'package:vidio/src/utils/package_utils/file_utils.dart';

/// Utility class for parsing video content, especially M3U8 playlists
class VideoParser {
  VideoParser._();

  /// Parses M3U8 playlist and extracts video quality options
  static Future<M3U8s?> parseM3U8Playlist({
    required String? videoUrl,
    required List<M3U8Data> m3u8UrlList,
    required List<AudioModel> audioList,
    Map<String, String>? headers,
    bool allowCacheFile = false,
    void Function(List<File>?)? onCacheFileCompleted,
    void Function(dynamic)? onCacheFileFailed,
  }) async {
    if (videoUrl == null) return null;

    // Add auto quality option first
    m3u8UrlList.add(M3U8Data(dataQuality: 'Auto', dataURL: videoUrl));

    final regExp = RegExp(
      RegexResponse.regexM3U8Resolution,
      caseSensitive: false,
      multiLine: true,
    );

    try {
      final response = await http
          .get(
            Uri.parse(videoUrl),
            headers: headers,
          )
          .timeout(VideoConstants.kNetworkTimeout);

      if (response.statusCode == 200) {
        final m3u8Content = utf8.decode(response.bodyBytes);

        final cachedFiles = <File>[];
        var index = 0;

        final matches = regExp.allMatches(m3u8Content).toList();

        for (final regExpMatch in matches) {
          final quality = regExpMatch.group(1).toString();
          final sourceURL = regExpMatch.group(3).toString();

          final netRegex = RegExp(RegexResponse.regexHTTP);
          final netRegex2 = RegExp(RegexResponse.regexURL);
          final isNetwork = netRegex.hasMatch(sourceURL);
          final match = netRegex2.firstMatch(videoUrl);

          String url;
          if (isNetwork) {
            url = sourceURL;
          } else {
            final dataURL = match?.group(0);
            url = '$dataURL$sourceURL';
          }

          // Process audio tracks
          for (final regExpMatch2 in matches) {
            final audioURL = regExpMatch2.group(1).toString();
            final isAudioNetwork = netRegex.hasMatch(audioURL);
            final audioMatch = netRegex2.firstMatch(videoUrl);
            var auURL = audioURL;

            if (!isAudioNetwork) {
              final auDataURL = audioMatch!.group(0);
              auURL = '$auDataURL$audioURL';
            }

            audioList.add(AudioModel(url: auURL));
          }

          var audio = '';
          if (audioList.isNotEmpty) {
            audio =
                '''#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-medium",NAME="audio",AUTOSELECT=YES,DEFAULT=YES,CHANNELS="2",
                  URI="${audioList.last.url}"\n''';
          }

          if (allowCacheFile) {
            try {
              final file = await FileUtils.cacheFileUsingWriteAsString(
                contents:
                    '''#EXTM3U\n#EXT-X-INDEPENDENT-SEGMENTS\n$audio#EXT-X-STREAM-INF:CLOSED-CAPTIONS=NONE,BANDWIDTH=1469712,
                  RESOLUTION=$quality,FRAME-RATE=30.000\n$url''',
                quality: quality,
                videoUrl: url,
              );

              cachedFiles.add(file);

              if (index < matches.length) {
                index++;
              }

              if (allowCacheFile && index == matches.length) {
                onCacheFileCompleted
                    ?.call(cachedFiles.isEmpty ? null : cachedFiles);
              }
            } catch (e) {
              onCacheFileFailed?.call(e);
            }
          }

          m3u8UrlList.add(M3U8Data(dataQuality: quality, dataURL: url));
        }

        return M3U8s(m3u8s: m3u8UrlList);
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout while fetching M3U8: $e');
    } on SocketException catch (e) {
      debugPrint('Socket error: $e');
    } catch (e) {
      debugPrint('Unexpected error: $e');
    }

    return null;
  }

  /// Determines the video format based on file extension
  static String? determineVideoFormat(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    if (pathSegments.isEmpty) return null;

    final fileName = pathSegments.last.toLowerCase();

    if (fileName.endsWith('mkv')) {
      return 'MKV';
    } else if (fileName.endsWith('mp4')) {
      return 'MP4';
    } else if (fileName.endsWith('webm')) {
      return 'WEBM';
    } else if (fileName.endsWith('m3u8')) {
      return 'HLS';
    }

    return null;
  }

  /// Checks if a URL is a network URL
  static bool isNetworkUrl(String url) {
    final netRegex = RegExp(RegexResponse.regexHTTP);
    return netRegex.hasMatch(url);
  }
}
