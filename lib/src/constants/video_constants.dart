import 'package:flutter/material.dart';

/// Video player constants and magic numbers
class VideoConstants {
  VideoConstants._();

  /// Primary color used for video controls and UI elements
  static const Color kPrimaryColor = Color(0xfff70808);
  
  /// Duration after which video controls are automatically hidden
  static const Duration kControlHideDuration = Duration(milliseconds: 5000);
  
  /// Timeout duration for network requests when fetching M3U8 content
  static const Duration kNetworkTimeout = Duration(seconds: 20);
}