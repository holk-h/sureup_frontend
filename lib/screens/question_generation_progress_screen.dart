import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
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
    extends State<QuestionGenerationProgressScreen> {
  final _questionGenerationService = QuestionGenerationService();
  StreamSubscription<QuestionGenerationTask>? _subscription;
  
  QuestionGenerationTask? _task;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        });

        // 如果任务完成，延迟导航到结果页面
        if (task.isSuccess && task.generatedQuestionIds != null) {
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
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
          const CupertinoActivityIndicator(radius: 16),
          const SizedBox(height: 16),
          Text(
            '正在加载任务...',
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
            CupertinoButton.filled(
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
              child: const Text('查看生成的题目'),
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

    switch (task.status) {
      case QuestionGenerationTaskStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = CupertinoIcons.clock;
        statusText = '等待处理';
        break;
      case QuestionGenerationTaskStatus.processing:
        statusColor = AppColors.accent;
        statusIcon = CupertinoIcons.arrow_2_circlepath;
        statusText = '生成中';
        break;
      case QuestionGenerationTaskStatus.completed:
        statusColor = AppColors.success;
        statusIcon = CupertinoIcons.check_mark_circled;
        statusText = '已完成';
        break;
      case QuestionGenerationTaskStatus.failed:
        statusColor = AppColors.error;
        statusIcon = CupertinoIcons.xmark_circle;
        statusText = '失败';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              statusIcon,
              size: 28,
              color: statusColor,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.typeDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${task.completedCount}/${task.totalCount}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress / 100,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                task.isFailed ? AppColors.error : AppColors.accent,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            '${task.progress.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildInfoRow('源题目数', '${task.sourceQuestionIds.length}'),
          const SizedBox(height: AppConstants.spacingS),
          _buildInfoRow('每题变式数', '${task.variantsPerQuestion}'),
          const SizedBox(height: AppConstants.spacingS),
          _buildInfoRow('预计生成', '${task.totalCount} 道题'),
          if (task.startedAt != null) ...[
            const SizedBox(height: AppConstants.spacingS),
            _buildInfoRow('开始时间', _formatTime(task.startedAt!)),
          ],
          if (task.completedAt != null) ...[
            const SizedBox(height: AppConstants.spacingS),
            _buildInfoRow('完成时间', _formatTime(task.completedAt!)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

