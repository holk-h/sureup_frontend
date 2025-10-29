import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/subject.dart';
import '../widgets/common/custom_app_bar.dart';

/// 学科详情页 - 显示某个学科的所有知识点
class SubjectDetailScreen extends StatefulWidget {
  final String subject;
  final List<dynamic> knowledgePoints;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.knowledgePoints,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with TickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 400), // 缩短动画时长
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
    
    // 滑入动画 - 减少滑动距离
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1), // 从30%减少到10%
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
    ));
    
    // 延迟启动动画，让UI先渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = List.from(widget.knowledgePoints);
    
    // 按选择的方式排序
    _sortKnowledgePoints(points);
    
    // 计算统计数据
    final stats = _calculateStats(points);
    
    // 获取学科对象和属性
    final subject = Subject.fromString(widget.subject);
    final subjectColor = subject?.color ?? AppColors.subjectDefault;
    final subjectIcon = subject?.icon ?? '📚';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // 统一的顶部导航栏
          CustomAppBar(
            title: '$subjectIcon ${widget.subject}',
            rightAction: CupertinoButton(
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
            ),
          ),
          
          // 主内容区域
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // 学科统计卡片
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingM, 
                          0, 
                          AppConstants.spacingM, 
                          AppConstants.spacingM
                        ),
                        child: _buildSubjectStatsCard(stats, subjectColor),
                      ),
                    ),
                    
                    // 知识点列表 - 两列展示
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 两列
                          crossAxisSpacing: AppConstants.spacingS, // 列间距
                          mainAxisSpacing: AppConstants.spacingM, // 行间距
                          childAspectRatio: 1.15, // 增加宽高比，减少卡片高度
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return RepaintBoundary(
                              child: _buildKnowledgePointCard(points[index]),
                            );
                          },
                          childCount: points.length,
                        ),
                      ),
                    ),
                    
                    // 底部间距
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

  // 学科统计卡片
  Widget _buildSubjectStatsCard(Map<String, dynamic> stats, Color subjectColor) {
    final avgMastery = stats['avgMastery'] as int;
    final masteryColor = _getMasteryColor(avgMastery);
    
    return Column(
      children: [
        // 知识点、薄弱点、错题统计卡片
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactStatItem(
                  '${stats['totalPoints']}',
                  '知识点',
                  CupertinoIcons.square_grid_2x2_fill,
                  AppColors.accent, // 使用蓝色，与学科色区分
                ),
              ),
              Container(
                width: 1,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingS),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      subjectColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: _buildCompactStatItem(
                  '${stats['weakPoints']}',
                  '薄弱点',
                  CupertinoIcons.exclamationmark_triangle_fill,
                  AppColors.warning,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingS),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      subjectColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: _buildCompactStatItem(
                  '${stats['totalMistakes']}',
                  '错题数',
                  CupertinoIcons.doc_text_fill,
                  AppColors.mistake,
                ),
              ),
            ],
          ),
        ),
        
        // 平均掌握度卡片 - 独立突出显示
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingL,
            AppConstants.spacingL, // 减少上边距
            AppConstants.spacingL,
            AppConstants.spacingL,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                masteryColor.withOpacity(0.12),
                masteryColor.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: masteryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: masteryColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: masteryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.chart_pie_fill,
                  size: 28,
                  color: masteryColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '平均掌握度',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: masteryColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '整体学习进度',
                      style: TextStyle(
                        fontSize: 11,
                        color: masteryColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: masteryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: masteryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$avgMastery',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: masteryColor,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: masteryColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      avgMastery >= 60
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 18,
                      color: masteryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 紧凑的统计项组件
  Widget _buildCompactStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 知识点卡片
  Widget _buildKnowledgePointCard(dynamic point) {
    final masteryColor = _getMasteryColor(point.masteryLevel);
    final subject = Subject.fromString(point.subject.displayName);
    final subjectColor = subject?.color ?? AppColors.subjectDefault;
    final urgency = _calculateUrgency(point);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: urgency == '紧急' 
              ? AppColors.error.withOpacity(0.3) 
              : AppColors.divider,
          width: urgency == '紧急' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: urgency == '紧急'
                ? AppColors.error.withOpacity(0.1)
                : AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Stack(
          children: [
            // 装饰性色条
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
                      subjectColor.withOpacity(0.5),
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
                  // 第一行：知识点名称
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppColors.textTertiary.withOpacity(0.6),
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
                          const Text(
                            '掌握度',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${point.masteryLevel}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: masteryColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                point.masteryLevel >= 60
                                    ? CupertinoIcons.arrow_up_right
                                    : CupertinoIcons.arrow_down_right,
                                size: 12,
                                color: masteryColor,
                              ),
                            ],
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
                                    masteryColor.withOpacity(0.8),
                                    masteryColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
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
                  
                  // 第三行：详细信息 - 一行平均显示
                  Row(
                    children: [
                      // 错题数
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingS),
                          decoration: BoxDecoration(
                            color: AppColors.mistake.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            const Icon(
                              CupertinoIcons.doc_text_fill,
                              size: 14,
                              color: AppColors.mistake,
                            ),
                              const SizedBox(width: 6),
                              Text(
                                '${point.mistakeCount}错题',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mistake,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      // 最近错误时间
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingS),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.clock,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _getTimeAgo(point.lastMistakeAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.accent,
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
          ],
        ),
      ),
    );
  }

  // 计算统计数据
  Map<String, dynamic> _calculateStats(List<dynamic> points) {
    if (points.isEmpty) {
      return {
        'totalPoints': 0,
        'weakPoints': 0,
        'totalMistakes': 0,
        'avgMastery': 0,
      };
    }

    final totalMistakes = points.fold<int>(0, (sum, p) => sum + (p.mistakeCount as int));
    final avgMastery = points.fold<int>(0, (sum, p) => sum + (p.masteryLevel as int)) ~/ points.length;
    final weakPoints = points.where((p) => p.masteryLevel < 60).length;

    return {
      'totalPoints': points.length,
      'weakPoints': weakPoints,
      'totalMistakes': totalMistakes,
      'avgMastery': avgMastery,
    };
  }

  // 排序知识点
  void _sortKnowledgePoints(List<dynamic> points) {
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

  // 计算紧急程度
  String _calculateUrgency(dynamic point) {
    if (point.masteryLevel < 40 && point.mistakeCount >= 4) {
      return '紧急';
    }
    if (point.lastMistakeAt != null) {
      final daysSince = DateTime.now().difference(point.lastMistakeAt!).inDays;
      if (daysSince < 1 && point.masteryLevel < 60) {
        return '紧急';
      }
    }
    return '正常';
  }

  // 获取时间差描述
  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '未知';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
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

