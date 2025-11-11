import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../config/text_styles.dart';
import '../../models/models.dart';
import '../common/math_markdown_text.dart';

/// 知识点卡片 - 现代化设计
class KnowledgePointCard extends StatelessWidget {
  final KnowledgePoint point;
  final VoidCallback? onTap;

  const KnowledgePointCard({
    super.key,
    required this.point,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final masteryColor = _getMasteryColor(point.masteryLevel);
    final subjectColor = point.subject.color;
    final subjectIcon = point.subject.icon;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Stack(
            children: [
              // 装饰性纯色条
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: subjectColor,
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Row(
                  children: [
                    // 学科图标
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: subjectColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: Center(
                        child: Text(
                          subjectIcon,
                          style: const TextStyle(
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    
                    // 知识点信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: MathMarkdownText(
                                  text: point.name,
                                  style: AppTextStyles.smallTitle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingS),
                          Row(
                            children: [
                              // 错题数
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 12,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${point.mistakeCount}题',
                                      style: AppTextStyles.small.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingS),
                              
                              // 掌握度
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: AppColors.divider,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: point.masteryLevel / 100,
                                            child: Container(
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: masteryColor,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${point.masteryLevel}%',
                                      style: AppTextStyles.small.copyWith(
                                        color: masteryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: AppConstants.spacingS),
                    
                    // 箭头
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

}

