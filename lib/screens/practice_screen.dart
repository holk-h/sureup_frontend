import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/cards/practice_mode_card.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/stats_service.dart';
import '../services/mistake_service.dart';
import '../widgets/common/math_markdown_text.dart';
import 'question_generation_history_screen.dart';
import 'mistake_preview_screen.dart';
import 'mistake_selection_screen.dart';

/// 练习页 - 智能练习
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final StatsService _statsService = StatsService();
  final MistakeService _mistakeService = MistakeService();
  
  // 初始显示默认数据，不阻塞UI
  int _continuousDays = 0;
  bool _isInitialized = false;
  List<MistakeRecord> _recentMistakes = [];
  // 缓存题目内容：questionId -> Question
  final Map<String, Question> _questionCache = {};
  bool _isRefreshingMistakes = false; // 刷新状态
  
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
      _mistakeService.initialize(authProvider.authService.client);

      // 并行获取统计数据和最近错题
      final statsFuture = _statsService.getHomeStats(userId);
      final mistakesFuture = _mistakeService.getUserMistakes(userId);
      
      final stats = await statsFuture;
      final allMistakes = await mistakesFuture;
      
      // 获取最近三条错题
      final recentMistakes = allMistakes.take(3).toList();
      
      // 加载对应的题目内容
      final questionIds = recentMistakes
          .where((m) => m.questionId != null)
          .map((m) => m.questionId!)
          .toSet()
          .toList();
      
      if (questionIds.isNotEmpty) {
        final questions = await _mistakeService.getQuestions(questionIds);
        for (final question in questions) {
          _questionCache[question.id] = question;
        }
      }

      // 数据获取成功后，更新UI
      if (mounted) {
        setState(() {
          _continuousDays = stats['continuousDays'] ?? 0;
          _recentMistakes = recentMistakes;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('加载连续练习数据失败: $e');
      // 静默失败，使用默认数据
    }
  }
  
  /// 刷新最近错题记录
  Future<void> _refreshMistakes() async {
    if (_isRefreshingMistakes) return;
    
    setState(() {
      _isRefreshingMistakes = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        return;
      }

      // 确保服务已初始化
      _mistakeService.initialize(authProvider.authService.client);

      // 获取最近错题
      final allMistakes = await _mistakeService.getUserMistakes(userId);
      
      // 获取最近三条错题
      final recentMistakes = allMistakes.take(3).toList();
      
      // 加载对应的题目内容
      final questionIds = recentMistakes
          .where((m) => m.questionId != null)
          .map((m) => m.questionId!)
          .toSet()
          .toList();
      
      if (questionIds.isNotEmpty) {
        final questions = await _mistakeService.getQuestions(questionIds);
        for (final question in questions) {
          _questionCache[question.id] = question;
        }
      }

      // 更新UI
      if (mounted) {
        setState(() {
          _recentMistakes = recentMistakes;
        });
      }
    } catch (e) {
      print('刷新错题记录失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingMistakes = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ), // 弹性滚动和惯性滚动
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
                  // 激励卡片（连续练习）
                  _buildStreakBanner(_continuousDays),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 最近错题记录卡片
                  _buildRecentMistakesCard(),
                  
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
                          onTap: null,
                          isCompact: true,
                          enabled: false,
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
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 变式题生成历史按钮
                  _buildHistoryButton(),
                  
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


  // 选择错题
  void _selectMistake() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
          title: const Text('请先登录'),
          content: const Text('需要登录后才能使用错题练习功能'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
        ),
      );
      return;
    }

    // 直接跳转到错题选择页面
                      Navigator.of(context).push(
                        CupertinoPageRoute(
        builder: (context) => const MistakeSelectionScreen(),
      ),
    );
  }


  Widget _buildHistoryButton() {
    return GestureDetector(
      onTap: _showGenerationHistory,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingL,
          vertical: AppConstants.spacingM,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.clock,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppConstants.spacingS),
            const Text(
              '生成历史',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerationHistory() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('请先登录'),
          content: const Text('需要登录后才能查看生成历史'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const QuestionGenerationHistoryScreen(),
      ),
    );
  }



  /// 构建最近错题记录卡片
  Widget _buildRecentMistakesCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingL,
              right: AppConstants.spacingL,
              top: AppConstants.spacingM,
              bottom: AppConstants.spacingS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text,
                        size: 20,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    const Expanded(
                      child: Text(
                        '最近错题记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // 刷新按钮
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isRefreshingMistakes ? null : _refreshMistakes,
                      child: _isRefreshingMistakes
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CupertinoActivityIndicator(
                                radius: 8,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.refresh,
                              size: 20,
                              color: AppColors.textSecondary,
                            ), minimumSize: Size(0, 0),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingM),
                // 浅分割线
                Container(
                  height: 0.5,
                  color: AppColors.divider,
                ),
              ],
            ),
          ),
          
          // 错题列表或空状态
          if (_recentMistakes.isEmpty)
            // 空状态提示
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spacingL,
                right: AppConstants.spacingL,
                top: AppConstants.spacingM,
                bottom: AppConstants.spacingL,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text,
                        size: 24,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    const Text(
                      '还没记录错题',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '记录错题后，这里会显示最近的错题',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // 错题列表
            ..._recentMistakes.asMap().entries.map((entry) {
              final index = entry.key;
              final mistake = entry.value;
              final isLast = index == _recentMistakes.length - 1;
              
              return GestureDetector(
                onTap: () => _navigateToMistakePreview(mistake),
                child: Container(
                  padding: EdgeInsets.only(
                    left: AppConstants.spacingL,
                    right: AppConstants.spacingL,
                    top: index == 0 ? 0 : AppConstants.spacingM,
                    bottom: AppConstants.spacingM,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(
                              color: AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      // 学科图标
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (mistake.subject?.color ?? AppColors.primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            mistake.subject?.icon ?? '📝',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppConstants.spacingM),
                    // 错题信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (mistake.subject != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mistake.subject!.color
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mistake.subject!.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mistake.subject!.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (mistake.subject != null)
                                const SizedBox(width: 6),
                              Text(
                                _formatTimeAgo(mistake.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 显示题目内容
                          Builder(
                            builder: (context) {
                              final question = mistake.questionId != null
                                  ? _questionCache[mistake.questionId]
                                  : null;
                              
                              if (question != null && question.content.isNotEmpty) {
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 20, // 单行高度（13 * 1.2 ≈ 15.6，留一些余量）
                                  ),
                                  child: ClipRect(
                                    child: MathMarkdownText(
                                      text: question.content,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return const Text(
                                  '错题记录',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// 格式化时间显示
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks周前';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months个月前';
    }
  }

  /// 跳转到错题预览页面
  void _navigateToMistakePreview(MistakeRecord mistake) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      return;
    }

    // 获取所有错题的ID列表，用于预览页面的导航
    final allMistakeIds = _recentMistakes.map((m) => m.id).toList();
    final initialIndex = allMistakeIds.indexOf(mistake.id);

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => MistakePreviewScreen(
          mistakeRecordIds: allMistakeIds,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }
}
