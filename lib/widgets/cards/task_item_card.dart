import 'package:flutter/material.dart';
import '../../models/daily_task.dart';
import '../../config/colors.dart';
import '../common/review_status_icon.dart';

/// 任务项卡片组件
class TaskItemCard extends StatelessWidget {
  final TaskItem item;
  final VoidCallback onTap;
  final bool isCompleted;

  const TaskItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isCompleted ? null : AppColors.cardGradient,
        color: isCompleted ? AppColors.background : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isCompleted ? null : AppColors.shadowSoft,
        border: Border.all(
          color: isCompleted 
              ? AppColors.divider 
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCompleted ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    // 综合题显示特殊图标
                    if (item.isComprehensive)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.workspaces_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      )
                    else
                      ReviewStatusIcon(
                        status: item.status,
                        size: 32,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.knowledgePointName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted 
                                        ? AppColors.textTertiary 
                                        : AppColors.textPrimary,
                                    decoration: isCompleted 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                  ),
                                ),
                              ),
                              if (item.isComprehensive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '综合',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          ReviewStatusIcon(
                            status: item.status,
                            showLabel: true,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppColors.success,
                          size: 20,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
                
                // 题目信息
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? AppColors.background 
                        : AppColors.primaryUltraLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 16,
                        color: isCompleted 
                            ? AppColors.textTertiary 
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '共 ${item.totalQuestions} 题',
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted 
                              ? AppColors.textTertiary 
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.originalCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '原题 ${item.originalCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted 
                                ? AppColors.textTertiary 
                                : AppColors.mistake,
                          ),
                        ),
                      ],
                      if (item.variantCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '变式 ${item.variantCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted 
                                ? AppColors.textTertiary 
                                : AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // AI 提示
                if (item.aiMessage != null && item.aiMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentUltraLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.aiMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 完成统计（如果已完成）
                if (isCompleted && (item.correctCount > 0 || item.wrongCount > 0)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatItem(
                        icon: Icons.check_circle_outline,
                        label: '正确',
                        value: '${item.correctCount}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        icon: Icons.cancel_outlined,
                        label: '错误',
                        value: '${item.wrongCount}',
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        icon: Icons.percent,
                        label: '正确率',
                        value: '${(item.accuracy * 100).toInt()}%',
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

