import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vidio/src/model/model.dart';

/// Enhanced caching manager for video files with smart caching strategies
class VideoCacheManager {
  factory VideoCacheManager() => _instance;

  VideoCacheManager._internal();

  static final VideoCacheManager _instance = VideoCacheManager._internal();

  final Map<String, CacheEntry> _cacheEntries = {};
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
      _cacheEntries[cacheKey] = CacheEntry(
        url: url,
        quality: quality,
        file: file,
        lastAccessed: DateTime.now(),
      );
      return file;
    }

    return null;
  }

  /// Cache video file with smart strategy and partial caching support
  Future<File?> cacheVideoFile(
    String url, {
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
    void Function(File? file)? onComplete,
    void Function(dynamic error)? onError,
    bool cacheInBackground = true,
    int? startByte, // For partial caching
    int? endByte, // For partial caching
  }) async {
    final cacheKey = _generateCacheKey(url, quality);
    onLog?.call('Starting cache for: $url');

    // Check if download is already in progress
    if (_pendingDownloads.containsKey(cacheKey)) {
      onLog?.call('Download already in progress for: $cacheKey');
      return _pendingDownloads[cacheKey]!.future;
    }

    final completer = Completer<File?>();
    _pendingDownloads[cacheKey] = completer;

    try {
      final existingFile = await _findExistingCacheFile(url, quality);
      if (existingFile != null) {
        onLog?.call('Cache hit for: $cacheKey');
        onProgress?.call(1); // Already cached
        onComplete?.call(existingFile);
        completer.complete(existingFile);
        return completer.future;
      }

      onLog?.call('Cache miss, downloading: $cacheKey');

      final file = await _downloadAndCacheFile(
        url: url,
        quality: quality,
        headers: headers,
        onProgress: (progress) {
          onProgress?.call(progress);
          onLog?.call('Cache progress: ${(progress * 100).toInt()}%');
        },
        startByte: startByte,
        endByte: endByte,
      );

      if (file != null) {
        _cacheEntries[cacheKey] = CacheEntry(
          url: url,
          quality: quality,
          file: file,
          lastAccessed: DateTime.now(),
        );
        onLog?.call('Cache completed: $cacheKey');
        onComplete?.call(file);
        completer.complete(file);
      } else {
        onLog?.call('Cache failed: $cacheKey');
        onError?.call('Failed to cache file');
        completer.complete(null);
      }
    } catch (error) {
      onLog?.call('Cache error: $error');
      onError?.call(error);
      completer.complete(null);
    } finally {
      _pendingDownloads.remove(cacheKey);
    }

    return completer.future;
  }

  /// Cache partial video file with range tracking (YouTube-style)
  Future<File?> cacheVideoFilePartial(
    String url, {
    required int startByte,
    required int endByte,
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(int start, int end)? onRangeCached,
    void Function(String log)? onLog,
    void Function(File? file)? onComplete,
    void Function(dynamic error)? onError,
  }) async {
    final cacheKey = _generateCacheKey(url, quality);
    onLog?.call('Starting partial cache for: $url ($startByte-$endByte)');

    try {
      // Check if this range is already cached
      final existingRanges =
          await getCachedRanges(url, quality, endByte - startByte + 1);
      final isRangeCached = existingRanges.any(
        (range) => range.startByte <= startByte && range.endByte >= endByte,
      );

      if (isRangeCached) {
        onLog?.call('Range already cached: $startByte-$endByte');
        onProgress?.call(1);
        onRangeCached?.call(startByte, endByte);
        onComplete?.call(null); // No new file created
        return null;
      }

      final file = await _downloadAndCacheFile(
        url: url,
        quality: quality,
        headers: headers,
        onProgress: onProgress,
        startByte: startByte,
        endByte: endByte,
      );

      if (file != null) {
        // Update cache entry with new range
        final entry = _cacheEntries[cacheKey];
        if (entry != null) {
          final newRange = CachedRange(
            startByte: startByte,
            endByte: endByte,
            cachedAt: DateTime.now(),
          );
          entry.cachedRanges.add(newRange);
          // Merge overlapping ranges
          _mergeRanges(entry.cachedRanges);
        } else {
          // Create new entry
          _cacheEntries[cacheKey] = CacheEntry(
            url: url,
            quality: quality,
            file: file,
            lastAccessed: DateTime.now(),
            cachedRanges: [
              CachedRange(
                startByte: startByte,
                endByte: endByte,
                cachedAt: DateTime.now(),
              ),
            ],
          );
        }

        onLog?.call('Partial cache completed: $startByte-$endByte');
        onRangeCached?.call(startByte, endByte);
        onComplete?.call(file);
        return file;
      } else {
        onLog?.call('Partial cache failed: $startByte-$endByte');
        onError?.call('Failed to cache partial file');
        return null;
      }
    } catch (error) {
      onLog?.call('Partial cache error: $error');
      onError?.call(error);
      return null;
    }
  }

  /// Merge overlapping ranges in a list
  void _mergeRanges(List<CachedRange> ranges) {
    if (ranges.length < 2) return;

    ranges.sort((a, b) => a.startByte.compareTo(b.startByte));

    final merged = <CachedRange>[];
    var current = ranges[0];

    for (var i = 1; i < ranges.length; i++) {
      final next = ranges[i];
      final mergedRange = current.merge(next);
      if (mergedRange != null) {
        current = mergedRange;
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    ranges
      ..clear()
      ..addAll(merged);
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
        unawaited(
          cacheVideoFile(
            url,
            quality: quality,
            headers: headers,
          ),
        );
      }
      return cachedFile.path;
    }

    // If no cache, start caching in background and return network URL
    if (enableBackgroundCaching) {
      unawaited(
        cacheVideoFile(
          url,
          quality: quality,
          headers: headers,
        ),
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

    final files = directory.listSync().whereType<File>().toList()
      // Sort by last modified time (oldest first)
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    // Remove files older than maxAge
    final cutoffDate = DateTime.now().subtract(maxAge);
    final filesToDelete = files
        .where((file) => file.lastModifiedSync().isBefore(cutoffDate))
        .toList();

    // If still too many files, remove oldest ones
    if (files.length - filesToDelete.length > maxFiles) {
      final remainingFiles = files
          .where((file) => file.lastModifiedSync().isAfter(cutoffDate))
          .toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      final additionalToDelete = remainingFiles
          .take(files.length - filesToDelete.length - maxFiles + 1)
          .toList();
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

  /// Get cached ranges for a video (as percentage of total duration)
  Future<List<CachedRange>> getCachedRanges(
    String url,
    String? quality,
    int totalBytes,
  ) async {
    final cacheKey = _generateCacheKey(url, quality);
    final entry = _cacheEntries[cacheKey];

    if (entry != null && entry.cachedRanges.isNotEmpty) {
      return entry.cachedRanges;
    }

    // Check if file exists and get its size
    final file = await _findExistingCacheFile(url, quality);
    if (file != null && file.existsSync()) {
      final fileSize = file.lengthSync();
      if (fileSize > 0 && totalBytes > 0) {
        final range = CachedRange(
          startByte: 0,
          endByte: fileSize - 1,
          cachedAt: file.lastModifiedSync(),
        );
        return [range];
      }
    }

    return [];
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

  /// Download and cache file with partial caching support
  Future<File?> _downloadAndCacheFile({
    required String url,
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    int? startByte, // For partial caching
    int? endByte, // For partial caching
  }) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    if (headers != null) {
      request.headers.addAll(headers);
    }

    // Add range header for partial caching
    if (startByte != null && endByte != null) {
      request.headers['Range'] = 'bytes=$startByte-$endByte';
    } else if (startByte != null) {
      request.headers['Range'] = 'bytes=$startByte-';
    }

    final response = await client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
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
    var total = response.contentLength ?? 0;

    // For partial downloads, calculate total based on range
    if (startByte != null && endByte != null) {
      total = endByte - startByte + 1;
    }

    if (kDebugMode) {
      print(
        'DEBUG: Download starting - '
        'Total bytes: $total, Range: $startByte-$endByte',
      );
    }

    await response.stream.forEach((chunk) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total > 0 && onProgress != null) {
        final progress = downloaded / total;
        if (kDebugMode) {
          print(
            'DEBUG: Download progress: '
            '${(progress * 100).toInt()}% ($downloaded/$total)',
          );
        }
        onProgress(progress);
      }
    });

    await sink.close();
    client.close();

    if (kDebugMode) {
      print('DEBUG: Download completed '
          '- Total downloaded: $downloaded bytes');
    }
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
