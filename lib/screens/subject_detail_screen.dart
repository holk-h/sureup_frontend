import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/knowledge_service.dart';
import '../widgets/common/custom_app_bar.dart';
import 'module_detail_screen.dart';

/// 学科详情页 - 显示某个学科的所有模块
class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with TickerProviderStateMixin {
  final _knowledgeService = KnowledgeService();
  
  List<Module>? _modules;
  bool _isLoading = true;
  String? _error;
  String _sortBy = '错题数'; // 排序方式：错题数、知识点数
  
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
          _modules = [];
          _isLoading = false;
        });
        return;
      }
      
      final client = authProvider.authService.client;
      _knowledgeService.initialize(client);
      
      final modules = await _knowledgeService.getSubjectModules(
        userId,
        widget.subject,
      );
      
      setState(() {
        _modules = modules;
        _isLoading = false;
      });
      
      // 延迟启动动画
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animationController.forward();
        }
      });
    } catch (e) {
      print('加载模块失败: $e');
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
    final subjectColor = widget.subject.color;
    final subjectIcon = widget.subject.icon;

    if (_isLoading) {
      return _buildLoadingState(subjectIcon, subjectColor);
    }
    
    if (_error != null) {
      return _buildErrorState(subjectIcon, subjectColor);
    }
    
    final modules = _modules ?? [];
    _sortModules(modules);
    final stats = _calculateStats(modules);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            title: '$subjectIcon ${widget.subject.displayName}',
            rightAction: modules.isNotEmpty ? CupertinoButton(
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
            child: modules.isEmpty
                ? _buildEmptyState()
                : FadeTransition(
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
                                AppConstants.spacingM,
                              ),
                              child: _buildSubjectStatsCard(stats, subjectColor),
                            ),
                          ),
                          
                          // 模块列表 - 两列网格
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingM,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // 两列
                                crossAxisSpacing: AppConstants.spacingS, // 列间距
                                mainAxisSpacing: AppConstants.spacingM, // 行间距
                                childAspectRatio: 0.95, // 调整宽高比以适应模块卡片内容
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return RepaintBoundary(
                                    child: _buildModuleCard(
                                      modules[index],
                                      subjectColor,
                                    ),
                                  );
                                },
                                childCount: modules.length,
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
          CustomAppBar(title: '$icon ${widget.subject.displayName}'),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 16, color: color),
                  const SizedBox(height: 16),
                  Text(
                    '正在加载模块...',
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
          CustomAppBar(title: '$icon ${widget.subject.displayName}'),
          Expanded(
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
                color: widget.subject.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                CupertinoIcons.folder,
                size: 40,
                color: widget.subject.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无模块',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '该学科还没有错题数据',
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

  Widget _buildSubjectStatsCard(Map<String, dynamic> stats, Color subjectColor) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              '${stats['totalModules']}',
              '模块',
              CupertinoIcons.folder_fill,
              AppColors.accent,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _buildStatItem(
              '${stats['totalKnowledgePoints']}',
              '知识点',
              CupertinoIcons.square_grid_2x2_fill,
              subjectColor,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _buildStatItem(
              '${stats['totalMistakes']}',
              '错题',
              CupertinoIcons.doc_text_fill,
              AppColors.mistake,
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

  Widget _buildModuleCard(Module module, Color subjectColor) {
    return GestureDetector(
      onTap: () => _handleModuleTap(module),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // 模块图标和名称
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    CupertinoIcons.folder_fill,
                    size: 22,
                    color: subjectColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    module.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            
            // 描述（如果有）
            if (module.description != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              Text(
                module.description!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const Spacer(),
            
            // 统计信息 - 上下排列更紧凑
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.square_grid_2x2,
                        size: 14,
                        color: subjectColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${module.knowledgePointCount} 知识点',
                        style: TextStyle(
                          fontSize: 12,
                          color: subjectColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mistake.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.doc_text_fill,
                        size: 14,
                        color: AppColors.mistake,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${module.mistakeCount} 错题',
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
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<Module> modules) {
    if (modules.isEmpty) {
      return {
        'totalModules': 0,
        'totalKnowledgePoints': 0,
        'totalMistakes': 0,
      };
    }

    final totalKnowledgePoints = modules.fold<int>(
      0,
      (sum, m) => sum + m.knowledgePointCount,
    );
    final totalMistakes = modules.fold<int>(
      0,
      (sum, m) => sum + m.mistakeCount,
    );

    return {
      'totalModules': modules.length,
      'totalKnowledgePoints': totalKnowledgePoints,
      'totalMistakes': totalMistakes,
    };
  }

  void _sortModules(List<Module> modules) {
    switch (_sortBy) {
      case '错题数':
        modules.sort((a, b) => b.mistakeCount.compareTo(a.mistakeCount));
        break;
      case '知识点数':
        modules.sort((a, b) => b.knowledgePointCount.compareTo(a.knowledgePointCount));
        break;
    }
  }

  void _showSortSheet() {
    final sortOptions = ['错题数', '知识点数'];
    
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

  void _handleModuleTap(Module module) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ModuleDetailScreen(module: module),
      ),
    );
  }
}
