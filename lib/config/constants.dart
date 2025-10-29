import 'package:flutter/material.dart';

/// 稳了！设计系统 - 常量配置
class AppConstants {
  // 圆角规范
  static const double radiusSmall = 8.0; // 小圆角 - 按钮、标签
  static const double radiusMedium = 12.0; // 中圆角 - 卡片、输入框
  static const double radiusLarge = 16.0; // 大圆角 - 大卡片、弹窗
  static const double radiusExtraLarge = 24.0; // 超大圆角 - 浮动按钮、特殊卡片

  // 间距系统（8px 基准）
  static const double spacingXS = 4.0; // 极小间距
  static const double spacingS = 8.0; // 小间距
  static const double spacingM = 16.0; // 标准间距
  static const double spacingL = 24.0; // 大间距
  static const double spacingXL = 32.0; // 超大间距
  static const double spacingXXL = 48.0; // 特大间距

  // 阴影规范
  // 微阴影（Elevation 1）
  static const BoxShadow shadowMicro = BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 3,
    color: Color.fromRGBO(0, 0, 0, 0.08),
  );

  // 轻阴影（Elevation 2）
  static const BoxShadow shadowLight = BoxShadow(
    offset: Offset(0, 2),
    blurRadius: 8,
    color: Color.fromRGBO(0, 0, 0, 0.10),
  );

  // 中阴影（Elevation 3）
  static const BoxShadow shadowMedium = BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 16,
    color: Color.fromRGBO(0, 0, 0, 0.12),
  );

  // 重阴影（Elevation 4）
  static const BoxShadow shadowHeavy = BoxShadow(
    offset: Offset(0, 8),
    blurRadius: 24,
    color: Color.fromRGBO(0, 0, 0, 0.15),
  );

  // 组件尺寸
  static const double buttonHeight = 48.0;
  static const double recordButtonHeight = 40.0;
  static const double recordButtonWidth = 120.0;
  static const double minTapTarget = 44.0;

  // 动画时长
  static const Duration animationFast = Duration(milliseconds: 100);
  static const Duration animationQuick = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}

