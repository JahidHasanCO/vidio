import 'package:flutter/material.dart';

class SeekButton extends StatefulWidget {
  final bool isForward;
  final VoidCallback onTap;
  final Widget? icon;

  const SeekButton({
    super.key,
    required this.isForward,
    required this.onTap,
    this.icon,
  });

  @override
  State<SeekButton> createState() => _SeekButtonState();
}

class _SeekButtonState extends State<SeekButton> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _textController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _textOpacity;
  late Animation<double> _iconOpacity;
  late Animation<Offset> _textOffset;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    _rotationAnimation = Tween<double>(
      begin: widget.isForward ? -0.5 : 0.5,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _textOffset = Tween<Offset>(
      begin: Offset.zero,
      end: widget.isForward ? const Offset(1.8, 0.0) : const Offset(-1.8, 0.0),
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _iconOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
  }

  void _playAnimations() {
    _rotationController.forward(from: 0.0);
    _textController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playAnimations,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
                opacity: _iconOpacity,
                child: RotationTransition(
                    turns: _rotationAnimation, child: widget.icon)),
            SlideTransition(
              position: _textOffset,
              child: FadeTransition(
                opacity: _textOpacity,
                child: SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      widget.isForward ? '+10' : '-10',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
