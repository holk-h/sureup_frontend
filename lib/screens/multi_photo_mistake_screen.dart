import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';

/// 多图拍题界面
/// 支持连续拍摄多张照片，组合为一道题
class MultiPhotoMistakeScreen extends StatefulWidget {
  const MultiPhotoMistakeScreen({super.key});

  @override
  State<MultiPhotoMistakeScreen> createState() => _MultiPhotoMistakeScreenState();
}

class _MultiPhotoMistakeScreenState extends State<MultiPhotoMistakeScreen> {
  // 当前题目已拍摄的照片列表
  final List<String> _currentQuestionPhotos = [];
  
  // ImagePicker 实例
  final ImagePicker _picker = ImagePicker();

  // 开始拍摄
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
          _currentQuestionPhotos.add(croppedFile.path);
        });
        HapticFeedback.mediumImpact();
      } else {
        // 用户取消了裁剪，询问是否使用原图
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _currentQuestionPhotos.add(image.path);
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
    HapticFeedback.mediumImpact();

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
          _currentQuestionPhotos.add(croppedFile.path);
        });
        HapticFeedback.mediumImpact();
      } else {
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _currentQuestionPhotos.add(image.path);
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
        uiSettings: [
          // iOS 设置
          IOSUiSettings(
            title: '裁剪照片',
            doneButtonTitle: '完成',
            cancelButtonTitle: '取消',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            minimumAspectRatio: 0.1, // 最小长宽比，允许更自由的比例
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            hidesNavigationBar: false,
          ),
          // Android 设置
          AndroidUiSettings(
            toolbarTitle: '裁剪照片',
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
      return null;
    }
  }

  // 显示使用原图对话框
  Future<bool?> _showUseOriginalDialog() async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('使用原图'),
        content: const Text('是否使用未裁剪的原始照片？'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('重新拍摄'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('使用原图'),
          ),
        ],
      ),
    );
  }

  // 显示错误对话框
  Future<void> _showErrorDialog(String title, String message) async {
    return showCupertinoDialog(
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

  // 删除某张照片
  void _deletePhoto(int index) {
    setState(() {
      _currentQuestionPhotos.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  // 完成这道题
  Future<void> _finishQuestion() async {
    if (_currentQuestionPhotos.isEmpty) return;

    HapticFeedback.mediumImpact();

    // 如果只有1张，提示用户
    if (_currentQuestionPhotos.length == 1) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('💡 提示'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('这道题只有 1 页吗？\n'),
                Text(
                  '• 如果题目还有下一页，请继续拍摄\n',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '• 如果题目完整，可以直接提交',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续拍摄'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认提交'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      // 多张照片，确认完成
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('✅ 确认完成？'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('这道题共拍摄了 ${_currentQuestionPhotos.length} 张照片\n即将整合为一道题目'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('再拍一张'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认完成'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // 返回照片列表
    if (mounted) {
      Navigator.of(context).pop(_currentQuestionPhotos);
    }
  }

  // 返回时的确认
  Future<bool> _onWillPop() async {
    if (_currentQuestionPhotos.isEmpty) {
      return true;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('⚠️ 正在拍摄中'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('当前题目还未完成（已拍 ${_currentQuestionPhotos.length} 张）'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续拍摄'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃并返回'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentQuestionPhotos.isEmpty, // 没有照片时允许直接返回（包括滑动返回）
      onPopInvoked: (didPop) async {
        if (!didPop && _currentQuestionPhotos.isNotEmpty) {
          // 有照片时，阻止了返回，显示确认对话框
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              _buildNavigationBar(),

              // 主内容区
              Expanded(
                child: _currentQuestionPhotos.isEmpty
                    ? _buildEmptyState()
                    : _buildPhotoList(),
              ),

              // 底部操作栏
              _buildBottomActionBar(),
            ],
          ),
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
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
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
            '多图拍题',
            style: AppTextStyles.smallTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 70), // 占位，保持标题居中
        ],
      ),
    );
  }

  // 构建空状态（引导界面）
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // 功能说明卡片 - 更现代的设计
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题区域
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.photo_on_rectangle,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '多图拍题',
                            style: AppTextStyles.smallTitle.copyWith(
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '将多页题目整合为一道题',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // 分割线
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.transparent,
                        const Color(0xFF8B5CF6).withOpacity(0.2),
                        CupertinoColors.transparent,
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 适用场景
                _buildGuideItem(
                  '适用场景',
                  CupertinoIcons.book_fill,
                  [
                    '题目跨页分布在多页',
                    '图表和题目分开',
                    '题目特别长',
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 使用方法
                _buildGuideItem(
                  '使用方法',
                  CupertinoIcons.checkmark_circle_fill,
                  [
                    '连续拍摄题目的每一部分',
                    '拍完后点击"完成这道题"',
                    '系统会自动整合为一题',
                  ],
                ),
              ],
            ),
          ),

          // 当前状态卡片 - 更精美的设计
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                  const Color(0xFF6366F1).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        color: Color(0xFF8B5CF6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '准备开始',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '点击下方"拍摄"按钮开始拍摄第一张照片',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 构建引导项 - 优化后的设计
  Widget _buildGuideItem(String title, IconData icon, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < items.length - 1 ? 8 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 构建照片列表
  Widget _buildPhotoList() {
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
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.photo_on_rectangle,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '已拍摄 ${_currentQuestionPhotos.length} 张照片',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        // 提示信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 18,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前拍摄的都是同一道题',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '如果题目还有下一页，可以继续拍摄；如果题目完整，点击"完成"即可',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 照片列表（垂直）
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingM,
              0,
              AppConstants.spacingM,
              AppConstants.spacingM,
            ),
            itemCount: _currentQuestionPhotos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _currentQuestionPhotos.length - 1 ? 12 : 0,
                ),
                child: _buildPhotoListItem(index),
              );
            },
          ),
        ),
      ],
    );
  }

  // 构建照片列表项
  Widget _buildPhotoListItem(int index) {
    return GestureDetector(
      onTap: () {
        // 可以点击查看大图
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cardBackground,
          boxShadow: AppColors.shadowSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // 照片
              Image.file(
                File(_currentQuestionPhotos[index]),
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        color: AppColors.textTertiary,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),

              // 底部操作栏
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.divider.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '第 ${index + 1} 张',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _deletePhoto(index),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.trash,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '删除',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ), minimumSize: Size(0, 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建底部操作栏
  Widget _buildBottomActionBar() {
    final bool hasPhotos = _currentQuestionPhotos.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 相册按钮
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              color: AppColors.accentLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              onPressed: _pickFromGallery,
              child: const Icon(
                CupertinoIcons.photo,
                color: AppColors.accent,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // 完成这道题按钮
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: _currentQuestionPhotos.isEmpty
                    ? AppColors.textTertiary.withOpacity(0.3)
                    : AppColors.success,
                borderRadius: BorderRadius.circular(16),
                onPressed: _currentQuestionPhotos.isEmpty ? null : _finishQuestion,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: _currentQuestionPhotos.isEmpty
                          ? AppColors.textTertiary
                          : CupertinoColors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '完成',
                      style: TextStyle(
                        color: _currentQuestionPhotos.isEmpty
                            ? AppColors.textTertiary
                            : CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 拍摄/继续拍摄按钮
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                onPressed: _takePicture,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasPhotos ? CupertinoIcons.add_circled_solid : CupertinoIcons.camera_fill,
                      color: const Color(0xFF8B5CF6),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasPhotos ? '继续拍摄' : '拍摄',
                      style: TextStyle(
                        color: const Color(0xFF8B5CF6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

