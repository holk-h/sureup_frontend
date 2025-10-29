import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';

/// 智能复盘卡片 - 简化版
class DailyReviewCard extends StatefulWidget {
  final int questionCount; // 题目数量
  final VoidCallback onTap;

  const DailyReviewCard({
    super.key,
    required this.questionCount,
    required this.onTap,
  });

  @override
  State<DailyReviewCard> createState() => _DailyReviewCardState();
}

class _DailyReviewCardState extends State<DailyReviewCard> {
  bool _isGenerating = false;
  bool _isReady = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _getOnTapHandler(),
      child: Container(
        padding: const EdgeInsets.only(
          left: AppConstants.spacingL,
          right: AppConstants.spacingL,
          top: AppConstants.spacingL,
          bottom: AppConstants.spacingM, // 底部用更小的间距
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.calendar_today,
                    color: AppColors.cardBackground,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '智能复盘',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '基于遗忘规律和错题记录，AI会智能出题',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppConstants.spacingM),
            
            // 开始按钮或进度显示
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  VoidCallback? _getOnTapHandler() {
    if (_isGenerating) return null; // 生成中不可点击
    if (_isReady) return widget.onTap; // 就绪时执行原回调
    return _startGenerating; // 初始状态开始生成
  }

  Widget _buildActionButton() {
    if (_isGenerating) {
      return _buildGeneratingState();
    } else if (_isReady) {
      return _buildReadyState();
    } else {
      return _buildInitialState();
    }
  }

  Widget _buildInitialState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        '开始生成',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.cardBackground,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 2.5,
                  backgroundColor: AppColors.dividerLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI正在为你生成题目...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.dividerLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 6,
                    width: constraints.maxWidth * _progress,
                    decoration: BoxDecoration(
                      gradient: AppColors.secondaryGradient,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: AppColors.cardBackground,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '题目就绪，去做题！→',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cardBackground,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _regenerate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '点击根据最新数据，重新生成',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 0),
      ],
    );
  }

  void _startGenerating() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    // 模拟生成过程 - 更流畅的动画
    const totalSteps = 100;
    for (int i = 0; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        setState(() {
          _progress = i / totalSteps;
        });
      }
    }

    // 生成完成
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _isReady = true;
      });
    }
  }

  void _regenerate() {
    setState(() {
      _isReady = false;
      _progress = 0.0;
    });
    _startGenerating();
  }
}

