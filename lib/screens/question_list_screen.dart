import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/math_markdown_text.dart';
import 'question_detail_screen.dart';

/// 题目列表页面 - 显示题目列表
class QuestionListScreen extends StatefulWidget {
  final List<String> questionIds;
  final String title;
  final List<String>? sourceQuestionIds; // 源题目ID列表（用于显示源题预览）
  final int? variantsPerQuestion; // 每题生成的变式数量（用于匹配源题目）

  const QuestionListScreen({
    super.key,
    required this.questionIds,
    required this.title,
    this.sourceQuestionIds,
    this.variantsPerQuestion,
  });

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  final _mistakeService = MistakeService();
  
  List<Question>? _questions;
  Map<String, Question>? _sourceQuestions; // 源题目映射：sourceQuestionId -> Question
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.authService.client;
      _mistakeService.initialize(client);

      // 加载生成的题目
      final questions = await _mistakeService.getQuestions(widget.questionIds);

      // 如果有源题目ID，加载源题目
      Map<String, Question>? sourceQuestions;
      if (widget.sourceQuestionIds != null && widget.sourceQuestionIds!.isNotEmpty) {
        final sources = await _mistakeService.getQuestions(widget.sourceQuestionIds!);
        sourceQuestions = {
          for (var q in sources) q.id: q,
        };
      }

      setState(() {
        _questions = questions;
        _sourceQuestions = sourceQuestions;
        _isLoading = false;
      });
    } catch (e) {
      print('加载题目失败: $e');
      setState(() {
        _error = '加载失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          CustomAppBar(title: widget.title),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _questions == null || _questions!.isEmpty
                        ? _buildEmptyState()
                        : _buildQuestionsList(),
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
              onPressed: _loadQuestions,
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
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                CupertinoIcons.doc_text,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            const Text(
              '暂无题目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    // 检查是否所有题目都来自同一个源题目
    Question? commonSourceQuestion;
    if (_sourceQuestions != null && 
        widget.sourceQuestionIds != null && 
        widget.sourceQuestionIds!.isNotEmpty) {
      if (widget.sourceQuestionIds!.length == 1) {
        // 只有一个源题目，所有变式题都对应它
        commonSourceQuestion = _sourceQuestions![widget.sourceQuestionIds!.first];
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // 第一个位置显示源题目预览（如果有且只有一个源题目）
                if (index == 0 && commonSourceQuestion != null) {
                  return _buildSourceQuestionPreview(commonSourceQuestion);
                }
                
                // 其他位置显示题目卡片
                // 如果有源题目预览，索引需要减1（因为第一个位置被源题目占用了）
                final questionIndex = commonSourceQuestion != null ? index - 1 : index;
                final question = _questions![questionIndex];
                return Padding(
                  padding: EdgeInsets.only(
                    top: (commonSourceQuestion != null && index == 1) ? AppConstants.spacingM : 0,
                    bottom: questionIndex < _questions!.length - 1
                        ? AppConstants.spacingM
                        : 0,
                  ),
                  child: _buildQuestionCard(question, questionIndex),
                );
              },
              childCount: _questions!.length + (commonSourceQuestion != null ? 1 : 0),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppConstants.spacingM),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    return GestureDetector(
      onTap: () => _handleQuestionTap(question, index),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 变式题内容
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '第 ${index + 1} 题',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    question.type.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                if (_sourceQuestions != null && widget.sourceQuestionIds != null && widget.sourceQuestionIds!.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '变式题',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 60,
              ),
              child: ClipRect(
                child: MathMarkdownText(
                  text: question.content,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '点击查看详情',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceQuestionPreview(Question sourceQuestion) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.doc_text,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              const Text(
                '源题目',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 60,
            ),
            child: ClipRect(
              child: MathMarkdownText(
                text: sourceQuestion.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleQuestionTap(Question question, int index) {
    // 导航到题目详情页面，直接从 questions 表读取
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => QuestionDetailScreen(
          questionIds: _questions!.map((q) => q.id).toList(),
          initialIndex: index,
        ),
      ),
    );
  }
}

