import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';
import '../../services/mistake_service.dart';
import '../common/math_markdown_text.dart';
import 'common/answer_widgets.dart';
import 'common/mistake_section.dart';
import 'common/question_content_widgets.dart';
import 'error_reason_selector.dart';
// import 'edit_answer_dialog.dart';
import 'mistake_note_section.dart';

/// 题目详情卡片组件
class QuestionDetailsCard extends StatefulWidget {
  final Question question;
  final MistakeRecord mistakeRecord;
  final Map<String, Map<String, String>> modulesInfo;
  final Map<String, Map<String, String>> knowledgePointsInfo;
  final Function(String) onErrorReasonChanged;
  final Future<void> Function(String)? onReportOcrError;

  const QuestionDetailsCard({
    super.key,
    required this.question,
    required this.mistakeRecord,
    required this.modulesInfo,
    required this.knowledgePointsInfo,
    required this.onErrorReasonChanged,
    this.onReportOcrError,
  });

  @override
  State<QuestionDetailsCard> createState() => _QuestionDetailsCardState();
}

class _QuestionDetailsCardState extends State<QuestionDetailsCard>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<double>> _itemAnimations;
  late List<Animation<Offset>> _slideAnimations;
  Set<String> _selectedAnswers = {};
  Set<String> _selectedUserAnswers = {};

  @override
  void initState() {
    super.initState();
    _initSelectedAnswers();
    _initSelectedUserAnswers();
    _setupStaggeredAnimations();
    _startAnimation();
  }

  void _initSelectedAnswers() {
    // 优先使用 MistakeRecord 中的 correctAnswer，如果为空则使用 Question 中的 answer
    final answer = widget.mistakeRecord.correctAnswer?.isNotEmpty == true
        ? widget.mistakeRecord.correctAnswer!
        : (widget.question.answer ?? '');

    if (answer.isNotEmpty) {
      if (answer.contains(',')) {
        _selectedAnswers = answer.split(',').toSet();
      } else {
        if (widget.question.options?.isNotEmpty == true && answer.length > 1) {
          _selectedAnswers = answer.split('').toSet();
        } else {
          _selectedAnswers = {answer};
        }
      }
    } else {
      _selectedAnswers = {};
    }
  }

  void _initSelectedUserAnswers() {
    final answer = widget.mistakeRecord.userAnswer ?? '';
    if (answer.isNotEmpty) {
      if (answer.contains(',')) {
        _selectedUserAnswers = answer.split(',').toSet();
      } else {
        if (widget.question.options?.isNotEmpty == true && answer.length > 1) {
          _selectedUserAnswers = answer.split('').toSet();
        } else {
          _selectedUserAnswers = {answer};
        }
      }
    } else {
      _selectedUserAnswers = {};
    }
  }

  @override
  void didUpdateWidget(QuestionDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.answer != widget.question.answer ||
        oldWidget.mistakeRecord.correctAnswer !=
            widget.mistakeRecord.correctAnswer) {
      _initSelectedAnswers();
    }
    if (oldWidget.mistakeRecord.userAnswer != widget.mistakeRecord.userAnswer) {
      _initSelectedUserAnswers();
    }
  }

  void _setupStaggeredAnimations() {
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 计算需要动画的项目数量（题目、选项、答案区、错因、模块、知识点、解题提示）
    // 使用更大的数量以覆盖所有可能的组合
    final itemCount = 10;
    _itemAnimations = List.generate(itemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.6;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _slideAnimations = List.generate(itemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.6;
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _staggerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    // 安全检查：如果索引超出范围，返回原始 widget
    if (index >= _itemAnimations.length) {
      return child;
    }
    return FadeTransition(
      opacity: _itemAnimations[index],
      child: SlideTransition(position: _slideAnimations[index], child: child),
    );
  }

  Widget _buildOcrFeedbackButton() {
    return GestureDetector(
      onTap: _showOcrFeedbackDialog,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '识别错误？点击更新',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showOcrFeedbackDialog() {
    final TextEditingController controller = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('反馈识别错误'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              placeholder: '例如：A选项的“B”应该是“13”',
              maxLines: 3,
              minLines: 1,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                return;
              }

              Navigator.of(context).pop();

              try {
                // 调用服务反馈 OCR 错误
                if (widget.onReportOcrError != null) {
                  await widget.onReportOcrError!(reason);
                } else {
                  // 降级方案：直接调用 MistakeService（如果没有传递回调）
                  await MistakeService().reportOcrError(
                    widget.mistakeRecord.id,
                    reason,
                  );
                }

                // 提交成功，状态会通过 Realtime 自动更新，页面会显示"AI 分析中"
                // 不需要手动刷新或关闭页面
              } catch (e) {
                // 只在失败时显示提示
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('反馈失败'),
                      content: Text('$e'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('确定'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int animationIndex = 0;

    // 调试日志
    print('🎨 QuestionDetailsCard build:');
    print('   - moduleIds: ${widget.question.moduleIds}');
    print('   - knowledgePointIds: ${widget.question.knowledgePointIds}');
    print('   - modulesInfo: ${widget.modulesInfo}');
    print('   - knowledgePointsInfo: ${widget.knowledgePointsInfo}');

    return Container(
      margin: const EdgeInsets.only(
        left: AppConstants.spacingM,
        right: AppConstants.spacingM,
        top: 0,
        bottom: AppConstants.spacingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容 (索引 0)
          _buildAnimatedItem(
            animationIndex++,
            MistakeSection(
              title: '题目内容',
              icon: CupertinoIcons.doc_text,
              actionButton: _buildOcrFeedbackButton(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MathMarkdownText(
                    text: widget.question.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (widget.question.extractedImages != null &&
                      widget.question.extractedImages!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ExtractedImagesWidget(
                        extractedImages: widget.question.extractedImages),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 选项（选择题）(索引 1)
          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            _buildAnimatedItem(
              animationIndex++,
              MistakeSection(
                title: '选项',
                icon: CupertinoIcons.list_bullet,
                child: OptionsListWidget(options: widget.question.options!),
              ),
            ),

          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            const SizedBox(height: AppConstants.spacingM),

          // 答案对比 (索引 2)
          _buildAnimatedItem(
            animationIndex++,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 我的答案
                  Expanded(
                    child: MistakeSection(
                      title: '我的答案',
                      icon: CupertinoIcons.person_fill,
                      iconColor: AppColors.secondary,
                      isEditable: true,
                      child: _buildUserAnswerWidget(),
                    ),
                  ),

                  const SizedBox(width: AppConstants.spacingM),

                  // 正确答案
                  Expanded(
                    child: MistakeSection(
                      title: '正确答案',
                      icon: CupertinoIcons.checkmark_seal_fill,
                      iconColor: AppColors.success,
                      isEditable: true,
                      child: _buildAnswerWidget(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 错题笔记 (索引 3)
          _buildAnimatedItem(
            animationIndex++,
            MistakeSection(
              title: '错题笔记',
              icon: CupertinoIcons.pencil,
              iconColor: AppColors.primary,
              isEditable: true,
              child: MistakeNoteSection(
                mistakeRecord: widget.mistakeRecord,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 错因分析 (索引 4)
          _buildAnimatedItem(
            animationIndex++,
            MistakeSection(
              title: '错因分析',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              iconColor: AppColors.error,
              isEditable: true,
              child: ErrorReasonSelector(
                mistakeRecord: widget.mistakeRecord,
                onErrorReasonChanged: widget.onErrorReasonChanged,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 模块标签 (索引 4)
          if (widget.question.moduleIds.isNotEmpty)
            Column(
              children: [
                _buildAnimatedItem(animationIndex++, _buildModuleSection()),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),

          // 知识点 (索引 5)
          if (widget.question.knowledgePointIds.isNotEmpty)
            Column(
              children: [
                _buildAnimatedItem(
                    animationIndex++, _buildKnowledgePointSection()),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),

          // 解题提示 (索引 6)
          if (widget.question.solvingHint != null &&
              widget.question.solvingHint!.isNotEmpty)
            _buildAnimatedItem(animationIndex++, _buildSolvingHintSection()),
        ],
      ),
    );
  }

  Widget _buildUserAnswerWidget() {
    // 判断是否为选择题
    final bool isChoiceQuestion =
        widget.question.options != null && widget.question.options!.isNotEmpty;

    if (isChoiceQuestion) {
      final optionCount = widget.question.options!.length;

      return ChoiceSelectorWidget(
        optionCount: optionCount,
        selectedAnswers: _selectedUserAnswers,
        activeColor: AppColors.error,
        onToggle: (label) async {
          setState(() {
            if (_selectedUserAnswers.contains(label)) {
              _selectedUserAnswers.remove(label);
            } else {
              _selectedUserAnswers.add(label);
            }
          });

          final sortedAnswers = _selectedUserAnswers.toList()..sort();
          final newAnswer = sortedAnswers.join(',');

          try {
            await MistakeService().updateMistakeRecord(
              recordId: widget.mistakeRecord.id,
              data: {'userAnswer': newAnswer},
            );
          } catch (e) {
            print('更新用户答案失败: $e');
            if (mounted) {
              _initSelectedUserAnswers();
              setState(() {});
            }
          }
        },
      );
    } else {
      // 非选择题
      return EditableTextCard(
        initialText: widget.mistakeRecord.userAnswer,
        placeholder: '点击记录',
        borderColor: AppColors.error,
        textColor: AppColors.error,
        onSave: (newAnswer) async {
          await MistakeService().updateMistakeRecord(
            recordId: widget.mistakeRecord.id,
            data: {'userAnswer': newAnswer},
          );
        },
      );
    }
  }

  Widget _buildAnswerWidget() {
    // 判断是否为选择题
    final bool isChoiceQuestion =
        widget.question.options != null && widget.question.options!.isNotEmpty;

    // 选择题：显示选项字母，直接点击更新答案
    if (isChoiceQuestion) {
      final optionCount = widget.question.options!.length;

      return ChoiceSelectorWidget(
        optionCount: optionCount,
        selectedAnswers: _selectedAnswers,
        activeColor: AppColors.success,
        onToggle: (label) async {
          // 更新本地状态（多选逻辑：反选）
          setState(() {
            if (_selectedAnswers.contains(label)) {
              _selectedAnswers.remove(label);
            } else {
              _selectedAnswers.add(label);
            }
          });

          // 构建新的答案字符串（排序并用逗号分隔）
          final sortedAnswers = _selectedAnswers.toList()..sort();
          final newAnswer = sortedAnswers.join(',');

          // 异步更新数据库
          try {
            // 更新 MistakeRecord 的 correctAnswer
            await MistakeService().updateMistakeRecord(
              recordId: widget.mistakeRecord.id,
              data: {'correctAnswer': newAnswer},
            );

            // 同时更新 Question 的 answer (如果需要同步)
            await MistakeService().updateQuestionAnswer(
              widget.question.id,
              newAnswer,
            );
          } catch (e) {
            print('更新答案失败: $e');
            // 如果更新失败，恢复原状态
            if (mounted) {
              _initSelectedAnswers();
              setState(() {});
            }
          }
        },
      );
    }

    return EditableTextCard(
      initialText: widget.mistakeRecord.correctAnswer?.isNotEmpty == true
          ? widget.mistakeRecord.correctAnswer
          : widget.question.answer,
      placeholder: '点击添加',
      borderColor: AppColors.success,
      textColor: AppColors.success,
      onSave: (newAnswer) async {
        // 更新 MistakeRecord 的 correctAnswer
        await MistakeService().updateMistakeRecord(
          recordId: widget.mistakeRecord.id,
          data: {'correctAnswer': newAnswer},
        );

        // 同时更新 Question 的 answer
        await MistakeService().updateQuestionAnswer(
          widget.question.id,
          newAnswer,
        );

        if (mounted) {
          // widget.onAnswerChanged(newAnswer);
        }
      },
    );
  }

  Widget _buildModuleSection() {
    final moduleIds = widget.question.moduleIds;

    return MistakeSection(
      title: moduleIds.length > 1 ? '相关模块（综合题）' : '相关模块',
      icon: CupertinoIcons.square_stack_3d_up_fill,
      iconColor: AppColors.primary,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: moduleIds.asMap().entries.map((entry) {
          final index = entry.key;
          final moduleId = entry.value;
          final moduleName = widget.modulesInfo[moduleId]?['name'] ?? '加载中...';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (moduleIds.length > 1)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                Text(
                  moduleName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKnowledgePointSection() {
    final kpIds = widget.question.knowledgePointIds;
    final primaryKpIds = widget.question.primaryKnowledgePointIds ?? [];

    return MistakeSection(
      title: '相关知识点 (${kpIds.length})',
      icon: CupertinoIcons.book_fill,
      iconColor: AppColors.accent,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kpIds.map((kpId) {
          final kpName = widget.knowledgePointsInfo[kpId]?['name'] ?? '加载中...';
          final isPrimary = primaryKpIds.contains(kpId);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.accent.withValues(alpha: 0.3),
                width: isPrimary ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPrimary)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      CupertinoIcons.star_fill,
                      size: 12,
                      color: AppColors.warning,
                    ),
                  ),
                MathMarkdownText(
                  text: kpName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                    color: isPrimary ? AppColors.warning : AppColors.accent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSolvingHintSection() {
    return MistakeSection(
      title: '解题提示',
      icon: CupertinoIcons.lightbulb_fill,
      iconColor: AppColors.warning,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: MathMarkdownText(
          text: widget.question.solvingHint!,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
