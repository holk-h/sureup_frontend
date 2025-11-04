import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/colors.dart';

/// 页面指示器组件
class PageIndicator extends StatelessWidget {
  final PageController pageController;
  final int totalPages;
  final int initialIndex;

  const PageIndicator({
    super.key,
    required this.pageController,
    required this.totalPages,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final currentPage = pageController.hasClients 
        ? (pageController.page ?? initialIndex).round()
        : initialIndex;
    
    return Container(
      margin: const EdgeInsets.only(
        left: 0,
        right: 0,
        bottom: 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.0),
            AppColors.background.withValues(alpha: 0.95),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 左箭头按钮
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: currentPage > 0
                  ? () {
                      pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: currentPage > 0
                      ? AppColors.cardBackground
                      : AppColors.cardBackground.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentPage > 0
                        ? AppColors.divider
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: currentPage > 0
                      ? [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: currentPage > 0
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 页码指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentPage + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success.withValues(alpha: 0.6),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalPages',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success.withValues(alpha: 0.7),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 右箭头按钮
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: currentPage < totalPages - 1
                  ? () {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: currentPage < totalPages - 1
                      ? AppColors.cardBackground
                      : AppColors.cardBackground.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentPage < totalPages - 1
                        ? AppColors.divider
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: currentPage < totalPages - 1
                      ? [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: currentPage < totalPages - 1
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
