import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// 稳了！设计系统 - 字体规范
class AppTextStyles {
  // 超大标题：32px - 粗体
  static const TextStyle extraLargeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // 大标题：24px - 粗体
  static const TextStyle largeTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // 中标题：20px - 粗体
  static const TextStyle mediumTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // 小标题：17px - 中等
  static const TextStyle smallTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // 正文：15px - 常规
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // 辅助文字：13px - 常规
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.4,
  );

  // 小号文字：11px - 常规
  static const TextStyle small = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.3,
  );

  // 按钮文字：15px - 粗体
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  // 数字强调：粗体
  static TextStyle numberEmphasis = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    height: 1.2,
  );
}

