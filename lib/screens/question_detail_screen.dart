import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';

/// 题目详情页面 - 直接从 questions 表读取题目信息
class QuestionDetailScreen extends StatefulWidget {
  final List<String> questionIds; // 题目 ID 列表
  final int initialIndex; // 初始显示的索引

  const QuestionDetailScreen({
    super.key,
    required this.questionIds,
    this.initialIndex = 0,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final _mistakeService = MistakeService();
  late PageController _pageController;
  
  // 题目缓存：questionId -> Question
  final Map<String, Question> _questionCache = {};
  // 加载状态：questionId -> isLoading
  final Map<String, bool> _loadingStatus = {};
  // 错误状态：questionId -> errorMessage
  final Map<String, String?> _errorStatus = {};
  
  // 折叠状态：questionId -> {answerExpanded, explanationExpanded}
  final Map<String, Map<String, bool>> _expandStatus = {};
  
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // 预加载初始页面和相邻页面
    _loadQuestion(widget.initialIndex);
    if (widget.initialIndex > 0) {
      _loadQuestion(widget.initialIndex - 1);
    }
    if (widget.initialIndex < widget.questionIds.length - 1) {
      _loadQuestion(widget.initialIndex + 1);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isExpanded(String questionId, String type) {
    return _expandStatus[questionId]?[type] ?? false;
  }

  void _toggleExpand(String questionId, String type) {
    setState(() {
      _expandStatus.putIfAbsent(questionId, () => {});
      _expandStatus[questionId]![type] = !_isExpanded(questionId, type);
    });
  }

  Future<void> _loadQuestion(int index) async {
    if (index < 0 || index >= widget.questionIds.length) return;
    
    final questionId = widget.questionIds[index];
    
    // 如果已经加载过，直接返回
    if (_questionCache.containsKey(questionId)) {
      return;
    }
    
    // 设置加载状态
    setState(() {
      _loadingStatus[questionId] = true;
      _errorStatus[questionId] = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.authService.client;
      _mistakeService.initialize(client);
      
      final question = await _mistakeService.getQuestion(questionId);
      
      if (question != null && mounted) {
        setState(() {
          _questionCache[questionId] = question;
          _loadingStatus[questionId] = false;
        });
      } else if (mounted) {
        setState(() {
          _loadingStatus[questionId] = false;
          _errorStatus[questionId] = '题目不存在';
        });
      }
    } catch (e) {
      print('加载题目失败: $e');
      if (mounted) {
        setState(() {
          _loadingStatus[questionId] = false;
          _errorStatus[questionId] = '加载失败：$e';
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // 预加载相邻页面
    _loadQuestion(index);
    if (index > 0) {
      _loadQuestion(index - 1);
    }
    if (index < widget.questionIds.length - 1) {
      _loadQuestion(index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(
            title: '题目详情',
            rightAction: widget.questionIds.length > 1
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${_currentIndex + 1}/${widget.questionIds.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.questionIds.length,
              itemBuilder: (context, index) {
                return _buildQuestionPage(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(int index) {
    final questionId = widget.questionIds[index];
    final question = _questionCache[questionId];
    final isLoading = _loadingStatus[questionId] ?? false;
    final error = _errorStatus[questionId];
    
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 16),
            const SizedBox(height: 16),
            Text(
              '正在加载题目...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    if (error != null || question == null) {
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
                error ?? '题目不存在',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () => _loadQuestion(index),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 题目详情卡片
        SliverToBoxAdapter(
          child: _buildQuestionDetails(question),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingM),
        ),
      ],
    );
  }

  Widget _buildQuestionDetails(Question question) {
    final questionId = question.id;
    
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容卡片
          _buildContentCard(question),
          
          // 选项卡片（如果有选项）
          if (question.options != null && question.options!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildOptionsCard(question.options!),
          ],
          
          const SizedBox(height: AppConstants.spacingM),
          
          // 答案卡片（可折叠）
          if (question.answer != null && question.answer!.isNotEmpty)
            _buildCollapsibleCard(
              questionId: questionId,
              type: 'answer',
              title: '答案',
              icon: CupertinoIcons.checkmark_circle_fill,
              iconColor: AppColors.success,
              child: MathMarkdownText(
                text: question.answer!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          
          // 解析卡片（可折叠）
          if (question.explanation != null && question.explanation!.isNotEmpty) ...[
            if (question.answer != null && question.answer!.isNotEmpty)
              const SizedBox(height: AppConstants.spacingM),
            _buildCollapsibleCard(
              questionId: questionId,
              type: 'explanation',
              title: '解析',
              icon: CupertinoIcons.lightbulb_fill,
              iconColor: AppColors.warning,
              child: MathMarkdownText(
                text: question.explanation!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentCard(Question question) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.doc_text_fill,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              const Text(
                '题目内容',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          // 题目内容
          MathMarkdownText(
            text: question.content,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(List<String> options) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildOptions(options),
    );
  }

  Widget _buildCollapsibleCard({
    required String questionId,
    required String type,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    final isExpanded = _isExpanded(questionId, type);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏（可点击）
            GestureDetector(
              onTap: () => _toggleExpand(questionId, type),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingL,
                  vertical: AppConstants.spacingM,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 内容区域（可折叠）- 使用预渲染策略减少卡顿
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  opacity: isExpanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: isExpanded ? null : 0,
                    child: Visibility(
                      visible: isExpanded,
                      maintainState: true,
                      maintainAnimation: true,
                      child: RepaintBoundary(
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.spacingL),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.list_bullet,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppConstants.spacingS),
            const Text(
              '选项',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final label = String.fromCharCode(65 + index); // A, B, C, D...
          
          return Container(
            margin: EdgeInsets.only(
              bottom: index < options.length - 1 ? AppConstants.spacingM : 0,
            ),
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: AppColors.divider,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent,
                        AppColors.accent.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: MathMarkdownText(
                    text: option,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

