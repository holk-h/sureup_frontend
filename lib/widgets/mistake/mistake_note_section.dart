import 'package:flutter/cupertino.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/mistake_record.dart';
import '../../services/mistake_service.dart';
import 'edit_note_dialog.dart';

class MistakeNoteSection extends StatefulWidget {
  final MistakeRecord mistakeRecord;

  const MistakeNoteSection({super.key, required this.mistakeRecord});

  @override
  State<MistakeNoteSection> createState() => _MistakeNoteSectionState();
}

class _MistakeNoteSectionState extends State<MistakeNoteSection> {
  String? _note;
  bool _isSaving = false;

  bool get _hasNote => _note != null && _note!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _note = widget.mistakeRecord.note;
  }

  @override
  void didUpdateWidget(covariant MistakeNoteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mistakeRecord.note != widget.mistakeRecord.note) {
      _note = widget.mistakeRecord.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSaving ? null : _handleEditNote,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: _hasNote
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.primary.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: _hasNote ? 0.25 : 0.15,
                ),
                width: 1.4,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _hasNote
                  ? _NoteFilledContent(
                      key: const ValueKey('note-filled'),
                      note: _note!.trim(),
                    )
                  : const _NoteEmptyContent(key: ValueKey('note-empty')),
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

  Future<void> _handleEditNote() async {
    String? result;
    
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => EditNoteDialog(
        initialNote: _note,
        onSave: (note) {
          // 保存结果，不要在这里 pop，dialog 内部会自己 pop
          result = note;
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final trimmed = result!.trim();
    final previousNote = _note;
    final previousNormalized = (previousNote ?? '').trim();

    if (previousNormalized == trimmed) {
      return;
    }

    setState(() {
      _note = trimmed;
      _isSaving = true;
    });

    try {
      await MistakeService().updateMistakeNote(
        widget.mistakeRecord.id,
        trimmed,
      );
    } catch (e) {
      print('更新备注失败: $e');
      if (mounted) {
        setState(() {
          _note = previousNote;
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

class _NoteEmptyContent extends StatelessWidget {
  const _NoteEmptyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(CupertinoIcons.plus_circle, color: AppColors.primary, size: 18),
          SizedBox(width: 6),
          Text(
            '点击添加备注',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteFilledContent extends StatelessWidget {
  final String note;

  const _NoteFilledContent({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          note,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击编辑备注',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
