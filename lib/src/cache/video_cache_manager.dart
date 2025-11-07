import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vidio/src/model/model.dart';

/// Enhanced caching manager with YouTube-style adaptive segment caching
class VideoCacheManager {
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();
  static final VideoCacheManager _instance = VideoCacheManager._internal();

  // ==================== Configuration ====================
  
  /// Duration of each segment in seconds
  static const int SEGMENT_DURATION_SECONDS = 5;
  
  /// Minimum buffer to maintain ahead of playback (in seconds)
  static const int MIN_BUFFER_SECONDS = 30;
  
  /// Target buffer to maintain (in seconds)
  static const int TARGET_BUFFER_SECONDS = 120;
  
  /// Maximum buffer to cache ahead (in seconds)
  static const int MAX_BUFFER_SECONDS = 600;
  
  /// Maximum cache size in MB
  static const int MAX_CACHE_SIZE_MB = 500;
  
  /// Estimated bytes per second of video (adjust based on quality)
  static const int ESTIMATED_BYTES_PER_SECOND = 200000; // ~200KB/s for 720p
  
  // ==================== State Management ====================
  
  /// In-memory segment cache
  final Map<String, VideoSegment> _segmentCache = {};
  
  /// LRU tracker for cache eviction
  final LinkedHashMap<String, int> _lruTracker = LinkedHashMap();
  
  /// Pending downloads to prevent duplicates
  final Map<String, Completer<VideoSegment?>> _pendingDownloads = {};
  
  /// Active caching sessions
  final Map<String, CachingSession> _activeSessions = {};
  
  /// Network status
  bool _isOnline = true;
  
  // ==================== Legacy Support ====================
  
  /// Old cache entries for backward compatibility
  final Map<String, CacheEntry> _cacheEntries = {};

  // ==================== Main Public API ====================

  /// Start adaptive caching for a video (YouTube-style)
  /// This is the main method to use for new implementations
  Future<void> startAdaptiveCaching({
    required String videoUrl,
    required Duration videoDuration,
    required Stream<Duration> currentPositionStream,
    String? quality,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
    void Function(List<CachedRange> ranges)? onCachedRangesUpdated,
  }) async {
    final sessionKey = _generateCacheKey(videoUrl, quality);
    
    // Create caching session
    final session = CachingSession(
      videoUrl: videoUrl,
      quality: quality,
      videoDuration: videoDuration,
      headers: headers,
      onProgress: onProgress,
      onLog: onLog,
      onCachedRangesUpdated: onCachedRangesUpdated,
    );
    
    _activeSessions[sessionKey] = session;
    
    onLog?.call('🚀 Starting adaptive caching for: $videoUrl');
    onLog?.call('📊 Video duration: ${videoDuration.inSeconds}s');
    
    // Calculate total segments
    final totalSegments = _calculateTotalSegments(videoDuration);
    onLog?.call('📦 Total segments: $totalSegments');
    
    // Step 1: Download initial segments for immediate playback
    await _downloadInitialSegments(
      videoUrl,
      quality,
      totalSegments,
      headers,
      onLog,
    );
    
    // Step 2: Start background adaptive caching
    _startBackgroundCaching(
      sessionKey,
      videoUrl,
      quality,
      currentPositionStream,
      videoDuration,
      totalSegments,
      headers,
      onProgress,
      onLog,
      onCachedRangesUpdated,
    );
  }

  /// Stop adaptive caching for a video
  void stopAdaptiveCaching(String videoUrl, {String? quality}) {
    final sessionKey = _generateCacheKey(videoUrl, quality);
    final session = _activeSessions[sessionKey];
    
    if (session != null) {
      session.stopCaching();
      _activeSessions.remove(sessionKey);
      session.onLog?.call('⏹️ Adaptive caching stopped');
    }
  }

  /// Check if a specific segment is cached
  bool isSegmentCached(String videoUrl, int segmentIndex, {String? quality}) {
    final segmentKey = _generateSegmentKey(videoUrl, quality, segmentIndex);
    return _segmentCache.containsKey(segmentKey);
  }

