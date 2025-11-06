import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator;
import '../../config/colors.dart';
import '../../models/daily_task.dart';

/// 每日任务摘要卡片 - 显示在首页
class DailyTaskSummaryCard extends StatelessWidget {
  final DailyTask? task;
  final bool isLoading;
  final VoidCallback onTap;
  final int continuousDays; // 连续完成天数

  const DailyTaskSummaryCard({
    super.key,
    required this.task,
    this.isLoading = false,
    required this.onTap,
    this.continuousDays = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingCard();
    }

    // 计算显示数据
    final completedCount = task?.completedCount ?? 0;
    final totalItems = task?.items.length ?? 0;
    final progress = task?.progress ?? 0.0;
    final isCompleted = task?.isCompleted ?? false;
    final hasTask = task != null && totalItems > 0;

    // 计算题目统计
    int totalQuestions = 0;
    int completedQuestions = 0;
    int newLearningCount = 0;
    int reviewingCount = 0;
    int masteredCount = 0;

    if (task != null && task!.items.isNotEmpty) {
      for (var item in task!.items) {
        totalQuestions += item.totalQuestions;
        if (item.isCompleted) {
          completedQuestions += item.totalQuestions;
        }
        // 统计各状态知识点
        switch (item.status.name) {
          case 'newLearning':
            newLearningCount++;
            break;
          case 'reviewing':
            reviewingCount++;
            break;
          case 'mastered':
            masteredCount++;
            break;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
          boxShadow: AppColors.shadowSoft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppColors.coloredShadow(
                        AppColors.primary,
                        opacity: 0.15,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.calendar_today,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '今日任务',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasTask ? '每天进步一点点' : '暂无任务',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted && hasTask)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: AppColors.success,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '已完成',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Icon(
                      CupertinoIcons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // 主要统计 - 三列布局
              Row(
                children: [
                  // 知识点进度
                  Expanded(
                    child: _buildStatItem(
                      icon: CupertinoIcons.book_fill,
                      iconColor: AppColors.accent,
                      label: '知识点',
                      value: '$completedCount',
                      suffix: '/$totalItems',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: AppColors.divider,
                  ),
                  // 题目进度
                  Expanded(
                    child: _buildStatItem(
                      icon: CupertinoIcons.doc_text_fill,
                      iconColor: AppColors.warning,
                      label: '题目',
                      value: '$completedQuestions',
                      suffix: '/$totalQuestions',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: AppColors.divider,
                  ),
                  // 连续天数
                  Expanded(
                    child: _buildStatItem(
                      icon: CupertinoIcons.flame_fill,
                      iconColor: continuousDays >= 7 
                          ? const Color(0xFFFF6B35) // 橙红色
                          : continuousDays >= 3 
                              ? const Color(0xFFFF8C42) // 橙色
                              : const Color(0xFFFFA500), // 浅橙色
                      label: '连续天数',
                      value: '$continuousDays',
                      suffix: '天',
                      isStreak: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 进度条
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '完成进度',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.primaryUltraLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),

              // 知识点状态标签（如果有任务）
              if (hasTask) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (newLearningCount > 0)
                      _buildStatusChip(
                        '新学习',
                        newLearningCount,
                        CupertinoIcons.star_fill,
                        Colors.yellow.shade700,
                      ),
                    if (reviewingCount > 0)
                      _buildStatusChip(
                        '复习中',
                        reviewingCount,
                        CupertinoIcons.arrow_clockwise,
                        Colors.blue.shade600,
                      ),
                    if (masteredCount > 0)
                      _buildStatusChip(
                        '已掌握',
                        masteredCount,
                        CupertinoIcons.checkmark_seal_fill,
                        Colors.orange.shade600,
                      ),
                  ],
                ),
              ],

              // 知识点预览（最多显示3个）
              if (hasTask && task!.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              CupertinoIcons.list_bullet,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '知识点列表',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...task!.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              item.isCompleted 
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: item.isCompleted 
                                  ? AppColors.success 
                                  : AppColors.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.knowledgePointName,
                                style: TextStyle(
                                  color: item.isCompleted 
                                      ? AppColors.textTertiary
                                      : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: item.isCompleted 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.totalQuestions}题',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (task!.items.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '还有 ${task!.items.length - 3} 个知识点...',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String suffix,
    bool isStreak = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              // 连续天数添加特殊效果
              boxShadow: isStreak && int.parse(value) >= 3
                  ? [
                      BoxShadow(
                        color: iconColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: const Center(
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}

