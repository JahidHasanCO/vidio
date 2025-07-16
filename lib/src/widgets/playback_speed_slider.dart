import 'package:flutter/material.dart';

class PlaybackSpeedSlider extends StatefulWidget {
  final List<double> speeds;
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const PlaybackSpeedSlider({
    super.key,
    required this.speeds,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  State<PlaybackSpeedSlider> createState() => _PlaybackSpeedSliderState();
}

class _PlaybackSpeedSliderState extends State<PlaybackSpeedSlider> {
  late double _tempSpeed;

  @override
  void initState() {
    super.initState();
    _tempSpeed = widget.currentSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SizedBox(width: 10),
            Icon(
              Icons.speed_rounded,
              size: 20,
              color: Colors.black87,
            ),
            SizedBox(width: 8),
            Text(
              'Playback Speed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              pressedElevation: 4,
            ),
            activeTrackColor: const Color(0xfff70808),
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: const Color(0xfff70808),
            overlayColor: const Color(0xfff70808).withOpacity(0.2),
            overlayShape: SliderComponentShape.noOverlay,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
            ),
            valueIndicatorColor: const Color(0xfff70808),
          ),
          child: Slider(
            min: 0,
            max: (widget.speeds.length - 1).toDouble(),
            divisions: widget.speeds.length - 1,
            value: widget.speeds.indexOf(_tempSpeed).toDouble(),
            label: _tempSpeed == 1.0 ? 'Normal' : '${_tempSpeed}x',
            onChanged: (val) {
              setState(() {
                _tempSpeed = widget.speeds[val.round()];
              });
            },
            onChangeEnd: (val) {
              final selected = widget.speeds[val.round()];
              widget.onSpeedChanged(selected);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.speeds.map((speed) {
              return Text(
                speed == 1.0 ? 'Normal' : '${speed}x',
                style: const TextStyle(fontSize: 14),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
