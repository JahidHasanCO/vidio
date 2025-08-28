import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Enhanced caching manager for video files with smart caching strategies
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();

  final Map<String, _CacheEntry> _cacheEntries = {};
  final Map<String, Completer<File?>> _pendingDownloads = {};

  /// Check if a video file is already cached
  Future<File?> getCachedFile(String url, {String? quality}) async {
    final cacheKey = _generateCacheKey(url, quality);
    final cacheEntry = _cacheEntries[cacheKey];

    if (cacheEntry != null && cacheEntry.file.existsSync()) {
      // Update last accessed time
      cacheEntry.lastAccessed = DateTime.now();
      return cacheEntry.file;
    }

    // Check file system for existing cache
    final file = await _findExistingCacheFile(url, quality);
    if (file != null && file.existsSync()) {
      _cacheEntries[cacheKey] = _CacheEntry(
        url: url,
        quality: quality,
        file: file,
        lastAccessed: DateTime.now(),
      );
      return file;
    }

    return null;
  }

  /// Cache video file with smart strategy
  Future<File?> cacheVideoFile(
    String url, {
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(File? file)? onComplete,
    void Function(dynamic error)? onError,
    bool cacheInBackground = true,
  }) async {
    final cacheKey = _generateCacheKey(url, quality);

    // Check if download is already in progress
    if (_pendingDownloads.containsKey(cacheKey)) {
      return _pendingDownloads[cacheKey]!.future;
    }

    final completer = Completer<File?>();
    _pendingDownloads[cacheKey] = completer;

    try {
      final file = await _downloadAndCacheFile(
        url: url,
        quality: quality,
        headers: headers,
        onProgress: onProgress,
      );

      if (file != null) {
        _cacheEntries[cacheKey] = _CacheEntry(
          url: url,
          quality: quality,
          file: file,
          lastAccessed: DateTime.now(),
        );
        onComplete?.call(file);
        completer.complete(file);
      } else {
        onError?.call('Failed to cache file');
        completer.complete(null);
      }
    } catch (error) {
      onError?.call(error);
      completer.complete(null);
    } finally {
      _pendingDownloads.remove(cacheKey);
    }

    return completer.future;
  }

  /// Get optimal video source (cached or network)
  Future<String> getOptimalVideoSource(
    String url, {
    String? quality,
    Map<String, String>? headers,
    bool enableBackgroundCaching = true,
  }) async {
    // First, try to get cached file
    final cachedFile = await getCachedFile(url, quality: quality);
    if (cachedFile != null) {
      // Start background caching of network version if enabled
      if (enableBackgroundCaching) {
        cacheVideoFile(
          url,
          quality: quality,
          headers: headers,
          cacheInBackground: true,
        );
      }
      return cachedFile.path;
    }

    // If no cache, start caching in background and return network URL
    if (enableBackgroundCaching) {
      cacheVideoFile(
        url,
        quality: quality,
        headers: headers,
        cacheInBackground: true,
      );
    }

    return url;
  }

  /// Cache HLS playlist and segments
  Future<void> cacheHLSContent(
    String playlistUrl,
    List<String> segmentUrls, {
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(List<File> files)? onComplete,
    void Function(dynamic error)? onError,
  }) async {
    try {
      final cachedFiles = <File>[];

      // Cache playlist first
      final playlistFile = await cacheVideoFile(
        playlistUrl,
        headers: headers,
      );

      if (playlistFile != null) {
        cachedFiles.add(playlistFile);
      }

      // Cache segments
      for (var i = 0; i < segmentUrls.length; i++) {
        final segmentUrl = segmentUrls[i];
        final progress = (i + 1) / segmentUrls.length;

        final segmentFile = await cacheVideoFile(
          segmentUrl,
          headers: headers,
        );

        if (segmentFile != null) {
          cachedFiles.add(segmentFile);
        }

        onProgress?.call(progress);
      }

      onComplete?.call(cachedFiles);
    } catch (error) {
      onError?.call(error);
    }
  }

  /// Clean old cache files
  Future<void> cleanCache({
    Duration maxAge = const Duration(days: 7),
    int maxFiles = 100,
  }) async {
    final directory = await _getCacheDirectory();
    if (directory == null) return;

    final files = directory.listSync().whereType<File>().toList();

    // Sort by last modified time (oldest first)
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    // Remove files older than maxAge
    final cutoffDate = DateTime.now().subtract(maxAge);
    var filesToDelete = files.where((file) =>
        file.lastModifiedSync().isBefore(cutoffDate)).toList();

    // If still too many files, remove oldest ones
    if (files.length - filesToDelete.length > maxFiles) {
      final remainingFiles = files.where((file) =>
          file.lastModifiedSync().isAfter(cutoffDate)).toList();
      remainingFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      final additionalToDelete = remainingFiles.take(files.length - filesToDelete.length - maxFiles + 1).toList();
      filesToDelete.addAll(additionalToDelete);
    }

    // Delete files
    for (final file in filesToDelete) {
      try {
        await file.delete();
        // Remove from cache entries
        _cacheEntries.removeWhere((key, entry) => entry.file.path == file.path);
      } catch (e) {
        debugPrint('Failed to delete cache file: $e');
      }
    }
  }

  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    final directory = await _getCacheDirectory();
    if (directory == null) {
      return CacheStats.empty();
    }

    final files = directory.listSync().whereType<File>().toList();
    var totalSize = 0;
    var fileCount = 0;

    for (final file in files) {
      if (file.existsSync()) {
        totalSize += file.lengthSync();
        fileCount++;
      }
    }

    return CacheStats(
      fileCount: fileCount,
      totalSize: totalSize,
      cacheEntries: _cacheEntries.length,
    );
  }

  /// Generate cache key for URL and quality
  String _generateCacheKey(String url, String? quality) {
    final qualitySuffix = quality != null ? '_$quality' : '';
    return '${p.basenameWithoutExtension(url)}$qualitySuffix';
  }

  /// Find existing cache file
  Future<File?> _findExistingCacheFile(String url, String? quality) async {
    final directory = await _getCacheDirectory();
    if (directory == null) return null;

    final cacheKey = _generateCacheKey(url, quality);
    final files = directory.listSync().whereType<File>();

    for (final file in files) {
      final fileName = p.basenameWithoutExtension(file.path);
      if (fileName.contains(cacheKey)) {
        return file;
      }
    }

    return null;
  }

  /// Download and cache file
  Future<File?> _downloadAndCacheFile({
    required String url,
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    if (headers != null) {
      request.headers.addAll(headers);
    }

    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final directory = await _getCacheDirectory();
    if (directory == null) {
      throw Exception('Could not access cache directory');
    }

    final cacheKey = _generateCacheKey(url, quality);
    final extension = p.extension(url).isNotEmpty ? p.extension(url) : '.mp4';
    final fileName = '$cacheKey$extension';
    final file = File('${directory.path}/$fileName');

    final sink = file.openWrite();
    var downloaded = 0;
    final total = response.contentLength ?? 0;

    await response.stream.forEach((chunk) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(downloaded / total);
      }
    });

    await sink.close();
    client.close();

    return file;
  }

  /// Get cache directory
  Future<Directory?> _getCacheDirectory() async {
    try {
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final cacheDir = Directory('${dir.path}/video_cache');
          if (!cacheDir.existsSync()) {
            cacheDir.createSync(recursive: true);
          }
          return cacheDir;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/video_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      return cacheDir;
    } catch (e) {
      debugPrint('Failed to get cache directory: $e');
      return null;
    }
  }
}

/// Cache entry for tracking cached files
class _CacheEntry {
  final String url;
  final String? quality;
  final File file;
  DateTime lastAccessed;

  _CacheEntry({
    required this.url,
    required this.quality,
    required this.file,
    required this.lastAccessed,
  });
}

/// Cache statistics
class CacheStats {
  final int fileCount;
  final int totalSize;
  final int cacheEntries;

  CacheStats({
    required this.fileCount,
    required this.totalSize,
    required this.cacheEntries,
  });

  factory CacheStats.empty() {
    return CacheStats(fileCount: 0, totalSize: 0, cacheEntries: 0);
  }

  String get formattedSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = totalSize.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}
