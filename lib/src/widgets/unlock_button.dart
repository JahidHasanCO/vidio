import 'package:flutter/material.dart';

class UnlockButton extends StatelessWidget {
  const UnlockButton({
    required this.isLocked,
    required this.showMenu,
    required this.onUnlock,
    super.key,
  });
  final bool isLocked;
  final bool showMenu;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: isLocked && showMenu,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TextButton.icon(
            onPressed: onUnlock,
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
            ),
            icon: const Icon(Icons.lock, color: Colors.white),
            label: const Text(
              'Unlock',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
