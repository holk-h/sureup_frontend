import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';

/// 练习完成页面
class PracticeResultScreen extends StatelessWidget {
  final PracticeSession session;
  final List<Question> questions;

  const PracticeResultScreen({
    super.key,
    required this.session,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = session.accuracy;
    final correctCount = session.correctCount;
    final totalCount = session.totalCount;
    final percentage = (accuracy * 100).toInt();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  children: [
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 庆祝图标
                    _buildCelebrationIcon(accuracy),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 标题
                    const Text(
                      '🎉 练习完成！',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 练习类型
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppConstants.spacingXL),
                    
                    // 成绩卡片
                    _buildScoreCard(correctCount, totalCount, percentage),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // AI 鼓励语
                    if (session.aiEncouragement != null)
                      _buildEncouragementCard(session.aiEncouragement!),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 知识点掌握度变化（仅知识点练习显示）
                    if (session.type == PracticeType.knowledgePointDrill)
                      _buildMasteryProgress(),
                  ],
                ),
              ),
            ),
            
            // 底部按钮
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationIcon(double accuracy) {
    String emoji;
    Color color;
    
    if (accuracy >= 0.9) {
      emoji = '🌟';
      color = AppColors.warning;
    } else if (accuracy >= 0.7) {
      emoji = '🎯';
      color = AppColors.primary;
    } else if (accuracy >= 0.5) {
      emoji = '💪';
      color = AppColors.secondary;
    } else {
      emoji = '📚';
      color = AppColors.accent;
    }
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 56),
        ),
      ),
    );
  }

  Widget _buildScoreCard(int correct, int total, int percentage) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '正确率',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.cardBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 大号正确率
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cardBackground,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cardBackground,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 详细分数
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '答对 $correct / $total 题',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.cardBackground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragementCard(String encouragement) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.heart_fill,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Text(
              encouragement,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryProgress() {
    // Mock数据：知识点掌握度提升
    const oldMastery = 60;
    const newMastery = 75;
    const improvement = newMastery - oldMastery;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '知识点掌握度',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: AppConstants.spacingM),
          
          // 进度条
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: newMastery / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingS),
          
          // 数值变化
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$oldMastery% → $newMastery%',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⬆️ +$improvement%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 返回按钮
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                onPressed: () {
                  // 返回练习页
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: AppConstants.spacingM),
            
            // 继续练习按钮
            Expanded(
              flex: 2,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                onPressed: () {
                  // 返回练习页（可以触发生成新的练习）
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  '继续练习',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cardBackground,
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

