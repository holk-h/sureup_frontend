import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/cards/daily_review_card.dart';
import '../widgets/cards/practice_mode_card.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/stats_service.dart';

/// 练习页 - 智能练习
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final StatsService _statsService = StatsService();
  
  // 初始显示默认数据，不阻塞UI
  int _continuousDays = 0;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // 异步加载数据
    _loadData();
  }
  
  /// 加载连续练习数据
  Future<void> _loadData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      // 如果未登录，显示默认数据
      if (userId == null) {
        if (mounted && !_isInitialized) {
          setState(() {
            _continuousDays = 0;
            _isInitialized = true;
          });
        }
        return;
      }

      // 初始化服务
      await _statsService.initialize(authProvider.authService.client);

      // 获取统计数据
      final stats = await _statsService.getHomeStats(userId);

      // 数据获取成功后，更新UI
      if (mounted) {
        setState(() {
          _continuousDays = stats['continuousDays'] ?? 0;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('加载连续练习数据失败: $e');
      // 静默失败，使用默认数据
    }
  }
  
  @override
  Widget build(BuildContext context) {
    
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      child: CustomScrollView(
        slivers: [
          // Large Title导航栏
          const CupertinoSliverNavigationBar(
            backgroundColor: Color(0x00000000), // 透明背景
            border: null,
            largeTitle: Text('练习 ✏️'),
            heroTag: 'practice_nav_bar',
          ),
          
          // 主内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 智能复盘卡片
                  DailyReviewCard(
                    questionCount: 8,
                    onTap: _startDailyReview,
                  ),
                  
                  const SizedBox(height: AppConstants.spacingM),
                  
                  // 激励卡片（连续练习）
                  _buildStreakBanner(_continuousDays),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 专项练习标题
                  _buildSectionHeader('🎯 专项练习'),
                  
                  const SizedBox(height: AppConstants.spacingM),
                  
                  // 专项练习卡片 - 两列布局
                  Row(
                    children: [
                      Expanded(
                        child: PracticeModeCard(
                          title: '按知识点',
                          description: '选择知识点专项突破',
                          icon: CupertinoIcons.square_grid_2x2,
                          color: AppColors.primary,
                          onTap: _selectKnowledgePoint,
                          isCompact: true,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: PracticeModeCard(
                          title: '按错题',
                          description: '针对错题变式练习',
                          icon: CupertinoIcons.doc_text,
                          color: AppColors.warning,
                          onTap: _selectMistake,
                          isCompact: true,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.spacingXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner(int days) {
    // 根据天数获取不同的样式和内容
    final streakInfo = _getStreakInfo(days);
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            streakInfo.color.withOpacity(0.15),
            streakInfo.color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: streakInfo.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: streakInfo.color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  streakInfo.color,
                  streakInfo.color.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: streakInfo.color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                streakInfo.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '连续练习',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            streakInfo.color,
                            streakInfo.color.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: streakInfo.color.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        days == 0 ? '第 0 天' : '第 $days 天',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.cardBackground,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  streakInfo.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 根据连续天数获取对应的样式和内容
  ({String emoji, Color color, String message}) _getStreakInfo(int days) {
    if (days == 0) {
      return (
        emoji: '💪',
        color: AppColors.primary,
        message: '今天就开始第一天吧！',
      );
    } else if (days == 1) {
      return (
        emoji: '🌱',
        color: AppColors.success,
        message: '很棒的开始！明天继续～',
      );
    } else if (days == 2) {
      return (
        emoji: '✨',
        color: AppColors.primary,
        message: '不错！再坚持一天就三天啦～',
      );
    } else if (days >= 3 && days < 7) {
      return (
        emoji: '🔥',
        color: AppColors.warning,
        message: '坚持得很好！继续保持～',
      );
    } else if (days >= 7 && days < 14) {
      return (
        emoji: '⭐️',
        color: const Color(0xFFFFB800),
        message: '太棒了！已经一周了，你真厉害！',
      );
    } else if (days >= 14 && days < 30) {
      return (
        emoji: '🏆',
        color: const Color(0xFFFF6B35),
        message: '两周了！你的毅力令人钦佩！',
      );
    } else if (days >= 30 && days < 60) {
      return (
        emoji: '👑',
        color: const Color(0xFF9B59B6),
        message: '满月啦！你已经养成好习惯了！',
      );
    } else if (days >= 60 && days < 100) {
      return (
        emoji: '💎',
        color: const Color(0xFF3498DB),
        message: '两个月！你就是坚持的典范！',
      );
    } else {
      return (
        emoji: '🌟',
        color: const Color(0xFFE74C3C),
        message: '$days天！你是真正的学习大师！',
      );
    }
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

  // 开始智能复盘
  void _startDailyReview() {
    // TODO: 接入真实的每日复盘数据
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('功能开发中'),
        content: const Text('每日智能复盘功能即将上线'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // 选择知识点
  void _selectKnowledgePoint() {
    _showSubjectPicker();
  }

  void _showSubjectPicker() {
    // TODO: 接入真实的知识点数据
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('功能开发中'),
        content: const Text('知识点练习功能即将上线'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // 下面的方法暂时未使用，保留以供将来实现
  Widget _buildSubjectPicker(List<Subject> subjects) {
    return Container(
      height: 300,
      color: AppColors.cardBackground,
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  '选择学科',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 60), // 占位
              ],
            ),
          ),
          
          // 学科列表
          Expanded(
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final subjectPoints = <KnowledgePoint>[];  // TODO: 获取真实数据
                
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingM,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showKnowledgePointPicker(subject, subjectPoints);
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: subject.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          subject.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${subjectPoints.length}个知识点',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.right_chevron,
                        color: AppColors.textTertiary,
                        size: 16,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showKnowledgePointPicker(Subject subject, List<KnowledgePoint> knowledgePoints) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => _buildKnowledgePointPicker(subject, knowledgePoints),
    );
  }

  Widget _buildKnowledgePointPicker(Subject subject, List<KnowledgePoint> knowledgePoints) {
    return Container(
      height: 400,
      color: AppColors.cardBackground,
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  '${subject.displayName} - 选择知识点',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 60), // 占位
              ],
            ),
          ),
          
          // 知识点列表
          Expanded(
            child: ListView.builder(
              itemCount: knowledgePoints.length,
              itemBuilder: (context, index) {
                final point = knowledgePoints[index];
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingM,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _startKnowledgePointPractice(point);
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: subject.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.book,
                          size: 20,
                          color: subject.color,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              point.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${point.mistakeCount}道错题',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 掌握度
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getMasteryColor(point.masteryLevel).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${point.masteryLevel}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _getMasteryColor(point.masteryLevel),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 选择错题
  void _selectMistake() {
    // TODO: 接入真实的错题数据
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('功能开发中'),
        content: const Text('错题专项练习功能即将上线'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakePicker(List<MistakeRecord> mistakes) {
    return Container(
      height: 500,
      color: AppColors.cardBackground,
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  '选择错题',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 60), // 占位
              ],
            ),
          ),
          
          // 错题列表
          Expanded(
            child: ListView.builder(
              itemCount: mistakes.length,
              itemBuilder: (context, index) {
                final mistake = mistakes[index];
                final daysAgo = DateTime.now().difference(mistake.createdAt).inDays;
                
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingM,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _startMistakePractice(mistake);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark_circle,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mistake.subject?.displayName ?? "错题"}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (mistake.subject != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      mistake.subject!.displayName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (mistake.subject != null)
                                  const SizedBox(width: 8),
                                Text(
                                  daysAgo == 0 ? '今天' : '$daysAgo天前',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 开始知识点练习
  void _startKnowledgePointPractice(KnowledgePoint point) {
    // TODO: 接入真实的知识点练习数据
  }

  // 开始错题练习
  void _startMistakePractice(MistakeRecord mistake) {
    // TODO: 接入真实的错题练习数据
  }

  void _showEmptyMistakesDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('暂无错题'),
        content: const Text('所有错题都已掌握，太棒了！\n可以先记录一些新错题～'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好的'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.primary;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}
