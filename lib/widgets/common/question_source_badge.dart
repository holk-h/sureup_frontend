import 'package:flutter/material.dart';
import '../../models/daily_task.dart';
import '../../config/colors.dart';

/// 题目来源标签组件
class QuestionSourceBadge extends StatelessWidget {
  final QuestionSource source;
  final bool compact;

  const QuestionSourceBadge({
    super.key,
    required this.source,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSourceConfig(source);

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: config.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        source.displayName,
        style: TextStyle(
          color: config.color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  _SourceConfig _getSourceConfig(QuestionSource source) {
    switch (source) {
      case QuestionSource.original:
        return _SourceConfig(
          color: AppColors.mistake,
          backgroundColor: const Color(0xFFFCE7F3),
        );
      case QuestionSource.variant:
        return _SourceConfig(
          color: AppColors.accent,
          backgroundColor: AppColors.accentUltraLight,
        );
    }
  }
}

class _SourceConfig {
  final Color color;
  final Color backgroundColor;

  _SourceConfig({
    required this.color,
    required this.backgroundColor,
  });
}

