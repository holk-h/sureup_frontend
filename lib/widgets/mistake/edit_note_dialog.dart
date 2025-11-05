import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';

/// 编辑备注对话框
class EditNoteDialog extends StatefulWidget {
  final String? initialNote;
  final ValueChanged<String>? onSave;

  const EditNoteDialog({
    super.key,
    this.initialNote,
    this.onSave,
  });

  @override
  State<EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<EditNoteDialog> {
  late TextEditingController _controller;
  bool _isChanged = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
    _controller.addListener(() {
      setState(() {
        _isChanged = _controller.text != (widget.initialNote ?? '');
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final bool canSave = _isChanged && trimmed.isNotEmpty;

    return CupertinoAlertDialog(
      title: const Text('编辑备注'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 220,
          ),
          child: CupertinoScrollbar(
            child: SingleChildScrollView(
              child: CupertinoTextField(
                controller: _controller,
                placeholder: '记录解题思路、易错点等',
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
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),
        ),
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
                  widget.onSave?.call(trimmed);
                  Navigator.of(context).pop(trimmed);
                }
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

