import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../models/models.dart';

/// 错因选择器组件
class ErrorReasonSelector extends StatelessWidget {
  final MistakeRecord mistakeRecord;
  final Function(String) onErrorReasonChanged;

  const ErrorReasonSelector({
    super.key,
    required this.mistakeRecord,
    required this.onErrorReasonChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentErrorReasonEnum = mistakeRecord.errorReasonEnum;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ErrorReason.values.where((e) => e != ErrorReason.other).map((reason) {
        final isSelected = currentErrorReasonEnum == reason;
        return GestureDetector(
          onTap: () {
            onErrorReasonChanged(reason.name);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.error
                  : AppColors.error.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.error
                    : AppColors.error.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Text(
              reason.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? CupertinoColors.white
                    : AppColors.error,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
