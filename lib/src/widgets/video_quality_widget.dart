import 'package:flutter/material.dart';
import 'package:vidio/vidio.dart';

/// A widget to display the video's current selected quality type.
class VideoQualityWidget extends StatelessWidget {
  /// Constructor
  const VideoQualityWidget({
    required this.child,
    super.key,
    this.onTap,
    this.videoStyle = const VideoStyle(),
  });

  /// Callback function when user tap this widget to open the options list.
  final void Function()? onTap;

  /// The custom child to display the selected quality type.
  final Widget child;

  /// The model to provide custom style for the video display widget.
  final VideoStyle videoStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: videoStyle.videoQualityBgColor ?? Colors.grey,
          borderRadius: videoStyle.videoQualityRadius ??
              const BorderRadius.all(Radius.circular(5)),
        ),
        child: Padding(
          padding: videoStyle.videoQualityPadding ??
              const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: child,
        ),
      ),
    );
  }
}