  /// Get a cached segment
  VideoSegment? getSegment(String videoUrl, int segmentIndex, {String? quality}) {
    final segmentKey = _generateSegmentKey(videoUrl, quality, segmentIndex);
    final segment = _segmentCache[segmentKey];
    
    if (segment != null) {
      _updateLRU(segmentKey);
    }
    
    return segment;
  }

  /// Get all cached ranges for a video (for seek bar visualization)
  List<CachedRange> getCachedRanges(String videoUrl, {String? quality}) {
    final cacheKey = _generateCacheKey(videoUrl, quality);
    final segments = _segmentCache.entries
        .where((entry) => entry.key.startsWith(cacheKey))
        .map((entry) => entry.value)
        .toList()
      ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    
    if (segments.isEmpty) return [];
    
    final ranges = <CachedRange>[];
    int? rangeStart;
    int? rangeEnd;
    
    for (final segment in segments) {
      if (rangeStart == null) {
        rangeStart = segment.startByte;
        rangeEnd = segment.endByte;
      } else if (segment.startByte <= rangeEnd! + 1) {
        // Consecutive segment - extend range
        rangeEnd = segment.endByte;
      } else {
        // Gap detected - save current range and start new one
        ranges.add(CachedRange(
          startByte: rangeStart,
          endByte: rangeEnd,
          cachedAt: DateTime.now(),
        ));
        rangeStart = segment.startByte;
        rangeEnd = segment.endByte;
      }
    }
    
    // Add final range
    if (rangeStart != null && rangeEnd != null) {
      ranges.add(CachedRange(
        startByte: rangeStart,
        endByte: rangeEnd,
        cachedAt: DateTime.now(),
      ));
    }
    
    return ranges;
  }

  /// Get segment at specific time position
  int getSegmentIndexAtPosition(Duration position) {
    return (position.inSeconds / SEGMENT_DURATION_SECONDS).floor();
  }

  /// Check if video can play from current position (has cached segments)
  bool canPlayFromPosition(
    String videoUrl, 
    Duration position, {
    String? quality,
    int minSegmentsRequired = 3,
  }) {
    final startSegment = getSegmentIndexAtPosition(position);
    
    for (int i = 0; i < minSegmentsRequired; i++) {
      if (!isSegmentCached(videoUrl, startSegment + i, quality: quality)) {
        return false;
      }
    }
    
    return true;
  }

  // ==================== Internal Implementation ====================

  /// Calculate total number of segments for a video
  int _calculateTotalSegments(Duration videoDuration) {
    return (videoDuration.inSeconds / SEGMENT_DURATION_SECONDS).ceil();
  }

  /// Calculate byte range for a segment
  SegmentByteRange _calculateSegmentByteRange(
    int segmentIndex,
    Duration videoDuration,
  ) {
    // Estimate total file size
    final estimatedTotalBytes = 
        videoDuration.inSeconds * ESTIMATED_BYTES_PER_SECOND;
    
    // Calculate bytes per segment
    final totalSegments = _calculateTotalSegments(videoDuration);
    final bytesPerSegment = estimatedTotalBytes ~/ totalSegments;
    
    final startByte = segmentIndex * bytesPerSegment;
    final endByte = (segmentIndex + 1) * bytesPerSegment - 1;
    
    return SegmentByteRange(
      startByte: startByte,
      endByte: endByte,
      segmentIndex: segmentIndex,
    );
  }

