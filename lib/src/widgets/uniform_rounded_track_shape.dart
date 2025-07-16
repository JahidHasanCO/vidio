import 'package:flutter/material.dart';

class UniformRoundedTrackShape extends SliderTrackShape {
  final Radius trackRadius;

  const UniformRoundedTrackShape({this.trackRadius = const Radius.circular(6)});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackLeft = offset.dx +
        (sliderTheme.thumbShape?.getPreferredSize(true, isDiscrete).width ??
                0) /
            2;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width -
        (sliderTheme.thumbShape?.getPreferredSize(true, isDiscrete).width ?? 0);

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    required RenderBox parentBox,
    Offset? secondaryOffset,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required Offset thumbCenter,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.orange;
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey;

    final bool isLTR = textDirection == TextDirection.ltr;
    final double thumbX = thumbCenter.dx;

    final RRect leftTrack = RRect.fromRectAndRadius(
      Rect.fromLTRB(trackRect.left, trackRect.top, thumbX, trackRect.bottom),
      trackRadius,
    );

    final RRect rightTrack = RRect.fromRectAndRadius(
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
