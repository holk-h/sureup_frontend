import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../services/appwrite_service.dart';

/// 编辑笔记对话框
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
  bool _isPolishing = false;

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

  Future<void> _polishNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isPolishing = true;
    });

    try {
      final functions = AppwriteService().functions;
      final execution = await functions.createExecution(
        functionId: 'ai-helper',
        body: jsonEncode({
          'action': 'polish_note',
          'note': text,
        }),
      );

      final response = jsonDecode(execution.responseBody);
      if (response['error'] != null) {
        throw Exception(response['error']);
      }

      final polished = response['polished'];
      if (polished != null) {
        setState(() {
          _controller.text = polished;
          _isChanged = true;
        });
      }
    } catch (e) {
      debugPrint('Polishing failed: $e');
      // Optionally show error
    } finally {
      if (mounted) {
        setState(() {
          _isPolishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final bool canSave = _isChanged && trimmed.isNotEmpty;

    return CupertinoAlertDialog(
      title: const Text('编辑笔记'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isPolishing)
                  const CupertinoActivityIndicator(radius: 8)
                else
                  GestureDetector(
                    onTap: trimmed.isNotEmpty ? _polishNote : null,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.wand_stars,
                          size: 16,
                          color: trimmed.isNotEmpty ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI 润色',
                          style: TextStyle(
                            fontSize: 14,
                            color: trimmed.isNotEmpty ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
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
