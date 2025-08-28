/// Cache statistics
class CacheStats {
  CacheStats({
    required this.fileCount,
    required this.totalSize,
    required this.cacheEntries,
  });

  factory CacheStats.empty() {
    return CacheStats(fileCount: 0, totalSize: 0, cacheEntries: 0);
  }

  final int fileCount;
  final int totalSize;
  final int cacheEntries;

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
