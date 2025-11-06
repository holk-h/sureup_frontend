import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';
import '../models/models.dart';
import '../services/mistake_service.dart';
import '../services/knowledge_service.dart';
import '../services/accumulated_analysis_service.dart';
import '../providers/auth_provider.dart';

/// AI分析复盘页面 - 深度错题分析
/// 
/// 本页面只分析 analyzedAt 为空的错题（未进行过 AI 积累分析的错题）
/// 完成分析后，后端会更新这些错题的 analyzedAt 字段
class AIAnalysisReviewScreen extends StatefulWidget {
  final int accumulatedMistakes; // 积累的错题数（用于初始显示，实际以加载的数据为准）
  final int daysSinceLastReview; // 距上次复盘天数

  const AIAnalysisReviewScreen({
    super.key,
    this.accumulatedMistakes = 15,
    this.daysSinceLastReview = 3,
  });

  @override
  State<AIAnalysisReviewScreen> createState() => _AIAnalysisReviewScreenState();
}

class _AIAnalysisReviewScreenState extends State<AIAnalysisReviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _mistakeService = MistakeService();
  final _knowledgeService = KnowledgeService();
  final _analysisService = AccumulatedAnalysisService();
  
  // 数据加载状态
  bool _isLoading = true;
  String? _error;
  List<MistakeRecord>? _mistakeRecords;
  List<KnowledgePoint>? _knowledgePoints;
  
  // 折叠状态
  bool _isKnowledgeExpanded = false;
  bool _isReasonExpanded = false;
  
  // AI建议生成状态
  bool _isGenerating = false;
  String _generatedText = '';
  String? _analysisId;  // 分析记录ID
  StreamSubscription<AnalysisUpdate>? _analysisSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // 缩短动画时长
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // 进一步减少滑动距离
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // 加载数据
    _loadData();
    
    // 延迟启动动画，让UI先渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }
  
  /// 加载真实数据
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
          _isLoading = false;
          _error = '用户未登录';
        });
        return;
      }
      
      // 初始化服务
      final client = authProvider.authService.client;
      _mistakeService.initialize(client);
      _knowledgeService.initialize(client);
      _analysisService.initialize(client);
      
      // 获取错题记录和知识点
      final results = await Future.wait([
        _mistakeService.getUserMistakes(userId),
        _knowledgeService.getUserKnowledgePoints(userId),
      ]);
      
      // 只保留 accumulatedAnalyzedAt 为空的错题（未分析的积累错题）
      final allMistakes = results[0] as List<MistakeRecord>;
      final unanalyzedMistakes = allMistakes.where((m) => m.accumulatedAnalyzedAt == null).toList();
      
      setState(() {
        _mistakeRecords = unanalyzedMistakes;
        _knowledgePoints = results[1] as List<KnowledgePoint>;
        _isLoading = false;
      });
    } catch (e) {
      print('加载数据失败: $e');
      setState(() {
        _isLoading = false;
        _error = '加载数据失败：$e';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _analysisSubscription?.cancel();
    _analysisService.dispose();
    super.dispose();
  }
  
  // 生成AI建议（真实API）
  Future<void> _generateAISuggestions() async {
    if (_isGenerating) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userProfile?.id;
    
    if (userId == null) {
      setState(() {
        _error = '用户未登录';
      });
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _generatedText = '';
      _error = null;
    });
    
    try {
      // 1. 创建分析任务
      _analysisId = await _analysisService.createAnalysis(userId);
      
      print('分析任务已创建: $_analysisId');
      
      // 2. 订阅分析更新
      _analysisService.subscribeToAnalysis(_analysisId!);
      
      // 3. 监听流式更新
      _analysisSubscription = _analysisService.analysisStream.listen(
        (update) {
          if (mounted) {
            setState(() {
              _generatedText = update.content;
              
              // 如果分析完成或失败，停止生成状态
              if (update.isCompleted || update.isFailed) {
                _isGenerating = false;
                
                if (update.isFailed) {
                  _error = '分析失败，请稍后重试';
                }
              }
            });
          }
        },
        onError: (error) {
          print('分析流错误: $error');
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _error = '分析失败：$error';
            });
          }
        },
        onDone: () {
          print('分析流结束');
          if (mounted) {
            setState(() {
              _isGenerating = false;
            });
          }
        },
      );
      
    } catch (e) {
      print('生成分析失败: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = '生成分析失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // 统一的顶部导航栏
          CustomAppBar(
            title: 'AI分析复盘',
          ),
          
          // 主内容区域
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }
  
  /// 加载状态
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 16),
          SizedBox(height: 16),
          Text(
            '正在分析你的错题...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 错误状态
  Widget _buildErrorState() {
    return Center(
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
              _error ?? '加载失败',
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
    );
  }
  
  /// 主内容
  Widget _buildContent() {
    // 如果没有错题记录，显示空状态
    if (_mistakeRecords == null || _mistakeRecords!.isEmpty) {
      return _buildEmptyState();
    }
    
    // 生成基于真实数据的分析
    final analysisData = _generateAnalysisData();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 主内容
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 学习状态总览
                    _buildOverviewCard(analysisData),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 知识点分布
                    _buildKnowledgeDistributionCard(analysisData),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // 错因分析
                    _buildReasonAnalysisCard(analysisData),
                    
                    const SizedBox(height: AppConstants.spacingM),
                    
                    // AI 个性化建议
                    _buildAISuggestionCard(analysisData),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 行动建议按钮组
                    _buildActionButtons(),
                    
                    const SizedBox(height: AppConstants.spacingXL),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(50),
                boxShadow: AppColors.coloredShadow(
                  AppColors.primary,
                  opacity: 0.3,
                ),
              ),
              child: const Icon(
                CupertinoIcons.chart_bar_circle,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '还没有积累错题',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '记录错题后，AI会帮你分析学习情况\n提供个性化的学习建议',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('去记录错题'),
            ),
          ],
        ),
      ),
    );
  }

  // 学习状态总览 - 精简版
  Widget _buildOverviewCard(Map<String, dynamic> data) {
    // 使用实际加载的未分析错题数量
    final actualAccumulatedMistakes = _mistakeRecords?.length ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatItem(
              '积累错题',
              '$actualAccumulatedMistakes',
              AppColors.mistake,
              CupertinoIcons.doc_text_fill,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '距上次',
              '${widget.daysSinceLastReview}天',
              AppColors.warning,
              CupertinoIcons.time,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '薄弱点',
              '${data['weakPoints']}个',
              AppColors.error,
              CupertinoIcons.exclamationmark_triangle_fill,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '建议',
              '${data['suggestedTime']}min',
              AppColors.accent,
              CupertinoIcons.clock_fill,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 可折叠卡片标题栏构建器
  Widget _buildCollapsibleHeader({
    required String title,
    required String badgeText,
    required Color iconColor,
    required Color badgeColor,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingL,
          vertical: AppConstants.spacingM,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // 与展开折叠同步的贝塞尔曲线
              child: const Icon(
                CupertinoIcons.chevron_down,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 知识点分布卡片 - 可折叠
  Widget _buildKnowledgeDistributionCard(Map<String, dynamic> data) {
    final subjects = data['subjectDistribution'] as List<Map<String, dynamic>>;
    final totalCount = subjects.fold<int>(0, (sum, s) => sum + (s['count'] as int));
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏 - 可点击展开/折叠
          _buildCollapsibleHeader(
            title: '知识点分布',
            badgeText: '共 $totalCount 道',
            icon: CupertinoIcons.chart_pie_fill,
            iconColor: AppColors.accent,
            badgeColor: AppColors.accent,
            isExpanded: _isKnowledgeExpanded,
            onTap: () {
              setState(() {
                _isKnowledgeExpanded = !_isKnowledgeExpanded;
              });
            },
          ),
          // 内容区域 - 展开折叠（贝塞尔曲线动画）
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material Design 标准贝塞尔曲线
              heightFactor: _isKnowledgeExpanded ? 1.0 : 0.0,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: Column(
                      children: subjects.map((subject) => _buildSubjectBar(subject)).toList(),
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

  Widget _buildSubjectBar(Map<String, dynamic> subject) {
    final String name = subject['name'];
    final int count = subject['count'];
    final Color color = subject['color'];
    final double percentage = subject['percentage'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$count 道',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 错因分析卡片 - 可折叠
  Widget _buildReasonAnalysisCard(Map<String, dynamic> data) {
    final reasons = data['mistakeReasons'] as List<Map<String, dynamic>>;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏 - 可点击展开/折叠
          _buildCollapsibleHeader(
            title: '错因分析',
            badgeText: '${reasons.length} 类',
            icon: CupertinoIcons.chart_bar_fill,
            iconColor: AppColors.warning,
            badgeColor: AppColors.warning,
            isExpanded: _isReasonExpanded,
            onTap: () {
              setState(() {
                _isReasonExpanded = !_isReasonExpanded;
              });
            },
          ),
          // 内容区域 - 展开折叠（贝塞尔曲线动画）
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material Design 标准贝塞尔曲线
              heightFactor: _isReasonExpanded ? 1.0 : 0.0,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: Column(
                      children: reasons.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reason = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < reasons.length - 1 ? AppConstants.spacingM : 0,
                          ),
                          child: _buildReasonItem(reason, index),
                        );
                      }).toList(),
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

  Widget _buildReasonItem(Map<String, dynamic> reason, int index) {
    final String name = reason['name'];
    final int count = reason['count'];
    final double percentage = reason['percentage'];
    final IconData icon = reason['icon'];
    final Color color = reason['color'];
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 20,
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
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count 道错题',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
    );
  }

  // AI 个性化建议卡片 - 流式输出
  Widget _buildAISuggestionCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 学习建议',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '根据你的学习情况量身定制',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          
          // 生成按钮或显示生成的内容
          if (_generatedText.isEmpty && !_isGenerating)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _generateAISuggestions,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      CupertinoIcons.wand_stars,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '生成学习建议',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 加载中动画
                  if (_isGenerating && _generatedText.isEmpty)
                    const Column(
                      children: [
                        CupertinoActivityIndicator(radius: 14),
                        SizedBox(height: 12),
                        Text(
                          'AI 正在分析中...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  // 显示生成的内容
                  else if (_generatedText.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MathMarkdownText(
                          text: _generatedText,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        // 显示光标效果
                        if (_isGenerating)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
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
  }

  // 行动建议按钮组
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 主按钮：去针对性练习
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              // TODO: 跳转到练习页面
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.play_circle_fill,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  '去针对性练习',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        // 次要按钮：查看错题
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppColors.accent,
              width: 1.5,
            ),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              // TODO: 跳转到错题列表
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  color: AppColors.accent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '查看全部错题',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 生成基于真实数据的分析
  Map<String, dynamic> _generateAnalysisData() {
    if (_mistakeRecords == null || _knowledgePoints == null) {
      return {
        'weakPoints': 0,
        'suggestedTime': 0,
        'subjectDistribution': [],
        'mistakeReasons': [],
        'suggestions': [],
      };
    }
    
    final records = _mistakeRecords!;
    final totalCount = records.length;
    
    if (totalCount == 0) {
      return {
        'weakPoints': 0,
        'suggestedTime': 0,
        'subjectDistribution': [],
        'mistakeReasons': [],
        'suggestions': [],
      };
    }
    
    // 1. 统计学科分布
    final subjectCounts = <String, int>{};
    for (final record in records) {
      if (record.subject != null) {
        final displayName = record.subject!.displayName;
        subjectCounts[displayName] = (subjectCounts[displayName] ?? 0) + 1;
      }
    }
    
    final subjects = subjectCounts.entries.map((entry) {
      final subject = Subject.fromString(entry.key);
      return {
        'name': entry.key,
        'count': entry.value,
        'percentage': (entry.value / totalCount * 100),
        'color': subject?.color ?? AppColors.subjectDefault,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // 2. 统计错因分布
    final reasonCounts = <String, int>{};
    final reasonIcons = {
      '概念理解不清': CupertinoIcons.book_fill,
      '思路断了': CupertinoIcons.layers_alt_fill,
      '计算错误': CupertinoIcons.number,
      '粗心大意': CupertinoIcons.exclamationmark_circle_fill,
      '知识盲区': CupertinoIcons.question_circle_fill,
      '审题不清': CupertinoIcons.eye_fill,
      '时间不够': CupertinoIcons.clock_fill,
    };
    final reasonColors = {
      '概念理解不清': const Color(0xFFEF4444),
      '思路断了': const Color(0xFFF59E0B),
      '计算错误': const Color(0xFF8B5CF6),
      '粗心大意': const Color(0xFF3B82F6),
      '知识盲区': const Color(0xFFEC4899),
      '审题不清': const Color(0xFF10B981),
      '时间不够': const Color(0xFF14B8A6),
    };
    
    for (final record in records) {
      if (record.errorReason != null && record.errorReason!.isNotEmpty) {
        reasonCounts[record.errorReason!] = (reasonCounts[record.errorReason!] ?? 0) + 1;
      }
    }
    
    final reasons = reasonCounts.entries.map((entry) {
      return {
        'name': entry.key,
        'count': entry.value,
        'percentage': (entry.value / totalCount * 100),
        'icon': reasonIcons[entry.key] ?? CupertinoIcons.exclamationmark_circle,
        'color': reasonColors[entry.key] ?? AppColors.textSecondary,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // 3. 计算薄弱知识点数量（错题数大于等于2的知识点）
    final weakPoints = _knowledgePoints!.where((kp) => kp.mistakeCount >= 2).length;
    
    // 4. 建议复习时间（根据错题数量）
    final suggestedTime = (totalCount * 2).clamp(10, 60); // 每题2分钟，最少10分钟，最多60分钟
    
    return {
      'weakPoints': weakPoints,
      'suggestedTime': suggestedTime,
      'subjectDistribution': subjects,
      'mistakeReasons': reasons,
      'suggestions': [], // AI建议暂时留空，后续再实现
    };
  }
}

