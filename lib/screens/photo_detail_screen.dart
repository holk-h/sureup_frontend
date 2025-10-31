import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';

/// 照片详情页面
/// 用于查看单张照片、删除照片
class PhotoDetailScreen extends StatefulWidget {
  final String photoPath;
  final int totalCount;
  final int currentIndex;
  final VoidCallback onDelete;

  const PhotoDetailScreen({
    super.key,
    required this.photoPath,
    required this.totalCount,
    required this.currentIndex,
    required this.onDelete,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 设置沉浸式状态栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // 删除照片
  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              widget.onDelete(); // 执行删除
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // 照片显示区，支持双指缩放
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  File(widget.photoPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: CupertinoColors.darkBackgroundGray,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              size: 80,
                              color: CupertinoColors.systemGrey3,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '照片加载失败',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey3,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 顶部工具栏
          _buildTopBar(),

          // 底部工具栏
          _buildBottomBar(),
        ],
      ),
    );
  }

  // 构建顶部工具栏
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: AppConstants.spacingM,
          right: AppConstants.spacingM,
          bottom: AppConstants.spacingM,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.6),
              CupertinoColors.black.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 返回按钮
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.back,
                  color: CupertinoColors.white,
                  size: 24,
                ),
              ),
            ),

            // 计数器
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.currentIndex + 1} / ${widget.totalCount}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 删除按钮
            GestureDetector(
              onTap: _confirmDelete,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: CupertinoColors.destructiveRed,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建底部工具栏
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + AppConstants.spacingL,
          top: AppConstants.spacingL,
          left: AppConstants.spacingL,
          right: AppConstants.spacingL,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.6),
              CupertinoColors.black.withOpacity(0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 提示文字
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle,
                    color: CupertinoColors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '双指缩放查看照片细节',
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

