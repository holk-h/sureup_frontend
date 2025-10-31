import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import 'camera_screen.dart';

/// 拍照功能主入口页面
class CameraPlaceholderScreen extends StatefulWidget {
  const CameraPlaceholderScreen({super.key});

  @override
  State<CameraPlaceholderScreen> createState() =>
      _CameraPlaceholderScreenState();
}

class _CameraPlaceholderScreenState extends State<CameraPlaceholderScreen> {
  Subject _selectedSubject = Subject.math; // 默认选择数学

  // 开始拍照
  Future<void> _startCamera() async {
    HapticFeedback.mediumImpact();

    // 进入拍照界面，现在会直接处理上传和分析
    final success = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => CameraScreen(
          subject: _selectedSubject,
        ),
      ),
    );

    // 分析完成，返回主页并刷新
    if (success == true && mounted) {
      // 可以在这里触发刷新或显示提示
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('分析完成'),
          content: const Text('AI 已成功分析你的错题，可以在分析页查看详情。'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        middle: Text('记录错题', style: AppTextStyles.smallTitle),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // 标题
              const Text(
                '拍照记录错题',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // 描述
              const Text(
                'AI 将自动识别题目、分析错因\n帮助你更好地复盘和提升',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // 学科选择
              _buildSubjectSelector(),

              const Spacer(),

              // 开始拍照按钮
              _buildStartButton(),

              const SizedBox(height: AppConstants.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  // 构建学科选择器
  Widget _buildSubjectSelector() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              const Icon(
                CupertinoIcons.book_fill,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                '选择学科',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 学科列表
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: Subject.values.map((subject) {
              final isSelected = _selectedSubject == subject;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedSubject = subject;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? CupertinoColors.white.withOpacity(0)
                          : AppColors.divider,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    subject.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? CupertinoColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 构建开始按钮
  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 56,
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
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        onPressed: _startCamera,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.camera_fill,
              color: CupertinoColors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              '开始拍照',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
