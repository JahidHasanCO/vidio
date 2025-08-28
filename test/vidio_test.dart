import 'package:flutter_test/flutter_test.dart';
import 'package:vidio/src/video_cache_manager.dart';

void main() {
  group('CacheStats', () {
    test('should create cache stats correctly', () {
      final stats = CacheStats(fileCount: 5, totalSize: 1024, cacheEntries: 3);

      expect(stats.fileCount, equals(5));
      expect(stats.totalSize, equals(1024));
      expect(stats.cacheEntries, equals(3));
      expect(stats.formattedSize, equals('1.0 KB'));
    });

    test('should format large file sizes correctly', () {
      final stats = CacheStats(fileCount: 1, totalSize: 1073741824, cacheEntries: 1); // 1GB

      expect(stats.formattedSize, equals('1.0 GB'));
    });

    test('should create empty cache stats', () {
      final stats = CacheStats.empty();

      expect(stats.fileCount, equals(0));
      expect(stats.totalSize, equals(0));
      expect(stats.cacheEntries, equals(0));
      expect(stats.formattedSize, equals('0.0 B'));
    });

    test('should format medium file sizes correctly', () {
      final stats = CacheStats(fileCount: 1, totalSize: 1048576, cacheEntries: 1); // 1MB

      expect(stats.formattedSize, equals('1.0 MB'));
    });
  });
}
