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
                  flex: 65,
                  child: _buildSection(
                    title: '错题备注',
                    icon: CupertinoIcons.pencil,
                    iconColor: AppColors.primary,
                    child: MistakeNoteSection(
                      mistakeRecord: widget.mistakeRecord,
                    ),
                  ),
                ),

                const SizedBox(width: AppConstants.spacingM),

                // 正确答案
                Expanded(
                  flex: 35,
                  child: _buildSection(
                    title: '正确答案',
                    icon: CupertinoIcons.checkmark_seal_fill,
                    iconColor: AppColors.success,
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

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(optionCount, (index) {
          final label = String.fromCharCode(65 + index); // A, B, C, D...
          final isSelected = _selectedAnswer == label;

          return GestureDetector(
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success
                    : AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
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
          );
        }),
      );
    }

    // 非选择题：已有答案显示答案，否则显示添加按钮
    if (widget.question.answer != null && widget.question.answer!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _showEditAnswerDialog(context),
        child: Center(
          child: Text(
            widget.question.answer!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showEditAnswerDialog(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.plus_circle,
              color: AppColors.success,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAnswerDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => EditAnswerDialog(
        initialAnswer: widget.question.answer,
        question: widget.question,
        onSave: (answer) async {
          try {
            await MistakeService().updateQuestionAnswer(
              widget.question.id,
              answer,
            );
            // 更新本地状态
            if (mounted) {
              setState(() {
                _selectedAnswer = answer;
              });
            }
          } catch (e) {
            print('更新答案失败: $e');
          }
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
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
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
