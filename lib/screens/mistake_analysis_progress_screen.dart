import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../services/mistake_service.dart';
import '../providers/auth_provider.dart';
import 'mistake_preview_screen.dart';

/// 错题分析进度页面
/// 显示图片上传和 AI 分析的实时进度
/// 学科由 AI 自动识别
class MistakeAnalysisProgressScreen extends StatefulWidget {
  final List<String> photoFilePaths; // 照片文件路径列表

  const MistakeAnalysisProgressScreen({
    super.key,
    required this.photoFilePaths,
  });

  @override
  State<MistakeAnalysisProgressScreen> createState() =>
      _MistakeAnalysisProgressScreenState();
}

class _MistakeAnalysisProgressScreenState
    extends State<MistakeAnalysisProgressScreen> with TickerProviderStateMixin {
  final MistakeService _mistakeService = MistakeService();

  // 进度状态
  String _status = '准备上传...';
  double _progress = 0.0;
  bool _isUploading = false;
  bool _isCompleted = false;
  bool _hasError = false;
  String? _errorMessage;

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startUploadAndAnalysis();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 开始上传和分析
  Future<void> _startUploadAndAnalysis() async {
    try {
      // 1. 上传图片
      setState(() {
        _isUploading = true;
        _status = '正在上传照片...';
        _progress = 0.1;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _progress = 0.3;
        _status = '上传中 (${widget.photoFilePaths.length} 张照片)...';
      });

      // 获取当前用户 ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;
      if (userId == null) {
        throw Exception('未登录');
      }

      // 创建错题记录（包含上传）
      final recordId = await _mistakeService.createMistakeFromPhotos(
        userId: userId,
        photoFilePaths: widget.photoFilePaths,
      );

      // 获取上传的图片 ID
      final record = await _mistakeService.getMistakeRecord(recordId);
      final imageIds = record?.originalImageIds ?? [];

      setState(() {
        _progress = 1.0;
        _isUploading = false;
        _isCompleted = true;
        _status = '上传完成！';
      });

      HapticFeedback.mediumImpact();

      // 等待一小段时间显示完成状态
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // 跳转到预览页面
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => MistakePreviewScreen(
            mistakeRecordId: recordId,
            originalImageIds: imageIds,
          ),
        ),
      );
    } catch (e) {
      _handleError('上传失败: $e');
    }
  }

  // 处理错误
  void _handleError(String message) {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isUploading = false;
    });

    HapticFeedback.heavyImpact();
  }

  // 重试
  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _progress = 0.0;
      _status = '准备上传...';
      _isCompleted = false;
    });

    await _startUploadAndAnalysis();
  }

  // 取消并返回
  void _cancel() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认取消'),
        content: const Text('确定要取消上传和分析吗？已上传的数据将保留。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('继续分析'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(false); // 返回上一页
            },
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Stack(
          children: [
            // 主内容
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 动画图标
                    _buildAnimatedIcon(),

                    const SizedBox(height: 32),

                    // 状态文本
                    Text(
                      _status,
                      style: AppTextStyles.largeTitle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // 进度条
                    if (!_hasError && !_isCompleted) _buildProgressBar(),

                    // 错误信息
                    if (_hasError) _buildErrorView(),

                    // 完成提示
                    if (_isCompleted) _buildCompletedView(),
                  ],
                ),
              ),
            ),

            // 顶部取消按钮（仅在未完成且无错误时显示）
            if (!_isCompleted && !_hasError)
              Positioned(
                top: 12,
                right: 12,
                child: CupertinoButton(
                  onPressed: _cancel,
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: AppColors.textTertiary,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建动画图标
  Widget _buildAnimatedIcon() {
    if (_hasError) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error.withOpacity(0.1),
        ),
        child: const Icon(
          CupertinoIcons.xmark_circle_fill,
          size: 60,
          color: AppColors.error,
        ),
      );
    }

    if (_isCompleted) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success.withOpacity(0.1),
        ),
        child: const Icon(
          CupertinoIcons.checkmark_circle_fill,
          size: 60,
          color: AppColors.success,
        ),
      );
    }

    // 分析中的动画
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF472B6), Color(0xFFC084FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF472B6).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.sparkles,
          size: 48,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  // 构建进度条
  Widget _buildProgressBar() {
    return Column(
      children: [
        // 进度条
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.dividerLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF472B6), Color(0xFFC084FC)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 百分比
        Text(
          '${(_progress * 100).toInt()}%',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 24),

        // 提示文本
        Text(
          _isUploading
              ? '正在上传照片到云端...'
              : 'AI 正在识别和分析题目，这可能需要一些时间',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 构建错误视图
  Widget _buildErrorView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
            ),
          ),
          child: Text(
            _errorMessage ?? '未知错误',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 24),

        // 重试按钮
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _retry,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.arrow_clockwise,
                  color: CupertinoColors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '重试',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 取消按钮
        CupertinoButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            '返回',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  // 构建完成视图
  Widget _buildCompletedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.checkmark_alt,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '分析完成！即将返回...',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'AI 已成功分析 ${widget.photoFilePaths.length} 张错题照片',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

