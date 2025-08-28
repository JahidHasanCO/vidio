import 'dart:io';
import 'package:vidio/src/model/model.dart';

/// Cache entry for tracking cached files
class CacheEntry {
  CacheEntry({
    required this.url,
    required this.quality,
    required this.file,
    required this.lastAccessed,
    this.cachedRanges = const [],
  });

  final String url;
  final String? quality;
  final File file;
  DateTime lastAccessed;
  final List<CachedRange> cachedRanges;
}
