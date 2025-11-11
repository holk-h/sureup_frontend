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
import 'question_generation_progress_screen.dart';

/// 变式题生成历史页面
class QuestionGenerationHistoryScreen extends StatefulWidget {
  const QuestionGenerationHistoryScreen({super.key});

  @override
  State<QuestionGenerationHistoryScreen> createState() =>
      _QuestionGenerationHistoryScreenState();
}

class _QuestionGenerationHistoryScreenState
    extends State<QuestionGenerationHistoryScreen> {
  final _questionGenerationService = QuestionGenerationService();

  List<QuestionGenerationTask>? _tasks;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        setState(() {
          _tasks = [];
          _isLoading = false;
        });
        return;
      }

      final client = authProvider.authService.client;
      _questionGenerationService.initialize(client);

      final tasks = await _questionGenerationService.getTaskHistory(
        userId: userId,
        limit: 50,
      );

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('加载历史失败: $e');
      setState(() {
        _error = '加载失败：$e';
        _isLoading = false;
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
            title: '生成历史',
            rightAction: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: _loadHistory,
              child: const Icon(
                CupertinoIcons.refresh,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _tasks == null || _tasks!.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
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
            '正在加载历史...',
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
              onPressed: _loadHistory,
              child: const Text('重试'),
            ),
          ],
        ),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                CupertinoIcons.time,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无生成历史',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '还没有生成过变式题\n快去生成一些吧～',
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

  Widget _buildHistoryList() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final task = _tasks![index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _tasks!.length - 1
                        ? AppConstants.spacingM
                        : 0,
                  ),
                  child: _buildTaskCard(task),
                );
              },
              childCount: _tasks!.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingM),
        ),
      ],
    );
  }

  Widget _buildTaskCard(QuestionGenerationTask task) {
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);

    return GestureDetector(
      onTap: () => _handleTaskTap(task),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
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
          children: [
            // 状态和标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    statusIcon,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.typeDescription,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.statusDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            
            const SizedBox(height: AppConstants.spacingM),
            
            // 统计信息
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '${task.sourceQuestionIds.length}',
                    '源题目',
                    CupertinoIcons.doc_text,
                    AppColors.accent,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.divider),
                Expanded(
                  child: _buildStatItem(
                    task.isSuccess && task.generatedQuestionIds != null
                        ? '${task.generatedQuestionIds!.length}'
                        : '${task.completedCount}',
                    '已生成',
                    CupertinoIcons.checkmark_circle,
                    AppColors.success,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.divider),
                Expanded(
                  child: _buildStatItem(
                    '${task.totalCount}',
                    '预计',
                    CupertinoIcons.number,
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            
            // 进度条（如果正在处理）
            if (task.isProcessing) ...[
              const SizedBox(height: AppConstants.spacingM),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress / 100,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${task.progress.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            
            // 时间信息
            const SizedBox(height: AppConstants.spacingM),
            Row(
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(task.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (task.completedAt != null) ...[
                  const SizedBox(width: AppConstants.spacingM),
                  Text(
                    '完成于 ${_formatTime(task.completedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(QuestionGenerationTaskStatus status) {
    switch (status) {
      case QuestionGenerationTaskStatus.pending:
        return AppColors.warning;
      case QuestionGenerationTaskStatus.processing:
        return AppColors.accent;
      case QuestionGenerationTaskStatus.completed:
        return AppColors.success;
      case QuestionGenerationTaskStatus.failed:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(QuestionGenerationTaskStatus status) {
    switch (status) {
      case QuestionGenerationTaskStatus.pending:
        return CupertinoIcons.clock;
      case QuestionGenerationTaskStatus.processing:
        return CupertinoIcons.arrow_2_circlepath;
      case QuestionGenerationTaskStatus.completed:
        return CupertinoIcons.check_mark_circled;
      case QuestionGenerationTaskStatus.failed:
        return CupertinoIcons.xmark_circle;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  void _handleTaskTap(QuestionGenerationTask task) {
    // 如果任务完成且有生成的题目，跳转到题目列表
    if (task.isSuccess && task.generatedQuestionIds != null && task.generatedQuestionIds!.isNotEmpty) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => QuestionListScreen(
            questionIds: task.generatedQuestionIds!,
            title: '${task.typeDescription} - ${_formatTime(task.createdAt)}',
            sourceQuestionIds: task.sourceQuestionIds, // 传递源题目ID列表
            variantsPerQuestion: task.variantsPerQuestion, // 传递每题变式数量
          ),
        ),
      );
    }
    // 如果任务还在处理中，跳转到进度页面
    else if (task.isProcessing || task.isPending) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => QuestionGenerationProgressScreen(
            taskId: task.id,
          ),
        ),
      );
    }
    // 如果任务失败，显示错误信息
    else if (task.isFailed) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('生成失败'),
          content: Text(task.error ?? '未知错误'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }
}

