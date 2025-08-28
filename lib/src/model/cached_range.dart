/// Represents a cached portion of a video file
class CachedRange {
  const CachedRange({
    required this.startByte,
    required this.endByte,
    required this.cachedAt,
  });

  final int startByte;
  final int endByte;
  final DateTime cachedAt;

  /// Get the size of this cached range in bytes
  int get size => endByte - startByte + 1;

  /// Check if a position (in bytes) is within this range
  bool contains(int position) {
    return position >= startByte && position <= endByte;
  }

  /// Merge this range with another if they overlap or are adjacent
  CachedRange? merge(CachedRange other) {
    if (endByte + 1 >= other.startByte && startByte <= other.endByte + 1) {
      return CachedRange(
        startByte: startByte < other.startByte ? startByte : other.startByte,
        endByte: endByte > other.endByte ? endByte : other.endByte,
        cachedAt: DateTime.now(),
      );
    }
    return null;
  }
}
