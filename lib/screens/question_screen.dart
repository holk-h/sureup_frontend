import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import 'practice_result_screen.dart';

/// 答题页面 - 通用组件
class QuestionScreen extends StatefulWidget {
  final PracticeSession session;
  final List<Question> questions;

  const QuestionScreen({
    super.key,
    required this.session,
    required this.questions,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int _currentIndex = 0;
  Set<String> _selectedAnswers = {}; // 改为支持多选
  bool _hasSubmitted = false;
  late PracticeSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Question get _currentQuestion => widget.questions[_currentIndex];
  bool get _isLastQuestion => _currentIndex == widget.questions.length - 1;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(),
            
            // 题目内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 题目内容
                    _buildQuestionContent(),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 选项
                    _buildOptions(),
                    
                    const SizedBox(height: AppConstants.spacingL),
                    
                    // 解析（提交后显示）
                    if (_hasSubmitted) _buildExplanation(),
                  ],
                ),
              ),
            ),
            
            // 底部按钮
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showExitDialog(),
            child: const Icon(
              CupertinoIcons.back,
              color: AppColors.textPrimary,
            ),
          ),
          
          // 进度
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.session.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 44), // 占位，保持居中
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 知识点标签
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentQuestion.subject?.displayName ?? '未知学科'} · ${_currentQuestion.knowledgePointName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(height: AppConstants.spacingM),
          
          // 题目内容
          Text(
            _currentQuestion.content,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              height: 1.6,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Column(
      children: List.generate(
        _currentQuestion.options?.length ?? 0,
        (index) {
          final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
          final isSelected = _selectedAnswers.contains(optionLabel);
          
          // 判断选项是否是正确答案的一部分
          final correctAnswer = _currentQuestion.answer ?? '';
          // 支持逗号分隔的格式 "A,C" 或无分隔符 "AC"
          final correctOptions = correctAnswer.contains(',') 
              ? correctAnswer.split(',') 
              : correctAnswer.split('');
          final isCorrectOption = correctOptions.contains(optionLabel);
          
          Color? backgroundColor;
          Color? borderColor;
          
          if (_hasSubmitted) {
            if (isCorrectOption) {
              // 正确答案显示绿色
              backgroundColor = AppColors.success.withOpacity(0.1);
              borderColor = AppColors.success;
            } else if (isSelected && !isCorrectOption) {
              // 选错的显示红色
              backgroundColor = AppColors.error.withOpacity(0.1);
              borderColor = AppColors.error;
            }
          } else if (isSelected) {
            // 选中状态显示主色
            backgroundColor = AppColors.primary.withOpacity(0.1);
            borderColor = AppColors.primary;
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
            child: GestureDetector(
              onTap: _hasSubmitted ? null : () {
                setState(() {
                  if (_selectedAnswers.contains(optionLabel)) {
                    _selectedAnswers.remove(optionLabel);
                  } else {
                    _selectedAnswers.add(optionLabel);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  color: backgroundColor ?? AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: borderColor ?? AppColors.divider,
                    width: borderColor != null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 选项标签
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: borderColor?.withOpacity(0.1) ?? AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor ?? AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          optionLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: borderColor ?? AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppConstants.spacingM),
                    
                    // 选项内容
                    Expanded(
                      child: Text(
                        _currentQuestion.options?[index] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    // 对错图标
                    if (_hasSubmitted && isCorrectOption)
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: AppColors.success,
                        size: 24,
                      )
                    else if (_hasSubmitted && isSelected && !isCorrectOption)
                      const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppColors.error,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplanation() {
    // 构建用户答案（排序并用逗号分隔）
    final sortedAnswers = _selectedAnswers.toList()..sort();
    final userAnswerStr = sortedAnswers.join(',');
    final isCorrect = userAnswerStr == (_currentQuestion.answer ?? '');
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: isCorrect 
            ? AppColors.success.withOpacity(0.05)
            : AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isCorrect 
              ? AppColors.success.withOpacity(0.2)
              : AppColors.accent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                isCorrect 
                    ? CupertinoIcons.checkmark_alt_circle_fill
                    : CupertinoIcons.lightbulb_fill,
                color: isCorrect ? AppColors.success : AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '✓ 回答正确！' : '💡 解析',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isCorrect ? AppColors.success : AppColors.accent,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingM),
          
          // 解析内容
          Text(
            _currentQuestion.explanation ?? '',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: _selectedAnswers.isNotEmpty ? AppColors.primary : AppColors.divider,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          onPressed: _selectedAnswers.isNotEmpty ? _handleButtonPress : null,
          child: Text(
            _hasSubmitted
                ? (_isLastQuestion ? '查看结果' : '下一题')
                : '提交答案',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.cardBackground,
            ),
          ),
        ),
      ),
    );
  }

  void _handleButtonPress() {
    if (!_hasSubmitted) {
      // 提交答案
      setState(() {
        _hasSubmitted = true;
        
        // 构建用户答案（排序并用逗号分隔）
        final sortedAnswers = _selectedAnswers.toList()..sort();
        final userAnswerStr = sortedAnswers.join(',');
        
        // 检查是否正确（完全匹配）
        final isCorrect = userAnswerStr == (_currentQuestion.answer ?? '');
        
        // 更新会话数据 - 使用新的QuestionResult模型
        final newResult = QuestionResult(
          questionId: _currentQuestion.id,
          userAnswer: userAnswerStr,
          isCorrect: isCorrect,
          timeSpent: 0, // TODO: 实际计算用时
          answeredAt: DateTime.now(),
        );
        
        final updatedResults = [..._session.results, newResult];
        _session = _session.copyWith(
          results: updatedResults,
        );
      });
    } else {
      // 下一题或完成
      if (_isLastQuestion) {
        _completeSession();
      } else {
        setState(() {
          _currentIndex++;
          _selectedAnswers.clear();
          _hasSubmitted = false;
        });
      }
    }
  }

  void _completeSession() {
    // 完成练习会话
    final completedSession = _session.copyWith(
      completedAt: DateTime.now(),
      aiEncouragement: _generateEncouragement(),
    );
    
    // 导航到结果页
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => PracticeResultScreen(
          session: completedSession,
          questions: widget.questions,
        ),
      ),
    );
  }

  String _generateEncouragement() {
    final accuracy = _session.accuracy;
    
    if (accuracy >= 0.9) {
      return '太棒了！你已经完全掌握了！';
    } else if (accuracy >= 0.7) {
      return '稳了！这些知识点你基本掌握了～';
    } else if (accuracy >= 0.5) {
      return '不错！继续保持，你会越来越好的！';
    } else {
      return '加油！这部分内容可以再复习一下～';
    }
  }

  void _showExitDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确定要退出吗？'),
        content: const Text('当前练习进度将不会保存'),
        actions: [
          CupertinoDialogAction(
            child: const Text('继续练习'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(); // 返回上一页
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

