import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/cards/daily_task_card.dart';
import '../widgets/cards/weekly_chart_card.dart';
import '../widgets/common/hitokoto_widget.dart';
import '../providers/auth_provider.dart';
import '../services/services.dart';
import 'auth/login_screen.dart';

/// 主页 - 今日任务
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  
  late AnimationController _encouragementController;
  late Animation<double> _encouragementAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 初始显示默认数据，不阻塞UI
  Map<String, dynamic> _stats = _getDefaultStats();
  
  bool _isInitialized = false;
  
  // 获取默认统计数据
  static Map<String, dynamic> _getDefaultStats() => {
    'totalMistakes': 0,
    'notMasteredCount': 0,
    'masteredCount': 0,
    'progress': 0.0,
    'totalPracticeSessions': 0,
    'completionRate': 0,
    'continuousDays': 0,
    'weekMistakes': 0,
    'weeklyChartData': <Map<String, dynamic>>[],
    'usageDays': 0,
    'userName': '游客',
  };

  @override
  void initState() {
    super.initState();
    
    // 初始化鼓励语动画（缓存 Animation 对象）
    _encouragementController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    final curvedAnimation = CurvedAnimation(
      parent: _encouragementController,
      curve: Curves.easeOut,
    );
    
    _encouragementAnimation = curvedAnimation;
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(curvedAnimation);
    
    // 异步刷新数据
    _loadData();
    
    // 启动鼓励语动画
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _encouragementController.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _encouragementController.dispose();
    super.dispose();
  }

  /// 异步刷新数据（包括图表数据）
  Future<void> _loadData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      // 如果未登录，显示默认数据
      if (userId == null) {
        if (mounted && !_isInitialized) {
          setState(() {
            _stats = _getDefaultStats();
            _isInitialized = true;
          });
        }
        return;
      }

      // 初始化服务
      await _statsService.initialize(authProvider.authService.client);

      // 检查并重置本周统计（如果需要）
      await _statsService.resetWeeklyStatsIfNeeded(userId);

      // 获取统计数据（优先从本地读取，包括最新的图表数据）
      final stats = await _statsService.getHomeStats(userId);

      // 数据获取成功后，更新UI
      if (mounted) {
        setState(() {
          _stats = stats;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('加载数据失败: $e');
      // 静默失败，使用默认数据
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 无论是否登录，都显示内容（未登录时显示0）
        return _buildContent(authProvider);
      },
    );
  }

  /// 构建主要内容
  Widget _buildContent(AuthProvider authProvider) {
    final notMasteredCount = _stats['notMasteredCount'] ?? 0;
    final masteredCount = _stats['masteredCount'] ?? 0;
    final progress = _stats['progress'] ?? 0.0;
    final userName = authProvider.userProfile?.name ?? _stats['userName'] ?? '游客';
    
    // 安全获取图表数据
    final weeklyDataRaw = _stats['weeklyChartData'];
    final weeklyData = (weeklyDataRaw is List)
        ? weeklyDataRaw.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

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
                    _buildHeaderSection(userName),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 今日任务卡片
                    DailyTaskCard(
                      reviewCount: notMasteredCount,
                      practiceCount: _stats['totalMistakes'] ?? 0,
                      masteredCount: masteredCount,
                      progress: progress,
                      currentStage: _calculateCurrentStage(progress),
                      onTap: authProvider.isLoggedIn ? null : _navigateToLogin,
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
  
  // 获取问候语和emoji（合并为一个方法减少重复计算）
  ({String greeting, String emoji}) _getGreetingInfo() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 5) {
      return (greeting: '早睡哦', emoji: '🌌');
    } else if (hour >= 5 && hour < 8) {
      return (greeting: '凌晨好', emoji: '🌅');
    } else if (hour >= 8 && hour < 11) {
      return (greeting: '早上好', emoji: '☀️');
    } else if (hour >= 11 && hour < 13) {
      return (greeting: '上午好', emoji: '☀️');
    } else if (hour >= 13 && hour < 17) {
      return (greeting: '下午好', emoji: '☕️');
    } else if (hour >= 17 && hour < 18) {
      return (greeting: '傍晚好', emoji: '🌇');
    } else if (hour >= 18 && hour < 22) {
      return (greeting: '晚上好', emoji: '🌙');
    } else {
      return (greeting: '夜深了', emoji: '🌃');
    }
  }
  
  // 鼓励语列表（静态常量避免重复创建）
  static const _encouragements = [
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

  String _getRandomEncouragement() {
    final random = DateTime.now().millisecondsSinceEpoch % _encouragements.length;
    return _encouragements[random];
  }

  Widget _buildHeaderSection(String userName) {
    final continuousDays = _stats['continuousDays'] ?? 0;
    final greetingInfo = _getGreetingInfo();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greetingInfo.greeting}，$userName ${greetingInfo.emoji}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _encouragementAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Row(
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
                      continuousDays > 0 
                        ? '已连续学习 $continuousDays 天，${_getRandomEncouragement()}'
                        : _getRandomEncouragement(),
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
            ),
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

  /// 导航到登录页面
  void _navigateToLogin() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
