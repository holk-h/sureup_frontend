import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';

/// 通用加载状态组件
class LoadingStateWidget extends StatelessWidget {
  final String message;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const LoadingStateWidget({
    super.key,
    required this.message,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (errorMessage == null)
              const CupertinoActivityIndicator(
                radius: 20,
                color: AppColors.primary,
              )
            else
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 48,
                color: AppColors.error,
              ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null && errorMessage != null) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