  /// Download initial segments for immediate playback
  Future<void> _downloadInitialSegments(
    String videoUrl,
    String? quality,
    int totalSegments,
    Map<String, String>? headers,
    void Function(String log)? onLog,
  ) async {
    // Download first 30 seconds worth of segments
    final initialSegmentCount = 
        (MIN_BUFFER_SECONDS / SEGMENT_DURATION_SECONDS).ceil();
    
    onLog?.call('⬇️ Downloading initial $initialSegmentCount segments...');
    
    final downloads = <Future<VideoSegment?>>[];
    
    for (int i = 0; i < initialSegmentCount && i < totalSegments; i++) {
      downloads.add(_downloadSegment(
        videoUrl,
        i,
        quality: quality,
        priority: SegmentPriority.HIGH,
        headers: headers,
        onLog: onLog,
      ));
    }
    
    await Future.wait(downloads);
    onLog?.call('✅ Initial segments downloaded');
  }

  /// Start background adaptive caching loop
  void _startBackgroundCaching(
    String sessionKey,
    String videoUrl,
    String? quality,
    Stream<Duration> currentPositionStream,
    Duration videoDuration,
    int totalSegments,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
    void Function(List<CachedRange> ranges)? onCachedRangesUpdated,
  ) {
    final session = _activeSessions[sessionKey];
    if (session == null) return;
    
    // Listen to playback position updates
    session.positionSubscription = currentPositionStream.listen(
      (currentPosition) async {
        if (!_isOnline || session.isStopped) {
          return;
        }
        
        final currentSegment = getSegmentIndexAtPosition(currentPosition);
        
        // Calculate buffer status
        final bufferedSegments = _countBufferedSegmentsAhead(
          videoUrl,
          currentSegment,
          quality,
        );
        final bufferSeconds = bufferedSegments * SEGMENT_DURATION_SECONDS;
        
        if (kDebugMode) {
          onLog?.call(
            '📊 Position: ${currentPosition.inSeconds}s, '
            'Segment: $currentSegment, '
            'Buffer: ${bufferSeconds}s'
          );
        }
        
        // Adaptive caching strategy based on buffer status
        if (bufferSeconds < MIN_BUFFER_SECONDS) {
          // 🔴 CRITICAL: Buffer running low
          onLog?.call('🔴 Critical buffer - downloading urgently');
          await _downloadNextSegments(
            videoUrl,
            currentSegment,
            5, // Download 5 segments (25 seconds)
            totalSegments,
            quality: quality,
            priority: SegmentPriority.HIGH,
            headers: headers,
            onLog: onLog,
          );
        } else if (bufferSeconds < TARGET_BUFFER_SECONDS) {
          // 🟡 MODERATE: Normal caching
          if (kDebugMode) {
            onLog?.call('🟡 Moderate buffer - downloading normally');
          }
          await _downloadNextSegments(
            videoUrl,
            currentSegment,
            3, // Download 3 segments (15 seconds)
            totalSegments,
            quality: quality,
            priority: SegmentPriority.MEDIUM,
            headers: headers,
            onLog: onLog,
          );
        } else if (bufferSeconds < MAX_BUFFER_SECONDS) {
          // 🟢 GOOD: Opportunistic caching
          if (kDebugMode) {
            onLog?.call('🟢 Good buffer - opportunistic caching');
          }
          await _downloadNextSegments(
            videoUrl,
            currentSegment,
            2, // Download 2 segments (10 seconds)
            totalSegments,
            quality: quality,
            priority: SegmentPriority.LOW,
            headers: headers,
            onLog: onLog,
          );
        } else {
          // ⚪ FULL: Buffer is full
          if (kDebugMode) {
            onLog?.call('⚪ Buffer full - caching paused');
          }
        }
        
        // Update UI with cached ranges
        final ranges = getCachedRanges(videoUrl, quality: quality);
        onCachedRangesUpdated?.call(ranges);
        
        // Update overall progress
        final cachedCount = _countCachedSegments(videoUrl, quality);
        final progress = cachedCount / totalSegments;
        onProgress?.call(progress);
        
        // Manage cache size
        await _evictOldSegmentsIfNeeded(onLog);
      },
      onError: (error) {
        onLog?.call('❌ Position stream error: $error');
      },
    );
  }

