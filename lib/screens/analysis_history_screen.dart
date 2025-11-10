import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';
import '../models/models.dart';
import '../services/accumulated_analysis_service.dart';
import '../providers/auth_provider.dart';

/// 历史分析记录页面
class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  final _analysisService = AccumulatedAnalysisService();
  
  bool _isLoading = true;
  String? _error;
  List<AccumulatedAnalysis> _analyses = [];
  
  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }
  
  @override
  void dispose() {
    _analysisService.dispose();
    super.dispose();
  }
  
  /// 加载历史分析记录
  Future<void> _loadAnalyses() async {
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
      _analysisService.initialize(client);
      
      // 获取历史记录
      final data = await _analysisService.getUserAnalyses(userId, limit: 50);
      final analyses = data.map((json) => AccumulatedAnalysis.fromJson(json)).toList();
      
      setState(() {
        _analyses = analyses;
        _isLoading = false;
      });
    } catch (e) {
      print('加载历史记录失败: $e');
      setState(() {
        _isLoading = false;
        _error = '加载失败：$e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            title: '历史分析记录',
          ),
          
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _analyses.isEmpty
                        ? _buildEmptyState()
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
            '加载中...',
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
              onPressed: _loadAnalyses,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
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
              '还没有分析记录',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '生成第一个 AI 分析\n开始你的学习复盘之旅',
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
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 主内容
  Widget _buildContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final analysis = _analyses[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _analyses.length - 1 ? AppConstants.spacingM : 0,
                  ),
                  child: _buildAnalysisCard(analysis),
                );
              },
              childCount: _analyses.length,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 分析记录卡片
  Widget _buildAnalysisCard(AccumulatedAnalysis analysis) {
    return GestureDetector(
      onTap: () => _showAnalysisDetail(analysis),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
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
          children: [
            // 头部：时间 + 状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(analysis.createdAt),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildStatusBadge(analysis),
              ],
            ),
            
            const SizedBox(height: AppConstants.spacingM),
            
            // 数据统计
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '错题数',
                    '${analysis.mistakeCount}',
                    CupertinoIcons.doc_text_fill,
                    AppColors.mistake,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildStatItem(
                    '距上次',
                    '${analysis.daysSinceLastReview}天',
                    CupertinoIcons.time,
                    AppColors.warning,
                  ),
                ),
                if (analysis.analysisDuration != null) ...[
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '用时',
                      '${analysis.analysisDuration!.inSeconds}秒',
                      CupertinoIcons.clock_fill,
                      AppColors.accent,
                    ),
                  ),
                ],
              ],
            ),
            
            // 如果有分析内容预览
            if (analysis.analysisContent != null && 
                analysis.analysisContent!.isNotEmpty &&
                analysis.isCompleted) ...[
              const SizedBox(height: AppConstants.spacingM),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                _getContentPreview(analysis.analysisContent!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 统计项
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
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
  
  /// 状态徽章
  Widget _buildStatusBadge(AccumulatedAnalysis analysis) {
    Color badgeColor;
    IconData icon;
    
    if (analysis.isCompleted) {
      badgeColor = AppColors.success;
      icon = CupertinoIcons.check_mark_circled_solid;
    } else if (analysis.isFailed) {
      badgeColor = AppColors.error;
      icon = CupertinoIcons.xmark_circle_fill;
    } else if (analysis.isProcessing) {
      badgeColor = AppColors.warning;
      icon = CupertinoIcons.hourglass;
    } else {
      badgeColor = AppColors.textTertiary;
      icon = CupertinoIcons.clock;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            analysis.statusText,
            style: TextStyle(
              fontSize: 12,
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inDays == 0) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// 获取内容预览
  String _getContentPreview(String content) {
    // 移除 Markdown 标记，只保留纯文本
    final text = content
        .replaceAll(RegExp(r'#{1,6}\s'), '')  // 标题
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')  // 粗体
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')  // 斜体
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')  // 链接
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')  // 代码
        .replaceAll(RegExp(r'\n+'), ' ')  // 换行转空格
        .trim();
    
    return text;
  }
  
  /// 显示分析详情
  void _showAnalysisDetail(AccumulatedAnalysis analysis) {
    if (!analysis.isCompleted || analysis.analysisContent == null) {
      // 如果未完成或没有内容，显示提示
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: Text(
            analysis.isFailed ? '此分析失败了' : '此分析还未完成',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }
    
    // 显示完整内容
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AnalysisDetailSheet(analysis: analysis),
    );
  }
}

/// 分析详情底部弹窗
class _AnalysisDetailSheet extends StatelessWidget {
  final AccumulatedAnalysis analysis;
  
  const _AnalysisDetailSheet({required this.analysis});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '分析详情',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: AppColors.textTertiary,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.divider),
          
          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 元信息
                  Container(
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
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.calendar,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '生成时间：${_formatFullDateTime(analysis.createdAt)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.doc_text,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '分析错题：${analysis.mistakeCount} 道',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 分析内容
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1,
                      ),
                    ),
                    child: MathMarkdownText(
                      text: analysis.analysisContent ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.spacingXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatFullDateTime(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

