import 'package:flutter/material.dart';

class AmbientModeSettings extends StatelessWidget {
  const AmbientModeSettings({
    required this.value,
    super.key,
    this.onChanged,
  });

  final bool value;
  final void Function({bool? value})? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(
            Icons.video_settings_outlined,
            size: 20,
            color: Colors.black87,
          ),
          title: const Text(
            'Ambient Mode',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          trailing: Switch(
            value: value,
            activeColor: const Color(0xfff70808),
            onChanged: (val) {
              onChanged?.call(value: val);
              Navigator.pop(context);
            },
          ),
          onTap: () {
            onChanged?.call(value: !value);
            Navigator.pop(context);
          },
        ),
        Center(
          child: Image.asset(
            'packages/vidio/assets/images/ambient.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
