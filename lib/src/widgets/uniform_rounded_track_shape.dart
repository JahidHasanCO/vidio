import 'package:flutter/material.dart';

class UniformRoundedTrackShape extends SliderTrackShape {
  const UniformRoundedTrackShape({this.trackRadius = const Radius.circular(6)});
  final Radius trackRadius;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackLeft = offset.dx +
        (sliderTheme.thumbShape?.getPreferredSize(true, isDiscrete).width ??
                0) /
            2;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width -
        (sliderTheme.thumbShape?.getPreferredSize(true, isDiscrete).width ?? 0);

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required Animation<double> enableAnimation,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isDiscrete = false,
    bool isEnabled = false,
    Offset? secondaryOffset,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.orange;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey;

    final isLTR = textDirection == TextDirection.ltr;
    final thumbX = thumbCenter.dx;

    final leftTrack = RRect.fromRectAndRadius(
      Rect.fromLTRB(trackRect.left, trackRect.top, thumbX, trackRect.bottom),
      trackRadius,
    );

    final rightTrack = RRect.fromRectAndRadius(
      Rect.fromLTRB(thumbX, trackRect.top, trackRect.right, trackRect.bottom),
      trackRadius,
    );

    if (isLTR) {
      context.canvas.drawRRect(leftTrack, activePaint);
      context.canvas.drawRRect(rightTrack, inactivePaint);
    } else {
      context.canvas.drawRRect(rightTrack, activePaint);
      context.canvas.drawRRect(leftTrack, inactivePaint);
    }
  }
}
