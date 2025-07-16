import 'package:flutter/material.dart';

class BorderedThumbShape extends SliderComponentShape {

  const BorderedThumbShape({
    this.thumbRadius = 12.0,
    this.centerColor = Colors.pinkAccent,
    this.borderWidth = 3.0,
  });

  final double thumbRadius;
  final Color centerColor;
  final double borderWidth;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Draw outer white circle (border)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, borderPaint);

    // Draw inner circle
    final fillPaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius - borderWidth, fillPaint);
  }
}
