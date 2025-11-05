import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';
import '../../services/mistake_service.dart';
import '../common/math_markdown_text.dart';
import 'edit_answer_dialog.dart';
import 'mistake_note_section.dart';
import 'error_reason_selector.dart';

/// 简化版题目内容卡片
/// 显示题目内容、选项、添加备注和正确答案，用于 OCR 完成但分析未完成时
class SimpleQuestionCard extends StatefulWidget {
  final Question question;
  final MistakeRecord mistakeRecord;
  final Function(String)? onErrorReasonChanged;

  const SimpleQuestionCard({
    super.key,
    required this.question,
    required this.mistakeRecord,
    this.onErrorReasonChanged,
  });

  @override
  State<SimpleQuestionCard> createState() => _SimpleQuestionCardState();
}

class _SimpleQuestionCardState extends State<SimpleQuestionCard> {
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.question.answer;
  }

  @override
  void didUpdateWidget(SimpleQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 question 对象变了，更新选中的答案
    if (oldWidget.question.answer != widget.question.answer) {
      _selectedAnswer = widget.question.answer;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // 题目内容
          _buildSection(
            title: '题目内容',
            icon: CupertinoIcons.doc_text,
            child: MathMarkdownText(
              text: widget.question.content,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),

          // 选项（选择题）
          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildSection(
              title: '选项',
              icon: CupertinoIcons.list_bullet,
              child: _buildOptionsWidget(),
            ),
          ],

          // 添加备注和正确答案区域
          const SizedBox(height: AppConstants.spacingM),
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
                    child: _buildAnswerWidget(context),
                  ),
                ),
              ],
            ),
          ),

          // 错因分析
          if (widget.onErrorReasonChanged != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildSection(
              title: '错因分析',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              iconColor: AppColors.error,
              isEditable: true,
              child: ErrorReasonSelector(
                mistakeRecord: widget.mistakeRecord,
                onErrorReasonChanged: widget.onErrorReasonChanged!,
              ),
            ),
          ],
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
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerWidget(BuildContext context) {
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

    return _NonChoiceAnswerCard(
      question: widget.question,
      onAnswerChanged: (answer) {
        setState(() {
          _selectedAnswer = answer;
        });
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
    bool isEditable = false,
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
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NonChoiceAnswerCard extends StatefulWidget {
  final Question question;
  final ValueChanged<String> onAnswerChanged;

  const _NonChoiceAnswerCard({
    required this.question,
    required this.onAnswerChanged,
  });

  @override
  State<_NonChoiceAnswerCard> createState() => _NonChoiceAnswerCardState();
}

class _NonChoiceAnswerCardState extends State<_NonChoiceAnswerCard> {
  String? _answer;
  bool _isSaving = false;

  bool get _hasAnswer => _answer != null && _answer!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _answer = widget.question.answer;
  }

  @override
  void didUpdateWidget(covariant _NonChoiceAnswerCard oldWidget) {
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
                  ? _AnswerFilledContent(
                      key: const ValueKey('answer-filled'),
                      answer: _answer!.trim(),
                    )
                  : const _AnswerEmptyContent(key: ValueKey('answer-empty')),
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

class _AnswerEmptyContent extends StatelessWidget {
  const _AnswerEmptyContent({super.key});

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

class _AnswerFilledContent extends StatelessWidget {
  final String answer;

  const _AnswerFilledContent({super.key, required this.answer});

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
