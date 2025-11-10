import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, SingleTickerProviderStateMixin, AnimationController, Animation, CurvedAnimation, Curves, ScaleTransition;
import '../models/daily_task.dart';
import '../models/review_state.dart';
import '../services/daily_task_service.dart';
import '../config/colors.dart';
import '../widgets/common/review_status_icon.dart';

/// 任务完成反馈页面
class TaskCompletionScreen extends StatefulWidget {
  final DailyTask task;
  final TaskItem item;
  final int itemIndex;

  const TaskCompletionScreen({
    super.key,
    required this.task,
    required this.item,
    required this.itemIndex,
  });

  @override
  State<TaskCompletionScreen> createState() => _TaskCompletionScreenState();
}

class _TaskCompletionScreenState extends State<TaskCompletionScreen>
    with SingleTickerProviderStateMixin {
  final DailyTaskService _taskService = DailyTaskService();
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

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      // 1. 更新任务项完成状态
      final updatedItems = List<TaskItem>.from(widget.task.items);
      updatedItems[widget.itemIndex] = widget.item.copyWith(
        isCompleted: true,
      );

      await _taskService.updateTaskProgress(widget.task.id, updatedItems);

      // 2. 返回任务列表
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

            Text(
              _getStatusDescription(),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // 学习成果卡片
            _buildProgressCard(),

            const SizedBox(height: 24),

            // 知识点信息卡片
            _buildKnowledgePointsCard(),

            const SizedBox(height: 24),

            // 鼓励语
            _buildEncouragementCard(),

            const SizedBox(height: 32),

            // 返回按钮
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        '完成',
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

  String _getStatusDescription() {
    switch (widget.item.status) {
      case ReviewStatus.newLearning:
        return '新知识学习完成！';
      case ReviewStatus.reviewing:
        return '复习完成，继续加油！';
      case ReviewStatus.mastered:
        return '知识巩固完成！';
    }
  }

  Widget _buildProgressCard() {
    final totalQuestions = widget.item.questions.length;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: AppColors.success,
            size: 56,
          ),
          const SizedBox(height: 20),
          const Text(
            '🎉 太棒了！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成了 $totalQuestions 道题目',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgePointsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.accent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          ReviewStatusIcon(
            status: widget.item.status,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '知识点',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.knowledgePointName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.status.displayName,
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

  Widget _buildEncouragementCard() {
    final encouragement = _getEncouragement();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.coloredShadow(AppColors.accent, opacity: 0.2),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.hand_thumbsup_fill,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              encouragement,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEncouragement() {
    switch (widget.item.status) {
      case ReviewStatus.newLearning:
        return '万事开头难，你已经迈出了第一步！继续保持这种学习热情，相信你一定能掌握这个知识点。';
      case ReviewStatus.reviewing:
        return '复习让知识更牢固！每一次回顾都是在加深理解，坚持下去，你会看到明显的进步。';
      case ReviewStatus.mastered:
        return '太棒了！你已经基本掌握了这个知识点。继续巩固，让知识成为你的本能！';
    }
  }
}

