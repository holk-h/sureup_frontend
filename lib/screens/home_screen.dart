import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/cards/daily_task_card.dart';
import '../widgets/cards/weekly_chart_card.dart';
import '../widgets/common/hitokoto_widget.dart';
import '../utils/mock_data.dart';
import '../models/models.dart';

/// 主页 - 今日任务
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用新的数据模型
    final mistakes = MockData.getMistakeRecords();
    final stats = MockData.getStats();
    final weeklyData = MockData.getWeeklyChartData();
    
    final notMasteredCount = mistakes.where((m) => m.masteryStatus != MasteryStatus.mastered).length;
    final masteredCount = mistakes.where((m) => m.masteryStatus == MasteryStatus.mastered).length;
    final progress = mistakes.isEmpty ? 0.0 : masteredCount / mistakes.length;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      child: CustomScrollView(
        slivers: [
          // 主内容
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false, // 不处理底部安全区域，因为自定义导航栏已经处理了
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // 问候语和欢迎语整合
                    _buildHeaderSection(stats),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 今日任务卡片
                    DailyTaskCard(
                      reviewCount: notMasteredCount,
                      practiceCount: mistakes.length,
                      masteredCount: masteredCount,
                      progress: progress,
                      currentStage: _calculateCurrentStage(progress),
                    ),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 过去一周数据图表
                    _buildSectionHeader('📊 过去一周'),
                    const SizedBox(height: AppConstants.spacingM),
                    WeeklyChartCard(
                      weeklyData: weeklyData,
                    ),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 一言
                    const HitokotoWidget(),
                    
                    const SizedBox(height: AppConstants.spacingXXL),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 根据完成进度计算当前所处阶段
  /// 0: 未开始, 1: 错题记录, 2: 分析, 3: 练习
  int _calculateCurrentStage(double progress) {
    if (progress == 0) {
      return 0; // 未开始
    } else if (progress < 0.33) {
      return 1; // 错题记录阶段
    } else if (progress < 0.67) {
      return 2; // 分析阶段
    } else {
      return 3; // 练习阶段
    }
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return '早上好 ☀️';
    } else if (hour >= 12 && hour < 18) {
      return '下午好 ☕️';
    } else if (hour >= 18 && hour < 22) {
      return '晚上好 🌙';
    } else {
      return '夜深了 🌃';
    }
  }
  
  String _getRandomEncouragement() {
    final encouragements = [
      '今天也要加油哦！',
      '每一次努力都不会白费',
      '坚持就是胜利',
      '你已经很棒了！',
      '继续保持，越来越好',
      '相信自己，你可以的',
      '积少成多，日拱一卒',
      '今天的你比昨天更进步',
      '保持热爱，奔赴山海',
      '小步快跑，持续精进',
    ];
    final random = DateTime.now().millisecondsSinceEpoch % encouragements.length;
    return encouragements[random];
  }

  Widget _buildHeaderSection(Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getRandomEncouragement(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                    height: 1.4,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }
}
