import 'package:flutter/material.dart';

class AmbientModeSettings extends StatelessWidget {
  const AmbientModeSettings({
    super.key,
    required this.value,
    this.onChanged,
  });

  final bool value;
  final void Function(bool)? onChanged;
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
            "Ambient Mode",
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          trailing: Switch(
            value: value,
            activeColor: const Color(0xfff70808),
            onChanged: (val) {
              onChanged?.call(val);
              Navigator.pop(context);
            },
          ),
          onTap: () {
            onChanged?.call(!value);
            Navigator.pop(context);
          },
        ),
        Center(
          child: Image.asset(
            'packages/ns_player/assets/images/ambient.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
