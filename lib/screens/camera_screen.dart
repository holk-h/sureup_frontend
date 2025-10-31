import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import 'photo_detail_screen.dart';
import 'mistake_analysis_progress_screen.dart';

/// 错题照片预览和管理页面
/// 支持查看已拍摄照片、继续拍摄、从相册选择、提交照片
class CameraScreen extends StatefulWidget {
  final Subject subject; // 学科
  
  const CameraScreen({
    super.key,
    required this.subject,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 已拍摄的照片列表（存储照片路径）
  final List<String> _photos = [];

  // 是否显示底部照片预览区
  bool get _hasPhotos => _photos.isNotEmpty;

  // ImagePicker 实例
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  // 拍照 - 调用系统相机
  Future<void> _takePicture() async {
    HapticFeedback.mediumImpact();

    try {
      // 调用系统相机拍照
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      // 自动进入裁剪界面
      final croppedFile = await _cropImage(image.path);

      if (!mounted) return;

      // 如果用户完成裁剪，添加到列表
      if (croppedFile != null) {
        setState(() {
          _photos.add(croppedFile.path);
        });
        HapticFeedback.mediumImpact();
      } else {
        // 用户取消了裁剪，询问是否使用原图
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _photos.add(image.path);
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('拍照失败', '无法访问相机，请检查相机权限设置');
    }
  }

  // 从相册选择
  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      final croppedFile = await _cropImage(image.path);

      if (!mounted) return;

      if (croppedFile != null) {
        setState(() {
          _photos.add(croppedFile.path);
        });
        HapticFeedback.mediumImpact();
      } else {
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _photos.add(image.path);
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('选择失败', '无法访问相册，请检查相册权限设置');
    }
  }

  // 裁剪图片
  Future<CroppedFile?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
        uiSettings: [
          // iOS 设置
          IOSUiSettings(
            title: '调整照片区域',
            doneButtonTitle: '完成',
            cancelButtonTitle: '取消',
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            aspectRatioLockEnabled: false,
            minimumAspectRatio: 0.2,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            hidesNavigationBar: false,
            rectX: 0,
            rectY: 0,
            rectWidth: 0,
            rectHeight: 0,
          ),
          // Android 设置
          AndroidUiSettings(
            toolbarTitle: '调整照片区域',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: CupertinoColors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            cropGridRowCount: 3,
            cropGridColumnCount: 3,
          ),
        ],
      );
      
      return croppedFile;
    } catch (e) {
      // 裁剪失败，返回 null
      return null;
    }
  }

  // 显示使用原图对话框
  Future<bool?> _showUseOriginalDialog() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('是否使用原图？'),
        content: const Text('您取消了裁剪，是否直接使用原图？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDefaultAction: true,
            child: const Text('使用原图'),
          ),
        ],
      ),
    );
  }

  // 显示错误对话框
  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 删除照片
  void _deletePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  // 查看照片详情
  void _viewPhotoDetail(int index) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => PhotoDetailScreen(
          photoPath: _photos[index],
          totalCount: _photos.length,
          currentIndex: index,
          onDelete: () {
            Navigator.of(context).pop();
            _deletePhoto(index);
          },
        ),
      ),
    );
  }

  // 完成并提交
  Future<void> _finish() async {
    if (_photos.isEmpty) return;

    HapticFeedback.mediumImpact();

    // 显示确认对话框
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认提交'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('即将提交 ${_photos.length} 张错题照片'),
              const SizedBox(height: 8),
              const Text(
                'AI 将自动识别和分析错题',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('再看看'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 导航到分析进度页面
      final success = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (context) => MistakeAnalysisProgressScreen(
            photoFilePaths: _photos,
            subject: widget.subject,
          ),
        ),
      );

      // 如果分析成功，返回 true 告知调用方
      if (success == true && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildNavigationBar(),

            // 主内容区：照片网格或空状态
            Expanded(
              child: _hasPhotos ? _buildPhotoGrid() : _buildEmptyState(),
            ),

            // 底部操作栏
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  // 构建顶部导航栏
  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.chevron_back,
                  size: 28,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '返回',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontSize: 17,
                  ),
                ),
              ],
            ), minimumSize: Size(44, 44),
          ),

          // 标题
          Text(
            '记录错题',
            style: AppTextStyles.smallTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          // 完成按钮（有照片时显示）
          if (_hasPhotos)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.success,
              onPressed: _finish,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '完成',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_photos.length}',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ), minimumSize: Size(0, 0),
            )
          else
            const SizedBox(width: 70), // 占位，保持标题居中
        ],
      ),
    );
  }

  // 构建照片网格
  Widget _buildPhotoGrid() {
    return Column(
      children: [
        // 统计信息条
        Container(
          margin: const EdgeInsets.all(AppConstants.spacingM),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.successLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '已拍摄 ${_photos.length} 张照片',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        // 照片网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingM,
              0,
              AppConstants.spacingM,
              AppConstants.spacingM,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              return _buildPhotoGridItem(index);
            },
          ),
        ),
      ],
    );
  }

  // 构建照片网格项
  Widget _buildPhotoGridItem(int index) {
    return GestureDetector(
      onTap: () => _viewPhotoDetail(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cardBackground,
          boxShadow: AppColors.shadowSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 照片
              Positioned.fill(
                child: Image.file(
                  File(_photos[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.background,
                      child: Center(
                        child: Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: AppColors.textTertiary,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 顶部渐变遮罩
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CupertinoColors.black.withOpacity(0.4),
                        CupertinoColors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // 序号标签
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 删除按钮
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _confirmDeletePhoto(index),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 确认删除照片
  Future<void> _confirmDeletePhoto(int index) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deletePhoto(index);
    }
  }

  // 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXL,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 拍照图标装饰
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF472B6), Color(0xFFC084FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF472B6).withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.camera_fill,
                size: 56,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 32),

            // 标题
            Text(
              '还没有照片哦，可以去拍多道错题 📄',
              style: AppTextStyles.largeTitle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 提示文字
            Text(
              '拍完所有错题后点击右上角"完成"\nAI 会帮你逐一分析每道题',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Row(
        children: [
          // 从相册选择按钮
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.accentLight.withOpacity(0.15),
              onPressed: _pickFromGallery,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.photo,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '相册',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.accent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 拍照按钮 - 粉紫渐变（与主页一致）
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF472B6), Color(0xFFC084FC)], // 粉紫梦幻渐变
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(12),
                onPressed: _takePicture,
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
                      '拍照',
                      style: AppTextStyles.button.copyWith(
                        color: CupertinoColors.white,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

