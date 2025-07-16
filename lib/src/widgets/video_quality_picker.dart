import 'package:flutter/material.dart';
import 'package:ns_player/ns_player.dart';
import 'package:ns_player/src/model/m3u8.dart';

class VideoQualityPicker extends StatelessWidget {
  final List<M3U8Data> videoData;
  final bool showPicker;
  final double? positionRight;
  final double? positionTop;
  final double? positionLeft;
  final double? positionBottom;
  final VideoStyle videoStyle;
  final String selectedQuality;
  final void Function(M3U8Data data)? onQualitySelected;

  const VideoQualityPicker({
    super.key,
    required this.videoData,
    this.videoStyle = const VideoStyle(),
    this.showPicker = false,
    this.positionRight,
    this.positionTop,
    this.onQualitySelected,
    this.positionLeft,
    this.positionBottom,
    required this.selectedQuality,
  });

  @override
  Widget build(BuildContext context) {
    videoData.sort((a, b) {
      if (a.dataQuality == 'Auto') {
        return -1;
      } else if (b.dataQuality == 'Auto') {
        return 1;
      } else {
        return int.parse(a.dataQuality!.split('x').last)
            .compareTo(int.parse(b.dataQuality!.split('x').last));
      }
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.video_settings,
                size: 20,
                color: Colors.black87,
              ),
              SizedBox(width: 8),
              Text(
                'Select Video Quality',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: videoData.map((item) {
              final isSelected = item.dataQuality == selectedQuality;
              final label = item.dataQuality == 'Auto'
                  ? 'Auto (Recommended)'
                  : '${item.dataQuality?.split('x').last}p';

              return ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 13)),
                selected: isSelected,
                selectedColor: const Color(0xfff70808),
                backgroundColor: Colors.white,
                showCheckmark: false,
                onSelected: (_) => onQualitySelected?.call(item),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.black87,
                  ),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