  /// Download next N segments from current position
  Future<void> _downloadNextSegments(
    String videoUrl,
    int currentSegment,
    int count,
    int totalSegments, {
    String? quality,
    SegmentPriority priority = SegmentPriority.MEDIUM,
    Map<String, String>? headers,
    void Function(String log)? onLog,
  }) async {
    final downloads = <Future<VideoSegment?>>[];
    
    for (int i = 1; i <= count; i++) {
      final segmentIndex = currentSegment + i;
      
      if (segmentIndex >= totalSegments) break;
      
      // Skip if already cached
      if (isSegmentCached(videoUrl, segmentIndex, quality: quality)) {
        continue;
      }
      
      downloads.add(_downloadSegment(
        videoUrl,
        segmentIndex,
        quality: quality,
        priority: priority,
        headers: headers,
        onLog: onLog,
      ));
    }
    
    if (downloads.isNotEmpty) {
      await Future.wait(downloads);
    }
  }

  /// Download a single segment
  Future<VideoSegment?> _downloadSegment(
    String videoUrl,
    int segmentIndex, {
    String? quality,
    SegmentPriority priority = SegmentPriority.MEDIUM,
    Map<String, String>? headers,
    void Function(String log)? onLog,
  }) async {
    final segmentKey = _generateSegmentKey(videoUrl, quality, segmentIndex);
    
    // Check if already cached
    if (_segmentCache.containsKey(segmentKey)) {
      _updateLRU(segmentKey);
      return _segmentCache[segmentKey];
    }
    
    // Check if download in progress
    if (_pendingDownloads.containsKey(segmentKey)) {
      return _pendingDownloads[segmentKey]!.future;
    }
    
    final completer = Completer<VideoSegment?>();
    _pendingDownloads[segmentKey] = completer;
    
    try {
      // Get video duration from active session
      final cacheKey = _generateCacheKey(videoUrl, quality);
      final session = _activeSessions[cacheKey];
      
      if (session == null) {
        throw Exception('No active caching session');
      }
      
      // Calculate byte range
      final byteRange = _calculateSegmentByteRange(
        segmentIndex,
        session.videoDuration,
      );
      
      if (kDebugMode) {
        onLog?.call(
          '⬇️ Downloading segment $segmentIndex '
          '(${byteRange.startByte}-${byteRange.endByte})'
        );
      }
      
      // Make HTTP range request
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(videoUrl));
      
      if (headers != null) {
        request.headers.addAll(headers);
      }
      
      request.headers['Range'] = 
          'bytes=${byteRange.startByte}-${byteRange.endByte}';
      
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode != 206 && response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      // Read segment data
      final bytes = await response.stream.toBytes();
      
      // Create segment
      final segment = VideoSegment(
        segmentIndex: segmentIndex,
        data: bytes,
        startByte: byteRange.startByte,
        endByte: byteRange.startByte + bytes.length - 1,
        downloadedAt: DateTime.now(),
        videoUrl: videoUrl,
        quality: quality,
      );
      
      // Cache in memory
      _segmentCache[segmentKey] = segment;
      _updateLRU(segmentKey);
      
      // Persist to disk
      await _persistSegmentToDisk(segmentKey, segment);
      
      if (kDebugMode) {
        onLog?.call('✅ Segment $segmentIndex cached (${bytes.length} bytes)');
      }
      
      client.close();
      completer.complete(segment);
      return segment;
      
    } catch (e) {
      onLog?.call('❌ Failed to download segment $segmentIndex: $e');
      
      if (e is TimeoutException || e is SocketException) {
        _isOnline = false;
      }
      
      completer.complete(null);
      return null;
      
    } finally {
      _pendingDownloads.remove(segmentKey);
    }
  }

  /// Count consecutive buffered segments ahead of current position
  int _countBufferedSegmentsAhead(
    String videoUrl,
    int currentSegment,
    String? quality,
  ) {
    int count = 0;
    
    for (int i = currentSegment + 1; i < currentSegment + 200; i++) {
      if (isSegmentCached(videoUrl, i, quality: quality)) {
        count++;
      } else {
        break; // Stop at first missing segment
      }
    }
    
    return count;
  }

  /// Count total cached segments
  int _countCachedSegments(String videoUrl, String? quality) {
    final cacheKey = _generateCacheKey(videoUrl, quality);
    return _segmentCache.keys.where((key) => key.startsWith(cacheKey)).length;
  }

  /// Persist segment to disk for long-term caching
  Future<void> _persistSegmentToDisk(String key, VideoSegment segment) async {
    try {
      final directory = await _getCacheDirectory();
      if (directory == null) return;
      
      final file = File('${directory.path}/$key.seg');
      await file.writeAsBytes(segment.data);
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to persist segment to disk: $e');
      }
    }
  }

  /// Load cached segments from disk on startup
  Future<void> loadCachedSegmentsFromDisk(
    String videoUrl, {
    String? quality,
    void Function(String log)? onLog,
  }) async {
    try {
      final directory = await _getCacheDirectory();
      if (directory == null) return;
      
      final cacheKey = _generateCacheKey(videoUrl, quality);
      final files = directory.listSync().whereType<File>();
      
      int loadedCount = 0;
      
      for (final file in files) {
        final fileName = p.basename(file.path);
        
        if (fileName.startsWith(cacheKey) && fileName.endsWith('.seg')) {
          try {
            final bytes = await file.readAsBytes();
            final segmentKey = p.basenameWithoutExtension(fileName);
            
            // Extract segment index from key
            final parts = segmentKey.split('_');
            final segmentIndex = int.tryParse(parts.last);
            
            if (segmentIndex != null) {
              final segment = VideoSegment(
                segmentIndex: segmentIndex,
                data: bytes,
                startByte: 0, // Will be recalculated if needed
                endByte: bytes.length - 1,
                downloadedAt: file.lastModifiedSync(),
                videoUrl: videoUrl,
                quality: quality,
              );
              
              _segmentCache[segmentKey] = segment;
              _updateLRU(segmentKey);
              loadedCount++;
            }
          } catch (e) {
            // Skip corrupted files
            continue;
          }
        }
      }
      
      if (loadedCount > 0) {
        onLog?.call('📂 Loaded $loadedCount cached segments from disk');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load cached segments: $e');
      }
    }
  }

  /// Evict old segments when cache size exceeds limit
  Future<void> _evictOldSegmentsIfNeeded(
    void Function(String log)? onLog,
  ) async {
    final totalSize = _segmentCache.values.fold<int>(
      0,
      (sum, segment) => sum + segment.data.length,
    );
    
    final maxSize = MAX_CACHE_SIZE_MB * 1024 * 1024;
    
    if (totalSize > maxSize) {
      onLog?.call('🗑️ Cache size exceeded, evicting old segments');
      
      // Remove 20% of least recently used segments
      final toRemove = (_segmentCache.length * 0.2).ceil();
      final keysToRemove = _lruTracker.keys.take(toRemove).toList();
      
      for (final key in keysToRemove) {
        _segmentCache.remove(key);
        _lruTracker.remove(key);
        
        // Delete from disk
        try {
          final directory = await _getCacheDirectory();
          if (directory != null) {
            final file = File('${directory.path}/$key.seg');
            if (file.existsSync()) {
              await file.delete();
            }
          }
        } catch (e) {
          // Ignore deletion errors
        }
      }
      
      onLog?.call('✅ Evicted $toRemove segments');
    }
  }

  /// Update LRU tracker
  void _updateLRU(String key) {
    _lruTracker.remove(key);
    _lruTracker[key] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Generate cache key for video
  String _generateCacheKey(String url, String? quality) {
    final qualitySuffix = quality != null ? '_$quality' : '';
    return '${url.hashCode.abs()}$qualitySuffix';
  }

  /// Generate segment key
  String _generateSegmentKey(String url, String? quality, int segmentIndex) {
    final cacheKey = _generateCacheKey(url, quality);
    return '${cacheKey}_$segmentIndex';
  }

  /// Get cache directory
  Future<Directory?> _getCacheDirectory() async {
    try {
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final cacheDir = Directory('${dir.path}/video_cache_segments');
          if (!cacheDir.existsSync()) {
            cacheDir.createSync(recursive: true);
          }
          return cacheDir;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/video_cache_segments');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      return cacheDir;
    } catch (e) {
      debugPrint('Failed to get cache directory: $e');
      return null;
    }
  }

  /// Set network online/offline status
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    if (kDebugMode) {
      print('Network status: ${isOnline ? "🟢 Online" : "🔴 Offline"}');
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
      cacheEntries: _segmentCache.length,
    );
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    _segmentCache.clear();
    _lruTracker.clear();
    _pendingDownloads.clear();
    
    for (final session in _activeSessions.values) {
      session.stopCaching();
    }
    _activeSessions.clear();
    
    final directory = await _getCacheDirectory();
    if (directory != null && directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    
    if (kDebugMode) {
      print('Cache cleared');
    }
  }

  /// Clear cache for specific URL
  Future<void> clearCacheForUrl(String url, {String? quality}) async {
    final cacheKey = _generateCacheKey(url, quality);
    
    // Remove from memory
    _segmentCache.removeWhere((key, _) => key.startsWith(cacheKey));
    _lruTracker.removeWhere((key, _) => key.startsWith(cacheKey));
    
    // Remove from disk
    final directory = await _getCacheDirectory();
    if (directory == null) return;

    final files = directory.listSync().whereType<File>();
    for (final file in files) {
      final fileName = p.basename(file.path);
      if (fileName.startsWith(cacheKey)) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Failed to delete cache file: $e');
        }
      }
    }
  }

  // ==================== Legacy Methods (Backward Compatibility) ====================

  /// Legacy method - kept for backward compatibility
  Future<File?> getCachedFile(String url, {String? quality}) async {
    // This is kept for backward compatibility but not used in new adaptive caching
    final cacheKey = _generateCacheKey(url, quality);
    final cacheEntry = _cacheEntries[cacheKey];

    if (cacheEntry != null && cacheEntry.file.existsSync()) {
      cacheEntry.lastAccessed = DateTime.now();
      return cacheEntry.file;
    }

    return null;
  }
}

