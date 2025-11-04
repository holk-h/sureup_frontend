import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../config/api_config.dart';

/// 原始图片显示组件
class OriginalImageWidget extends StatelessWidget {
  final String? imageId;

  const OriginalImageWidget({
    super.key,
    required this.imageId,
  });

  @override
  Widget build(BuildContext context) {
    if (imageId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Image.network(
          '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.originQuestionImageBucketId}/files/$imageId/view?project=${ApiConfig.projectId}',
          fit: BoxFit.contain,
          width: double.infinity,
          cacheWidth: 1200,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: AppColors.background,
              child: const Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: AppColors.background,
              child: const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: AppColors.success,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
