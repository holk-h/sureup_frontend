import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator, Material, InkWell, BoxDecoration, BorderRadius, MaterialPageRoute;
import '../models/daily_task.dart';
import '../models/question.dart';
import '../models/review_state.dart';
import '../services/mistake_service.dart';
import '../services/review_state_service.dart';
import '../config/colors.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/common/question_source_badge.dart';
import '../widgets/common/review_status_icon.dart';
import '../widgets/common/math_markdown_text.dart';
import 'task_completion_screen.dart';

/// 任务练习页面
class TaskPracticeScreen extends StatefulWidget {
  final DailyTask task;
  final int itemIndex;

  const TaskPracticeScreen({
    super.key,
    required this.task,
    required this.itemIndex,
  });

  @override
  State<TaskPracticeScreen> createState() => _TaskPracticeScreenState();
}

class _TaskPracticeScreenState extends State<TaskPracticeScreen> {
  final MistakeService _mistakeService = MistakeService();
  final ReviewStateService _reviewStateService = ReviewStateService();

  late TaskItem _currentItem;
  int _currentQuestionIndex = 0;
  List<Question?> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 答题记录
  final Map<int, bool> _answerResults = {}; // 题目索引 -> 是否已完成
  final Map<int, String> _userAnswers = {}; // 题目索引 -> 用户反馈选项
  bool _showStandardAnswer = false; // 是否显示标准答案
  bool _showSolvingHint = false; // 是否显示解题提示
  String? _currentSelection; // 当前题目的选择状态
  
  // 根据学习状态默认展开答案
  bool get _shouldDefaultExpandAnswer => _currentItem.status == ReviewStatus.newLearning;
  
  // 知识点和模块信息缓存
  final Map<String, Map<String, String>> _knowledgePointsInfo = {};
  final Map<String, Map<String, String>> _modulesInfo = {};

