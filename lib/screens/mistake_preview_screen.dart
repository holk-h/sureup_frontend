import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../services/mistake_service.dart';
import '../widgets/common/custom_app_bar.dart';

/// 错题预览页面
/// 显示上传后的题目信息，支持实时更新分析状态
class MistakePreviewScreen extends StatefulWidget {
  final String mistakeRecordId; // 错题记录 ID
  final List<String> originalImageIds; // 原始图片 ID 列表

  const MistakePreviewScreen({
    super.key,
    required this.mistakeRecordId,
    required this.originalImageIds,
  });

  @override
  State<MistakePreviewScreen> createState() => _MistakePreviewScreenState();
}

class _MistakePreviewScreenState extends State<MistakePreviewScreen>
    with SingleTickerProviderStateMixin {
  final MistakeService _mistakeService = MistakeService();

  // 数据状态
  MistakeRecord? _mistakeRecord;
  Question? _question;
  bool _isLoading = true;
  String? _errorMessage;

  // Realtime 订阅
  RealtimeSubscription? _subscription;

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialData();
    _subscribeToUpdates();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _subscription?.close();
    super.dispose();
  }

  // 加载初始数据
  Future<void> _loadInitialData() async {
    try {
      final record = await _mistakeService.getMistakeRecord(widget.mistakeRecordId);
      if (record == null) {
        throw Exception('错题记录不存在');
      }

      setState(() {
        _mistakeRecord = record;
        _isLoading = false;
      });

      // 如果已经有 questionId，加载题目详情
      if (record.questionId != null) {
        await _loadQuestionDetails(record.questionId!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  // 加载题目详情
  Future<void> _loadQuestionDetails(String questionId) async {
    try {
      final question = await _mistakeService.getQuestion(questionId);
      if (mounted) {
        setState(() {
          _question = question;
        });
      }
    } catch (e) {
      print('加载题目详情失败: $e');
    }
  }

  // 订阅实时更新
  void _subscribeToUpdates() {
    _subscription = _mistakeService.subscribeMistakeAnalysis(
      mistakeRecordId: widget.mistakeRecordId,
      onUpdate: _handleUpdate,
      onError: _handleError,
    );
  }

  // 处理更新
  void _handleUpdate(MistakeRecord record) {
    if (!mounted) return;

    setState(() {
      _mistakeRecord = record;
    });

    // 如果分析完成且有 questionId，加载题目详情
    if (record.analysisStatus == AnalysisStatus.completed &&
        record.questionId != null &&
        _question == null) {
      _loadQuestionDetails(record.questionId!);
      HapticFeedback.mediumImpact();
    }
  }

  // 处理错误
  void _handleError(dynamic error) {
    if (!mounted) return;

    setState(() {
      _errorMessage = '更新失败: $error';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // 顶部导航栏
          CustomAppBar(
            title: '错题详情',
            rightAction: _buildMenuButton(),
          ),

          // 主内容
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  // 构建菜单按钮
  Widget _buildMenuButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _showActionSheet,
      child: const Icon(
        CupertinoIcons.ellipsis_circle,
        color: AppColors.textPrimary,
        size: 24,
      ),
    );
  }

  // 显示操作菜单
  void _showActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 重新分析
            },
            child: const Text('重新分析'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 添加备注
            },
            child: const Text('添加备注'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 删除错题
            },
            isDestructiveAction: true,
            child: const Text('删除错题'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  // 构建主内容
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_mistakeRecord == null) {
      return const Center(
        child: Text('错题记录不存在'),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 原始图片
        SliverToBoxAdapter(
          child: _buildOriginalImages(),
        ),

        // 分析状态卡片
        SliverToBoxAdapter(
          child: _buildAnalysisStatusCard(),
        ),

        // 题目详情（分析完成后显示）
        if (_mistakeRecord!.isAnalyzed && _question != null)
          SliverToBoxAdapter(
            child: _buildQuestionDetails(),
          ),

        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingXL),
        ),
      ],
    );
  }

  // 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '未知错误',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _loadInitialData();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // 构建原始图片
  Widget _buildOriginalImages() {
    if (widget.originalImageIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '原始图片',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.originalImageIds.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(
                    right: index < widget.originalImageIds.length - 1
                        ? AppConstants.spacingM
                        : 0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    border: Border.all(
                      color: AppColors.divider,
                      width: 1,
                    ),
                    boxShadow: AppColors.shadowSoft,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: Image.network(
                      '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.originQuestionImageBucketId}/files/${widget.originalImageIds[index]}/view?project=${ApiConfig.projectId}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建分析状态卡片
  Widget _buildAnalysisStatusCard() {
    final status = _mistakeRecord!.analysisStatus;

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: _getStatusGradient(status),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 状态图标
          _buildStatusIcon(status),

          const SizedBox(height: 16),

          // 状态文本
          Text(
            _getStatusTitle(status),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          // 状态描述
          Text(
            _getStatusDescription(status),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          // 学科标签（分析完成后显示）
          if (status == AnalysisStatus.completed && _mistakeRecord!.subject != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.book_fill,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _mistakeRecord!.subject!.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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

  // 构建状态图标
  Widget _buildStatusIcon(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.processing:
        return ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              size: 40,
              color: CupertinoColors.white,
            ),
          ),
        );

      case AnalysisStatus.completed:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withOpacity(0.15),
            border: Border.all(
              color: AppColors.success,
              width: 2,
            ),
          ),
          child: const Icon(
            CupertinoIcons.checkmark_alt,
            size: 40,
            color: AppColors.success,
          ),
        );

      case AnalysisStatus.failed:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withOpacity(0.15),
            border: Border.all(
              color: AppColors.error,
              width: 2,
            ),
          ),
          child: const Icon(
            CupertinoIcons.xmark,
            size: 40,
            color: AppColors.error,
          ),
        );
    }
  }

  // 获取状态渐变
  LinearGradient _getStatusGradient(AnalysisStatus status) {
    final color = _getStatusColor(status);
    return LinearGradient(
      colors: [
        color.withOpacity(0.08),
        color.withOpacity(0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // 获取状态颜色
  Color _getStatusColor(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.processing:
        return AppColors.primary;
      case AnalysisStatus.completed:
        return AppColors.success;
      case AnalysisStatus.failed:
        return AppColors.error;
    }
  }

  // 获取状态标题
  String _getStatusTitle(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
        return '准备分析';
      case AnalysisStatus.processing:
        return 'AI 分析中...';
      case AnalysisStatus.completed:
        return '分析完成';
      case AnalysisStatus.failed:
        return '分析失败';
    }
  }

  // 获取状态描述
  String _getStatusDescription(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
        return '正在准备分析你的错题';
      case AnalysisStatus.processing:
        return 'AI 正在识别题目内容和分析错因';
      case AnalysisStatus.completed:
        return 'AI 已完成分析，查看下方详情';
      case AnalysisStatus.failed:
        return _mistakeRecord?.analysisError ?? '分析过程中出现错误';
    }
  }

  // 构建题目详情
  Widget _buildQuestionDetails() {
    if (_question == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容
          _buildSection(
            title: '题目内容',
            icon: CupertinoIcons.doc_text,
            child: Text(
              _question!.content,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 选项（选择题）
          if (_question!.options != null && _question!.options!.isNotEmpty)
            _buildSection(
              title: '选项',
              icon: CupertinoIcons.list_bullet,
              child: Column(
                children: _question!.options!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final label = String.fromCharCode(65 + index); // A, B, C, D...
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_question!.options != null && _question!.options!.isNotEmpty)
            const SizedBox(height: AppConstants.spacingM),

          // 答案
          if (_question!.answer != null)
            _buildSection(
              title: '正确答案',
              icon: CupertinoIcons.checkmark_seal_fill,
              iconColor: AppColors.success,
              child: Text(
                _question!.answer!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                  height: 1.6,
                ),
              ),
            ),

          if (_question!.answer != null)
            const SizedBox(height: AppConstants.spacingM),

          // 解析
          if (_question!.explanation != null)
            _buildSection(
              title: '题目解析',
              icon: CupertinoIcons.lightbulb_fill,
              iconColor: AppColors.warning,
              child: Text(
                _question!.explanation!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),

          if (_question!.explanation != null)
            const SizedBox(height: AppConstants.spacingM),

          // 错因分析
          if (_mistakeRecord!.errorReason != null)
            _buildSection(
              title: '错因分析',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              iconColor: AppColors.error,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _mistakeRecord!.errorReason!.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),

          if (_mistakeRecord!.errorReason != null)
            const SizedBox(height: AppConstants.spacingM),

          // 知识点
          _buildSection(
            title: '相关知识点',
            icon: CupertinoIcons.book_fill,
            iconColor: AppColors.accent,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _question!.knowledgePointName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区块
  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
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
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

