import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';

/// 编辑备注对话框
class EditNoteDialog extends StatefulWidget {
  final String? initialNote;
  final Function(String) onSave;

  const EditNoteDialog({
    super.key,
    this.initialNote,
    required this.onSave,
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
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height; // 最大高度为屏幕高度的 65%
    
    return CupertinoAlertDialog(
      // title: const Text('编辑备注'),
      content: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          child: SingleChildScrollView(
            child: CupertinoTextField(
              controller: _controller,
              placeholder: '记录解题思路、易错点等',
              maxLines: null,
              minLines: 1,
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
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _isChanged
              ? () {
                  widget.onSave(_controller.text.trim());
                  Navigator.of(context).pop();
                }
              : null,
          isDefaultAction: true,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

