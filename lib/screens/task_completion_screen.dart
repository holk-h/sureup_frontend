import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, SingleTickerProviderStateMixin, AnimationController, Animation, CurvedAnimation, Curves, ScaleTransition, Material, InkWell;
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';
import '../config/colors.dart';
import '../widgets/common/review_status_icon.dart';

/// 任务完成反馈页面
class TaskCompletionScreen extends StatefulWidget {
  final DailyTask task;
  final TaskItem item;
  final int itemIndex;
  final int correctCount;
  final int wrongCount;

  const TaskCompletionScreen({
    super.key,
    required this.task,
    required this.item,
    required this.itemIndex,
    required this.correctCount,
    required this.wrongCount,
  });

  @override
  State<TaskCompletionScreen> createState() => _TaskCompletionScreenState();
}

class _TaskCompletionScreenState extends State<TaskCompletionScreen>
    with SingleTickerProviderStateMixin {
  final DailyTaskService _taskService = DailyTaskService();
  String? _selectedFeedback;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _accuracy {
    final total = widget.correctCount + widget.wrongCount;
    if (total == 0) return 0.0;
    return widget.correctCount / total;
  }

  Future<void> _handleSubmit() async {
    if (_selectedFeedback == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('请选择你的掌握程度'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. 创建练习记录
      await _taskService.createPracticeSession(
        taskId: widget.task.id,
        knowledgePointId: widget.item.knowledgePointId,
        knowledgePointName: widget.item.knowledgePointName,
        totalQuestions: widget.item.totalQuestions,
        correctQuestions: widget.correctCount,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)), // 估算
        userFeedback: _selectedFeedback!,
      );

      // 2. 更新任务项完成状态
      final updatedItems = List<TaskItem>.from(widget.task.items);
      updatedItems[widget.itemIndex] = widget.item.copyWith(
        isCompleted: true,
        correctCount: widget.correctCount,
        wrongCount: widget.wrongCount,
      );

      await _taskService.updateTaskProgress(widget.task.id, updatedItems);

      // 3. 返回任务列表
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('提交失败'),
            content: Text('$e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(
            CupertinoIcons.xmark,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 完成动画图标
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.coloredShadow(
                    AppColors.success,
                    opacity: 0.3,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.check_mark_circled,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 标题
            Text(
              widget.item.knowledgePointName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              '练习完成！',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // 成绩卡片
            _buildScoreCard(),

            const SizedBox(height: 24),

            // 掌握度卡片
            _buildMasteryCard(),

            const SizedBox(height: 32),

            // 自我评价
            const Text(
              '你对这个知识点的掌握程度如何？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            _buildFeedbackOptions(),

            const SizedBox(height: 32),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        '提交并返回',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final total = widget.correctCount + widget.wrongCount;
    final accuracy = _accuracy;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Column(
        children: [
          const Text(
            '本次成绩',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreStat(
                icon: CupertinoIcons.question_circle,
                label: '题目数',
                value: '$total',
                color: AppColors.accent,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              _buildScoreStat(
                icon: CupertinoIcons.check_mark_circled,
                label: '正确',
                value: '${widget.correctCount}',
                color: AppColors.success,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              _buildScoreStat(
                icon: CupertinoIcons.xmark_circle,
                label: '错误',
                value: '${widget.wrongCount}',
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: accuracy >= 0.8
                  ? AppColors.successGradient
                  : accuracy >= 0.6
                      ? AppColors.accentGradient
                      : AppColors.warningGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.percent,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '正确率',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(accuracy * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildMasteryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.coloredShadow(AppColors.accent, opacity: 0.15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ReviewStatusIcon(
                status: widget.item.status,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前状态',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.status.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_up_right,
                color: Colors.white,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.calendar,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  '下次复习',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getNextReviewHint(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getNextReviewHint() {
    // 根据正确率估算下次复习时间
    final accuracy = _accuracy;
    if (accuracy >= 0.9) {
      return '7天后';
    } else if (accuracy >= 0.7) {
      return '3天后';
    } else {
      return '明天';
    }
  }

  Widget _buildFeedbackOptions() {
    return Row(
      children: [
        Expanded(
          child: _buildFeedbackOption(
            '完全掌握',
            CupertinoIcons.smiley_fill,
            AppColors.success,
            '完全掌握',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeedbackOption(
            '基本会了',
            CupertinoIcons.smiley,
            AppColors.accent,
            '基本会了',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeedbackOption(
            '还不会',
            CupertinoIcons.hand_thumbsdown,
            AppColors.warning,
            '还不会',
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackOption(
    String label,
    IconData icon,
    Color color,
    String value,
  ) {
    final isSelected = _selectedFeedback == value;

    return Material(
      color: isSelected ? color : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFeedback = value;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

