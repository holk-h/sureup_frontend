import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../screens/camera_placeholder_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../providers/auth_provider.dart';

/// 自定义底部导航栏
class CustomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CustomTabItem> items;
  final bool showAnalysisBadge; // 是否在分析标签显示小红点

  const CustomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showAnalysisBadge = false, // 默认不显示
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 自定义形状的底部导航栏
        CustomPaint(
          painter: _TabBarPainter(),
          child: Container(
            height: 70 + MediaQuery.of(context).padding.bottom,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isActive = index == currentIndex;
                
                // 中间位置留空给拍照按钮
                if (index == 2) {
                  return const Expanded(child: SizedBox());
                }
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8), // 增加上边距，让图标往下移
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 图标（带小红点）
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                color: isActive ? AppColors.primary : AppColors.textTertiary,
                                size: 26,
                              ),
                              // 小红点 - 只在分析标签（index 1）显示
                              if (index == 1 && showAnalysisBadge)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight, // 使用更浅的红色
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.cardBackground,
                                        width: 1.5,
                                      ),
                                      // 去掉阴影
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 标签
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? AppColors.primary : AppColors.textTertiary,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        // 中间的拍照按钮和文字
        Positioned(
          left: 0,
          right: 0,
          top: -13, // 调整向上偏移量，让文字与其他项对齐
          child: Center(
            child: GestureDetector(
              onTap: () => _onCameraButtonTap(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF472B6), Color(0xFFC084FC)], // 粉紫梦幻渐变
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF472B6).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: const Color(0xFFC084FC).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      color: AppColors.cardBackground,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '错题记录',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onCameraButtonTap(BuildContext context) {
    // 检查登录状态
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isLoggedIn) {
      // 已登录，跳转到学科选择和拍照页面
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => const CameraPlaceholderScreen(),
        ),
      );
    } else {
      // 未登录，跳转到登录页面
      // 使用更快的过渡动画减少卡顿
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 250), // 缩短过渡时间
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 使用简单的淡入+轻微滑动效果，减少渲染压力
            const begin = Offset(0.0, 0.03); // 很小的偏移
            const end = Offset.zero;
            const curve = Curves.easeOut;
            
            var slideTween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: curve),
            );
            
            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: SlideTransition(
                position: animation.drive(slideTween),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }
}

/// 自定义底部导航栏项目
class CustomTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CustomTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 自定义绘制器 - 绘制带凸起的底部导航栏
class _TabBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(245, 255, 255, 255) // 半透明白色，略带透明度
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = AppColors.divider.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    
    // 凸起的宽度和高度（负值表示向上凸）
    const notchWidth = 60.0;
    const notchHeight = -19.0; // 减小凸起程度，贴合按钮位置
    const notchRadius = 30.0;
    
    final centerX = size.width / 2;
    
    // 开始绘制路径
    // 左上角圆角
    path.moveTo(0, 20);
    path.quadraticBezierTo(0, 0, 20, 0);
    
    // 左边直线到凸起开始
    path.lineTo(centerX - notchWidth / 2 - notchRadius, 0);
    
    // 凸起的左侧曲线（向上）
    path.quadraticBezierTo(
      centerX - notchWidth / 2 - notchRadius / 2,
      0,
      centerX - notchWidth / 2,
      notchHeight / 2, // 这会是负值，向上
    );
    
    // 凸起的顶部弧线（向上弧形）
    path.quadraticBezierTo(
      centerX - notchWidth / 4,
      notchHeight, // 最高点
      centerX,
      notchHeight,
    );
    
    path.quadraticBezierTo(
      centerX + notchWidth / 4,
      notchHeight,
      centerX + notchWidth / 2,
      notchHeight / 2,
    );
    
    // 凸起的右侧曲线（向上）
    path.quadraticBezierTo(
      centerX + notchWidth / 2 + notchRadius / 2,
      0,
      centerX + notchWidth / 2 + notchRadius,
      0,
    );
    
    // 右边直线
    path.lineTo(size.width - 20, 0);
    
    // 右上角圆角
    path.quadraticBezierTo(size.width, 0, size.width, 20);
    
    // 右边和底部
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // 绘制阴影
    canvas.drawPath(path, shadowPaint);
    
    // 绘制主体
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
