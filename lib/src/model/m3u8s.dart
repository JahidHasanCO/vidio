import 'package:vidio/src/model/m3u8.dart';

/// A model that contains a list of m3u8 stream data.
class M3U8s {

  /// The list of m3u8 stream data.
  final List<M3U8Data>? m3u8s;

  /// Creates an instance of [M3U8s].
  ///
  /// The [m3u8s] parameter is an optional list of [M3U8Data] objects.
  M3U8s({this.m3u8s});
}
