import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, TickerProviderStateMixin, AnimationController, Animation, CurvedAnimation, Curves, ScaleTransition, FadeTransition, SlideTransition, Offset;
import '../models/daily_task.dart';
import '../models/review_state.dart';
import '../services/daily_task_service.dart';
import '../services/auth_service.dart';
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
    with TickerProviderStateMixin {
  final DailyTaskService _taskService = DailyTaskService();
  bool _isSubmitting = false;
  
  late AnimationController _iconController;
  late AnimationController _contentController;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotateAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();
    
    // 图标动画
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _iconScaleAnimation = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );
    _iconRotateAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    // 内容动画
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));
    
    // 启动动画
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
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

      // 2. 更新每周复习数据
      final authService = AuthService();
      final questionCount = widget.item.questions.length;
      await authService.updateWeeklyReviewData(questionCount);

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
      child: SafeArea(
        child: Stack(
          children: [
            // 主内容
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 顶部成功图标和标题
                  _buildHeader(),
                  
                  const SizedBox(height: 40),
                  
                  // 内容区域（带动画）
                  FadeTransition(
                    opacity: _contentFadeAnimation,
                    child: SlideTransition(
                      position: _contentSlideAnimation,
                      child: Column(
                        children: [
                          // 统计信息
                          _buildStatsRow(),
                          
                          const SizedBox(height: 24),
                          
                          // 知识点卡片
                          _buildKnowledgeCard(),
                          
                          const SizedBox(height: 20),
                          
                          // 鼓励语
                          _buildEncouragementText(),
                          
                          const SizedBox(height: 32),
                          
                          // 完成按钮
                          _buildCompleteButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 关闭按钮
            Positioned(
              top: 16,
              right: 16,
              child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    shape: BoxShape.circle,
                  ),
          child: const Icon(
            CupertinoIcons.xmark,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  // 顶部标题区域
  Widget _buildHeader() {
    return Column(
          children: [
        // 成功图标
            ScaleTransition(
          scale: _iconScaleAnimation,
          child: RotationTransition(
            turns: _iconRotateAnimation,
              child: Container(
              width: 100,
              height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
                ),
                child: const Icon(
                CupertinoIcons.checkmark_alt,
                  color: Colors.white,
                size: 50,
              ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 标题
            Text(
          _getStatusDescription(),
              style: const TextStyle(
            fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
            letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

        // 副标题
            Text(
          widget.item.knowledgePointName,
          textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
            color: AppColors.textSecondary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
              ),
            ),
          ],
    );
  }

  // 统计信息行
  Widget _buildStatsRow() {
    final totalQuestions = widget.item.questions.length;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: CupertinoIcons.checkmark_circle_fill,
            iconColor: AppColors.success,
            label: '完成题目',
            value: '$totalQuestions',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: CupertinoIcons.star_fill,
            iconColor: AppColors.accent,
            label: '学习状态',
            value: widget.item.status.displayName,
          ),
        ),
      ],
    );
  }

  // 单个统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // 知识点卡片
  Widget _buildKnowledgeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 状态图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: ReviewStatusIcon(
            status: widget.item.status,
                size: 28,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 知识点信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '知识点',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.knowledgePointName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 鼓励文本
  Widget _buildEncouragementText() {
    final encouragement = _getEncouragement();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.heart_fill,
            color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
            child: Text(
              encouragement,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textPrimary.withOpacity(0.85),
                fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 完成按钮
  Widget _buildCompleteButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? const CupertinoActivityIndicator(
                color: Colors.white,
              )
            : const Text(
                '完成',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (widget.item.status) {
      case ReviewStatus.newLearning:
        return '学习完成！';
      case ReviewStatus.reviewing:
        return '复习完成！';
      case ReviewStatus.mastered:
        return '巩固完成！';
    }
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

