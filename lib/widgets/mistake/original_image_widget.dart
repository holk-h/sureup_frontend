import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../config/api_config.dart';

/// 原始图片显示组件（支持单图和多图）
class OriginalImageWidget extends StatelessWidget {
  final List<String>? imageIds; // 图片ID列表

  const OriginalImageWidget({
    super.key,
    this.imageIds,
  });

  @override
  Widget build(BuildContext context) {
    final ids = imageIds ?? [];
    
    if (ids.isEmpty) {
      return const SizedBox.shrink();
    }

    // 单图显示
    if (ids.length == 1) {
      return _buildSingleImage(ids[0]);
    }

    // 多图显示
    return _buildMultipleImages(ids);
  }

  // 构建单图显示
  Widget _buildSingleImage(String id) {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: _buildImageNetwork(id),
      ),
    );
  }

  // 构建多图显示（纵向排列）
  Widget _buildMultipleImages(List<String> ids) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 多图提示标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.photo_on_rectangle,
                  size: 14,
                  color: CupertinoColors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '多图题（${ids.length} 张）',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
          // 所有图片纵向排列
          ...ids.asMap().entries.map((entry) {
            final index = entry.key;
            final id = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: index < ids.length - 1 ? 12 : 0,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: _buildImageNetwork(id),
                  ),
                  // 页码标识
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '第 ${index + 1} 页',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 构建网络图片
  Widget _buildImageNetwork(String id) {
    return Image.network(
      '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.originQuestionImageBucketId}/files/$id/view?project=${ApiConfig.projectId}',
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
    );
  }
}
