import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/text_styles.dart';

/// 学习状态概览卡片
class StatsOverviewCard extends StatelessWidget {
  final int weekMistakes; // 本周错题数
  final int completionRate; // 完成率
  final int continuousDays; // 连续天数

  const StatsOverviewCard({
    super.key,
    required this.weekMistakes,
    required this.completionRate,
    required this.continuousDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.dividerLight,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              label: '本周错题',
              value: '$weekMistakes',
              icon: CupertinoIcons.xmark_circle,
              color: AppColors.error,
            ),
          ),
          Container(
            width: 1,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.dividerLight,
                  AppColors.divider,
                  AppColors.dividerLight,
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildStatItem(
              label: '完成率',
              value: '$completionRate%',
              icon: CupertinoIcons.checkmark_alt_circle,
              color: AppColors.success,
            ),
          ),
          Container(
            width: 1,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.dividerLight,
                  AppColors.divider,
                  AppColors.dividerLight,
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildStatItem(
              label: '连续打卡',
              value: '$continuousDays天',
              icon: CupertinoIcons.flame,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label, 
          style: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

