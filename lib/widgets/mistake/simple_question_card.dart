import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';
import '../../services/mistake_service.dart';
import '../common/math_markdown_text.dart';
import 'common/answer_widgets.dart';
import 'common/mistake_section.dart';
import 'common/question_content_widgets.dart';
import 'mistake_note_section.dart';
import 'error_reason_selector.dart';

/// 简化版题目内容卡片
/// 显示题目内容、选项、添加笔记和正确答案，用于 OCR 完成但分析未完成时
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
  Set<String> _selectedAnswers = {};
  Set<String> _selectedUserAnswers = {};

  @override
  void initState() {
    super.initState();
    _initSelectedAnswers();
    _initSelectedUserAnswers();
  }

  @override
  void didUpdateWidget(SimpleQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 question 对象变了，更新选中的答案
    if (oldWidget.question.answer != widget.question.answer) {
      _initSelectedAnswers();
    }
    if (oldWidget.mistakeRecord.userAnswer != widget.mistakeRecord.userAnswer) {
      _initSelectedUserAnswers();
    }
  }

  void _initSelectedAnswers() {
    _selectedAnswers.clear();
    if (widget.question.answer != null && widget.question.answer!.isNotEmpty) {
      // 支持逗号分隔的多选答案
      final answers = widget.question.answer!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedAnswers.addAll(answers);
    }
  }

  void _initSelectedUserAnswers() {
    _selectedUserAnswers.clear();
    if (widget.mistakeRecord.userAnswer != null && widget.mistakeRecord.userAnswer!.isNotEmpty) {
      final answers = widget.mistakeRecord.userAnswer!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedUserAnswers.addAll(answers);
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
          MistakeSection(
            title: '题目内容',
            icon: CupertinoIcons.doc_text,
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

          // 选项（选择题）
          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingM),
            MistakeSection(
              title: '选项',
              icon: CupertinoIcons.list_bullet,
              child: OptionsListWidget(options: widget.question.options!),
            ),
          ],

          // 答案区域：我的答案 + 正确答案
          const SizedBox(height: AppConstants.spacingM),
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
                    child: _buildAnswerWidget(context),
                  ),
                ),
              ],
            ),
          ),

          // 错题笔记
          const SizedBox(height: AppConstants.spacingM),
          MistakeSection(
            title: '错题笔记',
            icon: CupertinoIcons.pencil,
            iconColor: AppColors.primary,
            isEditable: true,
            child: MistakeNoteSection(
              mistakeRecord: widget.mistakeRecord,
            ),
          ),

          // 错因分析
          if (widget.onErrorReasonChanged != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            MistakeSection(
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
      return EditableTextCard(
        initialText: widget.mistakeRecord.userAnswer,
        placeholder: '点击记录我的答案',
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

  Widget _buildAnswerWidget(BuildContext context) {
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
          // 立即更新本地状态，提供即时反馈
          setState(() {
            if (_selectedAnswers.contains(label)) {
              _selectedAnswers.remove(label);
            } else {
              _selectedAnswers.add(label);
            }
          });

          // 整理答案字符串
          final sortedAnswers = _selectedAnswers.toList()..sort();
          final answerStr = sortedAnswers.join(',');

          // 异步更新数据库
          try {
            await MistakeService().updateQuestionAnswer(
              widget.question.id,
              answerStr,
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
      initialText: widget.question.answer,
      placeholder: '点击添加',
      borderColor: AppColors.success,
      textColor: AppColors.success,
      onSave: (newAnswer) async {
        await MistakeService().updateQuestionAnswer(
          widget.question.id,
          newAnswer,
        );
        // 触发重新加载
        setState(() {
          _initSelectedAnswers();
        });
      },
    );
  }
}
