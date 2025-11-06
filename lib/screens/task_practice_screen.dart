import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator, Material, InkWell, BoxDecoration, BorderRadius, MaterialPageRoute;
import '../models/daily_task.dart';
import '../models/question.dart';
import '../services/mistake_service.dart';
import '../config/colors.dart';
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

  late TaskItem _currentItem;
  int _currentQuestionIndex = 0;
  List<Question?> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 答题记录
  final Map<int, bool> _answerResults = {}; // 题目索引 -> 是否已完成r
  final Map<int, String> _userAnswers = {}; // 题目索引 -> 理解程度
  bool _showStandardAnswer = false; // 是否显示标准答案
  bool _showSolvingHint = false; // 是否显示解题提示
  String? _currentSelection; // 当前题目的选择状态
  
  // 知识点和模块信息缓存
  final Map<String, Map<String, String>> _knowledgePointsInfo = {};
  final Map<String, Map<String, String>> _modulesInfo = {};

  @override
  void initState() {
    super.initState();
    _currentItem = widget.task.items[widget.itemIndex];
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 加载所有题目
      final questions = <Question?>[];
      for (final taskQuestion in _currentItem.questions) {
        final question = await _mistakeService.getQuestion(taskQuestion.questionId);
        questions.add(question);
      }

      // 加载所有题目的知识点和模块信息
      final allKpIds = <String>{};
      final allModuleIds = <String>{};
      for (final question in questions) {
        if (question != null) {
          allKpIds.addAll(question.knowledgePointIds);
          allModuleIds.addAll(question.moduleIds);
        }
      }

      if (allKpIds.isNotEmpty) {
        final kps = await _mistakeService.getKnowledgePoints(allKpIds.toList());
        _knowledgePointsInfo.addAll(kps);
      }

      if (allModuleIds.isNotEmpty) {
        final modules = await _mistakeService.getModules(allModuleIds.toList());
        _modulesInfo.addAll(modules);
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
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
        _showStandardAnswer = false;
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
        _showStandardAnswer = false;
        _showSolvingHint = false;
        // 恢复当前题目的选择状态
        _currentSelection = _userAnswers[_currentQuestionIndex];
      });
    }
  }

  void _handleUnderstanding(String level) {
    // 理解程度反馈（所有学习状态通用）
    setState(() {
      _currentSelection = level;
      _answerResults[_currentQuestionIndex] = true; // 标记为已查看
      _userAnswers[_currentQuestionIndex] = level; // 记录理解程度
    });
  }

  Future<void> _navigateToCompletion() async {
    final correctCount = _answerResults.values.where((isCorrect) => isCorrect).length;
    final wrongCount = _answerResults.values.where((isCorrect) => !isCorrect).length;

    // 跳转到完成页面
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskCompletionScreen(
          task: widget.task,
          item: _currentItem,
          itemIndex: widget.itemIndex,
          correctCount: correctCount,
          wrongCount: wrongCount,
        ),
      ),
    );

    // 返回到任务列表
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
      return const Center(
        child: CupertinoActivityIndicator(),
      );
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

                  // 答案和理解程度区域（统一流程）
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

  /// 统一的答案和反馈视图（所有学习状态通用）
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

        // 理解程度询问
        const SizedBox(height: 24),
        const Text(
          '这道题理解了吗？',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildUnderstandingButton(
                '完全理解',
                CupertinoIcons.checkmark_circle_fill,
                const Color(0xFF10B981), // 清新绿
                const Color(0xFF34D399), // 亮绿
                _currentSelection == '完全理解',
                () => _handleUnderstanding('完全理解'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUnderstandingButton(
                '基本理解',
                CupertinoIcons.minus_circle_fill,
                const Color(0xFF8B5CF6), // 柔和紫
                const Color(0xFFA78BFA), // 亮紫
                _currentSelection == '基本理解',
                () => _handleUnderstanding('基本理解'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUnderstandingButton(
                '还不太懂',
                CupertinoIcons.xmark_circle_fill,
                const Color(0xFFEC4899), // 温暖粉
                const Color(0xFFF472B6), // 亮粉
                _currentSelection == '还不太懂',
                () => _handleUnderstanding('还不太懂'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnderstandingButton(
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('选择答案'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: question.options!.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              // 提取选项的真实标识符（如果选项以A.、B.等开头）
              final optionMatch = RegExp(r'^([A-Z])[.、]\s*(.*)').firstMatch(option);
              final optionLabel = optionMatch?.group(1) ?? String.fromCharCode(65 + index);
              final optionContent = optionMatch?.group(2) ?? option;

              return CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                onPressed: () {
                  Navigator.pop(context);
                  _updateQuestionAnswer(question, optionLabel, null);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
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
                        child: Text(
                          optionContent,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
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

