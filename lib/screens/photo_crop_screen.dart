import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../config/colors.dart';
import '../config/constants.dart';

/// 照片裁剪确认页面
/// 拍照或选择照片后，进入此页面进行裁剪和确认
class PhotoCropScreen extends StatefulWidget {
  final String photoPath;
  final VoidCallback? onRetake; // 重拍回调（仅拍照时显示）

  const PhotoCropScreen({
    super.key,
    required this.photoPath,
    this.onRetake,
  });

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  // 裁剪框位置和大小（这里用比例表示：0.0 ~ 1.0）
  final double _cropLeft = 0.05;
  final double _cropTop = 0.2;
  final double _cropWidth = 0.9;
  final double _cropHeight = 0.4;

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

  // 确认使用照片
  void _confirmUse() {
    HapticFeedback.mediumImpact();
    // 返回裁剪信息
    Navigator.of(context).pop({
      'photoPath': widget.photoPath,
      'cropRect': {
        'left': _cropLeft,
        'top': _cropTop,
        'width': _cropWidth,
        'height': _cropHeight,
      },
    });
  }

  // 取消或重拍
  void _cancel() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // 照片显示区域
          Positioned.fill(
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
                          size: 60,
                          color: CupertinoColors.systemGrey3,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '照片加载失败',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey3,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 裁剪框和遮罩
          _buildCropOverlay(screenWidth, screenHeight),

          // 顶部提示
          _buildTopHint(),

          // 底部操作按钮
          _buildBottomActions(),
        ],
      ),
    );
  }

  // 构建裁剪框遮罩
  Widget _buildCropOverlay(double screenWidth, double screenHeight) {
    // 计算裁剪框的实际像素位置
    final cropLeft = screenWidth * _cropLeft;
    final cropTop = screenHeight * _cropTop;
    final cropWidth = screenWidth * _cropWidth;
    final cropHeight = screenHeight * _cropHeight;

    return Stack(
      children: [
        // 半透明黑色遮罩
        Container(
          color: CupertinoColors.black.withOpacity(0.5),
        ),

        // 镂空裁剪区域
        Positioned(
          left: cropLeft,
          top: cropTop,
          child: Container(
            width: cropWidth,
            height: cropHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: CupertinoColors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              children: [
                // 网格线
                CustomPaint(
                  size: Size(cropWidth, cropHeight),
                  painter: _CropGridPainter(),
                ),

                // 四个角的拖拽点
                _buildCornerHandle(Alignment.topLeft),
                _buildCornerHandle(Alignment.topRight),
                _buildCornerHandle(Alignment.bottomLeft),
                _buildCornerHandle(Alignment.bottomRight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建角落拖拽点
  Widget _buildCornerHandle(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          border: Border.all(
            color: AppColors.primary,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // 构建顶部提示
  Widget _buildTopHint() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          left: AppConstants.spacingL,
          right: AppConstants.spacingL,
          bottom: AppConstants.spacingL,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.7),
              CupertinoColors.black.withOpacity(0.0),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.crop,
              color: CupertinoColors.white,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              '调整裁剪框，只保留题目部分',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '拖动角落可以调整大小',
              style: TextStyle(
                color: CupertinoColors.white.withOpacity(0.7),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 构建底部操作按钮
  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + AppConstants.spacingL,
          top: AppConstants.spacingXL,
          left: AppConstants.spacingXL,
          right: AppConstants.spacingXL,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.8),
              CupertinoColors.black.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 取消/重拍按钮
            _buildActionButton(
              icon: widget.onRetake != null
                  ? CupertinoIcons.camera_rotate
                  : CupertinoIcons.xmark,
              label: widget.onRetake != null ? '重拍' : '取消',
              onPressed: _cancel,
              isPrimary: false,
            ),

            // 使用照片按钮
            _buildActionButton(
              icon: CupertinoIcons.checkmark_alt,
              label: '使用照片',
              onPressed: _confirmUse,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isPrimary ? null : CupertinoColors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: CupertinoColors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 裁剪框网格线绘制器
class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    // 绘制三等分的网格线
    // 垂直线
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // 水平线
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

