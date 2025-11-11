import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/colors.dart';

/// 自定义顶部导航栏组件
/// 支持标题居中、返回按钮、右侧操作按钮等
class CustomAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final Widget? rightAction;
  final Color? backgroundColor;
  final Color? titleColor;
  final double? elevation;
  final bool showBackButton;
  final String? subtitle;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.onBack,
    this.rightAction,
    this.backgroundColor,
    this.titleColor,
    this.elevation,
    this.showBackButton = true,
    this.subtitle,
  }) : assert(title != null || titleWidget != null, 'title 或 titleWidget 必须提供一个');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.background,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: elevation! * 2,
                  offset: Offset(0, elevation! / 2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: subtitle != null ? 64 : 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              // 返回按钮
              if (showBackButton)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.back,
                          color: titleColor ?? AppColors.accent,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 居中标题区域
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    titleWidget != null
                        ? titleWidget!
                        : Text(
                            title ?? '',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: titleColor ?? AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: (titleColor ?? AppColors.textSecondary).withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              // 右侧操作按钮
              if (rightAction != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: rightAction!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带渐变背景的导航栏
class GradientAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? rightAction;
  final List<Color> gradientColors;
  final bool showBackButton;
  final String? subtitle;

  const GradientAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.rightAction,
    this.gradientColors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
    ],
    this.showBackButton = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: subtitle != null ? 64 : 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              // 返回按钮
              if (showBackButton)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          CupertinoIcons.back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 居中标题区域
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              // 右侧操作按钮
              if (rightAction != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: rightAction!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带统计信息的导航栏
class StatsAppBar extends StatelessWidget {
  final String title;
  final String statsText;
  final VoidCallback? onBack;
  final Widget? rightAction;
  final Color? backgroundColor;
  final bool showBackButton;

  const StatsAppBar({
    super.key,
    required this.title,
    required this.statsText,
    this.onBack,
    this.rightAction,
    this.backgroundColor,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              // 返回按钮
              if (showBackButton)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          CupertinoIcons.back,
                          color: AppColors.accent,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 居中标题和统计信息
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statsText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 右侧操作按钮
              if (rightAction != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: rightAction!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