  @override
  void initState() {
    super.initState();
    _currentItem = widget.task.items[widget.itemIndex];
    // 延迟加载，等待页面切换动画完全结束
    Future.delayed(const Duration(milliseconds: 30), () {
      if (mounted) {
    _loadQuestions();
      }
    });
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 让 UI 先渲染加载状态
    await Future.delayed(const Duration(milliseconds: 30));

    try {
      // 并行加载所有题目
      final questionFutures = _currentItem.questions.map((taskQuestion) {
        return _mistakeService.getQuestion(taskQuestion.questionId);
      }).toList();
      
      final questions = await Future.wait(questionFutures);

      // 收集所有知识点和模块ID
      final allKpIds = <String>{};
      final allModuleIds = <String>{};
      for (final question in questions) {
        if (question != null) {
          allKpIds.addAll(question.knowledgePointIds);
          allModuleIds.addAll(question.moduleIds);
        }
      }

      // 并行加载知识点和模块信息
      final futures = <Future>[];

      if (allKpIds.isNotEmpty) {
        futures.add(
          _mistakeService.getKnowledgePoints(allKpIds.toList()).then((kps) {
        _knowledgePointsInfo.addAll(kps);
          })
        );
      }

      if (allModuleIds.isNotEmpty) {
        futures.add(
          _mistakeService.getModules(allModuleIds.toList()).then((modules) {
        _modulesInfo.addAll(modules);
          })
        );
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
          // 新学习状态默认展开答案
          _showStandardAnswer = _shouldDefaultExpandAnswer;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleNextQuestion() {
    if (_currentQuestionIndex < _currentItem.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        // 新学习状态默认展开答案
        _showStandardAnswer = _shouldDefaultExpandAnswer;
        _showSolvingHint = false;
        // 恢复当前题目的选择状态
        _currentSelection = _userAnswers[_currentQuestionIndex];
      });
    } else {
      // 最后一题，检查是否所有题目都做完了
      _checkAndCompleteTask();
    }
  }

  void _checkAndCompleteTask() {
    final totalQuestions = _currentItem.questions.length;
    final completedCount = _answerResults.length;

    if (completedCount < totalQuestions) {
      // 还有题目未完成，显示提示
      final uncompletedCount = totalQuestions - completedCount;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('还有题目未完成'),
          content: Text('还有 $uncompletedCount 道题未作答，请完成所有题目后再提交'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } else {
      // 所有题目完成，跳转到完成页面
      _navigateToCompletion();
    }
  }

  void _handlePreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        // 新学习状态默认展开答案
        _showStandardAnswer = _shouldDefaultExpandAnswer;
        _showSolvingHint = false;
        // 恢复当前题目的选择状态
        _currentSelection = _userAnswers[_currentQuestionIndex];
      });
    }
  }

  void _handleUnderstanding(String feedback) {
    // 记录用户反馈
    setState(() {
      _currentSelection = feedback;
      _answerResults[_currentQuestionIndex] = true; // 标记为已完成
      _userAnswers[_currentQuestionIndex] = feedback; // 记录用户反馈
    });
  }

  Future<void> _navigateToCompletion() async {
    // 1. 更新知识点的复习状态
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;
      
      if (userId != null) {
        // 综合所有题目的反馈，更新知识点的复习状态
        // 策略：取最后一题的反馈作为整体反馈（因为用户做完所有题后的感受更准确）
        final lastFeedback = _userAnswers[_currentQuestionIndex];
        
        if (lastFeedback != null) {
          // 先获取当前的复习状态
          final currentState = await _reviewStateService.getReviewState(
            userId,
            _currentItem.knowledgePointId,
          );
          
          // 更新状态
          await _reviewStateService.updateReviewState(
            userId: userId,
            knowledgePointId: _currentItem.knowledgePointId,
            currentStatus: _currentItem.status,
            currentMasteryScore: currentState?.masteryScore ?? 0,
            currentInterval: currentState?.currentInterval ?? 1,
            consecutiveCorrect: currentState?.consecutiveCorrect ?? 0,
            feedback: lastFeedback,
          );
        }
      }
    } catch (e) {
      print('❌ 更新复习状态失败: $e');
      // 即使更新失败也继续流程，不影响用户体验
    }

    // 2. 跳转到完成页面
    if (!mounted) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskCompletionScreen(
          task: widget.task,
          item: _currentItem,
          itemIndex: widget.itemIndex,
        ),
      ),
    );

    // 3. 返回到任务列表
    if (mounted && result == true) {
      Navigator.pop(context, true);
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
            CupertinoIcons.back,
            color: AppColors.textPrimary,
          ),
        ),
        middle: Text(
          _currentItem.knowledgePointName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_questions.isEmpty || _questions[_currentQuestionIndex] == null) {
      return const Center(
        child: Text('题目加载失败'),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex]!;
    final taskQuestion = _currentItem.questions[_currentQuestionIndex];

    return SafeArea(
      child: Column(
        children: [
          // 进度指示器
          _buildProgressIndicator(),

          // AI 提示（如果有）
          if (_currentItem.aiMessage != null && _currentItem.aiMessage!.isNotEmpty)
            _buildAIHint(),

          // 题目内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 题目来源标签
                  Row(
                    children: [
                      QuestionSourceBadge(source: taskQuestion.source),
                      const SizedBox(width: 8),
                      Text(
                        '第 ${_currentQuestionIndex + 1} / ${_currentItem.questions.length} 题',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 题目卡片
                  _buildQuestionCard(currentQuestion),

                  const SizedBox(height: 16),

                  // 学习引导提示
                  _buildLearningHint(),

                  const SizedBox(height: 16),

                  // 答案和理解程度区域（根据学习状态差异化）
                  _buildAnswerAndFeedbackView(currentQuestion),
                  
                  // 底部额外间距，避免被底部按钮遮挡
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // 底部导航按钮
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // 计算真正完成的题目数量
    final completedCount = _answerResults.length;
    final totalCount = _currentItem.questions.length;
    final progress = completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '已完成：$completedCount / $totalCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReviewStatusIcon(
                    status: _currentItem.status,
                    showLabel: false,
                    size: 16,
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.coloredShadow(AppColors.accent, opacity: 0.1),
      ),
      child: Row(
        children: [
            const Icon(
              CupertinoIcons.lightbulb,
              color: Colors.white,
              size: 24,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentItem.aiMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryUltraLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  question.type.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentUltraLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  question.difficulty.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 题目内容
          MathMarkdownText(
            text: question.content,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),

          // 选择题选项
          if (question.type == QuestionType.choice && question.options != null) ...[
            const SizedBox(height: 16),
            ...question.options!.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              // 提取选项的真实标识符（如果选项以A.、B.等开头）
              final optionMatch = RegExp(r'^([A-Z])[.、]\s*(.*)').firstMatch(option);
              final optionLabel = optionMatch?.group(1) ?? String.fromCharCode(65 + index);
              final optionContent = optionMatch?.group(2) ?? option;
              
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          optionLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MathMarkdownText(
                        text: optionContent,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          
          // 知识点标签
          const SizedBox(height: 20),
          _buildKnowledgePointTags(),
        ],
      ),
    );
  }

  Widget _buildKnowledgePointTags() {
    final question = _questions[_currentQuestionIndex];
    if (question == null) {
      return const SizedBox.shrink();
    }

    final tags = <Widget>[];

    // 1. 先显示模块标签
    for (final moduleId in question.moduleIds) {
      final moduleInfo = _modulesInfo[moduleId];
      final moduleName = moduleInfo?['name'] ?? '未知模块';
      
      tags.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.1),
                AppColors.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.square_grid_2x2_fill,
                size: 10,
                color: AppColors.accent.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                moduleName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent.withOpacity(0.9),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. 后显示知识点标签
    for (final kpId in question.knowledgePointIds) {
      final kpInfo = _knowledgePointsInfo[kpId];
      final kpName = kpInfo?['name'] ?? '未知知识点';
      
      tags.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.circle_fill,
                size: 6,
                color: AppColors.primary.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                kpName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary.withOpacity(0.9),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags,
    );
  }

  /// 学习引导提示（根据学习状态显示不同的引导文案）
  Widget _buildLearningHint() {
    String hintText;
    IconData hintIcon;
    Color hintColor;

    switch (_currentItem.status) {
      case ReviewStatus.newLearning:
        hintText = '💡 这是新知识点，认真看答案和解题思路';
        hintIcon = CupertinoIcons.lightbulb_fill;
        hintColor = const Color(0xFF10B981); // 绿色
        break;
      case ReviewStatus.reviewing:
        hintText = '🔄 先自己回忆解题思路，再查看答案';
        hintIcon = CupertinoIcons.arrow_2_circlepath;
        hintColor = const Color(0xFFF59E0B); // 橙色
        break;
      case ReviewStatus.mastered:
        hintText = '🎯 测试一下掌握情况，自己先做一遍';
        hintIcon = CupertinoIcons.scope;
        hintColor = const Color(0xFF3B82F6); // 蓝色
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hintColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hintColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hintIcon,
            color: hintColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: hintColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据学习状态差异化的答案和反馈视图
  Widget _buildAnswerAndFeedbackView(Question question) {
    final taskQuestion = _currentItem.questions[_currentQuestionIndex];
    final isOriginalWithoutAnswer = taskQuestion.source == QuestionSource.original && 
                                     (question.answer == null || question.answer!.trim().isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 答案卡片
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isOriginalWithoutAnswer 
                ? AppColors.warning.withOpacity(0.05)
                : AppColors.success.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOriginalWithoutAnswer
                  ? AppColors.warning.withOpacity(0.2)
                  : AppColors.success.withOpacity(0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和展开按钮
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onPressed: () {
                    setState(() {
                      _showStandardAnswer = !_showStandardAnswer;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        isOriginalWithoutAnswer 
                            ? CupertinoIcons.exclamationmark_circle
                            : CupertinoIcons.check_mark_circled,
                        color: isOriginalWithoutAnswer ? AppColors.warning : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '标准答案',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isOriginalWithoutAnswer ? AppColors.warning : AppColors.success,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showStandardAnswer ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                // 预渲染内容，只切换可见性
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Offstage(
                      offstage: !_showStandardAnswer,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: isOriginalWithoutAnswer
                            ? CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _showAddAnswerDialog(question),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.warning.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        CupertinoIcons.add_circled,
                                        color: AppColors.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '暂未录入，点击添加',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : question.answer != null
                                ? RepaintBoundary(
                                    child: MathMarkdownText(
                                      text: question.answer!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        height: 1.5,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),


        // 解题提示
        if (question.solvingHint != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onPressed: () {
                      setState(() {
                        _showSolvingHint = !_showSolvingHint;
                      });
                    },
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.lightbulb,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '解题提示',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showSolvingHint ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  // 预渲染内容，只切换可见性
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Offstage(
                        offstage: !_showSolvingHint,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: RepaintBoundary(
                            child: MathMarkdownText(
                              text: question.solvingHint!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 反馈询问（根据学习状态差异化）
        const SizedBox(height: 24),
        _buildFeedbackPrompt(),
        const SizedBox(height: 12),
        _buildFeedbackButtons(),
      ],
    );
  }

  /// 反馈提示文案（根据学习状态）
  Widget _buildFeedbackPrompt() {
    String promptText;
    
    switch (_currentItem.status) {
      case ReviewStatus.newLearning:
        promptText = '看完答案后，你的理解程度如何？';
        break;
      case ReviewStatus.reviewing:
        promptText = '回忆起来了吗？';
        break;
      case ReviewStatus.mastered:
        promptText = '自己做完后，对照一下答案：';
        break;
    }

    return Text(
      promptText,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// 反馈按钮（根据学习状态显示不同选项）
  Widget _buildFeedbackButtons() {
    switch (_currentItem.status) {
      case ReviewStatus.newLearning:
        return Row(
          children: [
            Expanded(
              child: _buildFeedbackButton(
                '完全看懂了',
                CupertinoIcons.smiley_fill,
                const Color(0xFF10B981), // 绿色
                const Color(0xFF34D399),
                _currentSelection == '完全看懂了',
                () => _handleUnderstanding('完全看懂了'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '大致理解了',
                CupertinoIcons.minus_circle_fill,
                const Color(0xFF8B5CF6), // 紫色
                const Color(0xFFA78BFA),
                _currentSelection == '大致理解了',
                () => _handleUnderstanding('大致理解了'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '还是不太懂',
                CupertinoIcons.xmark_circle_fill,
                const Color(0xFFEC4899), // 粉色
                const Color(0xFFF472B6),
                _currentSelection == '还是不太懂',
                () => _handleUnderstanding('还是不太懂'),
              ),
            ),
          ],
        );

      case ReviewStatus.reviewing:
        return Row(
          children: [
            Expanded(
              child: _buildFeedbackButton(
                '一看就会了',
                CupertinoIcons.smiley_fill,
                const Color(0xFF10B981), // 绿色
                const Color(0xFF34D399),
                _currentSelection == '一看就会了',
                () => _handleUnderstanding('一看就会了'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '想了会儿才懂',
                CupertinoIcons.minus_circle_fill,
                const Color(0xFF8B5CF6), // 紫色
                const Color(0xFFA78BFA),
                _currentSelection == '想了会儿才懂',
                () => _handleUnderstanding('想了会儿才懂'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '完全想不起来',
                CupertinoIcons.xmark_circle_fill,
                const Color(0xFFEC4899), // 粉色
                const Color(0xFFF472B6),
                _currentSelection == '完全想不起来',
                () => _handleUnderstanding('完全想不起来'),
              ),
            ),
          ],
        );

      case ReviewStatus.mastered:
        return Row(
          children: [
            Expanded(
              child: _buildFeedbackButton(
                '做对了',
                CupertinoIcons.checkmark_circle_fill,
                const Color(0xFF10B981), // 绿色
                const Color(0xFF34D399),
                _currentSelection == '做对了',
                () => _handleUnderstanding('做对了'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '做错了但看懂了',
                CupertinoIcons.minus_circle_fill,
                const Color(0xFF8B5CF6), // 紫色
                const Color(0xFFA78BFA),
                _currentSelection == '做错了但看懂了',
                () => _handleUnderstanding('做错了但看懂了'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackButton(
                '还是不太会',
                CupertinoIcons.xmark_circle_fill,
                const Color(0xFFEC4899), // 粉色
                const Color(0xFFF472B6),
                _currentSelection == '还是不太会',
                () => _handleUnderstanding('还是不太会'),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFeedbackButton(
    String label,
    IconData icon,
    Color primaryColor,
    Color lightColor,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, lightColor],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.15),
                  lightColor.withOpacity(0.08),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primaryColor : primaryColor.withOpacity(0.2),
          width: isSelected ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(isSelected ? 0.3 : 0.15),
            blurRadius: isSelected ? 16 : 12,
            offset: Offset(0, isSelected ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: isSelected 
              ? Colors.white.withOpacity(0.2)
              : primaryColor.withOpacity(0.2),
          highlightColor: isSelected 
              ? Colors.white.withOpacity(0.1)
              : primaryColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : primaryColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: CupertinoButton(
                onPressed: _handlePreviousQuestion,
                color: CupertinoColors.systemGrey5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.back, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      '上一题',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          if (_currentQuestionIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: CupertinoButton.filled(
              onPressed: _currentSelection != null ? _handleNextQuestion : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _currentQuestionIndex < _currentItem.questions.length - 1
                        ? CupertinoIcons.forward
                        : CupertinoIcons.check_mark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentQuestionIndex < _currentItem.questions.length - 1
                        ? '下一题'
                        : '完成',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return SafeArea(
      child: Column(
        children: [
          // 进度指示器占位
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      height: 16,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),

          // 题目内容区域占位
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签占位
                  Row(
                    children: [
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 16,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 题目卡片占位
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.shadowSoft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 24,
                              width: 60,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 24,
                              width: 50,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 20,
                          width: double.infinity * 0.8,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 20,
                          width: double.infinity * 0.6,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Loading indicator
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部按钮占位
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '加载失败',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
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


  /// 显示添加答案的弹窗
  void _showAddAnswerDialog(Question question) {
    // 如果是选择题，显示选项选择器
    if (question.type == QuestionType.choice && question.options != null && question.options!.isNotEmpty) {
      _showChoiceAnswerDialog(question);
    } else {
      // 其他题型显示输入框
      _showTextAnswerDialog(question);
    }
  }

  /// 显示选择题答案选择器
  void _showChoiceAnswerDialog(Question question) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择答案',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '请选择正确答案选项',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppColors.textTertiary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            // 选项列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: question.options!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  // 提取选项的真实标识符（如果选项以A.、B.等开头）
                  final optionMatch = RegExp(r'^([A-Z])[.、]\s*(.*)').firstMatch(option);
                  final optionLabel = optionMatch?.group(1) ?? String.fromCharCode(65 + index);
                  final optionContent = optionMatch?.group(2) ?? option;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pop(context);
                        _updateQuestionAnswer(question, optionLabel, null);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 1,
                          ),
                          boxShadow: AppColors.shadowSoft,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  optionLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: MathMarkdownText(
                                  text: optionContent,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示文本答案输入框
  void _showTextAnswerDialog(Question question) {
    final TextEditingController answerController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('添加答案'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: answerController,
            placeholder: '请输入答案',
            maxLines: 1,
            padding: const EdgeInsets.all(12),
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final answer = answerController.text.trim();
              if (answer.isEmpty) {
                // 显示提示
                return;
              }

              Navigator.pop(context);

              // 调用服务更新答案
              await _updateQuestionAnswer(question, answer, null);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 更新题目答案
  Future<void> _updateQuestionAnswer(
    Question question,
    String answer,
    String? explanation,
  ) async {
    try {
      // 调用 MistakeService 更新答案到数据库
      await _mistakeService.updateQuestionAnswer(question.id, answer);

      // 清除题目缓存，强制重新加载
      _mistakeService.clearQuestionCache(question.id);

      // 重新加载题目数据以获取更新后的答案
      await _loadQuestions();

      if (mounted) {
        // 显示成功提示
        showCupertinoDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('保存成功'),
            content: const Text('答案已添加'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('保存失败'),
            content: Text('无法保存答案：$e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    }
  }
}

