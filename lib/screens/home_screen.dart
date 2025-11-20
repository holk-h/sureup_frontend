import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/cards/daily_task_summary_card.dart';
import '../widgets/cards/weekly_chart_card.dart';
import '../widgets/common/hitokoto_widget.dart';
import '../providers/auth_provider.dart';
import '../services/services.dart';
import '../services/daily_task_service.dart';
import '../models/daily_task.dart';
import 'auth/login_screen.dart';
import 'daily_task_screen.dart';

/// 主页 - 今日任务
class HomeScreen extends StatefulWidget {
  /// 刷新触发器 - 当这个值改变时，触发内容刷新
  final int refreshTrigger;
  
  const HomeScreen({
    super.key,
    this.refreshTrigger = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final StatsService _statsService = StatsService();
  final DailyTaskService _dailyTaskService = DailyTaskService();
  
  late AnimationController _encouragementController;
  late Animation<double> _encouragementAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 初始显示默认数据，不阻塞UI
  Map<String, dynamic> _stats = _getDefaultStats();
  DailyTask? _todayTask;
  bool _isLoadingTask = false;
  int _continuousDays = 0; // 连续完成天数
  
  bool _isLoading = false; // 防止重复加载
  bool _isDataLoaded = false; // 数据是否已加载完成（用于避免图表闪烁）
  bool _isLocaleInitialized = false; // 标记本地化数据是否已初始化

  // 用于触发鼓励语和一言刷新的key
  Key _contentRefreshKey = UniqueKey();
  DateTime? _lastVisibleTime;
  
  // 滚动控制器 - 用于预热滚动
  final ScrollController _scrollController = ScrollController();

  // 图表类型选择
  WeeklyChartType _selectedChartType = WeeklyChartType.mistake;
  
  @override
  bool get wantKeepAlive => true; // 保持页面状态，避免重复构建
  
  // 获取默认统计数据
  static Map<String, dynamic> _getDefaultStats() {
    // 生成7天的默认数据（全为0）
    final now = DateTime.now();
    final List<Map<String, dynamic>> weeklyChartData = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      weeklyChartData.add({
        'day': _getDayName(date.weekday),
        'date': _getDateKey(date),
        'mistakeCount': 0.0,
        'practiceCount': 0.0,
        'isToday': i == 0,
      });
    }
    
    return {
      'totalMistakes': 0,
      'notMasteredCount': 0,
      'masteredCount': 0,
      'progress': 0.0,
      'totalPracticeSessions': 0,
      'completionRate': 0,
      'continuousDays': 0,
      'weekMistakes': 0,
      'weeklyChartData': weeklyChartData,
      'usageDays': 0,
      'userName': '游客',
    };
  }
  
  // 获取日期键（用于分组）格式：YYYY-MM-DD
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  // 获取星期几的中文名称
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '周一';
      case 2: return '周二';
      case 3: return '周三';
      case 4: return '周四';
      case 5: return '周五';
      case 6: return '周六';
      case 7: return '周日';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    
    final startTime = DateTime.now();
    print('🏠 HomeScreen initState 开始');

    // 确保本地化数据已初始化（防御性编程，防止热重载导致 main() 未运行）
    initializeDateFormatting('zh_CN', null).then((_) {
      if (mounted) {
        setState(() {
          _isLocaleInitialized = true;
        });
      }
    });
    
    // 监听应用生命周期变化
    WidgetsBinding.instance.addObserver(this);
    
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
    
    // 延迟加载数据和动画，优先渲染UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initTime = DateTime.now().difference(startTime).inMilliseconds;
      print('🏠 HomeScreen 首次渲染完成，耗时: ${initTime}ms');
      
      _lastVisibleTime = DateTime.now();
      
      // 加载数据
      _loadData();
      _loadTodayTask();
      
      // 延迟启动动画，避免和数据加载冲突
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _encouragementController.forward();
        }
      });
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用回到前台时，检查是否需要刷新内容
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshContent();
    }
  }
  
  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查刷新触发器是否改变
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      print('🔄 收到刷新触发器: ${widget.refreshTrigger}');
      _forceRefreshContent();
    }
  }
  
  /// 强制刷新内容（忽略时间限制）
  void _forceRefreshContent() {
    print('🔄 强制刷新主页内容（数据、鼓励语和一言）');
    setState(() {
      _contentRefreshKey = UniqueKey(); // 触发鼓励语和一言的重建
      _lastVisibleTime = DateTime.now();
      _isDataLoaded = false; // 重置数据加载状态，避免图表闪烁
    });
    
    // 后台刷新统计数据
    _loadData();
    
    // 重新播放动画
    _encouragementController.reset();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _encouragementController.forward();
      }
    });
  }
  
  /// 检查并刷新内容（鼓励语和一言）
  void _checkAndRefreshContent() {
    // 如果距离上次显示超过5秒，就刷新内容
    if (_lastVisibleTime == null || 
        DateTime.now().difference(_lastVisibleTime!) > const Duration(seconds: 5)) {
      print('🔄 刷新主页内容（鼓励语和一言）');
      setState(() {
        _contentRefreshKey = UniqueKey(); // 触发鼓励语和一言的重建
        _lastVisibleTime = DateTime.now();
      });
      
      // 重新播放动画
      _encouragementController.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _encouragementController.forward();
        }
      });
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _encouragementController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载今日任务
  Future<void> _loadTodayTask() async {
    if (_isLoadingTask) return;

    setState(() => _isLoadingTask = true);

    try {
      final authService = AuthService();
      if (authService.userId == null) {
        if (mounted) {
          setState(() {
            _todayTask = null;
            _isLoadingTask = false;
          });
        }
        return;
      }

      _dailyTaskService.initialize(authService.client);
      final task = await _dailyTaskService.getTodayTask();

      // 计算连续天数
      final continuousDays = await _calculateContinuousDays();

      if (mounted) {
        setState(() {
          _todayTask = task;
          _continuousDays = continuousDays;
          _isLoadingTask = false;
        });
      }
    } catch (e) {
      print('加载今日任务失败: $e');
      if (mounted) {
        setState(() {
          _todayTask = null;
          _isLoadingTask = false;
        });
      }
    }
  }

  /// 计算连续完成天数
  Future<int> _calculateContinuousDays() async {
    try {
      final authService = AuthService();
      if (authService.userId == null) return 0;

      // 获取最近的任务历史
      final recentTasks = await _dailyTaskService.getRecentTasks(limit: 30);
      
      if (recentTasks.isEmpty) return 0;

      // 从今天开始往前数，计算连续完成的天数
      int continuousDays = 0;
      final now = DateTime.now();
      
      // 按日期倒序排列
      final sortedTasks = recentTasks.toList()
        ..sort((a, b) => b.taskDate.compareTo(a.taskDate));
      
      // 从最近的日期开始检查
      DateTime checkDate = DateTime(now.year, now.month, now.day);
      
      for (int i = 0; i < sortedTasks.length; i++) {
        final task = sortedTasks[i];
        final taskDay = DateTime(
          task.taskDate.year,
          task.taskDate.month,
          task.taskDate.day,
        );
        
        // 如果任务日期等于检查日期且已完成
        if (taskDay.isAtSameMomentAs(checkDate) && task.isCompleted) {
          continuousDays++;
          // 检查前一天
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else if (taskDay.isBefore(checkDate)) {
          // 如果任务日期早于检查日期，说明中断了
          break;
        }
      }
      
      return continuousDays;
    } catch (e) {
      print('计算连续天数失败: $e');
      return 0;
    }
  }

  /// 跳转到每日任务页面
  void _navigateToDailyTask() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const DailyTaskScreen(),
      ),
    ).then((_) {
      // 返回后刷新任务状态
      _loadTodayTask();
    });
  }

  /// 异步刷新数据（包括图表数据）
  Future<void> _loadData() async {
    // 防止重复加载
    if (_isLoading) {
      print('⚠️ 数据正在加载中，跳过重复请求');
      return;
    }
    
    _isLoading = true;
    final loadStartTime = DateTime.now();
    print('📊 开始加载主页数据...');
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      // 如果未登录，显示默认数据
      if (userId == null) {
        print('👤 未登录，显示默认数据');
        if (mounted) {
          setState(() {
            _stats = _getDefaultStats();
            _isDataLoaded = true; // 未登录也标记为已加载，显示0数据图表
          });
        }
        return;
      }

      // 初始化服务（已经预初始化了LocalStorage，这里很快）
      await _statsService.initialize(authProvider.authService.client);

      // 获取统计数据（优先从本地读取，包括最新的图表数据）
      final stats = await _statsService.getHomeStats(userId);
      
      final loadTime = DateTime.now().difference(loadStartTime).inMilliseconds;
      print('✅ 数据加载完成，耗时: ${loadTime}ms');

      // 数据获取成功后，更新UI
      if (mounted) {
        setState(() {
          _stats = stats;
          _isDataLoaded = true; // 标记数据已加载
        });
        
        final updateTime = DateTime.now().difference(loadStartTime).inMilliseconds;
        print('🎨 UI 更新完成，总耗时: ${updateTime}ms');
      }
    } catch (e) {
      print('❌ 加载数据失败: $e');
      // 静默失败，使用默认数据
      if (mounted) {
        setState(() {
          _isDataLoaded = true; // 即使失败也标记为已加载，避免一直显示加载中
        });
      }
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 无论是否登录，都显示内容（未登录时显示0）
        return _buildContent(authProvider);
      },
    );
  }

  /// 构建主要内容
  Widget _buildContent(AuthProvider authProvider) {
    final userName = authProvider.userProfile?.name ?? _stats['userName'] ?? '游客';
    
    // 安全获取图表数据
    final weeklyDataRaw = _stats['weeklyChartData'];
    final weeklyData = (weeklyDataRaw is List)
        ? weeklyDataRaw.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000), // 透明，显示下层渐变
        child: CustomScrollView(
          controller: _scrollController,
          // 滚动性能优化
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          // 启用缓存扩展，减少重建
          cacheExtent: 500,
          slivers: [
            // 顶部安全区域
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingM,
                    AppConstants.spacingS,
                    AppConstants.spacingM,
                    AppConstants.spacingM,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 头部区域（加大版）
                      const SizedBox(height: 8),
                      _buildModernHeader(userName),
                      
                      const SizedBox(height: AppConstants.spacingM), // 下边距小点
                      
                      // 2. 每日任务卡片 (Hero Section) - 直接上移，移除统计卡片
                      DailyTaskSummaryCard(
                        task: _todayTask,
                        isLoading: _isLoadingTask,
                        continuousDays: _continuousDays,
                        onTap: authProvider.isLoggedIn 
                            ? _navigateToDailyTask 
                            : _navigateToLogin,
                      ),
                      
                      const SizedBox(height: AppConstants.spacingL),
                      
                      // 3. 学习分析图表 (带切换)
                      _buildAnalysisSection(weeklyData),
                      
                      const SizedBox(height: AppConstants.spacingM),
                      
                      // 4. 一言（使用 key 触发重建）
                      HitokotoWidget(key: _contentRefreshKey),
                      
                      const SizedBox(height: AppConstants.spacingXXL),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  
  // 鼓励语列表
  static const _encouragements = [
    '冲鸭！今天也要元气满满', '每一道题都是在变强', '你超棒的，继续保持',
    '学习使我快乐！', '又进步了一点点呢', '做自己的学霸',
    '慢慢来，比较快', '今天的我比昨天更强', '热爱可抵岁月漫长',
    '今天也要加油呀～', '小步快跑，稳步前进', '相信自己，你可以的'
  ];

  String _getRandomEncouragement() {
    final seed = DateTime.now().millisecondsSinceEpoch + _contentRefreshKey.hashCode;
    final random = seed % _encouragements.length;
    return _encouragements[random];
  }

  // 1. 现代头部设计（加大版）
  Widget _buildModernHeader(String userName) {
    final greetingInfo = _getGreetingInfo();
    final now = DateTime.now();
    
    // 防御性编程：如果本地化数据未初始化，使用简单的日期格式
    String dateStr;
    if (_isLocaleInitialized) {
      try {
        dateStr = DateFormat('MM月dd日 EEEE', 'zh_CN').format(now);
      } catch (e) {
        // 降级处理
        dateStr = '${now.month}月${now.day}日';
      }
    } else {
      // 降级处理
      dateStr = '${now.month}月${now.day}日';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 15, // 加大字号
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // 问候语和用户名（合并，不换行）
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${greetingInfo.emoji} ',
                  style: const TextStyle(
                    fontSize: 38, // 增大字号
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PingFang SC',
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: '${greetingInfo.greeting}，',
                  style: const TextStyle(
                    fontSize: 38, // 增大字号
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'PingFang SC',
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: userName,
                  style: const TextStyle(
                    fontSize: 38, // 增大字号
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'PingFang SC',
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12), // 上边距稍微大点
          // 鼓励语
          FadeTransition(
            opacity: _encouragementAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Row(
                children: [
                  const SizedBox(width: 8), // 左边距
                  Container(
                    width: 3, // 粗一点
                    height: 18, // 高一点
                    decoration: BoxDecoration(
                      color: AppColors.primary, // 绿色
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getRandomEncouragement(),
                      style: const TextStyle(
                        fontSize: 18, // 增大字号
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // 4. 分析图表部分
  Widget _buildAnalysisSection(List<Map<String, dynamic>> weeklyData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '学习分析',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            // 自定义分段控件
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0).withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildSegmentBtn('错题', WeeklyChartType.mistake),
                  _buildSegmentBtn('复习', WeeklyChartType.practice),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isDataLoaded)
          WeeklyChartCard(
            weeklyData: weeklyData,
            type: _selectedChartType,
          )
        else
          _buildChartPlaceholder(),
      ],
    );
  }
  
  Widget _buildSegmentBtn(String label, WeeklyChartType type) {
    final isSelected = _selectedChartType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  /// 图表加载占位符
  Widget _buildChartPlaceholder() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: const Center(
        child: CupertinoActivityIndicator(),
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
