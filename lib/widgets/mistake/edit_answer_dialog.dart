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
  final Function(String) onSave;

  const EditAnswerDialog({
    super.key,
    this.initialAnswer,
    required this.question,
    required this.onSave,
  });

  @override
  State<EditAnswerDialog> createState() => _EditAnswerDialogState();
}

class _EditAnswerDialogState extends State<EditAnswerDialog> {
  late TextEditingController _controller;
  String? _selectedOption;
  bool _isChanged = false;

  bool get _isChoiceQuestion =>
      widget.question.options != null && widget.question.options!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    
    if (_isChoiceQuestion) {
      // 选择题：初始化选中的选项
      _selectedOption = widget.initialAnswer;
      _isChanged = false;
    } else {
      // 其他题型：初始化文本输入框
      _controller = TextEditingController(text: widget.initialAnswer ?? '');
      _controller.addListener(() {
        setState(() {
          _isChanged = _controller.text != (widget.initialAnswer ?? '');
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
    return CupertinoAlertDialog(
      title: Text(_isChoiceQuestion ? '选择正确答案' : '输入正确答案'),
      content: _isChoiceQuestion
          ? _buildChoiceSelector()
          : _buildTextInput(),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _canSave()
              ? () {
                  final answer = _isChoiceQuestion
                      ? _selectedOption!
                      : _controller.text.trim();
                  widget.onSave(answer);
                  Navigator.of(context).pop();
                }
              : null,
          isDefaultAction: true,
          child: const Text('保存'),
        ),
      ],
    );
  }

  bool _canSave() {
    if (_isChoiceQuestion) {
      return _isChanged && _selectedOption != null && _selectedOption!.isNotEmpty;
    } else {
      return _isChanged && _controller.text.trim().isNotEmpty;
    }
  }

  Widget _buildChoiceSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.question.options!.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final label = String.fromCharCode(65 + index); // A, B, C, D...
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOption = label;
                    _isChanged = _selectedOption != widget.initialAnswer;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedOption == label
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedOption == label
                          ? AppColors.success
                          : AppColors.divider,
                      width: _selectedOption == label ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _selectedOption == label
                              ? AppColors.success
                              : AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _selectedOption == label
                              ? const Icon(
                                  CupertinoIcons.check_mark,
                                  size: 16,
                                  color: CupertinoColors.white,
                                )
                              : Text(
                                  label,
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
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 15,
                            color: _selectedOption == label
                                ? AppColors.success
                                : AppColors.textPrimary,
                            fontWeight: _selectedOption == label
                                ? FontWeight.w600
                                : FontWeight.normal,
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
      ),
    );
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 200,
        ),
        child: SingleChildScrollView(
          child: CupertinoTextField(
            controller: _controller,
            placeholder: '请输入正确答案',
            maxLines: null,
            minLines: 3,
            autofocus: true,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.divider,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }
}

