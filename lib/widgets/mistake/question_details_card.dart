import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';
import '../../services/mistake_service.dart';
import '../common/math_markdown_text.dart';
import 'error_reason_selector.dart';
import 'edit_answer_dialog.dart';
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
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.question.answer;
    _setupStaggeredAnimations();
    _startAnimation();
  }

  @override
  void didUpdateWidget(QuestionDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 question 对象变了，更新选中的答案
    if (oldWidget.question.answer != widget.question.answer) {
      _selectedAnswer = widget.question.answer;
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
            '识别错误？点击反馈',
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
            const Text(
              '请说明哪里识别错了，帮助我们改进：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              placeholder: '例如：题目内容识别不完整、选项错误等',
              maxLines: 3,
              minLines: 3,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
            _buildSection(
              title: '题目内容',
              icon: CupertinoIcons.doc_text,
              actionButton: _buildOcrFeedbackButton(),
              child: MathMarkdownText(
                text: widget.question.content,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 选项（选择题）(索引 1)
          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            _buildAnimatedItem(
              animationIndex++,
              _buildSection(
                title: '选项',
                icon: CupertinoIcons.list_bullet,
                child: _buildOptionsWidget(),
              ),
            ),

          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            const SizedBox(height: AppConstants.spacingM),

          // 答案和备注 (索引 2)
          _buildAnimatedItem(
            animationIndex++,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 添加备注
                  Expanded(
                    flex: 50,
                    child: _buildSection(
                      title: '错题备注',
                      icon: CupertinoIcons.pencil,
                      iconColor: AppColors.primary,
                      isEditable: true,
                      child: MistakeNoteSection(
                        mistakeRecord: widget.mistakeRecord,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppConstants.spacingM),

                  // 正确答案
                  Expanded(
                    flex: 50,
                    child: _buildSection(
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

          // 错因分析 (索引 3)
          _buildAnimatedItem(
            animationIndex++,
            _buildSection(
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
            _buildAnimatedItem(animationIndex++, _buildKnowledgePointSection()),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),

          // 解题提示 (索引 6)
          if (widget.question.solvingHint != null && widget.question.solvingHint!.isNotEmpty)
            _buildAnimatedItem(animationIndex++, _buildSolvingHintSection()),
        ],
      ),
    );
  }

  Widget _buildOptionsWidget() {
    return Column(
      children: widget.question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final label = String.fromCharCode(65 + index); // A, B, C, D...

        String cleanedOption = option;
        final prefixPattern = RegExp(r'^[A-Z]\.?\s*');
        if (prefixPattern.hasMatch(option)) {
          cleanedOption = option.replaceFirst(prefixPattern, '');
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MathMarkdownText(
                  text: cleanedOption,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                  scrollable: true,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerWidget() {
    // 判断是否为选择题
    final bool isChoiceQuestion =
        widget.question.options != null && widget.question.options!.isNotEmpty;

    // 选择题：显示选项字母，直接点击更新答案
    if (isChoiceQuestion) {
      final optionCount = widget.question.options!.length;

      return Column(
        children: List.generate((optionCount / 2).ceil(), (rowIndex) {
          return Padding(
            padding: EdgeInsets.only(bottom: rowIndex < (optionCount / 2).ceil() - 1 ? 8 : 0),
            child: Row(
              children: [
                for (int colIndex = 0; colIndex < 2; colIndex++) ...[
                  if (colIndex > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final index = rowIndex * 2 + colIndex;
                      if (index >= optionCount) {
                        return const Expanded(child: SizedBox());
                      }
                      
          final label = String.fromCharCode(65 + index); // A, B, C, D...
          final isSelected = _selectedAnswer == label;

                      return Expanded(
                        child: GestureDetector(
            onTap: () async {
              // 添加触觉反馈
              HapticFeedback.selectionClick();

              // 立即更新本地状态，提供即时反馈
              setState(() {
                _selectedAnswer = label;
              });

              // 异步更新数据库
              try {
                await MistakeService().updateQuestionAnswer(
                  widget.question.id,
                  label,
                );
              } catch (e) {
                print('更新答案失败: $e');
                // 如果更新失败，恢复原状态
                if (mounted) {
                  setState(() {
                    _selectedAnswer = widget.question.answer;
                  });
                }
              }
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success
                    : AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(
                    alpha: isSelected ? 1.0 : 0.3,
                  ),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.success,
                  ),
                ),
              ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }),
      );
    }

    return _NonChoiceAnswerDetailCard(
      question: widget.question,
      onAnswerChanged: (answer) {
        setState(() {
          _selectedAnswer = answer;
        });
      },
    );
  }

  Widget _buildModuleSection() {
    final moduleIds = widget.question.moduleIds;

    return _buildSection(
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

    return _buildSection(
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
                Text(
              kpName,
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
    return _buildSection(
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
    bool isEditable = false,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isEditable) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '可编辑',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              if (actionButton != null) ...[
                const Spacer(),
                actionButton,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NonChoiceAnswerDetailCard extends StatefulWidget {
  final Question question;
  final ValueChanged<String> onAnswerChanged;

  const _NonChoiceAnswerDetailCard({
    required this.question,
    required this.onAnswerChanged,
  });

  @override
  State<_NonChoiceAnswerDetailCard> createState() => _NonChoiceAnswerDetailCardState();
}

class _NonChoiceAnswerDetailCardState extends State<_NonChoiceAnswerDetailCard> {
  String? _answer;
  bool _isSaving = false;

  bool get _hasAnswer => _answer != null && _answer!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _answer = widget.question.answer;
  }

  @override
  void didUpdateWidget(covariant _NonChoiceAnswerDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.answer != widget.question.answer) {
      _answer = widget.question.answer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSaving ? null : _handleEditAnswer,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: _hasAnswer
                  ? AppColors.success.withValues(alpha: 0.06)
                  : AppColors.success.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: AppColors.success.withValues(
                  alpha: _hasAnswer ? 0.28 : 0.16,
                ),
                width: 1.4,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _hasAnswer
                  ? KeyedSubtree(
                      key: const ValueKey('answer-filled'),
                      child: _AnswerDetailFilledContent(
                        answer: _answer!.trim(),
                      ),
                    )
                  : const KeyedSubtree(
                      key: ValueKey('answer-empty'),
                      child: _AnswerDetailEmptyContent(),
                    ),
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                  ),
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleEditAnswer() async {
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => EditAnswerDialog(
        initialAnswer: _answer,
        question: widget.question,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final trimmed = result.trim();
    final previousAnswer = _answer;
    final previousNormalized = (previousAnswer ?? '').trim();

    if (previousNormalized == trimmed) {
      return;
    }

    setState(() {
      _answer = trimmed;
      _isSaving = true;
    });

    try {
      await MistakeService().updateQuestionAnswer(
        widget.question.id,
        trimmed,
      );
      if (mounted) {
        widget.onAnswerChanged(trimmed);
      }
    } catch (e) {
      print('更新答案失败: $e');
      if (mounted) {
        setState(() {
          _answer = previousAnswer;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _AnswerDetailEmptyContent extends StatelessWidget {
  const _AnswerDetailEmptyContent();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(CupertinoIcons.plus_circle, color: AppColors.success, size: 18),
          SizedBox(width: 6),
          Text(
            '点击添加答案',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerDetailFilledContent extends StatelessWidget {
  final String answer;

  const _AnswerDetailFilledContent({required this.answer});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MathMarkdownText(
          text: answer,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击编辑正确答案',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.success.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

}
