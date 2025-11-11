import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/photo_question.dart';
import 'photo_detail_screen.dart';
import 'mistake_analysis_progress_screen.dart';
import 'multi_photo_mistake_screen.dart';

/// 错题照片预览和管理页面
/// 支持查看已拍摄照片、继续拍摄、从相册选择、提交照片
/// 学科由 AI 自动识别，不需要手动选择
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 已拍摄的题目列表（支持单图题和多图题）
  final List<PhotoQuestion> _questions = [];

  // 是否显示底部照片预览区
  bool get _hasPhotos => _questions.isNotEmpty;

  // 获取总照片数
  int get _totalPhotoCount {
    return _questions.fold(0, (sum, q) => sum + q.photoCount);
  }

  // 获取总题目数
  int get _totalQuestionCount => _questions.length;

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

      // 如果用户完成裁剪，添加到列表（作为单图题）
      if (croppedFile != null) {
        setState(() {
          _questions.add(PhotoQuestion.single(croppedFile.path));
        });
        HapticFeedback.mediumImpact();
      } else {
        // 用户取消了裁剪，询问是否使用原图
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _questions.add(PhotoQuestion.single(image.path));
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
          _questions.add(PhotoQuestion.single(croppedFile.path));
        });
        HapticFeedback.mediumImpact();
      } else {
        final useOriginal = await _showUseOriginalDialog();
        if (useOriginal == true) {
          setState(() {
            _questions.add(PhotoQuestion.single(image.path));
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('选择失败', '无法访问相册，请检查相册权限设置');
    }
  }

  // 多图拍题
  Future<void> _multiPhotoMistake() async {
    HapticFeedback.mediumImpact();

    final result = await Navigator.of(context).push<List<String>>(
      CupertinoPageRoute(
        builder: (context) => const MultiPhotoMistakeScreen(),
      ),
    );

    // 如果用户完成了多图拍摄，添加到列表
    if (result != null && result.isNotEmpty) {
      setState(() {
        _questions.add(PhotoQuestion.multi(result));
      });
      HapticFeedback.mediumImpact();
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
            resetAspectRatioEnabled: true,
            aspectRatioLockEnabled: false,
            minimumAspectRatio: 0.1, // 放宽最小长宽比限制
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

  // 删除题目
  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  // 查看题目详情（单图题直接查看，多图题显示所有照片）
  void _viewQuestionDetail(int index) {
    final question = _questions[index];
    
    if (question.isSinglePhoto) {
      // 单图题，直接查看
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => PhotoDetailScreen(
            photoPath: question.photosPaths[0],
            totalCount: _totalQuestionCount,
            currentIndex: index,
            onDelete: () {
              Navigator.of(context).pop();
              _deleteQuestion(index);
            },
          ),
        ),
      );
    } else {
      // 多图题，展示所有照片（可以考虑创建一个新的查看界面）
      // 暂时使用简单的提示
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('多图题（${question.photoCount} 张）'),
          content: const Text('这是一道多图题，包含多张照片'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  // 完成并提交
  Future<void> _finish() async {
    if (_questions.isEmpty) return;

    HapticFeedback.mediumImpact();

    // 组织题目数据：每个题目的照片路径列表
    final questionPhotos = _questions.map((q) => q.photosPaths).toList();
    final totalPhotos = _questions.fold(0, (sum, q) => sum + q.photoCount);

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
              Text('即将提交 $_totalQuestionCount 道题（共 $totalPhotos 张照片）'),
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
      // 导航到分析进度页面，传入题目组织的数据
      final success = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (context) => MistakeAnalysisProgressScreen(
            questions: questionPhotos,
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
            onPressed: () => Navigator.of(context).pop(), minimumSize: Size(44, 44),
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
            ),
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
              onPressed: _finish, minimumSize: Size(0, 0),
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
                      '$_totalQuestionCount',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 70), // 占位，保持标题居中
        ],
      ),
    );
  }

  // 构建照片列表
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
                '已拍摄 $_totalPhotoCount 张照片，共 $_totalQuestionCount 题',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        // 题目列表（单列）
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingM,
              0,
              AppConstants.spacingM,
              AppConstants.spacingM,
            ),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _questions.length - 1 ? 12 : 0,
                ),
                child: _buildQuestionListItem(index),
              );
            },
          ),
        ),
      ],
    );
  }

  // 构建题目列表项（支持单图题和多图题）
  Widget _buildQuestionListItem(int index) {
    final question = _questions[index];
    
    return GestureDetector(
      onTap: () => _viewQuestionDetail(index),
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
              // 多图题标识（如果是多图题）
              if (question.isMultiPhoto)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.1),
                        const Color(0xFF6366F1).withOpacity(0.1),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.photo_on_rectangle,
                        size: 16,
                        color: Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '多图题（${question.photoCount} 张）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),

              // 照片预览 - 单图题显示一张，多图题显示横向滚动
              if (question.isSinglePhoto)
                Image.file(
                  File(question.photosPaths[0]),
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
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    itemCount: question.photoCount,
                    itemBuilder: (context, photoIndex) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: photoIndex < question.photoCount - 1 ? 8 : 0,
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(question.photosPaths[photoIndex]),
                                height: 176,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 176,
                                    color: AppColors.background,
                                    child: const Icon(
                                      CupertinoIcons.exclamationmark_triangle,
                                      color: AppColors.textTertiary,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${photoIndex + 1}/${question.photoCount}',
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 序号
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '第 ${index + 1} 题',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // 操作按钮
                    Row(
                      children: [
                        // 查看按钮
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          onPressed: () => _viewQuestionDetail(index),
                          minSize: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.eye,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '查看',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        // 删除按钮
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          onPressed: () => _confirmDeleteQuestion(index),
                          minSize: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.trash,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '删除',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // 确认删除题目
  Future<void> _confirmDeleteQuestion(int index) async {
    final question = _questions[index];
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除题目'),
        content: Text(
          question.isMultiPhoto 
            ? '确定要删除这道多图题吗？（包含 ${question.photoCount} 张照片）'
            : '确定要删除这道题吗？'
        ),
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
      _deleteQuestion(index);
    }
  }

  // 构建空状态
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
                  color: const Color(0xFFF472B6).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFFC084FC).withOpacity(0.04),
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
                          colors: [Color(0xFFF472B6), Color(0xFFC084FC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF472B6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
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
                            '拍题记录',
                            style: AppTextStyles.smallTitle.copyWith(
                              color: const Color(0xFFF472B6),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '记录错题，智能分析',
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
                        const Color(0xFFF472B6).withOpacity(0.2),
                        CupertinoColors.transparent,
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 功能说明
                _buildGuideItem(
                  '功能说明',
                  CupertinoIcons.info_circle_fill,
                  [
                    '可以拍摄多道错题',
                    '拍完后点击右上角"完成"',
                    '系统会自动识别学科并分析',
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 使用提示
                _buildGuideItem(
                  '使用提示',
                  CupertinoIcons.lightbulb_fill,
                  [
                    '支持单图题和多图题',
                    '确保照片清晰、完整',
                    '可以随时添加或删除题目',
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
                  const Color(0xFFF472B6).withOpacity(0.1),
                  const Color(0xFFC084FC).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF472B6).withOpacity(0.2),
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
                        color: const Color(0xFFF472B6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        color: Color(0xFFF472B6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '准备开始',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF472B6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '点击下方"拍照"按钮开始拍摄第一道错题',
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
              color: const Color(0xFFF472B6),
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
                    color: const Color(0xFFF472B6).withOpacity(0.6),
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

  // 构建底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 相册按钮 - 只显示图标
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

            // 多图拍题按钮
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: const Color(0xFFC7D2FE),
                borderRadius: BorderRadius.circular(16),
                onPressed: _multiPhotoMistake,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.photo_on_rectangle,
                      color: AppColors.accentDark,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '多图',
                      style: TextStyle(
                        color: AppColors.accentDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 拍照按钮 - 粉紫渐变
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF472B6), Color(0xFFC084FC)],
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  borderRadius: BorderRadius.circular(16),
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
                        _hasPhotos ? '继续拍照' : '拍照',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

