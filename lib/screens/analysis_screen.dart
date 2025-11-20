import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/knowledge_service.dart';
import '../services/mistake_service.dart';
import '../services/auth_service.dart';
import 'subject_detail_screen.dart';
import 'ai_analysis_review_screen.dart';
import 'auth/login_screen.dart';
import 'note_aggregation_screen.dart';
import '../widgets/analysis/knowledge_galaxy_view.dart';

/// 分析页 - 错题分析和知识点地图
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with WidgetsBindingObserver {
  final _knowledgeService = KnowledgeService();
  final _mistakeService = MistakeService();
  
  List<KnowledgePoint>? _allPoints;
  Map<String, int>? _accumulationStats;
  bool _isLoading = true;
  String? _error;
  bool _isFirstLoad = true;
  DateTime? _lastRefreshTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台返回前台时刷新数据
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshIfNeeded();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面首次加载后，每次变为可见时刷新数据
    if (!_isFirstLoad && mounted) {
      // 延迟一帧执行，避免在 build 过程中调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshIfNeeded();
        }
      });
    }
    _isFirstLoad = false;
  }
  
  /// 根据上次刷新时间判断是否需要刷新（避免频繁刷新）
  void _refreshIfNeeded() {
    final now = DateTime.now();
    // 如果距离上次刷新超过5秒，则刷新数据
    if (_lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds > 5) {
      _loadData();
    }
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authService = AuthService();
      final userId = authService.userId;
      
      // 如果未登录，显示空数据（不报错）
      if (userId == null) {
        setState(() {
          _allPoints = [];
          _accumulationStats = {
            'daysSinceLastReview': 0,
            'accumulatedMistakes': 0,
          };
          _isLoading = false;
          _lastRefreshTime = DateTime.now();
        });
        return;
      }
      
      // 初始化服务（使用相同的client）
      final client = authService.client;
      _knowledgeService.initialize(client);
      _mistakeService.initialize(client);
      
      // 并发加载数据
      final results = await Future.wait([
        _knowledgeService.getUserKnowledgePoints(userId),
        _mistakeService.getAccumulationStats(userId),
      ]);
      
      setState(() {
        _allPoints = results[0] as List<KnowledgePoint>;
        _accumulationStats = results[1] as Map<String, int>;
        _isLoading = false;
        _lastRefreshTime = DateTime.now();
      });
    } catch (e) {
      print('加载数据失败: $e');
      setState(() {
        _isLoading = false;
        _error = '加载数据失败：$e';
        _lastRefreshTime = DateTime.now();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 获取用户关注的学科
    final authProvider = Provider.of<AuthProvider>(context);
    final focusSubjects = authProvider.userProfile?.focusSubjects ?? [];
    
    // 如果正在加载，显示加载指示器
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    // 如果有错误，显示错误信息
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    
    // 如果没有数据，使用空列表
    final allPoints = _allPoints ?? [];
    
    // 按学科分组
    final allSubjectGroups = _knowledgeService.groupBySubject(allPoints);
    
    // 为所有关注的学科创建条目（即使没有数据）
    final subjectGroups = <String, List<KnowledgePoint>>{};
    for (final subjectId in focusSubjects) {
      // 将英文学科ID转换为中文显示名称
      final subject = Subject.fromString(subjectId);
      if (subject != null) {
        final displayName = subject.displayName;
        subjectGroups[displayName] = allSubjectGroups[displayName] ?? [];
      }
    }
    
    // 计算整体统计数据（只计算关注学科的）
    final filteredPoints = _knowledgeService.getFilteredPoints(allPoints, focusSubjects);
    final stats = _knowledgeService.calculateStats(filteredPoints);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      child: CustomScrollView(
        slivers: [
          // Large Title 导航栏
          CupertinoSliverNavigationBar(
            backgroundColor: const Color(0x00000000), // 透明背景
            border: null,
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              top: 0,
            ),
            largeTitle: const Text('分析 🔍'),
            heroTag: 'analysis_nav_bar',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadData,
              child: const Icon(
                CupertinoIcons.refresh,
                size: 22,
              ),
            ),
          ),
          
          // 主内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI 每日错题分析卡片
                  _buildDailyAnalysisCard(),
                  
                  const SizedBox(height: AppConstants.spacingM),
                  
                  // 笔记汇总卡片
                  _buildNoteAggregationCard(),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 学科分类标题
                  _buildSubjectHeader(stats),
                  
                  const SizedBox(height: AppConstants.spacingM),
                  
                  // 整体统计卡片
                  _buildStatsCard(stats),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 知识点全景图
                  if (filteredPoints.isNotEmpty) ...[
                    KnowledgeGalaxyView(
                      points: filteredPoints,
                      onPointTap: (point) {
                        // 点击知识点跳转到对应学科详情
                        _handleSubjectCardTap(point.subject.displayName, [point]);
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                  ],
                  
                  // 学科列表
                  if (focusSubjects.isEmpty)
                    _buildNoFocusSubjectsState()
                  else
                    _buildSubjectGrid(subjectGroups),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 加载状态
  Widget _buildLoadingState() {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            backgroundColor: Color(0x00000000),
            border: null,
            largeTitle: Text('分析 🔍'),
            heroTag: 'analysis_nav_bar',
          ),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(radius: 16),
                  const SizedBox(height: 16),
                  Text(
                    '正在加载数据...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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
  
  // 错误状态
  Widget _buildErrorState(String error) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: const Color(0x00000000),
            border: null,
            largeTitle: const Text('分析 🔍'),
            heroTag: 'analysis_nav_bar',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadData,
              child: const Icon(
                CupertinoIcons.refresh,
                size: 22,
              ),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      onPressed: _loadData,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 没有关注学科的空状态
  Widget _buildNoFocusSubjectsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                CupertinoIcons.book,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '关注学科暂无数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '你关注的学科暂时还没有错题数据\n去"我的"页面可以调整关注学科',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 笔记汇总卡片
  Widget _buildNoteAggregationCard() {
    return GestureDetector(
      onTap: () {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isLoggedIn) {
          _navigateToLogin();
          return;
        }
        
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const NoteAggregationScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.12),
              AppColors.primary.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.doc_text,
                color: AppColors.cardBackground,
                size: 22,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '笔记汇总',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '查看和导出所有错题笔记',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AI 积累错题分析卡片
  Widget _buildDailyAnalysisCard() {
    // 从真实数据获取统计
    final daysSinceLastReview = _accumulationStats?['daysSinceLastReview'] ?? 0;
    final accumulatedMistakes = _accumulationStats?['accumulatedMistakes'] ?? 0;
    
    // 只有满足以下条件之一时才显示引导提示：
    // 1. 距离上次复盘超过2天
    // 2. 积累的错题超过30道
    final shouldShowPrompt = daysSinceLastReview > 2 || accumulatedMistakes > 30;
    
    return GestureDetector(
      onTap: () => _handleAnalysisCardTap(accumulatedMistakes, daysSinceLastReview),
      child: Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.12),
            AppColors.primary.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: AppColors.cardBackground,
                  size: 22,
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
                          '积累错题分析',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$accumulatedMistakes道',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'AI分析错题，提供个性化建议',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          
          // 温柔的引导提示区域 - 只有满足条件时才显示
          if (shouldShowPrompt) ...[
            const SizedBox(height: AppConstants.spacingM),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 左侧图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.warning.withOpacity(0.2),
                          AppColors.warning.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      CupertinoIcons.time,
                      color: AppColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  // 右侧文字
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 第一行：统计信息
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: '距上次复盘已经 '),
                              TextSpan(
                                text: '$daysSinceLastReview',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const TextSpan(text: ' 天啦，积累了 '),
                              TextSpan(
                                text: '$accumulatedMistakes',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const TextSpan(text: ' 道错题'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 第二行：温柔引导
                        Row(
                          children: [
                            const Text(
                              '要不要去阶段性分析一下？',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.hand_point_right,
                              size: 14,
                              color: AppColors.textTertiary.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  // 学科网格布局
  Widget _buildSubjectGrid(Map<String, List<KnowledgePoint>> subjectGroups) {
    final subjects = subjectGroups.entries.toList();
    
    return Column(
      children: [
        for (int i = 0; i < subjects.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < subjects.length ? AppConstants.spacingM : 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubjectCard(
                    subjects[i].key,
                    subjects[i].value,
                    isCompact: true,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                if (i + 1 < subjects.length)
                  Expanded(
                    child: _buildSubjectCard(
                      subjects[i + 1].key,
                      subjects[i + 1].value,
                      isCompact: true,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  // 学科分类标题
  Widget _buildSubjectHeader(Map<String, dynamic> stats) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            '📚 学科分类',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // 整体统计卡片
  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '总知识点',
                  '${stats['totalPoints']}',
                  CupertinoIcons.square_grid_2x2,
                  AppColors.accent,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              Expanded(
                child: _buildStatItem(
                  '薄弱点',
                  '${stats['weakPoints']}',
                  CupertinoIcons.exclamationmark_triangle,
                  AppColors.warning,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              Expanded(
                child: _buildStatItem(
                  '总错题',
                  '${stats['totalMistakes']}',
                  CupertinoIcons.doc_text,
                  AppColors.mistake,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: _getOverallMasteryColor(stats['avgMastery']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.chart_pie,
                  size: 20,
                  color: _getOverallMasteryColor(stats['avgMastery']),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  '整体掌握度',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${stats['avgMastery']}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _getOverallMasteryColor(stats['avgMastery']),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  // 学科卡片
  Widget _buildSubjectCard(String subjectName, List<KnowledgePoint> points, {bool isCompact = false}) {
    // 从中文名称获取 Subject 对象
    final subject = Subject.fromString(subjectName);
    final subjectColor = subject?.color ?? AppColors.subjectDefault;
    final subjectIcon = subject?.icon ?? '📚';
    
    // 计算学科统计数据（用于显示错题数和薄弱点数）
    final subjectStats = _knowledgeService.calculateSubjectStats(points);
    
    // 优先从 UserProfile 的 subjectMasteryScores 获取后端聚合的掌握度
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subjectMasteryScores = authProvider.userProfile?.subjectMasteryScores;
    
    // 尝试从后端同步的数据获取掌握度
    // 需要同时尝试中文 key 和英文 key（因为后端可能用的是枚举 name）
    int avgMastery = 0;
    if (subjectMasteryScores != null) {
      // 先尝试中文 key
      if (subjectMasteryScores.containsKey(subjectName)) {
        avgMastery = subjectMasteryScores[subjectName]!;
        print('📊 [$subjectName] 使用后端掌握度(中文key): $avgMastery');
      } 
      // 再尝试英文 key（通过 Subject 枚举的 name）
      else {
        final subjectEnumName = subject?.name;
        if (subjectEnumName != null && subjectMasteryScores.containsKey(subjectEnumName)) {
          avgMastery = subjectMasteryScores[subjectEnumName]!;
          print('📊 [$subjectName] 使用后端掌握度(英文key): $avgMastery');
        } else {
          // 如果后端数据不存在，回退到前端计算（兼容性）
          avgMastery = subjectStats['avgMastery'] as int;
          print('📊 [$subjectName] 使用前端计算掌握度: $avgMastery (知识点数: ${points.length})');
        }
      }
    } else {
      avgMastery = subjectStats['avgMastery'] as int;
      print('📊 [$subjectName] 使用前端计算掌握度(无后端数据): $avgMastery');
    }
    
    final masteryColor = _getMasteryColor(avgMastery);
    
    return GestureDetector(
      onTap: () => _handleSubjectCardTap(subjectName, points),
      child: Container(
        margin: isCompact ? EdgeInsets.zero : const EdgeInsets.only(bottom: AppConstants.spacingM),
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
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? AppConstants.spacingM : AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // 第一行：学科图标和名称
                    if (isCompact)
                      // 紧凑布局：优化的横向排列
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: subjectColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                ),
                                child: Center(
                                  child: Text(
                                    subjectIcon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subjectName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${points.length}个知识点',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 添加小箭头指示器
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.textTertiary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      // 原始布局：水平排列
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: subjectColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                            ),
                            child: Center(
                              child: Text(
                                subjectIcon,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subjectName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${points.length}个知识点',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 第二行：掌握度进度条
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isCompact ? '掌握度' : '平均掌握度',
                              style: TextStyle(
                                fontSize: isCompact ? 11 : 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$avgMastery%',
                                  style: TextStyle(
                                    fontSize: isCompact ? 15 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: masteryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  avgMastery >= 60
                                      ? CupertinoIcons.arrow_up_right
                                      : CupertinoIcons.arrow_down_right,
                                  size: isCompact ? 12 : 14,
                                  color: masteryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 6 : 8),
                        Stack(
                          children: [
                            Container(
                              height: isCompact ? 6 : 8,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(isCompact ? 3 : 4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: avgMastery / 100,
                              child: Container(
                                height: isCompact ? 6 : 8,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      masteryColor.withOpacity(0.8),
                                      masteryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(isCompact ? 3 : 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: masteryColor.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 第三行：统计信息标签
                    Row(
                      children: [
                        // 错题数
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 6 : AppConstants.spacingS,
                              vertical: isCompact ? 6 : AppConstants.spacingS,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mistake.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.doc_text_fill,
                                  size: isCompact ? 14 : 16,
                                  color: AppColors.mistake,
                                ),
                                SizedBox(width: isCompact ? 4 : 6),
                                Flexible(
                                  child: Text(
                                    '${subjectStats['totalMistakes']}${isCompact ? '' : '道'}错题',
                                    style: TextStyle(
                                      fontSize: isCompact ? 11 : 13,
                                      color: AppColors.mistake,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : AppConstants.spacingS),
                        // 薄弱点数
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 6 : AppConstants.spacingS,
                              vertical: isCompact ? 6 : AppConstants.spacingS,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  size: isCompact ? 14 : 16,
                                  color: AppColors.warning,
                                ),
                                SizedBox(width: isCompact ? 4 : 6),
                                Flexible(
                                  child: Text(
                                    '${subjectStats['weakPoints']}${isCompact ? '' : '个'}薄弱',
                                    style: TextStyle(
                                      fontSize: isCompact ? 11 : 13,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
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
            ],
          ),
        ),
      ),
    );
  }

  // UI辅助方法
  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Color _getOverallMasteryColor(int level) {
    if (level >= 75) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 45) return AppColors.warning;
    return AppColors.error;
  }

  /// 处理 AI 分析卡片点击
  void _handleAnalysisCardTap(int accumulatedMistakes, int daysSinceLastReview) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _navigateToLogin();
      return;
    }
    
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AIAnalysisReviewScreen(
          accumulatedMistakes: accumulatedMistakes,
          daysSinceLastReview: daysSinceLastReview,
        ),
      ),
    );
  }

  /// 处理学科卡片点击
  void _handleSubjectCardTap(String subjectName, List<KnowledgePoint> points) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _navigateToLogin();
      return;
    }
    
    // 从学科名称获取 Subject 枚举
    final subject = Subject.fromString(subjectName);
    if (subject == null) {
      print('无效的学科名称: $subjectName');
      return;
    }
    
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SubjectDetailScreen(
          subject: subject,
        ),
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

