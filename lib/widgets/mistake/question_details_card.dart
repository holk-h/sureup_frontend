import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/models.dart';
import '../../services/mistake_service.dart';
import '../common/math_markdown_text.dart';
import 'error_reason_selector.dart';
import 'edit_answer_dialog.dart';
import 'mistake_note_section.dart';

/// 题目详情卡片组件
class QuestionDetailsCard extends StatefulWidget {
  final Question question;
  final MistakeRecord mistakeRecord;
  final Map<String, Map<String, String>> modulesInfo;
  final Map<String, Map<String, String>> knowledgePointsInfo;
  final Function(String) onErrorReasonChanged;

  const QuestionDetailsCard({
    super.key,
    required this.question,
    required this.mistakeRecord,
    required this.modulesInfo,
    required this.knowledgePointsInfo,
    required this.onErrorReasonChanged,
  });

  @override
  State<QuestionDetailsCard> createState() => _QuestionDetailsCardState();
}

class _QuestionDetailsCardState extends State<QuestionDetailsCard>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<double>> _itemAnimations;
  late List<Animation<Offset>> _slideAnimations;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.question.answer;
    _setupStaggeredAnimations();
    _startAnimation();
  }

  @override
  void didUpdateWidget(QuestionDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 question 对象变了，更新选中的答案
    if (oldWidget.question.answer != widget.question.answer) {
      _selectedAnswer = widget.question.answer;
    }
  }

  void _setupStaggeredAnimations() {
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 计算需要动画的项目数量（题目、选项、答案区、错因、模块、知识点）
    final itemCount = 6;
    _itemAnimations = List.generate(itemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.6;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _slideAnimations = List.generate(itemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.6;
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _staggerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: _itemAnimations[index],
      child: SlideTransition(position: _slideAnimations[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    int animationIndex = 0;

    // 调试日志
    print('🎨 QuestionDetailsCard build:');
    print('   - moduleIds: ${widget.question.moduleIds}');
    print('   - knowledgePointIds: ${widget.question.knowledgePointIds}');
    print('   - modulesInfo: ${widget.modulesInfo}');
    print('   - knowledgePointsInfo: ${widget.knowledgePointsInfo}');

    return Container(
      margin: const EdgeInsets.only(
        left: AppConstants.spacingM,
        right: AppConstants.spacingM,
        top: 0,
        bottom: AppConstants.spacingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容 (索引 0)
          _buildAnimatedItem(
            animationIndex++,
            _buildSection(
              title: '题目内容',
              icon: CupertinoIcons.doc_text,
              child: MathMarkdownText(
                text: widget.question.content,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 选项（选择题）(索引 1)
          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            _buildAnimatedItem(
              animationIndex++,
              _buildSection(
                title: '选项',
                icon: CupertinoIcons.list_bullet,
                child: _buildOptionsWidget(),
              ),
            ),

          if (widget.question.options != null &&
              widget.question.options!.isNotEmpty)
            const SizedBox(height: AppConstants.spacingM),

          // 答案和备注 (索引 2)
          _buildAnimatedItem(
            animationIndex++,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 添加备注
                  Expanded(
                    flex: 65,
                    child: _buildSection(
                      title: '错题备注',
                      icon: CupertinoIcons.pencil,
                      iconColor: AppColors.primary,
                      child: MistakeNoteSection(
                        mistakeRecord: widget.mistakeRecord,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppConstants.spacingM),

                  // 正确答案
                  Expanded(
                    flex: 35,
                    child: _buildSection(
                      title: '正确答案',
                      icon: CupertinoIcons.checkmark_seal_fill,
                      iconColor: AppColors.success,
                      child: _buildAnswerWidget(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 错因分析 (索引 3)
          _buildAnimatedItem(
            animationIndex++,
            _buildSection(
              title: '错因分析',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              iconColor: AppColors.error,
              child: ErrorReasonSelector(
                mistakeRecord: widget.mistakeRecord,
                onErrorReasonChanged: widget.onErrorReasonChanged,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 模块标签 (索引 4)
          if (widget.question.moduleIds.isNotEmpty)
            Column(
              children: [
                _buildAnimatedItem(animationIndex++, _buildModuleSection()),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),

          // 知识点 (索引 5)
          if (widget.question.knowledgePointIds.isNotEmpty)
            _buildAnimatedItem(animationIndex++, _buildKnowledgePointSection()),
        ],
      ),
    );
  }

  Widget _buildOptionsWidget() {
    return Column(
      children: widget.question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final label = String.fromCharCode(65 + index); // A, B, C, D...

        String cleanedOption = option;
        final prefixPattern = RegExp(r'^[A-Z]\.?\s*');
        if (prefixPattern.hasMatch(option)) {
          cleanedOption = option.replaceFirst(prefixPattern, '');
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MathMarkdownText(
                  text: cleanedOption,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerWidget() {
    // 判断是否为选择题
    final bool isChoiceQuestion =
        widget.question.options != null && widget.question.options!.isNotEmpty;

    // 选择题：显示选项字母，直接点击更新答案
    if (isChoiceQuestion) {
      final optionCount = widget.question.options!.length;

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(optionCount, (index) {
          final label = String.fromCharCode(65 + index); // A, B, C, D...
          final isSelected = _selectedAnswer == label;

          return GestureDetector(
            onTap: () async {
              // 添加触觉反馈
              HapticFeedback.selectionClick();

              // 立即更新本地状态，提供即时反馈
              setState(() {
                _selectedAnswer = label;
              });

              // 异步更新数据库
              try {
                await MistakeService().updateQuestionAnswer(
                  widget.question.id,
                  label,
                );
              } catch (e) {
                print('更新答案失败: $e');
                // 如果更新失败，恢复原状态
                if (mounted) {
                  setState(() {
                    _selectedAnswer = widget.question.answer;
                  });
                }
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success
                    : AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withValues(
                    alpha: isSelected ? 1.0 : 0.3,
                  ),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.success,
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    // 非选择题：已有答案显示答案，否则显示添加按钮
    if (widget.question.answer != null && widget.question.answer!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _showEditAnswerDialog(),
        child: Center(
          child: Text(
            widget.question.answer!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showEditAnswerDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.plus_circle,
              color: AppColors.success,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAnswerDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => EditAnswerDialog(
        initialAnswer: widget.question.answer,
        question: widget.question,
        onSave: (answer) async {
          try {
            await MistakeService().updateQuestionAnswer(
              widget.question.id,
              answer,
            );
            // 更新本地状态
            if (mounted) {
              setState(() {
                _selectedAnswer = answer;
              });
            }
          } catch (e) {
            print('更新答案失败: $e');
          }
        },
      ),
    );
  }

  Widget _buildModuleSection() {
    final moduleIds = widget.question.moduleIds;

    return _buildSection(
      title: moduleIds.length > 1 ? '相关模块（综合题）' : '相关模块',
      icon: CupertinoIcons.square_stack_3d_up_fill,
      iconColor: AppColors.primary,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: moduleIds.asMap().entries.map((entry) {
          final index = entry.key;
          final moduleId = entry.value;
          final moduleName = widget.modulesInfo[moduleId]?['name'] ?? '加载中...';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (moduleIds.length > 1)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                Text(
                  moduleName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKnowledgePointSection() {
    final kpIds = widget.question.knowledgePointIds;

    return _buildSection(
      title: '相关知识点 (${kpIds.length})',
      icon: CupertinoIcons.book_fill,
      iconColor: AppColors.accent,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kpIds.map((kpId) {
          final kpName = widget.knowledgePointsInfo[kpId]?['name'] ?? '加载中...';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              kpName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
