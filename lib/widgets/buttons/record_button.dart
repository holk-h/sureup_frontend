import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../config/colors.dart';
import '../../config/constants.dart';

/// 📷记录错题按钮
class RecordButton extends StatefulWidget {
  final VoidCallback onPressed;

  const RecordButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AppConstants.animationQuick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppColors.coloredShadow(AppColors.accent, opacity: 0.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.camera_fill,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Text(
                '记录错题',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

