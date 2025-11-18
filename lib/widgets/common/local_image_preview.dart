import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';

/// 本地图片预览组件
class LocalImagePreview extends StatelessWidget {
  final String imagePath;
  final double? height;
  final double? width;
  final BoxFit fit;

  const LocalImagePreview({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height != null ? 16 : 12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height != null ? 16 : 12),
        child: Image.file(
          File(imagePath),
          fit: fit,
        ),
      ),
    );
  }
}

