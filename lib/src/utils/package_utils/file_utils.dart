import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utility class to implement video caching method
class FileUtils {
  /// Cache file to local storage method using [File] class method.
  static void cacheFileToLocalStorage(
    String videoUrl, {
    Map<String, String>? headers,
    String? fileExtension,
    void Function(File? file)? onSaveCompleted,
    void Function(dynamic err)? onSaveFailed,
  }) {
    final client = http.Client();
    client.get(Uri.parse(videoUrl), headers: headers).then((response) {
      if (response.statusCode == 200) {
        final fileName = _getFileNameFromUrl(videoUrl);
        _writeFile(
          response: response,
          fileExtension: fileExtension,
          onSaveCompleted: onSaveCompleted,
          onSaveFailed: onSaveFailed,
          fileName: fileName,
        );
      }
    }).catchError((dynamic err) {
      onSaveFailed?.call(err);
    });
  }

  /// Method to write the downloaded video into device local
  /// storage using [writeAsBytes] method
  /// from [File]'s object.
  static Future<void> _writeFile({
    required http.Response response,
    String? fileExtension,
    void Function(File file)? onSaveCompleted,
    void Function(dynamic err)? onSaveFailed,
    String? fileName,
  }) async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir != null) {
      final file = File(
        '${dir.path}/${(fileName != null && fileName.isNotEmpty) ? fileName : DateTime.now().millisecondsSinceEpoch}.${fileExtension ?? 'm3u8'}',
      );
      await file.writeAsBytes(response.bodyBytes).then((f) async {
        onSaveCompleted?.call(f);
      }).catchError((dynamic err) {
        onSaveFailed?.call(err);
      });
    }
  }

  /// Method to get the file name from a video url
  static String _getFileNameFromUrl(String? videoUrl) {
    if (videoUrl != null) {
      return p.basenameWithoutExtension(videoUrl);
    }

    return '';
  }

  /// Method to write the downloaded video into device local storage using
  /// [writeAsString] method
  /// from [File]'s object.
  static Future<File> cacheFileUsingWriteAsString({
    required String contents,
    required String quality,
    required String videoUrl,
  }) async {
    final name = _getFileNameFromUrl(videoUrl);
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final file = File(
      '${directory?.path ?? ''}/yoyo_${name.isNotEmpty ? '${name}_' : name}$quality.m3u8',
    );
    return file.writeAsString(contents).then((f) {
      return f;
    }).catchError((err) {
      return File('');
    });
  }

  /// Method to read a cached video file of m3u8 type.
  static Future<File?> readFileFromPath({
    required String videoUrl,
    required String quality,
  }) async {
    final name = _getFileNameFromUrl(videoUrl);
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final file = File(
      '${directory?.path ?? ''}/yoyo_${name.isNotEmpty ? '${name}_' : name}$quality.m3u8',
    );

    final exists = file.existsSync();
    if (exists) return file;

    return null;
  }
}
