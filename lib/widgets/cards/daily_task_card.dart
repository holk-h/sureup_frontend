import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../config/text_styles.dart';

/// 今日任务卡片 - 现代化设计
class DailyTaskCard extends StatelessWidget {
  final int reviewCount; // 待复盘错题数
  final int practiceCount; // 举一反三数量
  final int masteredCount; // 已掌握数量
  final double progress; // 完成进度 0-1
  final int currentStage; // 当前阶段 1-错题记录 2-分析 3-练习 0-未开始
  final VoidCallback? onTap; // 点击回调

  const DailyTaskCard({
    super.key,
    required this.reviewCount,
    required this.practiceCount,
    required this.masteredCount,
    required this.progress,
    this.currentStage = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
          boxShadow: [
            // 简单的浅灰色小阴影
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x06000000),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    color: AppColors.cardBackground,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日任务',
                      style: AppTextStyles.mediumTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '坚持每天进步一点点',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            
            // 任务数量 - 三个子卡片
            Row(
              children: [
                Expanded(
                  child: _buildModernTaskItem(
                    icon: CupertinoIcons.doc_text_fill,
                    label: '待复盘',
                    count: reviewCount,
                    color: AppColors.accent, // 蓝色
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModernTaskItem(
                    icon: CupertinoIcons.lightbulb_fill,
                    label: '举一反三',
                    count: practiceCount,
                    color: AppColors.warning, // 橙色
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModernTaskItem(
                    icon: CupertinoIcons.checkmark_shield_fill,
                    label: '已掌握',
                    count: masteredCount,
                    color: AppColors.success, // 绿色
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            
            // 学习阶段 - 三阶段展示
            _buildLearningStages(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildModernTaskItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：图标 + 数字
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x06000000),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.cardBackground,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 第二排：文字描述
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建学习阶段展示 - 精致版进度条
  Widget _buildLearningStages() {
    final stages = ['错题记录', '分析', '练习'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今日完成度',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.coloredShadow(
                  AppColors.primary,
                  opacity: 0.2,
                ),
              ),
              child: Text(
                _getStageText(),
                style: const TextStyle(
                  color: AppColors.cardBackground,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        
        // 进度条和圆点
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              // 背景横条
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // 激活的进度横条
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _getProgressWidth(),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // 三个圆点和标签
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  final stageNumber = index + 1;
                  final isActive = currentStage >= stageNumber;
                  final isCurrent = currentStage == stageNumber;
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDot(isActive, isCurrent),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 64,
                        child: Text(
                          stages[index],
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: isActive 
                                ? AppColors.textPrimary 
                                : AppColors.textTertiary,
                            fontWeight: isActive 
                                ? FontWeight.w600 
                                : FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建圆点
  Widget _buildDot(bool isActive, bool isCurrent) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: isCurrent ? 10 : 8,
          height: isCurrent ? 10 : 8,
          decoration: BoxDecoration(
            gradient: isActive
                ? AppColors.primaryGradient
                : null,
            color: isActive ? null : AppColors.dividerLight,
            shape: BoxShape.circle,
            boxShadow: isActive && isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }

  /// 获取阶段文本
  String _getStageText() {
    switch (currentStage) {
      case 1:
        return '记录中';
      case 2:
        return '分析中';
      case 3:
        return '练习中';
      default:
        return '未开始';
    }
  }

  /// 计算进度条宽度
  double _getProgressWidth() {
    if (currentStage == 0) return 0.0;
    if (currentStage == 1) return 0.0;
    if (currentStage == 2) return 0.5;
    return 1.0; // currentStage == 3
  }
}


