import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../services/mistake_service.dart';
import '../widgets/common/custom_app_bar.dart';

/// 错题预览页面
/// 显示上传后的题目信息，支持实时更新分析状态
/// 简化版：一条记录 = 一道题，支持切换多条记录
class MistakePreviewScreen extends StatefulWidget {
  final List<String> mistakeRecordIds; // 错题记录 ID 列表
  final int initialIndex; // 初始显示的索引

  const MistakePreviewScreen({
    super.key,
    required this.mistakeRecordIds,
    this.initialIndex = 0,
  });

  @override
  State<MistakePreviewScreen> createState() => _MistakePreviewScreenState();
}

// 兼容旧版本的构造函数
extension MistakePreviewScreenCompat on MistakePreviewScreen {
  static MistakePreviewScreen single({
    required String mistakeRecordId,
  }) {
    return MistakePreviewScreen(
      mistakeRecordIds: [mistakeRecordId],
      initialIndex: 0,
    );
  }
}

class _MistakePreviewScreenState extends State<MistakePreviewScreen>
    with SingleTickerProviderStateMixin {
  final MistakeService _mistakeService = MistakeService();

  // PageView 控制器
  late PageController _pageController;
  
  // 缓存所有记录和题目数据（按记录ID缓存）
  final Map<String, MistakeRecord> _cachedRecords = {}; // recordId -> MistakeRecord
  final Map<String, Question> _cachedQuestions = {}; // recordId -> Question
  final Map<String, Map<String, Map<String, String>>> _recordModulesInfo = {}; // recordId -> moduleId -> moduleInfo
  final Map<String, Map<String, Map<String, String>>> _recordKnowledgePointsInfo = {}; // recordId -> kpId -> kpInfo
  
  // 每个页面的加载状态（按索引缓存）
  final Map<int, bool> _pageLoadingStatus = {}; // index -> isLoading
  final Map<int, String?> _pageErrorStatus = {}; // index -> errorMessage
  
  // Realtime 订阅管理（单一订阅，符合 Appwrite 最佳实践）
  RealtimeSubscription? _realtimeSubscription;
  final Set<String> _subscribedRecordIds = {}; // 当前订阅的记录ID集合

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _setupAnimations();
    
    // 立即建立 Realtime 订阅（订阅所有记录）
    _setupRealtimeSubscription();
    
    // 预加载初始页面和相邻页面
    _preloadPage(widget.initialIndex);
    if (widget.initialIndex > 0) {
      _preloadPage(widget.initialIndex - 1);
    }
    if (widget.initialIndex < widget.mistakeRecordIds.length - 1) {
      _preloadPage(widget.initialIndex + 1);
    }
  }
  
  // 预加载指定页面的数据
  Future<void> _preloadPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= widget.mistakeRecordIds.length) return;
    
    final recordId = widget.mistakeRecordIds[pageIndex];
    
    // 如果已经加载过
    if (_cachedRecords.containsKey(recordId)) {
      final cachedRecord = _cachedRecords[recordId]!;
      
      // 如果分析尚未完成，进行后台刷新以获取最新状态
      if (cachedRecord.analysisStatus != AnalysisStatus.completed &&
          cachedRecord.analysisStatus != AnalysisStatus.failed) {
        _refreshRecord(recordId, pageIndex);
      }
      
      return;
    }
    
    // 设置加载状态（只在首次加载时）
    setState(() {
      _pageLoadingStatus[pageIndex] = true;
      _pageErrorStatus[pageIndex] = null;
    });
    
    try {
      // 加载记录数据
      final record = await _mistakeService.getMistakeRecord(recordId);
      if (record == null) {
        throw Exception('错题记录不存在');
      }
      
      // 缓存记录数据
      _cachedRecords[recordId] = record;
      
      if (!mounted) return;
      
      setState(() {
        _pageLoadingStatus[pageIndex] = false;
      });
      
      // 如果已经有 questionId，加载题目详情
      if (record.questionId != null) {
        await _loadQuestionDetails(recordId, record.questionId!);
        // 加载题目的模块和知识点信息
        if (_cachedQuestions.containsKey(recordId)) {
          await _loadQuestionInfo(recordId);
        }
      }
      
      // 检查是否所有记录都已完成分析
      _checkAndCloseSubscriptionIfAllCompleted();
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageLoadingStatus[pageIndex] = false;
          _pageErrorStatus[pageIndex] = '加载失败: $e';
        });
      }
    }
  }
  
  // 后台刷新记录数据（不显示loading状态，不改变UI）
  Future<void> _refreshRecord(String recordId, int pageIndex) async {
    try {
      final record = await _mistakeService.getMistakeRecord(recordId);
      if (record == null || !mounted) return;
      
      final oldRecord = _cachedRecords[recordId];
      
      // 检查是否真的有变化
      final hasStatusChange = oldRecord?.analysisStatus != record.analysisStatus;
      final hasQuestionIdChange = oldRecord?.questionId != record.questionId;
      
      // 更新缓存
      _cachedRecords[recordId] = record;
      
      // 如果状态有变化，才更新UI
      if (hasStatusChange || hasQuestionIdChange) {
        // 如果新增了questionId，加载题目详情
        if (record.questionId != null && !_cachedQuestions.containsKey(recordId)) {
          await _loadQuestionDetails(recordId, record.questionId!);
          if (_cachedQuestions.containsKey(recordId)) {
            await _loadQuestionInfo(recordId);
          }
        }
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('后台刷新失败: $e');
      // 后台刷新失败不影响用户体验，仅打印日志
    }
  }
  
  // 页面切换回调
  void _onPageChanged(int pageIndex) {
    HapticFeedback.lightImpact();
    
    // 确保当前页面的数据已加载和订阅正确
    _preloadPage(pageIndex);
    
    // 预加载前后页面
    if (pageIndex > 0) {
      _preloadPage(pageIndex - 1);
    }
    if (pageIndex < widget.mistakeRecordIds.length - 1) {
      _preloadPage(pageIndex + 1);
    }
    
    setState(() {});
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
    _pageController.dispose();
    // 关闭 Realtime 订阅
    _realtimeSubscription?.close();
    _realtimeSubscription = null;
    _subscribedRecordIds.clear();
    super.dispose();
  }
  
  // 建立 Realtime 订阅（一次性订阅所有记录，保持连接直到全部完成或页面销毁）
  void _setupRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      // 已经有订阅，不重复创建
      return;
    }
    
    // 构建所有记录的频道列表
    final channels = widget.mistakeRecordIds
        .map((id) => 'databases.${ApiConfig.databaseId}.collections.${ApiConfig.mistakeRecordsCollectionId}.documents.$id')
        .toList();
    
    if (channels.isEmpty) {
      print('⚠️ 没有需要订阅的记录');
      return;
    }
    
    print('📡 建立 Realtime 订阅 (频道数: ${channels.length})');
    print('📋 订阅记录: ${widget.mistakeRecordIds.join(", ")}');
    
    try {
      // 创建单一订阅，订阅所有记录
      _realtimeSubscription = _mistakeService.subscribeMultipleMistakes(
        channels: channels,
        onUpdate: _handleRealtimeUpdate,
        onError: _handleRealtimeError,
      );
      
      _subscribedRecordIds.addAll(widget.mistakeRecordIds);
      print('✅ Realtime 订阅已建立');
    } catch (e) {
      print('❌ 建立 Realtime 订阅失败: $e');
    }
  }
  
  // 检查是否所有记录都已完成分析，如果是则关闭订阅
  void _checkAndCloseSubscriptionIfAllCompleted() {
    if (_realtimeSubscription == null) {
      return; // 没有活跃的订阅
    }
    
    // 检查所有记录是否都已完成或失败
    bool allCompleted = true;
    for (final recordId in widget.mistakeRecordIds) {
      final record = _cachedRecords[recordId];
      if (record != null &&
          record.analysisStatus != AnalysisStatus.completed &&
          record.analysisStatus != AnalysisStatus.failed) {
        allCompleted = false;
        break;
      }
    }
    
    if (allCompleted) {
      print('🎉 所有记录分析完成，关闭 Realtime 订阅');
      try {
        _realtimeSubscription?.close();
        _realtimeSubscription = null;
        _subscribedRecordIds.clear();
      } catch (e) {
        print('❌ 关闭订阅失败: $e');
      }
    }
  }
  
  // 加载题目的模块和知识点详细信息
  Future<void> _loadQuestionInfo(String recordId) async {
    final question = _cachedQuestions[recordId];
    if (question == null) {
      return;
    }

    // 检查是否已缓存
    if (_recordModulesInfo.containsKey(recordId) &&
        _recordKnowledgePointsInfo.containsKey(recordId)) {
      return;
    }

    try {
      final futures = <Future>[];
      
      // 加载模块信息
      if (question.moduleIds.isNotEmpty) {
        futures.add(
          _mistakeService.getModules(question.moduleIds).then((modules) {
            if (mounted) {
              _recordModulesInfo[recordId] = modules;
            }
          })
        );
      }
      
      // 加载知识点信息
      if (question.knowledgePointIds.isNotEmpty) {
        futures.add(
          _mistakeService.getKnowledgePoints(question.knowledgePointIds).then((kps) {
            if (mounted) {
              _recordKnowledgePointsInfo[recordId] = kps;
            }
          })
        );
      }

      // 等待所有数据加载完成
      await Future.wait(futures);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('加载题目详细信息失败: $e');
    }
  }

  // 加载题目详情
  Future<void> _loadQuestionDetails(String recordId, String questionId) async {
    try {
      final questions = await _mistakeService.getQuestions([questionId]);
      if (mounted && questions.isNotEmpty) {
        final question = questions.first;
        // 缓存题目数据
        _cachedQuestions[recordId] = question;
        
        setState(() {});
      }
    } catch (e) {
      print('加载题目详情失败: $e');
    }
  }

  // 处理 Realtime 更新
  Future<void> _handleRealtimeUpdate(MistakeRecord updatedRecord) async {
    if (!mounted) return;

    final recordId = updatedRecord.id;
    print('📨 收到 Realtime 更新: $recordId (状态: ${updatedRecord.analysisStatus})');

    // 更新缓存
    _cachedRecords[recordId] = updatedRecord;

    // 如果分析完成且有 questionId，加载题目详情
    if (updatedRecord.analysisStatus == AnalysisStatus.completed &&
        updatedRecord.questionId != null &&
        !_cachedQuestions.containsKey(recordId)) {
      print('🎯 分析完成，加载题目详情: ${updatedRecord.questionId}');
      await _loadQuestionDetails(recordId, updatedRecord.questionId!);
      if (_cachedQuestions.containsKey(recordId)) {
        await _loadQuestionInfo(recordId);
      }
      HapticFeedback.mediumImpact();
    }
    
    // 更新UI
    if (mounted) {
      setState(() {});
    }
    
    // 检查是否所有记录都已完成分析，如果是则关闭订阅
    _checkAndCloseSubscriptionIfAllCompleted();
  }

  // 处理 Realtime 错误
  void _handleRealtimeError(dynamic error) {
    if (!mounted) return;

    print('❌ Realtime 订阅错误: $error');
    
    // 关闭失败的订阅
    _realtimeSubscription?.close();
    _realtimeSubscription = null;
    _subscribedRecordIds.clear();
    
    // 延迟重试重新建立连接
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        print('🔄 尝试重新建立 Realtime 订阅...');
        _setupRealtimeSubscription();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Stack(
        children: [
          // 主内容 - 使用 PageView
          Column(
            children: [
              // 顶部导航栏
              CustomAppBar(
                title: '错题详情',
                rightAction: _buildMenuButton(),
              ),

              // 主内容 - PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.mistakeRecordIds.length,
                  itemBuilder: (context, index) {
                    return _buildPage(index);
                  },
                ),
              ),
            ],
          ),

          // 底部浮动的页面指示器
          if (widget.mistakeRecordIds.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingIndicator(),
            ),
        ],
      ),
    );
  }
  
  // 构建单个页面
  Widget _buildPage(int pageIndex) {
    return _MistakeDetailPage(
      key: ValueKey('page_$pageIndex'),
      pageIndex: pageIndex,
      recordId: widget.mistakeRecordIds[pageIndex],
      isLoading: _pageLoadingStatus[pageIndex] ?? false,
      errorMessage: _pageErrorStatus[pageIndex],
      mistakeRecord: _cachedRecords[widget.mistakeRecordIds[pageIndex]],
      question: _cachedQuestions[widget.mistakeRecordIds[pageIndex]],
      modulesInfo: _recordModulesInfo[widget.mistakeRecordIds[pageIndex]] ?? {},
      knowledgePointsInfo: _recordKnowledgePointsInfo[widget.mistakeRecordIds[pageIndex]] ?? {},
      onRetry: () {
        setState(() {
          _pageErrorStatus[pageIndex] = null;
        });
        _preloadPage(pageIndex);
      },
      onUpdateErrorReason: (MistakeRecord record, String errorReason) async {
        await _mistakeService.updateErrorReason(record.id, errorReason: errorReason);
        final updatedRecord = record.copyWith(errorReason: errorReason);
        _cachedRecords[record.id] = updatedRecord;
        setState(() {});
      },
      pulseAnimation: _pulseAnimation,
    );
  }

  // 构建底部浮动指示器
  Widget _buildFloatingIndicator() {
    final currentPage = _pageController.hasClients 
        ? (_pageController.page ?? widget.initialIndex).round()
        : widget.initialIndex;
    
    return Container(
      margin: const EdgeInsets.only(
        left: 0,
        right: 0,
        bottom: 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.0),
            AppColors.background.withValues(alpha: 0.95),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            // 左箭头按钮
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: currentPage > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                      decoration: BoxDecoration(
                  color: currentPage > 0
                      ? AppColors.cardBackground
                      : AppColors.cardBackground.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentPage > 0
                        ? AppColors.divider
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: currentPage > 0
                      ? [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                      ),
                        ]
                      : null,
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: currentPage > 0
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  size: 20,
              ),
            ),
          ),
          
            const SizedBox(width: 16),
            
            // 页码指示器
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
              ),
                ],
            ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentPage + 1}',
              style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success.withValues(alpha: 0.6),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.mistakeRecordIds.length}',
                    style: TextStyle(
                      fontSize: 15,
                fontWeight: FontWeight.w600,
                      color: AppColors.success.withValues(alpha: 0.7),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 右箭头按钮
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: currentPage < widget.mistakeRecordIds.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: currentPage < widget.mistakeRecordIds.length - 1
                      ? AppColors.cardBackground
                      : AppColors.cardBackground.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentPage < widget.mistakeRecordIds.length - 1
                        ? AppColors.divider
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: currentPage < widget.mistakeRecordIds.length - 1
                      ? [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: currentPage < widget.mistakeRecordIds.length - 1
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  size: 20,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // 构建菜单按钮
  Widget _buildMenuButton() {
    final currentPage = _pageController.hasClients 
        ? (_pageController.page ?? widget.initialIndex).round()
        : widget.initialIndex;
    final recordId = widget.mistakeRecordIds[currentPage];
    final mistakeRecord = _cachedRecords[recordId];
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: mistakeRecord != null ? () => _showActionSheet(currentPage, mistakeRecord) : null,
      child: const Icon(
        CupertinoIcons.ellipsis_circle,
        color: AppColors.textPrimary,
        size: 24,
      ),
    );
  }

  // 显示操作菜单
  void _showActionSheet(int pageIndex, MistakeRecord mistakeRecord) {
    final canReanalyze = mistakeRecord.analysisStatus == AnalysisStatus.failed ||
                         mistakeRecord.analysisStatus == AnalysisStatus.completed;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (canReanalyze)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
                _retryAnalysis(pageIndex, mistakeRecord);
            },
            child: const Text('重新分析'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _deleteMistake(pageIndex, mistakeRecord);
            },
            isDestructiveAction: true,
            child: const Text('删除错题'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  // 重新分析
  Future<void> _retryAnalysis(int pageIndex, MistakeRecord mistakeRecord) async {
    final recordId = widget.mistakeRecordIds[pageIndex];
    
    try {
      // 更新分析状态为 pending
      await _mistakeService.updateMistakeRecord(
        recordId: recordId,
        data: {
          'analysisStatus': 'pending',
          'analysisError': null,
        },
      );

      if (mounted) {
        // 创建新的记录对象，清空错误信息
        final updatedRecord = MistakeRecord(
          id: mistakeRecord.id,
          userId: mistakeRecord.userId,
          questionId: mistakeRecord.questionId,
          subject: mistakeRecord.subject,
          moduleIds: mistakeRecord.moduleIds,
          knowledgePointIds: mistakeRecord.knowledgePointIds,
          errorReason: mistakeRecord.errorReason,
          note: mistakeRecord.note,
          userAnswer: mistakeRecord.userAnswer,
          analysisStatus: AnalysisStatus.pending, // 重置为pending
          analysisError: null, // 清空错误
          analyzedAt: null, // 清空分析时间
          masteryStatus: mistakeRecord.masteryStatus,
          reviewCount: mistakeRecord.reviewCount,
          correctCount: mistakeRecord.correctCount,
          originalImageId: mistakeRecord.originalImageId,
          createdAt: mistakeRecord.createdAt,
          lastReviewAt: mistakeRecord.lastReviewAt,
          masteredAt: mistakeRecord.masteredAt,
        );
        
        _cachedRecords[recordId] = updatedRecord;
        setState(() {});
        
        // 显示提示
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('重新分析'),
            content: const Text('已提交重新分析请求，请稍候...'),
            actions: [
              CupertinoDialogAction(
                child: const Text('知道了'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('操作失败'),
            content: Text('重新分析失败: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('确定'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  // 删除错题
  Future<void> _deleteMistake(int pageIndex, MistakeRecord mistakeRecord) async {
    final recordId = widget.mistakeRecordIds[pageIndex];
    
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这道错题吗？此操作无法撤销。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _mistakeService.deleteMistakeRecord(recordId);
        if (mounted) {
          Navigator.of(context).pop(); // 返回上一页（主页）
        }
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('删除失败'),
              content: Text('$e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('确定'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}

/// 支持 Markdown 和 LaTeX 的文本渲染 widget
/// 使用 gpt_markdown 包，原生支持 Markdown 和 LaTeX
/// gpt_markdown 本身已支持文本选择，无需额外包装
class _MathMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _MathMarkdownText({
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      text,
      style: style,
    );
  }
}

/// 单个错题详情页面 - 使用 AutomaticKeepAliveClientMixin 保持状态
class _MistakeDetailPage extends StatefulWidget {
  final int pageIndex;
  final String recordId;
  final bool isLoading;
  final String? errorMessage;
  final MistakeRecord? mistakeRecord;
  final Question? question;
  final Map<String, Map<String, String>> modulesInfo;
  final Map<String, Map<String, String>> knowledgePointsInfo;
  final VoidCallback onRetry;
  final Future<void> Function(MistakeRecord, String) onUpdateErrorReason;
  final Animation<double> pulseAnimation;

  const _MistakeDetailPage({
    super.key,
    required this.pageIndex,
    required this.recordId,
    required this.isLoading,
    required this.errorMessage,
    required this.mistakeRecord,
    required this.question,
    required this.modulesInfo,
    required this.knowledgePointsInfo,
    required this.onRetry,
    required this.onUpdateErrorReason,
    required this.pulseAnimation,
  });

  @override
  State<_MistakeDetailPage> createState() => _MistakeDetailPageState();
}

class _MistakeDetailPageState extends State<_MistakeDetailPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，AutomaticKeepAliveClientMixin 需要
    
    if (widget.isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }
    
    if (widget.errorMessage != null) {
      return _buildErrorView();
    }
    
    if (widget.mistakeRecord == null) {
      return const Center(
        child: Text('错题记录不存在'),
      );
    }
    
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 原始图片
        SliverToBoxAdapter(
          child: _buildOriginalImage(),
        ),

        // 分析状态卡片（仅在未完成时显示）
        if (widget.mistakeRecord!.analysisStatus != AnalysisStatus.completed)
          SliverToBoxAdapter(
            child: _buildAnalysisStatusCard(),
          ),

        // 题目详情（分析完成后显示）
        if (widget.mistakeRecord!.isAnalyzed && widget.question != null)
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeIn,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: _buildQuestionDetails(),
              ),
            ),
          ),

        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 120),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              widget.errorMessage!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: widget.onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalImage() {
    final imageId = widget.mistakeRecord!.originalImageId;
    if (imageId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Image.network(
          '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.originQuestionImageBucketId}/files/$imageId/view?project=${ApiConfig.projectId}',
          fit: BoxFit.contain,
          width: double.infinity,
          cacheWidth: 1200,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: AppColors.background,
              child: const Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: AppColors.background,
              child: const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: AppColors.success,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnalysisStatusCard() {
    final status = widget.mistakeRecord!.analysisStatus;

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
          if (status == AnalysisStatus.completed && widget.mistakeRecord!.subject != null)
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
                      widget.mistakeRecord!.subject!.displayName,
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
      case AnalysisStatus.processing:
        // 使用旋转的圆圈动画
        return ScaleTransition(
          scale: widget.pulseAnimation,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.success,
                  AppColors.success.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CupertinoActivityIndicator(
              radius: 16,
              color: CupertinoColors.white,
            ),
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
      case AnalysisStatus.processing:
        return AppColors.primary;
      case AnalysisStatus.completed:
        return AppColors.success;
      case AnalysisStatus.failed:
        return AppColors.error;
    }
  }

  String _getStatusTitle(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.pending:
      case AnalysisStatus.processing:
        return 'AI 分析中';
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
      case AnalysisStatus.completed:
        return 'AI 已完成分析，查看下方详情';
      case AnalysisStatus.failed:
        return widget.mistakeRecord?.analysisError ?? '分析过程中出现错误';
    }
  }

  Widget _buildQuestionDetails() {
    final question = widget.question!;
    final recordId = widget.recordId;
    final mistakeRecord = widget.mistakeRecord!;
    
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
          // 题目内容
          _buildSection(
            title: '题目内容',
            icon: CupertinoIcons.doc_text,
            child: _MathMarkdownText(
              text: question.content,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 选项（选择题）
          if (question.options != null && question.options!.isNotEmpty)
            _buildSection(
              title: '选项',
              icon: CupertinoIcons.list_bullet,
              child: Column(
                children: question.options!.asMap().entries.map((entry) {
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
                          child: _MathMarkdownText(
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
              ),
            ),

          if (question.options != null && question.options!.isNotEmpty)
            const SizedBox(height: AppConstants.spacingM),

          // 答案和备注
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 添加备注
              Expanded(
                flex: 65,
                child: _buildSection(
                  title: '添加备注',
                  icon: CupertinoIcons.pencil,
                  iconColor: AppColors.primary,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      // TODO: 实现添加备注功能
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.plus_circle,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '点击添加备注',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  child: question.answer != null && question.answer!.isNotEmpty
                      ? Text(
                          question.answer!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            height: 1.6,
                          ),
                        )
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // TODO: 实现添加正确答案功能
                          },
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.plus_circle,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                const Text(
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
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 错因分析
          _buildSection(
            title: '错因分析',
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            iconColor: AppColors.error,
            child: _buildErrorReasonSelector(mistakeRecord),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // 模块标签
          if (question.moduleIds.isNotEmpty)
            Column(
              children: [
                _buildModuleSection(recordId, question),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),

          // 知识点
          if (question.knowledgePointIds.isNotEmpty)
            _buildKnowledgePointSection(recordId, question),
        ],
      ),
    );
  }

  Widget _buildErrorReasonSelector(MistakeRecord mistakeRecord) {
    final currentErrorReasonEnum = mistakeRecord.errorReasonEnum;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预定义错因标签
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ErrorReason.values.where((e) => e != ErrorReason.other).map((reason) {
            final isSelected = currentErrorReasonEnum == reason;
            return GestureDetector(
              onTap: () {
                widget.onUpdateErrorReason(mistakeRecord, reason.name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.error
                      : AppColors.error.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  reason.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.error,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModuleSection(String recordId, Question question) {
    final moduleIds = question.moduleIds;
    final modulesInfo = widget.modulesInfo;

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
          final moduleName = modulesInfo[moduleId]?['name'] ?? '加载中...';
          
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
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

  Widget _buildKnowledgePointSection(String recordId, Question question) {
    final kpIds = question.knowledgePointIds;
    final kpsInfo = widget.knowledgePointsInfo;

    return _buildSection(
      title: '相关知识点 (${kpIds.length})',
      icon: CupertinoIcons.book_fill,
      iconColor: AppColors.accent,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kpIds.map((kpId) {
          final kpName = kpsInfo[kpId]?['name'] ?? '加载中...';
          
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
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
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primary,
              ),
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


