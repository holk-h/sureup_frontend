import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../widgets/common/custom_app_bar.dart';
import 'mistake_preview_screen.dart';

/// 知识点错题列表页面 - 显示某个知识点关联的所有错题
class KnowledgePointMistakesScreen extends StatefulWidget {
  final KnowledgePoint knowledgePoint;

  const KnowledgePointMistakesScreen({
    super.key,
    required this.knowledgePoint,
  });

  @override
  State<KnowledgePointMistakesScreen> createState() =>
      _KnowledgePointMistakesScreenState();
}

class _KnowledgePointMistakesScreenState
    extends State<KnowledgePointMistakesScreen> {
  final _mistakeService = MistakeService();

  List<MistakeRecord>? _mistakes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;

      if (userId == null) {
        setState(() {
          _mistakes = [];
          _isLoading = false;
        });
        return;
      }

      final client = authProvider.authService.client;
      _mistakeService.initialize(client);

      // 获取该知识点关联的所有题目的错题记录
      final allMistakes = await _mistakeService.getUserMistakes(userId);
      
      // 筛选出包含该知识点的错题
      final filteredMistakes = allMistakes.where((mistake) {
        // 检查错题记录的 questionId 是否在知识点的 questionIds 列表中
        return mistake.questionId != null &&
            widget.knowledgePoint.questionIds.contains(mistake.questionId);
      }).toList();

      setState(() {
        _mistakes = filteredMistakes;
        _isLoading = false;
      });
    } catch (e) {
      print('加载错题失败: $e');
      setState(() {
        _error = '加载失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectIcon = widget.knowledgePoint.subject.icon;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            title: '$subjectIcon ${widget.knowledgePoint.name}',
            rightAction: _mistakes != null && _mistakes!.isNotEmpty
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _loadMistakes,
                    child: const Icon(
                      CupertinoIcons.refresh,
                      size: 22,
                    ),
                  )
                : null,
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _mistakes == null || _mistakes!.isEmpty
                        ? _buildEmptyState()
                        : _buildMistakesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(
            radius: 16,
            color: widget.knowledgePoint.subject.color,
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载错题...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _loadMistakes,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.knowledgePoint.subject.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                CupertinoIcons.doc_text,
                size: 40,
                color: widget.knowledgePoint.subject.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无错题',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '该知识点还没有关联的错题',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakesList() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 统计信息卡片
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: _buildStatsCard(),
          ),
        ),

        // 错题列表
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final mistake = _mistakes![index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _mistakes!.length - 1
                        ? AppConstants.spacingM
                        : 0,
                  ),
                  child: _buildMistakeCard(mistake),
                );
              },
              childCount: _mistakes!.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingM),
        ),
      ],
    );
  }

  Widget _buildMistakeCard(MistakeRecord mistake) {
    final mistakeIndex = _mistakes!.indexOf(mistake);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => MistakePreviewScreen(
              mistakeRecordIds: _mistakes!.map((m) => m.id).toList(),
              initialIndex: mistakeIndex,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.knowledgePoint.subject.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                CupertinoIcons.doc_text_fill,
                size: 24,
                color: widget.knowledgePoint.subject.color,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(mistake.masteryStatus),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(mistake.masteryStatus),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeAgo(mistake.createdAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(MasteryStatus status) {
    switch (status) {
      case MasteryStatus.notStarted:
        return '未开始复习';
      case MasteryStatus.practicing:
        return '练习中';
      case MasteryStatus.mastered:
        return '已掌握';
    }
  }

  Color _getStatusColor(MasteryStatus status) {
    switch (status) {
      case MasteryStatus.notStarted:
        return AppColors.warning;
      case MasteryStatus.practicing:
        return AppColors.accent;
      case MasteryStatus.mastered:
        return AppColors.success;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Widget _buildStatsCard() {
    final totalMistakes = _mistakes!.length;
    final masteryColor = _getMasteryColor(widget.knowledgePoint.masteryLevel);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.knowledgePoint.subject.color.withValues(alpha: 0.08),
            widget.knowledgePoint.subject.color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: widget.knowledgePoint.subject.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    widget.knowledgePoint.subject.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.knowledgePoint.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.knowledgePoint.description != null)
                      Text(
                        widget.knowledgePoint.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '$totalMistakes',
                  '错题数',
                  CupertinoIcons.doc_text_fill,
                  AppColors.mistake,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: _buildStatItem(
                  '${widget.knowledgePoint.masteryLevel}%',
                  '掌握度',
                  CupertinoIcons.chart_pie_fill,
                  masteryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

