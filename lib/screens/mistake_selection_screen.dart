import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../services/question_generation_service.dart';
import '../widgets/common/math_markdown_text.dart';
import 'question_generation_progress_screen.dart';

/// 错题选择页面 - 用于选择错题生成变式题
class MistakeSelectionScreen extends StatefulWidget {
  const MistakeSelectionScreen({super.key});

  @override
  State<MistakeSelectionScreen> createState() => _MistakeSelectionScreenState();
}

class _MistakeSelectionScreenState extends State<MistakeSelectionScreen> {
  final MistakeService _mistakeService = MistakeService();
  final QuestionGenerationService _questionGenerationService = QuestionGenerationService();
  
  List<MistakeRecord> _allMistakes = [];
  final Map<String, Question> _questionCache = {};
  final Set<String> _selectedMistakeIds = {};
  int _variantsPerQuestion = 1; // 默认每题生成1道变式题
  int _currentPage = 0; // 当前页码（从0开始）
  static const int _itemsPerPage = 10; // 每页显示10道错题
  bool _isLoading = true;
  bool _isGenerating = false;
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
          _error = '请先登录';
          _isLoading = false;
        });
        return;
      }

      _mistakeService.initialize(authProvider.authService.client);

      // 获取所有错题
      final mistakes = await _mistakeService.getUserMistakes(userId);
      
      // 只显示有题目ID的错题（已分析的）
      final mistakesWithQuestions = mistakes
          .where((m) => m.questionId != null)
          .toList();

      // 加载对应的题目内容
      final questionIds = mistakesWithQuestions
          .map((m) => m.questionId!)
          .toSet()
          .toList();

      if (questionIds.isNotEmpty) {
        final questions = await _mistakeService.getQuestions(questionIds);
        for (final question in questions) {
          _questionCache[question.id] = question;
        }
      }

      if (mounted) {
        setState(() {
          _allMistakes = mistakesWithQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载错题失败: $e');
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(String mistakeId) {
    setState(() {
      if (_selectedMistakeIds.contains(mistakeId)) {
        _selectedMistakeIds.remove(mistakeId);
      } else {
        _selectedMistakeIds.add(mistakeId);
      }
    });
  }

  Future<void> _generateVariants() async {
    if (_selectedMistakeIds.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('请选择错题'),
          content: const Text('至少选择一道错题才能生成变式题'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userProfile?.id;
      final userProfile = authProvider.userProfile;

      if (userId == null) {
        throw Exception('请先登录');
      }

      _questionGenerationService.initialize(authProvider.authService.client);

      // 获取选中错题对应的题目ID
      final selectedMistakes = _allMistakes
          .where((m) => _selectedMistakeIds.contains(m.id))
          .toList();
      
      final questionIds = selectedMistakes
          .map((m) => m.questionId!)
          .where((id) => id.isNotEmpty)
          .toList();

      if (questionIds.isEmpty) {
        throw Exception('所选错题没有对应的题目ID');
      }

      // 创建生成任务
      final task = await _questionGenerationService.createTask(
        userId: userId,
        sourceQuestionIds: questionIds,
        variantsPerQuestion: _variantsPerQuestion,
        userProfile: userProfile,
      );

      if (mounted) {
        // 跳转到进度页面
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => QuestionGenerationProgressScreen(
              taskId: task.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('生成变式题失败: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('生成失败'),
            content: Text(e.toString()),
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
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('选择错题'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 变式题数量选择
            _buildVariantCountSelector(),
            
            // 错题列表
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _allMistakes.isEmpty
                          ? _buildEmptyState()
                          : _buildMistakeList(),
            ),
            
            // 底部操作栏
            if (!_isLoading && _error == null && _allMistakes.isNotEmpty)
              _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantCountSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '每题生成',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // 减少按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _variantsPerQuestion > 1
                ? () {
                    setState(() {
                      _variantsPerQuestion--;
                    });
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _variantsPerQuestion > 1
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      )
                    : null,
                color: _variantsPerQuestion > 1
                    ? null
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _variantsPerQuestion > 1
                    ? AppColors.coloredShadow(AppColors.primary, opacity: 0.2)
                    : null,
              ),
              child: Icon(
                CupertinoIcons.minus,
                size: 18,
                color: _variantsPerQuestion > 1
                    ? AppColors.cardBackground
                    : AppColors.textTertiary,
              ),
            ), minimumSize: Size(0, 0),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // 数量显示
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.coloredShadow(AppColors.primary, opacity: 0.25),
            ),
            child: Text(
              '$_variantsPerQuestion',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.cardBackground,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // 增加按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _variantsPerQuestion < 10
                ? () {
                    setState(() {
                      _variantsPerQuestion++;
                    });
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _variantsPerQuestion < 10
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      )
                    : null,
                color: _variantsPerQuestion < 10
                    ? null
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _variantsPerQuestion < 10
                    ? AppColors.coloredShadow(AppColors.primary, opacity: 0.2)
                    : null,
              ),
              child: Icon(
                CupertinoIcons.plus,
                size: 18,
                color: _variantsPerQuestion < 10
                    ? AppColors.cardBackground
                    : AppColors.textTertiary,
              ),
            ), minimumSize: Size(0, 0),
          ),
          const SizedBox(width: AppConstants.spacingM),
          const Text(
            '道变式题',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.shadowSoft,
            ),
            child: const CupertinoActivityIndicator(
              radius: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '加载错题中...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请稍候',
            style: TextStyle(
              fontSize: 13,
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
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: AppColors.shadowSoft,
              ),
              child: const Icon(
                CupertinoIcons.doc_text,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '暂无错题',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '记录错题后，这里会显示所有错题',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取当前页的错题列表
  List<MistakeRecord> get _currentPageMistakes {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _allMistakes.length);
    return _allMistakes.sublist(startIndex, endIndex);
  }

  // 获取总页数
  int get _totalPages {
    if (_allMistakes.isEmpty) return 1;
    return ((_allMistakes.length - 1) / _itemsPerPage).floor() + 1;
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  Widget _buildMistakeList() {
    final currentPageMistakes = _currentPageMistakes;
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            itemCount: currentPageMistakes.length,
            itemBuilder: (context, index) {
              final mistake = currentPageMistakes[index];
              final isSelected = _selectedMistakeIds.contains(mistake.id);
              final question = mistake.questionId != null
                  ? _questionCache[mistake.questionId]
                  : null;

        return GestureDetector(
          onTap: () => _toggleSelection(mistake.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.accent.withValues(alpha: 0.03),
                      ],
                    )
                  : null,
              color: isSelected ? null : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.divider,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? AppColors.coloredShadow(AppColors.primary, opacity: 0.1)
                  : AppColors.shadowSoft,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 选择框 - 精美设计
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? AppColors.primaryGradient
                        : null,
                    color: isSelected
                        ? null
                        : AppColors.cardBackground,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.divider,
                      width: isSelected ? 0 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: isSelected
                      ? const Icon(
                          CupertinoIcons.checkmark,
                          size: 14,
                          color: AppColors.cardBackground,
                        )
                      : null,
                ),
                const SizedBox(width: AppConstants.spacingS),
                // 错题内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 学科和时间
                      Row(
                        children: [
                          if (mistake.subject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    mistake.subject!.color.withValues(alpha: 0.12),
                                    mistake.subject!.color.withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: mistake.subject!.color.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    mistake.subject!.icon,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    mistake.subject!.displayName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: mistake.subject!.color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (mistake.subject != null)
                            const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _formatTimeAgo(mistake.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 题目内容
                      if (question != null && question.content.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 48,
                          ),
                          child: ClipRect(
                            child: MathMarkdownText(
                              text: question.content,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.doc_text,
                                size: 12,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '错题记录',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
        // 分页控制器
        if (_totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cardBackground,
            AppColors.cardBackground.withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页按钮
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            onPressed: _currentPage > 0
                ? () => _goToPage(_currentPage - 1)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
              decoration: BoxDecoration(
                gradient: _currentPage > 0
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      )
                    : null,
                color: _currentPage > 0 ? null : AppColors.divider,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _currentPage > 0
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.chevron_left,
                    size: 16,
                    color: _currentPage > 0
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '上一页',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _currentPage > 0
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ), minimumSize: Size(0, 0),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // 页码显示
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.coloredShadow(AppColors.primary, opacity: 0.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentPage + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cardBackground,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cardBackground,
                    ),
                  ),
                ),
                Text(
                  '$_totalPages',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cardBackground.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          // 下一页按钮
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            onPressed: _currentPage < _totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
              decoration: BoxDecoration(
                gradient: _currentPage < _totalPages - 1
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      )
                    : null,
                color: _currentPage < _totalPages - 1
                    ? null
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _currentPage < _totalPages - 1
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '下一页',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _currentPage < _totalPages - 1
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: _currentPage < _totalPages - 1
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ],
              ),
            ), minimumSize: Size(0, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final selectedCount = _selectedMistakeIds.length;
    final totalVariants = selectedCount * _variantsPerQuestion;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: CupertinoColors.transparent,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统计信息 - 紧凑设计
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(
                  icon: CupertinoIcons.checkmark_circle,
                  label: '已选择',
                  value: '$selectedCount',
                  unit: '道',
                ),
                const SizedBox(width: AppConstants.spacingL),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.divider,
                ),
                const SizedBox(width: AppConstants.spacingL),
                _buildStatItem(
                  icon: CupertinoIcons.sparkles,
                  label: '将生成',
                  value: '$totalVariants',
                  unit: '道',
                  isHighlight: true,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                onPressed: _isGenerating || selectedCount == 0
                    ? null
                    : _generateVariants,
                child: _isGenerating
                    ? const CupertinoActivityIndicator()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.sparkles,
                            size: 18,
                            color: AppColors.cardBackground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedCount == 0
                                ? '请先选择错题'
                                : '生成 $totalVariants 道变式题',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cardBackground,
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    bool isHighlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlight ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isHighlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isHighlight
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isHighlight
                ? AppColors.primary.withValues(alpha: 0.8)
                : AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks周前';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months个月前';
    }
  }
}

