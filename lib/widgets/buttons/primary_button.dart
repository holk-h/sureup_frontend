import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';

/// 主按钮组件
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isSecondary = false,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppConstants.animationFast,
        child: Container(
          width: widget.width,
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.isSecondary ? null : AppColors.primaryGradient,
            color: widget.isSecondary ? AppColors.cardBackground : null,
            borderRadius: BorderRadius.circular(16),
            border: widget.isSecondary
                ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)
                : null,
            boxShadow: widget.isSecondary 
                ? AppColors.shadowSoft
                : AppColors.coloredShadow(AppColors.primary, opacity: 0.25),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: widget.isSecondary ? AppColors.primary : AppColors.cardBackground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

