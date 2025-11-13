import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/knowledge_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';
import 'knowledge_point_mistakes_screen.dart';

/// 模块详情页 - 显示某个模块下的所有知识点
class ModuleDetailScreen extends StatefulWidget {
  final Module module;

  const ModuleDetailScreen({
    super.key,
    required this.module,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen>
    with TickerProviderStateMixin {
  final _knowledgeService = KnowledgeService();
  
  List<KnowledgePoint>? _knowledgePoints;
  bool _isLoading = true;
  String? _error;
  String _sortBy = '错题数'; // 排序方式：错题数、掌握度、最近错误
  
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // 淡入动画
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    
    // 滑入动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;
      
      if (userId == null) {
        setState(() {
          _knowledgePoints = [];
          _isLoading = false;
        });
        return;
      }
      
      final client = authProvider.authService.client;
      _knowledgeService.initialize(client);
      
      final points = await _knowledgeService.getModuleKnowledgePoints(
        userId,
        widget.module.id,
      );
      
      setState(() {
        _knowledgePoints = points;
        _isLoading = false;
      });
      
      // 延迟启动动画
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animationController.forward();
        }
      });
    } catch (e) {
      print('加载知识点失败: $e');
      setState(() {
        _error = '加载失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectColor = widget.module.subject.color;
    final subjectIcon = widget.module.subject.icon;

    if (_isLoading) {
      return _buildLoadingState(subjectIcon, subjectColor);
    }
    
    if (_error != null) {
      return _buildErrorState(subjectIcon, subjectColor);
    }
    
    final points = _knowledgePoints ?? [];
    _sortKnowledgePoints(points);
    final stats = _calculateStats(points);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            title: '$subjectIcon ${widget.module.name}',
            rightAction: points.isNotEmpty ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: _showSortSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.divider,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.sort_down,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortBy,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ) : null,
          ),
          
          Expanded(
            child: points.isEmpty
                ? _buildEmptyState()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // 模块描述卡片
                          if (widget.module.description != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppConstants.spacingM,
                                  0,
                                  AppConstants.spacingM,
                                  AppConstants.spacingM,
                                ),
                                child: _buildModuleInfoCard(subjectColor),
                              ),
                            ),
                          
                          // 统计卡片
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppConstants.spacingM,
                                0,
                                AppConstants.spacingM,
                                AppConstants.spacingM,
                              ),
                              child: _buildStatsCard(stats, subjectColor),
                            ),
                          ),
                          
                          // 知识点列表
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingM,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppConstants.spacingS,
                                mainAxisSpacing: AppConstants.spacingM,
                                childAspectRatio: 1.3, // 增加宽高比，降低卡片高度
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return RepaintBoundary(
                                    child: _buildKnowledgePointCard(
                                      points[index],
                                      subjectColor,
                                    ),
                                  );
                                },
                                childCount: points.length,
                              ),
                            ),
                          ),
                          
                          const SliverToBoxAdapter(
                            child: SizedBox(height: AppConstants.spacingM),
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

  Widget _buildLoadingState(String icon, Color color) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(title: '$icon ${widget.module.name}'),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 16, color: color),
                  const SizedBox(height: 16),
                  Text(
                    '正在加载知识点...',
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

  Widget _buildErrorState(String icon, Color color) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(title: '$icon ${widget.module.name}'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.module.subject.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                CupertinoIcons.chart_bar,
                size: 40,
                color: widget.module.subject.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无知识点',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '该模块还没有错题数据',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleInfoCard(Color subjectColor) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            subjectColor.withValues(alpha: 0.08),
            subjectColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: subjectColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                widget.module.subject.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.module.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.module.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.module.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats, Color subjectColor) {
    final avgMastery = stats['avgMastery'] as int;
    final masteryColor = _getMasteryColor(avgMastery);
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '${stats['totalPoints']}',
                  '知识点',
                  CupertinoIcons.square_grid_2x2_fill,
                  AppColors.accent,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: _buildStatItem(
                  '${stats['weakPoints']}',
                  '薄弱点',
                  CupertinoIcons.exclamationmark_triangle_fill,
                  AppColors.warning,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: _buildStatItem(
                  '${stats['totalMistakes']}',
                  '错题数',
                  CupertinoIcons.doc_text_fill,
                  AppColors.mistake,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: masteryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.chart_pie,
                  size: 20,
                  color: masteryColor,
                ),
                const SizedBox(width: AppConstants.spacingS),
                const Text(
                  '平均掌握度',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$avgMastery%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: masteryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildKnowledgePointCard(KnowledgePoint point, Color subjectColor) {
    final masteryColor = _getMasteryColor(point.masteryLevel);
    
    return GestureDetector(
      onTap: () => _handleKnowledgePointTap(point),
      child: Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      subjectColor,
                      subjectColor.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MathMarkdownText(
                          text: point.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.spacingM),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '掌握度',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            '${point.masteryLevel}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: masteryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: point.masteryLevel / 100,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    masteryColor.withValues(alpha: 0.8),
                                    masteryColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: AppColors.mistake.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Icon(
                          CupertinoIcons.doc_text_fill,
                          size: 14,
                          color: AppColors.mistake,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${point.questionIds.length}题',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mistake,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _handleKnowledgePointTap(KnowledgePoint point) {
    // 如果没有错题，显示提示
    if (point.questionIds.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('该知识点还没有关联的错题'),
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
    
    // 导航到知识点错题列表页面
    // 从分析页面进入，不显示选择按钮
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => KnowledgePointMistakesScreen(
          knowledgePoint: point,
          initialSelectionMode: false,
          showSelectionButton: false, // 从分析页面进入，不显示选择按钮
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<KnowledgePoint> points) {
    if (points.isEmpty) {
      return {
        'totalPoints': 0,
        'weakPoints': 0,
        'totalMistakes': 0,
        'avgMastery': 0,
      };
    }

    final totalMistakes = points.fold<int>(0, (sum, p) => sum + p.mistakeCount);
    final avgMastery = points.fold<int>(0, (sum, p) => sum + p.masteryLevel) ~/ points.length;
    final weakPoints = points.where((p) => p.masteryLevel < 60).length;

    return {
      'totalPoints': points.length,
      'weakPoints': weakPoints,
      'totalMistakes': totalMistakes,
      'avgMastery': avgMastery,
    };
  }

  void _sortKnowledgePoints(List<KnowledgePoint> points) {
    switch (_sortBy) {
      case '错题数':
        points.sort((a, b) => b.mistakeCount.compareTo(a.mistakeCount));
        break;
      case '掌握度':
        points.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));
        break;
      case '最近错误':
        points.sort((a, b) {
          if (a.lastMistakeAt == null) return 1;
          if (b.lastMistakeAt == null) return -1;
          return b.lastMistakeAt!.compareTo(a.lastMistakeAt!);
        });
        break;
    }
  }

  void _showSortSheet() {
    final sortOptions = ['错题数', '掌握度', '最近错误'];
    
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('排序方式'),
        actions: sortOptions.map((option) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() {
              _sortBy = option;
            });
            Navigator.pop(context);
          },
          isDefaultAction: option == _sortBy,
          child: Text(option),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

