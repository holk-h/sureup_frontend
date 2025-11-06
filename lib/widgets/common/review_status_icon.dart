import 'package:flutter/material.dart';
import '../../models/review_state.dart';
import '../../config/colors.dart';

/// 复习状态图标组件
class ReviewStatusIcon extends StatelessWidget {
  final ReviewStatus status;
  final double size;
  final bool showLabel;

  const ReviewStatusIcon({
    super.key,
    required this.status,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: config.color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.icon,
              color: config.color,
              size: size * 0.8,
            ),
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: config.color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          config.icon,
          color: config.color,
          size: size * 0.6,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.newLearning:
        return _StatusConfig(
          icon: Icons.auto_awesome,
          color: AppColors.success,
          backgroundColor: AppColors.primaryUltraLight,
          label: '新学习',
        );
      case ReviewStatus.reviewing:
        return _StatusConfig(
          icon: Icons.book_outlined,
          color: AppColors.accent,
          backgroundColor: AppColors.accentUltraLight,
          label: '复习中',
        );
      case ReviewStatus.mastered:
        return _StatusConfig(
          icon: Icons.star,
          color: AppColors.warning,
          backgroundColor: const Color(0xFFFFFBEB),
          label: '已掌握',
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String label;

  _StatusConfig({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.label,
  });
}

