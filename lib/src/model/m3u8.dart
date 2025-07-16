/// Represents a single stream entry in an m3u8 playlist.
///
/// Contains information about the video's quality and its URL.
class M3U8Data {

  /// Creates an instance of [M3U8Data].
  ///
  /// Both [dataURL] and [dataQuality] are optional.
  M3U8Data({this.dataURL, this.dataQuality});
  /// The quality label of the video (e.g., 720p, 1080p).
  final String? dataQuality;

  /// The URL of the video stream.
  final String? dataURL;
}
