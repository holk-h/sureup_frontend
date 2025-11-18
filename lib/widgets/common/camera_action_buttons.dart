import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../config/colors.dart';

/// 相机操作按钮组件
class CameraActionButtons extends StatelessWidget {
  final VoidCallback onTakePicture;
  final VoidCallback onPickFromGallery;
  final String? takePictureText;
  final String? pickFromGalleryText;
  final bool hasImage;

  const CameraActionButtons({
    super.key,
    required this.onTakePicture,
    required this.onPickFromGallery,
    this.takePictureText,
    this.pickFromGalleryText,
    this.hasImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 拍照按钮
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onTakePicture();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFC084FC), // 粉紫色纯色
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.camera_fill,
                  color: CupertinoColors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  takePictureText ?? (hasImage ? '重新拍照' : '拍照'),
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // 相册按钮
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onPickFromGallery();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.photo,
                  color: AppColors.accent,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  pickFromGalleryText ?? (hasImage ? '更换图片' : '从相册选择'),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

