import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../widgets/common/custom_app_bar.dart';

/// AI分析复盘页面 - 深度错题分析
class AIAnalysisReviewScreen extends StatefulWidget {
  final int accumulatedMistakes; // 积累的错题数
  final int daysSinceLastReview; // 距上次复盘天数

  const AIAnalysisReviewScreen({
    super.key,
    this.accumulatedMistakes = 15,
    this.daysSinceLastReview = 3,
  });

  @override
  State<AIAnalysisReviewScreen> createState() => _AIAnalysisReviewScreenState();
}

class _AIAnalysisReviewScreenState extends State<AIAnalysisReviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 折叠状态
  bool _isKnowledgeExpanded = false;
  bool _isReasonExpanded = false;
  
  // AI建议生成状态
  bool _isGenerating = false;
  String _generatedText = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // 缩短动画时长
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // 进一步减少滑动距离
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // 延迟启动动画，让UI先渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // 模拟流式输出AI建议
  Future<void> _generateAISuggestions() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
      _generatedText = '';
    });
    
    const fullText = '''根据你积累的15道错题分析，我发现了以下学习模式和改进建议：

📊 学习现状分析
你在数学学科的错题最多（5道），占比33.3%。这些错题主要集中在"概念理解不清"这一错因上，说明基础概念的掌握还需要加强。

💡 针对性建议

1. 优先攻克概念理解类问题
   建议你先从基础概念入手，不要急于做难题。可以尝试用自己的话解释每个概念，看看能否讲给别人听懂。

2. 建立错题复盘习惯
   距离上次复盘已经3天了，建议每2-3天复盘一次，效果会更好。复盘时不仅要看错题，更要思考"为什么会错"和"下次怎么避免"。

3. 针对性练习策略
   对于数学薄弱点，建议每天花15-20分钟做同类型变式题。不求多，但求精，每道题都要真正搞懂。

4. 时间规划建议
   根据当前情况，建议你安排30分钟进行系统复习。可以分配为：概念复习10分钟 + 错题分析10分钟 + 变式练习10分钟。

💪 加油！每一次复盘都是进步的机会，稳了！''';
    
    // 流式输出，安全地处理UTF-16字符
    final runes = fullText.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      if (!_isGenerating) break;
      
      // 根据字符类型调整延迟时间
      final char = String.fromCharCode(runes[i]);
      int delay = 30;
      if (char == '\n') {
        delay = 100; // 换行稍微停顿
      } else if (char == '。' || char == '！' || char == '？') {
        delay = 150; // 句号停顿更久
      } else if (char == '，' || char == '、') {
        delay = 80; // 逗号适中停顿
      }
      
      await Future.delayed(Duration(milliseconds: delay));
      
      if (mounted) {
        setState(() {
          // 安全地构建字符串，避免UTF-16问题
          _generatedText = String.fromCharCodes(runes.take(i + 1));
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 模拟AI分析数据
    final analysisData = _generateAnalysisData();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // 统一的顶部导航栏
          CustomAppBar(
            title: 'AI分析复盘',
          ),
          
          // 主内容区域
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 主内容
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 学习状态总览
                            _buildOverviewCard(analysisData),
                            
                            const SizedBox(height: AppConstants.spacingM),
                            
                            // 知识点分布
                            _buildKnowledgeDistributionCard(analysisData),
                            
                            const SizedBox(height: AppConstants.spacingM),
                            
                            // 错因分析
                            _buildReasonAnalysisCard(analysisData),
                            
                            const SizedBox(height: AppConstants.spacingM),
                            
                            // AI 个性化建议
                            _buildAISuggestionCard(analysisData),
                            
                            const SizedBox(height: AppConstants.spacingL),
                            
                            // 行动建议按钮组
                            _buildActionButtons(),
                            
                            const SizedBox(height: AppConstants.spacingXL),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 学习状态总览 - 精简版
  Widget _buildOverviewCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatItem(
              '积累错题',
              '${widget.accumulatedMistakes}',
              AppColors.mistake,
              CupertinoIcons.doc_text_fill,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '距上次',
              '${widget.daysSinceLastReview}天',
              AppColors.warning,
              CupertinoIcons.time,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '薄弱点',
              '${data['weakPoints']}个',
              AppColors.error,
              CupertinoIcons.exclamationmark_triangle_fill,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildCompactStatItem(
              '建议',
              '${data['suggestedTime']}min',
              AppColors.accent,
              CupertinoIcons.clock_fill,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 可折叠卡片标题栏构建器
  Widget _buildCollapsibleHeader({
    required String title,
    required String badgeText,
    required Color iconColor,
    required Color badgeColor,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingL,
          vertical: AppConstants.spacingM,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // 与展开折叠同步的贝塞尔曲线
              child: const Icon(
                CupertinoIcons.chevron_down,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 知识点分布卡片 - 可折叠
  Widget _buildKnowledgeDistributionCard(Map<String, dynamic> data) {
    final subjects = data['subjectDistribution'] as List<Map<String, dynamic>>;
    final totalCount = subjects.fold<int>(0, (sum, s) => sum + (s['count'] as int));
    
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏 - 可点击展开/折叠
          _buildCollapsibleHeader(
            title: '知识点分布',
            badgeText: '共 $totalCount 道',
            icon: CupertinoIcons.chart_pie_fill,
            iconColor: AppColors.accent,
            badgeColor: AppColors.accent,
            isExpanded: _isKnowledgeExpanded,
            onTap: () {
              setState(() {
                _isKnowledgeExpanded = !_isKnowledgeExpanded;
              });
            },
          ),
          // 内容区域 - 展开折叠（贝塞尔曲线动画）
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material Design 标准贝塞尔曲线
              heightFactor: _isKnowledgeExpanded ? 1.0 : 0.0,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: Column(
                      children: subjects.map((subject) => _buildSubjectBar(subject)).toList(),
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

  Widget _buildSubjectBar(Map<String, dynamic> subject) {
    final String name = subject['name'];
    final int count = subject['count'];
    final Color color = subject['color'];
    final double percentage = subject['percentage'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$count 道',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 错因分析卡片 - 可折叠
  Widget _buildReasonAnalysisCard(Map<String, dynamic> data) {
    final reasons = data['mistakeReasons'] as List<Map<String, dynamic>>;
    
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏 - 可点击展开/折叠
          _buildCollapsibleHeader(
            title: '错因分析',
            badgeText: '${reasons.length} 类',
            icon: CupertinoIcons.chart_bar_fill,
            iconColor: AppColors.warning,
            badgeColor: AppColors.warning,
            isExpanded: _isReasonExpanded,
            onTap: () {
              setState(() {
                _isReasonExpanded = !_isReasonExpanded;
              });
            },
          ),
          // 内容区域 - 展开折叠（贝塞尔曲线动画）
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material Design 标准贝塞尔曲线
              heightFactor: _isReasonExpanded ? 1.0 : 0.0,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: Column(
                      children: reasons.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reason = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < reasons.length - 1 ? AppConstants.spacingM : 0,
                          ),
                          child: _buildReasonItem(reason, index),
                        );
                      }).toList(),
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

  Widget _buildReasonItem(Map<String, dynamic> reason, int index) {
    final String name = reason['name'];
    final int count = reason['count'];
    final double percentage = reason['percentage'];
    final IconData icon = reason['icon'];
    final Color color = reason['color'];
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count 道错题',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
    );
  }

  // AI 个性化建议卡片 - 流式输出
  Widget _buildAISuggestionCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 学习建议',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '根据你的学习情况量身定制',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          
          // 生成按钮或显示生成的内容
          if (_generatedText.isEmpty && !_isGenerating)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _generateAISuggestions,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      CupertinoIcons.wand_stars,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '生成学习建议',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(_generatedText),
                  // 显示光标效果
                  if (_isGenerating)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 格式化文本显示
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      
      // 检查是否是标题行（包含emoji）
      if (line.contains('📊') || line.contains('💡') || line.contains('💪')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        );
      }
      // 检查是否是编号列表
      else if (RegExp(r'^\d+\.').hasMatch(line.trim())) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      }
      // 普通文本
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // 行动建议按钮组
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 主按钮：去针对性练习
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
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
            onPressed: () {
              // TODO: 跳转到练习页面
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.play_circle_fill,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  '去针对性练习',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        // 次要按钮：查看错题
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppColors.accent,
              width: 1.5,
            ),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              // TODO: 跳转到错题列表
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  color: AppColors.accent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '查看全部错题',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 生成模拟分析数据
  Map<String, dynamic> _generateAnalysisData() {
    // 学科分布
    final subjects = [
      {
        'name': '数学',
        'count': 5,
        'percentage': 33.3,
        'color': const Color(0xFF3B82F6), // blue
      },
      {
        'name': '物理',
        'count': 4,
        'percentage': 26.7,
        'color': const Color(0xFF8B5CF6), // purple
      },
      {
        'name': '化学',
        'count': 3,
        'percentage': 20.0,
        'color': const Color(0xFFEF4444), // red
      },
      {
        'name': '英语',
        'count': 3,
        'percentage': 20.0,
        'color': const Color(0xFF10B981), // green
      },
    ];

    // 错因分析
    final reasons = [
      {
        'name': '概念理解不清',
        'count': 6,
        'percentage': 40.0,
        'icon': CupertinoIcons.book_fill,
        'color': const Color(0xFFEF4444),
      },
      {
        'name': '思路断了',
        'count': 4,
        'percentage': 26.7,
        'icon': CupertinoIcons.layers_alt_fill,
        'color': const Color(0xFFF59E0B),
      },
      {
        'name': '计算错误',
        'count': 3,
        'percentage': 20.0,
        'icon': CupertinoIcons.number,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'name': '粗心大意',
        'count': 2,
        'percentage': 13.3,
        'icon': CupertinoIcons.exclamationmark_circle_fill,
        'color': const Color(0xFF3B82F6),
      },
    ];

    // AI建议
    final suggestions = [
      {
        'title': '优先复习"概念理解不清"的错题',
        'description': '这类问题占比最高（40%），建议先巩固基础概念，再进行变式训练',
        'icon': CupertinoIcons.flag_fill,
      },
      {
        'title': '数学薄弱点需要重点关注',
        'description': '数学错题最多（5道），建议每天花15-20分钟专项突破',
        'icon': CupertinoIcons.chart_bar_fill,
      },
      {
        'title': '建立错题复盘习惯',
        'description': '已经${widget.daysSinceLastReview}天没有复盘了，建议每2-3天复盘一次，效果更好',
        'icon': CupertinoIcons.time,
      },
    ];

    return {
      'weakPoints': 4,
      'suggestedTime': 30,
      'subjectDistribution': subjects,
      'mistakeReasons': reasons,
      'suggestions': suggestions,
    };
  }
}

