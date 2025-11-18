import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import '../../config/colors.dart';
import '../../config/api_config.dart';

/// 图片预览网格组件
class ImagePreviewGrid extends StatelessWidget {
  final List<String> imageIds;
  final Function(int index)? onDelete;
  final int crossAxisCount;
  final double aspectRatio;

  const ImagePreviewGrid({
    super.key,
    required this.imageIds,
    this.onDelete,
    this.crossAxisCount = 2,
    this.aspectRatio = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    if (imageIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '没有可预览的图片',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: imageIds.length,
      itemBuilder: (context, index) {
        final imageId = imageIds[index];
        return _ImagePreviewItem(
          imageId: imageId,
          onDelete: onDelete != null ? () => onDelete!(index) : null,
        );
      },
    );
  }
}

class _ImagePreviewItem extends StatelessWidget {
  final String imageId;
  final VoidCallback? onDelete;

  const _ImagePreviewItem({
    required this.imageId,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.originQuestionImageBucketId}/files/$imageId/view?project=${ApiConfig.projectId}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.divider,
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
                  color: AppColors.divider,
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onDelete!();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

