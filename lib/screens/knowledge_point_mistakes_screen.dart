import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../services/question_generation_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';
import 'mistake_preview_screen.dart';
import 'question_generation_progress_screen.dart';

/// 知识点错题列表页面 - 显示某个知识点关联的所有错题
class KnowledgePointMistakesScreen extends StatefulWidget {
  final KnowledgePoint knowledgePoint;
  final bool initialSelectionMode; // 是否默认开启选择模式
  final bool showSelectionButton; // 是否显示选择按钮

  const KnowledgePointMistakesScreen({
    super.key,
    required this.knowledgePoint,
    this.initialSelectionMode = false,
    this.showSelectionButton = true, // 默认显示选择按钮
  });

  @override
  State<KnowledgePointMistakesScreen> createState() =>
      _KnowledgePointMistakesScreenState();
}

class _KnowledgePointMistakesScreenState
    extends State<KnowledgePointMistakesScreen> {
  final _mistakeService = MistakeService();
  final _questionGenerationService = QuestionGenerationService();

  List<Question>? _questions;
  bool _isLoading = true;
  String? _error;
  
  // 选择模式
  bool _isSelectionMode = false;
  final Set<String> _selectedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    // 如果指定了初始选择模式，则开启
    _isSelectionMode = widget.initialSelectionMode;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        setState(() {
          _questions = [];
          _isLoading = false;
        });
        return;
      }

      final client = authProvider.authService.client;
      _mistakeService.initialize(client);

      // 直接使用知识点的 questionIds 字段，从 questions 集合获取题目
      final questionIds = widget.knowledgePoint.questionIds;
      
      if (questionIds.isEmpty) {
        setState(() {
          _questions = [];
          _isLoading = false;
        });
        return;
      }

      // 从 questions 集合获取题目
        final questions = await _mistakeService.getQuestions(questionIds);

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('加载题目失败: $e');
      setState(() {
        _error = '加载失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectIcon = widget.knowledgePoint.subject.icon;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            titleWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$subjectIcon ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Flexible(
                  child: MathMarkdownText(
                    text: widget.knowledgePoint.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            rightAction: _questions != null && _questions!.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showSelectionButton)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: _toggleSelectionMode,
                        child: Text(
                          _isSelectionMode ? '取消' : '选择',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isSelectionMode 
                                ? AppColors.error 
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _loadQuestions,
                    child: const Icon(
                      CupertinoIcons.refresh,
                      size: 22,
                    ),
                      ),
                    ],
                  )
                : null,
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _questions == null || _questions!.isEmpty
                        ? _buildEmptyState()
                        : Column(
                            children: [
                              Expanded(child: _buildQuestionsList()),
                              if (_isSelectionMode && _selectedQuestionIds.isNotEmpty)
                                _buildSelectionBar(),
                            ],
                          ),
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
          CupertinoActivityIndicator(
            radius: 16,
            color: widget.knowledgePoint.subject.color,
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载题目...',
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
              onPressed: _loadQuestions,
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
                color: widget.knowledgePoint.subject.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                CupertinoIcons.doc_text,
                size: 40,
                color: widget.knowledgePoint.subject.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无题目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '该知识点还没有关联的题目',
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

  Widget _buildQuestionsList() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 统计信息卡片
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: _buildStatsCard(),
          ),
        ),

        // 题目列表
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final question = _questions![index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _questions!.length - 1
                        ? AppConstants.spacingM
                        : 0,
                  ),
                  child: _buildQuestionCard(question, index),
                );
              },
              childCount: _questions!.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingM),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    final questionId = question.id;
    final isSelected = _selectedQuestionIds.contains(questionId);
    
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedQuestionIds.remove(questionId);
            } else {
              _selectedQuestionIds.add(questionId);
            }
          });
        } else {
          // 导航到错题预览页面
          _navigateToMistakePreview(questionId, index);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedQuestionIds.add(questionId);
          });
        }
      },
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
        child: Row(
          children: [
            // 选择框（在选择模式下显示）
            if (_isSelectionMode) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.accent 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.accent 
                        : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        CupertinoIcons.checkmark,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: AppConstants.spacingM),
            ],
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.knowledgePoint.subject.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(
                CupertinoIcons.doc_text_fill,
                size: 24,
                color: widget.knowledgePoint.subject.color,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 题目内容（最多两行）
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 42, // 大约两行的高度（14 * 1.5 * 2）
                      ),
                      child: ClipRect(
                        child: MathMarkdownText(
                        text: question.content,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 题目类型标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                          question.type.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalQuestions = _questions!.length;
    final masteryColor = _getMasteryColor(widget.knowledgePoint.masteryLevel);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.knowledgePoint.subject.color.withValues(alpha: 0.08),
            widget.knowledgePoint.subject.color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: widget.knowledgePoint.subject.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    widget.knowledgePoint.subject.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathMarkdownText(
                      text: widget.knowledgePoint.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.knowledgePoint.description != null)
                      Text(
                        widget.knowledgePoint.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '$totalQuestions',
                  '题目数',
                  CupertinoIcons.doc_text_fill,
                  AppColors.mistake,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: _buildStatItem(
                  '${widget.knowledgePoint.masteryLevel}%',
                  '掌握度',
                  CupertinoIcons.chart_pie_fill,
                  masteryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedQuestionIds.clear();
      }
    });
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选择 ${_selectedQuestionIds.length} 道题',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            CupertinoButton.filled(
              onPressed: _createGenerationTask,
              child: const Text('生成变式题'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToMistakePreview(String questionId, int questionIndex) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('错误'),
            content: const Text('请先登录'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }

      final client = authProvider.authService.client;
      _mistakeService.initialize(client);

      // 显示加载提示
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text('正在加载错题记录...'),
            ],
          ),
        ),
      );

      // 获取用户的所有错题记录
      final allMistakes = await _mistakeService.getUserMistakes(userId);
      
      // 筛选出匹配该 questionId 的错题记录
      final matchingMistakes = allMistakes
          .where((mistake) => mistake.questionId == questionId)
          .toList();

      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (matchingMistakes.isEmpty) {
        // 如果没有找到错题记录，显示提示
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('提示'),
              content: const Text('该题目还没有错题记录'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 获取错题记录的 ID 列表
      final mistakeRecordIds = matchingMistakes.map((m) => m.id).toList();
      
      // 找到当前题目在列表中的索引
      // 如果有多个错题记录，默认显示第一个
      final initialIndex = 0;

      // 导航到错题预览页面
      if (mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => MistakePreviewScreen(
              mistakeRecordIds: mistakeRecordIds,
              initialIndex: initialIndex,
            ),
          ),
        );
      }
    } catch (e) {
      print('导航到错题预览失败: $e');
      
      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误提示
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('加载失败'),
            content: Text('加载错题记录失败：$e'),
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

  Future<void> _createGenerationTask() async {
    if (_selectedQuestionIds.isEmpty) {
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('错误'),
            content: const Text('请先登录'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }

      final client = authProvider.authService.client;
      _questionGenerationService.initialize(client);

      // 显示加载提示
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text('正在创建任务...'),
            ],
          ),
        ),
      );

      // 创建任务（权限检查在 service 层进行）
      final task = await _questionGenerationService.createTask(
        userId: userId,
        sourceQuestionIds: _selectedQuestionIds.toList(),
        variantsPerQuestion: 1, // 默认每题生成1道变式
        userProfile: authProvider.userProfile,
      );

      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 退出选择模式
      setState(() {
        _isSelectionMode = false;
        _selectedQuestionIds.clear();
      });

      // 导航到进度页面
      if (mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => QuestionGenerationProgressScreen(
              taskId: task.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('创建任务失败: $e');
      
      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误提示
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('创建失败'),
            content: Text('创建任务失败：$e'),
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
}

