import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../models/models.dart';

/// 编辑正确答案对话框
/// 根据题目类型显示不同的编辑界面：
/// - 选择题：显示选项选择器
/// - 其他题型：显示文本输入框
class EditAnswerDialog extends StatefulWidget {
  final String? initialAnswer;
  final Question question;
  final ValueChanged<String>? onSave;

  const EditAnswerDialog({
    super.key,
    this.initialAnswer,
    required this.question,
    this.onSave,
  });

  @override
  State<EditAnswerDialog> createState() => _EditAnswerDialogState();
}

class _EditAnswerDialogState extends State<EditAnswerDialog> {
  late final bool _isChoiceQuestion;
  late TextEditingController _controller;
  String? _selectedOption;
  bool _isChanged = false;

  @override
  void initState() {
    super.initState();
    _isChoiceQuestion =
        widget.question.options != null && widget.question.options!.isNotEmpty;

    if (_isChoiceQuestion) {
      _selectedOption = widget.initialAnswer;
    } else {
      _controller = TextEditingController(text: widget.initialAnswer ?? '');
      _controller.addListener(() {
        setState(() {
          _isChanged =
              _controller.text != (widget.initialAnswer ?? '');
        });
      });
    }
  }

  @override
  void dispose() {
    if (!_isChoiceQuestion) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedText = _isChoiceQuestion ? null : _controller.text.trim();
    final bool canSave = _isChoiceQuestion
        ? _selectedOption != null &&
            _selectedOption!.isNotEmpty &&
            _selectedOption != widget.initialAnswer
        : _isChanged && trimmedText!.isNotEmpty;

    return CupertinoAlertDialog(
      title: Text(_isChoiceQuestion ? '选择正确答案' : '输入正确答案'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _isChoiceQuestion ? _buildChoiceSelector() : _buildTextEditor(),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: canSave
              ? () {
                  final result =
                      _isChoiceQuestion ? _selectedOption! : trimmedText!;
                  widget.onSave?.call(result);
                  Navigator.of(context).pop(result);
                }
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildChoiceSelector() {
    final options = widget.question.options!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: CupertinoScrollbar(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: options.length,
          padding: const EdgeInsets.symmetric(vertical: 4),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final label = String.fromCharCode(65 + index);
            final option = options[index];
            final prefixPattern = RegExp(r'^[A-Z]\.?\s*');
            final cleanedOption = prefixPattern.hasMatch(option)
                ? option.replaceFirst(prefixPattern, '')
                : option;
            final bool isSelected = _selectedOption == label;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOption = label;
                  _isChanged = _selectedOption != widget.initialAnswer;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.success
                        : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.success
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? CupertinoColors.white
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cleanedOption,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: isSelected
                              ? AppColors.success
                              : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 220,
      ),
      child: CupertinoTextField(
        controller: _controller,
        placeholder: '请输入正确答案',
        maxLines: 6,
        minLines: 3,
        autofocus: true,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }
}

