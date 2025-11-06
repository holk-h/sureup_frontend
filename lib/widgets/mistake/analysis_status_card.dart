import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';

/// 分析状态卡片组件
class AnalysisStatusCard extends StatelessWidget {
  final MistakeRecord mistakeRecord;
  final Animation<double> progressAnimation;
  final VoidCallback onStartProgress;

  const AnalysisStatusCard({
    super.key,
    required this.mistakeRecord,
    required this.progressAnimation,
    required this.onStartProgress,
  });

  @override
  Widget build(BuildContext context) {
    final status = mistakeRecord.analysisStatus;

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: _getStatusGradient(status),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 状态图标
          _buildStatusIcon(status),

          const SizedBox(height: 16),

          // 状态文本
          Text(
            _getStatusTitle(status),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          // 状态描述
          Text(
            _getStatusDescription(status),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          // 学科标签（分析完成后显示）
          if (status == AnalysisStatus.completed && mistakeRecord.subject != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.book_fill,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mistakeRecord.subject!.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.ocrOK:
      case AnalysisStatus.processing:
        // 启动进度条动画
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onStartProgress();
        });
        
        // 使用15秒进度条
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圆圈
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.1),
                      AppColors.success.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  size: 32,
                  color: AppColors.success,
                ),
              ),
              // 进度条圆环
              SizedBox(
                width: 100,
                height: 100,
                child: AnimatedBuilder(
                  animation: progressAnimation,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: progressAnimation.value,
                      strokeWidth: 4,
                      backgroundColor: AppColors.success.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    );
                  },
                ),
              ),
              // 百分比文字
              Positioned(
                bottom: 0,
                child: AnimatedBuilder(
                  animation: progressAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progressAnimation.value * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

      case AnalysisStatus.ocrWrong:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.warning,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 40,
            color: AppColors.warning,
          ),
        );

      case AnalysisStatus.completed:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.success,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.checkmark_alt,
            size: 40,
            color: AppColors.success,
          ),
        );

      case AnalysisStatus.failed:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.error,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.xmark,
            size: 40,
            color: AppColors.error,
          ),
        );
    }
  }

  LinearGradient _getStatusGradient(AnalysisStatus status) {
    final color = _getStatusColor(status);
    return LinearGradient(
      colors: [
        color.withValues(alpha: 0.08),
        color.withValues(alpha: 0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getStatusColor(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.ocrOK:
      case AnalysisStatus.processing:
        return AppColors.primary;
      case AnalysisStatus.ocrWrong:
        return AppColors.warning;
      case AnalysisStatus.completed:
        return AppColors.success;
      case AnalysisStatus.failed:
        return AppColors.error;
    }
  }

  String _getStatusTitle(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
        return 'AI 分析中';
      case AnalysisStatus.ocrOK:
        return 'AI 深度分析中';
      case AnalysisStatus.processing:
        return 'AI 分析中';
      case AnalysisStatus.ocrWrong:
        return '识别有误';
      case AnalysisStatus.completed:
        return '分析完成';
      case AnalysisStatus.failed:
        return '分析失败';
    }
  }

  String _getStatusDescription(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.processing:
        return '分析过程大约需要 10-15 秒，请稍候';
      case AnalysisStatus.ocrOK:
        return '正在分析答案、知识点等信息，请稍候';
      case AnalysisStatus.ocrWrong:
        return mistakeRecord.wrongReason ?? '已反馈识别错误，等待重新处理';
      case AnalysisStatus.completed:
        return 'AI 已完成分析，查看下方详情';
      case AnalysisStatus.failed:
        return mistakeRecord.analysisError ?? '分析过程中出现错误';
    }
  }
}
