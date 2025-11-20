import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../config/colors.dart';
import '../../../config/constants.dart';
import '../../common/math_markdown_text.dart';

class ChoiceSelectorWidget extends StatelessWidget {
  final int optionCount;
  final Set<String> selectedAnswers;
  final Function(String) onToggle;
  final Color activeColor;

  const ChoiceSelectorWidget({
    super.key,
    required this.optionCount,
    required this.selectedAnswers,
    required this.onToggle,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate((optionCount / 2).ceil(), (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: rowIndex < (optionCount / 2).ceil() - 1 ? 8 : 0),
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
                    final isSelected = selectedAnswers.contains(label);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToggle(label);
                        },
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? activeColor
                                : activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activeColor.withValues(
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
                                    : activeColor,
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
}

class EditableTextCard extends StatefulWidget {
  final String? initialText;
  final String placeholder;
  final Color borderColor;
  final Color textColor;
  final Future<void> Function(String) onSave;

  const EditableTextCard({
    super.key,
    this.initialText,
    required this.placeholder,
    required this.borderColor,
    this.textColor = AppColors.textSecondary,
    required this.onSave,
  });

  @override
  State<EditableTextCard> createState() => _EditableTextCardState();
}

class _EditableTextCardState extends State<EditableTextCard> {
  String? _text;
  bool _isSaving = false;

  bool get _hasText => _text != null && _text!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
  }

  @override
  void didUpdateWidget(covariant EditableTextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText) {
      _text = widget.initialText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSaving ? null : _handleEdit,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: _hasText
                  ? widget.borderColor.withValues(alpha: 0.06)
                  : widget.borderColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: widget.borderColor.withValues(
                  alpha: _hasText ? 0.28 : 0.16,
                ),
                width: 1.4,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _hasText
                  ? KeyedSubtree(
                      key: const ValueKey('text-filled'),
                      child: _AnswerFilledContent(
                        answer: _text!.trim(),
                        textColor: widget.textColor,
                        borderColor: widget.borderColor,
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('text-empty'),
                      child: _AnswerEmptyContent(
                        placeholder: widget.placeholder,
                        color: widget.borderColor,
                      ),
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

  Future<void> _handleEdit() async {
    final TextEditingController controller = TextEditingController(text: _text);

    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('编辑答案'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: '请输入答案',
              minLines: 1,
              maxLines: 5,
              autofocus: true,
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
            child: const Text('保存'),
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final trimmed = result.trim();
    final previousText = _text;
    final previousNormalized = (previousText ?? '').trim();

    if (previousNormalized == trimmed) {
      return;
    }

    setState(() {
      _text = trimmed;
      _isSaving = true;
    });

    try {
      await widget.onSave(trimmed);
    } catch (e) {
      print('保存失败: $e');
      if (mounted) {
        setState(() {
          _text = previousText;
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
  final String placeholder;
  final Color color;

  const _AnswerEmptyContent({
    required this.placeholder,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.plus_circle, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            placeholder,
            style: TextStyle(
              fontSize: 14,
              color: color,
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
  final Color textColor;
  final Color borderColor;

  const _AnswerFilledContent({
    required this.answer,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MathMarkdownText(
          text: answer,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击编辑',
          style: TextStyle(
            fontSize: 12,
            color: borderColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

