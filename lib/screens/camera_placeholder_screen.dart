import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';

/// 拍照功能占位页面
class CameraPlaceholderScreen extends StatelessWidget {
  const CameraPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0x00000000), // 透明背景
        border: null,
        heroTag: 'camera_nav_bar', // 唯一的 Hero tag
        transitionBetweenRoutes: false, // 禁用路由间的过渡动画
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: const Text('记录错题', style: AppTextStyles.smallTitle),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 相机图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: const [AppConstants.shadowMedium],
                  ),
                  child: const Icon(
                    CupertinoIcons.camera_fill,
                    size: 60,
                    color: AppColors.cardBackground,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                
                // 提示文字
                Text(
                  '拍照功能开发中',
                  style: AppTextStyles.largeTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  '很快就能使用啦~\n敬请期待！',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXL),
                
                // 返回按钮
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingL,
                      vertical: AppConstants.spacingM,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      boxShadow: const [AppConstants.shadowLight],
                    ),
                    child: const Text(
                      '返回',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardBackground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