// ==================== Supporting Classes ====================

/// Represents a video segment
class VideoSegment {
  final int segmentIndex;
  final Uint8List data;
  final int startByte;
  final int endByte;
  final DateTime downloadedAt;
  final String videoUrl;
  final String? quality;

  VideoSegment({
    required this.segmentIndex,
    required this.data,
    required this.startByte,
    required this.endByte,
    required this.downloadedAt,
    required this.videoUrl,
    this.quality,
  });

  int get sizeInBytes => data.length;
}

/// Segment byte range information
class SegmentByteRange {
  final int startByte;
  final int endByte;
  final int segmentIndex;

  SegmentByteRange({
    required this.startByte,
    required this.endByte,
    required this.segmentIndex,
  });
}

/// Download priority for segments
enum SegmentPriority {
  HIGH,    // Critical - needed immediately
  MEDIUM,  // Normal - building buffer
  LOW,     // Opportunistic - if bandwidth available
}

/// Caching session for a video
class CachingSession {
  final String videoUrl;
  final String? quality;
  final Duration videoDuration;
  final Map<String, String>? headers;
  final void Function(double progress)? onProgress;
  final void Function(String log)? onLog;
  final void Function(List<CachedRange> ranges)? onCachedRangesUpdated;
  
  StreamSubscription<Duration>? positionSubscription;
  bool isStopped = false;

  CachingSession({
    required this.videoUrl,
    required this.quality,
    required this.videoDuration,
    this.headers,
    this.onProgress,
    this.onLog,
    this.onCachedRangesUpdated,
  });

  void stopCaching() {
    isStopped = true;
    positionSubscription?.cancel();
  }
}