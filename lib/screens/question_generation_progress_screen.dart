import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/question_generation_task.dart';
import '../providers/auth_provider.dart';
import '../services/question_generation_service.dart';
import '../widgets/common/custom_app_bar.dart';
import 'question_list_screen.dart';

/// 题目生成进度页面
class QuestionGenerationProgressScreen extends StatefulWidget {
  final String taskId;

  const QuestionGenerationProgressScreen({
    super.key,
    required this.taskId,
  });

  @override
  State<QuestionGenerationProgressScreen> createState() =>
      _QuestionGenerationProgressScreenState();
}

class _QuestionGenerationProgressScreenState
    extends State<QuestionGenerationProgressScreen>
    with SingleTickerProviderStateMixin {
  final _questionGenerationService = QuestionGenerationService();
  StreamSubscription<QuestionGenerationTask>? _subscription;
  bool _isClosed = false;
  
  QuestionGenerationTask? _task;
  bool _isLoading = true;
  String? _error;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadTask();
    _watchTask();
  }

  Future<void> _loadTask() async {
    try {
      final task = await _questionGenerationService.getTask(widget.taskId);
      if (mounted) {
        setState(() {
          _task = task;
          _isLoading = false;
          
          // 控制旋转动画
          if (task != null && task.status == QuestionGenerationTaskStatus.processing) {
            _rotationController.repeat();
          }
        });
      }
    } catch (e) {
      print('加载任务失败: $e');
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _isLoading = false;
        });
      }
    }
  }

  void _watchTask() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final client = authProvider.authService.client;
    _questionGenerationService.initialize(client);

    _subscription = _questionGenerationService
        .watchTask(widget.taskId)
        .listen((task) {
      if (mounted) {
        setState(() {
          _task = task;
          
          // 控制旋转动画
          if (task.status == QuestionGenerationTaskStatus.processing) {
            if (!_rotationController.isAnimating) {
              _rotationController.repeat();
            }
          } else {
            _rotationController.stop();
          }
        });

        // 如果任务完成，断开 realtime 连接并延迟导航到结果页面
        if (task.isSuccess && task.generatedQuestionIds != null && !_isClosed) {
          _isClosed = true;
          // 断开 realtime 连接
          _subscription?.cancel();
          _subscription = null;
          _questionGenerationService.cancelWatch();
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(
                  builder: (context) => QuestionListScreen(
                    questionIds: task.generatedQuestionIds!,
                    title: '生成的变式题',
                  ),
                ),
              );
            }
          });
        }
        
        // 如果任务失败，也断开连接
        if (task.isFailed && !_isClosed) {
          _isClosed = true;
          _subscription?.cancel();
          _subscription = null;
          _questionGenerationService.cancelWatch();
        }
      }
    });
  }

  @override
  void dispose() {
    if (!_isClosed) {
      _isClosed = true;
      _subscription?.cancel();
      _subscription = null;
      _questionGenerationService.cancelWatch();
    }
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(title: '生成变式题'),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _task == null
                        ? _buildEmptyState()
                        : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: AppColors.shadowSoft,
            ),
            child: const CupertinoActivityIndicator(
              radius: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '正在加载任务...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请稍候',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _loadTask,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        '任务不存在',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final task = _task!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          // 状态卡片
          _buildStatusCard(task),
          
          const SizedBox(height: AppConstants.spacingL),
          
          // 进度卡片
          _buildProgressCard(task),
          
          const SizedBox(height: AppConstants.spacingL),
          
          // 生成中提示
          if (task.status == QuestionGenerationTaskStatus.processing)
            _buildProcessingTip(),
          
          if (task.status == QuestionGenerationTaskStatus.processing)
            const SizedBox(height: AppConstants.spacingL),
          
          // 信息卡片
          _buildInfoCard(task),
          
          // 如果失败，显示错误信息
          if (task.isFailed && task.error != null) ...[
            const SizedBox(height: AppConstants.spacingL),
            _buildErrorCard(task.error!),
          ],
          
          // 如果完成，显示查看按钮
          if (task.isSuccess && task.generatedQuestionIds != null) ...[
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    CupertinoPageRoute(
                      builder: (context) => QuestionListScreen(
                        questionIds: task.generatedQuestionIds!,
                        title: '生成的变式题',
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.eye,
                      size: 18,
                      color: AppColors.cardBackground,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '查看生成的题目',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cardBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(QuestionGenerationTask task) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    LinearGradient? statusGradient;

    switch (task.status) {
      case QuestionGenerationTaskStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = CupertinoIcons.clock;
        statusText = '等待处理';
        statusGradient = AppColors.warningGradient;
        break;
      case QuestionGenerationTaskStatus.processing:
        statusColor = AppColors.accent;
        statusIcon = CupertinoIcons.arrow_2_circlepath;
        statusText = '生成中';
        statusGradient = AppColors.accentGradient;
        break;
      case QuestionGenerationTaskStatus.completed:
        statusColor = AppColors.success;
        statusIcon = CupertinoIcons.check_mark_circled;
        statusText = '已完成';
        statusGradient = AppColors.successGradient;
        break;
      case QuestionGenerationTaskStatus.failed:
        statusColor = AppColors.error;
        statusIcon = CupertinoIcons.xmark_circle;
        statusText = '失败';
        statusGradient = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: task.status == QuestionGenerationTaskStatus.processing
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: task.status == QuestionGenerationTaskStatus.processing
            ? null
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: statusGradient,
              color: statusGradient == null
                  ? statusColor.withValues(alpha: 0.15)
                  : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: statusGradient != null
                  ? AppColors.coloredShadow(statusColor, opacity: 0.2)
                  : null,
            ),
            child: task.status == QuestionGenerationTaskStatus.processing
                ? RotationTransition(
                    turns: _rotationController,
                    child: Icon(
                      statusIcon,
                      size: 32,
                      color: statusGradient != null
                          ? AppColors.cardBackground
                          : statusColor,
                    ),
                  )
                : Icon(
                    statusIcon,
                    size: 32,
                    color: statusGradient != null
                        ? AppColors.cardBackground
                        : statusColor,
                  ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.typeDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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

  Widget _buildProgressCard(QuestionGenerationTask task) {
    final progressColor = task.isFailed
        ? AppColors.error
        : task.isSuccess
            ? AppColors.success
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '生成进度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${task.completedCount}/${task.totalCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
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
                widthFactor: task.progress / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${task.progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (task.status == QuestionGenerationTaskStatus.processing)
                Text(
                  'AI 正在生成中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(QuestionGenerationTask task) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.info,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '任务信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Container(
            height: 1,
            color: AppColors.divider,
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildInfoRow(
            '源题目数',
            '${task.sourceQuestionIds.length}',
            CupertinoIcons.doc_text,
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildInfoRow(
            '每题变式数',
            '${task.variantsPerQuestion}',
            CupertinoIcons.sparkles,
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildInfoRow(
            '预计生成',
            '${task.totalCount} 道题',
            CupertinoIcons.number,
          ),
          if (task.startedAt != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildInfoRow(
              '开始时间',
              _formatTime(task.startedAt!),
              CupertinoIcons.clock,
            ),
          ],
          if (task.completedAt != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildInfoRow(
              '完成时间',
              _formatTime(task.completedAt!),
              CupertinoIcons.check_mark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData? icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingTip() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              '生成任务已经提交啦~可以随时退出，在生成历史中查看进度',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

