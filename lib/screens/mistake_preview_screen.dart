import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import '../services/mistake_preview_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/mistake/analysis_status_card.dart';
import '../widgets/mistake/question_details_card.dart';
import '../widgets/mistake/simple_question_card.dart';
import '../widgets/mistake/original_image_widget.dart';
import '../widgets/mistake/page_indicator.dart';

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
    with TickerProviderStateMixin {
  late final MistakePreviewService _previewService;
  late PageController _pageController;
  
  // 每个页面的加载状态（按索引缓存）
  final Map<int, bool> _pageLoadingStatus = {}; // index -> isLoading
  final Map<int, String?> _pageErrorStatus = {}; // index -> errorMessage

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // 进度条动画控制器（15秒）
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final Map<String, bool> _progressStarted = {}; // recordId -> isProgressStarted
  
  // 事件订阅
  StreamSubscription<MistakeRecord>? _recordUpdateSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _previewService = MistakePreviewService();
    _pageController = PageController(initialPage: widget.initialIndex);
    _setupAnimations();
    _setupEventListeners();
    
    // 立即建立 Realtime 订阅（订阅所有记录）
    _previewService.setupRealtimeSubscription(widget.mistakeRecordIds);
    
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
  Future<void> _preloadPage(int pageIndex, {bool forceReload = false}) async {
    if (pageIndex < 0 || pageIndex >= widget.mistakeRecordIds.length) return;
    
    final recordId = widget.mistakeRecordIds[pageIndex];
    
    // 如果已经加载过且不强制重新加载，直接返回
    if (!forceReload && _previewService.getCachedRecord(recordId) != null) {
      return;
    }
    
    // 设置加载状态（只在首次加载时）
    if (!forceReload) {
      setState(() {
        _pageLoadingStatus[pageIndex] = true;
        _pageErrorStatus[pageIndex] = null;
      });
    }
    
    try {
      // 使用服务加载记录数据
      final record = await _previewService.loadRecord(recordId);
      
      if (!mounted) return;
      
      if (!forceReload) {
        setState(() {
          _pageLoadingStatus[pageIndex] = false;
        });
      }
      
      if (record == null) {
        throw Exception('错题记录不存在');
        }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageLoadingStatus[pageIndex] = false;
          _pageErrorStatus[pageIndex] = '加载失败: $e';
        });
      }
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
    
    // 15秒进度条动画控制器
    _progressController = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );
  }

  void _setupEventListeners() {
    // 监听记录更新事件
    _recordUpdateSubscription = _previewService.recordUpdates.listen((record) {
      print('🔔 UI 收到记录更新: ${record.id} (状态: ${record.analysisStatus})');
      if (mounted) {
        // 如果状态变回 pending，重置进度条（用于重新分析的情况）
        if (record.analysisStatus == AnalysisStatus.pending) {
          print('   🔄 状态变回 pending，重置进度条');
          _progressStarted[record.id] = false;
        }
        
        // 如果状态变为 ocrOK 或 completed，确保该记录的 Question 数据已加载
        if (record.analysisStatus == AnalysisStatus.ocrOK || 
            record.analysisStatus == AnalysisStatus.completed) {
          final question = _previewService.getCachedQuestion(record.id);
          if (question == null) {
            print('   📥 状态已完成但 Question 未加载，触发加载: ${record.id}');
            // 找到该记录对应的页面索引
            final pageIndex = widget.mistakeRecordIds.indexOf(record.id);
            if (pageIndex != -1) {
              _preloadPage(pageIndex, forceReload: true);
            }
          }
        }
        
        print('   🎨 调用 setState 刷新 UI');
        setState(() {});
        HapticFeedback.mediumImpact();
      } else {
        print('   ⚠️ Widget 未挂载，跳过刷新');
      }
    });
    
    // 监听错误事件
    _errorSubscription = _previewService.errors.listen((error) {
      if (mounted) {
        // 可以在这里显示错误提示
        print('预览服务错误: $error');
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _pageController.dispose();
    _recordUpdateSubscription?.cancel();
    _errorSubscription?.cancel();
    _previewService.dispose();
    super.dispose();
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
              child: PageIndicator(
                pageController: _pageController,
                totalPages: widget.mistakeRecordIds.length,
                initialIndex: widget.initialIndex,
              ),
            ),
        ],
      ),
    );
  }
  
  // 构建单个页面
  Widget _buildPage(int pageIndex) {
    final recordId = widget.mistakeRecordIds[pageIndex];
    final mistakeRecord = _previewService.getCachedRecord(recordId);
    final question = _previewService.getCachedQuestion(recordId);
    
    print('📄 构建页面 $pageIndex:');
    print('   recordId: $recordId');
    print('   record 状态: ${mistakeRecord?.analysisStatus}');
    print('   question: ${question != null ? "已加载" : "未加载"}');
    
    return _MistakeDetailPage(
      key: ValueKey('page_$pageIndex'),
      pageIndex: pageIndex,
      recordId: recordId,
      isLoading: _pageLoadingStatus[pageIndex] ?? false,
      errorMessage: _pageErrorStatus[pageIndex],
      mistakeRecord: mistakeRecord,
      question: question,
      modulesInfo: _previewService.getCachedModulesInfo(recordId),
      knowledgePointsInfo: _previewService.getCachedKnowledgePointsInfo(recordId),
      onRetry: () {
        setState(() {
          _pageErrorStatus[pageIndex] = null;
        });
        _preloadPage(pageIndex);
      },
      onUpdateErrorReason: (MistakeRecord record, String errorReason) async {
        await _previewService.updateErrorReason(record.id, errorReason);
      },
      onToggleImportant: (String recordId, bool isImportant) async {
        await _previewService.updateIsImportant(recordId, isImportant);
      },
      onReportOcrError: (recordId, wrongReason) async {
        await _previewService.reportOcrError(recordId, wrongReason);
      },
      pulseAnimation: _pulseAnimation,
      progressAnimation: _progressAnimation,
      onStartProgress: (recordId) => _startProgressAnimation(recordId),
    );
  }


  // 构建菜单按钮
  Widget _buildMenuButton() {
    final currentPage = _pageController.hasClients 
        ? (_pageController.page ?? widget.initialIndex).round()
        : widget.initialIndex;
    final recordId = widget.mistakeRecordIds[currentPage];
    final mistakeRecord = _previewService.getCachedRecord(recordId);
    
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
                         mistakeRecord.analysisStatus == AnalysisStatus.completed ||
                         mistakeRecord.analysisStatus == AnalysisStatus.ocrOK;

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
      await _previewService.retryAnalysis(recordId);

      if (mounted) {
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
        await _previewService.deleteRecord(recordId);
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
  
  // 启动进度条动画
  void _startProgressAnimation(String recordId) {
    if (_progressStarted[recordId] == true) return;
    
    _progressStarted[recordId] = true;
    _progressController.reset();
    _progressController.forward();
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
  final Future<void> Function(String, bool) onToggleImportant;
  final Future<void> Function(String, String) onReportOcrError;
  final Animation<double> pulseAnimation;
  final Animation<double> progressAnimation;
  final void Function(String) onStartProgress;

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
    required this.onToggleImportant,
    required this.onReportOcrError,
    required this.pulseAnimation,
    required this.progressAnimation,
    required this.onStartProgress,
  });

  @override
  State<_MistakeDetailPage> createState() => _MistakeDetailPageState();
}

class _MistakeDetailPageState extends State<_MistakeDetailPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  
  // 题目详情动画控制器
  late AnimationController _detailsAnimationController;
  late Animation<double> _detailsOpacityAnimation;
  late Animation<Offset> _detailsSlideAnimation;
  late Animation<double> _detailsScaleAnimation;
  
  // 记录上一次的分析状态，用于检测状态变化
  AnalysisStatus? _previousAnalysisStatus;
  bool _previousHasQuestion = false; // 记录上一次是否有 question 数据
  
  @override
  void initState() {
    super.initState();
    _setupDetailsAnimation();
    _previousAnalysisStatus = widget.mistakeRecord?.analysisStatus;
    _previousHasQuestion = widget.question != null;
    
    // 如果页面初始化时记录已经是 completed 状态且有 question 数据，直接完成动画
    // 这种情况发生在：用户滑到一个已经分析完成的页面
    if (widget.mistakeRecord?.analysisStatus == AnalysisStatus.completed &&
        widget.question != null) {
      _detailsAnimationController.value = 1.0; // 直接设置为完成状态
    }
  }
  
  void _setupDetailsAnimation() {
    _detailsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _detailsOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _detailsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _detailsScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutBack),
    ));
  }
  
  @override
  void dispose() {
    _detailsAnimationController.dispose();
    super.dispose();
  }
  
  // 检测分析状态变化，触发动画
  void _checkAnalysisStatusChange() {
    final currentStatus = widget.mistakeRecord?.analysisStatus;
    final currentHasQuestion = widget.question != null;
    
    // 两种情况需要启动动画：
    // 1. 状态从非完成变为完成，且有 question 数据
    // 2. 状态已经是完成，但 question 数据刚刚加载完成（从无到有）
    final shouldStartAnimation = currentStatus == AnalysisStatus.completed &&
        currentHasQuestion &&
        (_previousAnalysisStatus != AnalysisStatus.completed || !_previousHasQuestion);
    
    if (shouldStartAnimation && _detailsAnimationController.value == 0.0) {
      // 延迟一点启动动画，让分析状态卡片先消失
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _detailsAnimationController.forward();
          }
        });
      });
    }
    
    _previousAnalysisStatus = currentStatus;
    _previousHasQuestion = currentHasQuestion;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，AutomaticKeepAliveClientMixin 需要
    
    // 检测分析状态变化，触发动画
    _checkAnalysisStatusChange();
    
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
        // 学科标签和重点标记
        SliverToBoxAdapter(
          child: _buildTopBar(widget.mistakeRecord!),
        ),
        
        // 原始图片
        SliverToBoxAdapter(
          child: OriginalImageWidget(
            imageId: widget.mistakeRecord!.originalImageId,
          ),
        ),

        // OCR 完成：显示简化的题目内容（题目、选项、备注、答案）
        if (widget.mistakeRecord!.analysisStatus == AnalysisStatus.ocrOK && 
            widget.question != null)
          SliverToBoxAdapter(
            child: SimpleQuestionCard(
              question: widget.question!,
              mistakeRecord: widget.mistakeRecord!,
              onErrorReasonChanged: (errorReason) {
                widget.onUpdateErrorReason(widget.mistakeRecord!, errorReason);
              },
            ),
          ),

        // 分析状态卡片（pending、ocrOK、processing、failed 时显示）
        if (widget.mistakeRecord!.analysisStatus != AnalysisStatus.completed)
          SliverToBoxAdapter(
            child: AnalysisStatusCard(
              mistakeRecord: widget.mistakeRecord!,
              progressAnimation: widget.progressAnimation,
              onStartProgress: () => widget.onStartProgress(widget.recordId),
            ),
          ),

        // 题目详情（分析完成后显示完整信息）
        if (widget.mistakeRecord!.isAnalyzed && widget.question != null)
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _detailsOpacityAnimation,
              child: SlideTransition(
                position: _detailsSlideAnimation,
                child: ScaleTransition(
                  scale: _detailsScaleAnimation,
                  child: QuestionDetailsCard(
                    question: widget.question!,
                    mistakeRecord: widget.mistakeRecord!,
                    modulesInfo: widget.modulesInfo,
                    knowledgePointsInfo: widget.knowledgePointsInfo,
                    onErrorReasonChanged: (errorReason) {
                      widget.onUpdateErrorReason(widget.mistakeRecord!, errorReason);
                    },
                    onReportOcrError: (wrongReason) async {
                      await widget.onReportOcrError(widget.mistakeRecord!.id, wrongReason);
                    },
                  ),
                ),
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

  // 构建顶部栏：左边学科标签，右边重点标记
  Widget _buildTopBar(MistakeRecord mistakeRecord) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingM,
        AppConstants.spacingM,
        AppConstants.spacingM,
        0, // 下边距为0，让图片的margin来控制间距
      ),
      child: Row(
        children: [
          // 左边：学科标签
          if (mistakeRecord.subject != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: mistakeRecord.subject!.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20), // 胶囊状，和右边按钮一致
                border: Border.all(
                  color: mistakeRecord.subject!.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mistakeRecord.subject!.icon,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mistakeRecord.subject!.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mistakeRecord.subject!.color,
                    ),
                  ),
                ],
              ),
            ),
          
          const Spacer(),
          
          // 右边：标记为重点
          GestureDetector(
            onTap: () => _toggleImportant(mistakeRecord),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: mistakeRecord.isImportant 
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.textTertiary.withValues(alpha: 0.08), // 未标记时灰色背景
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: mistakeRecord.isImportant 
                      ? AppColors.warning.withValues(alpha: 0.4)
                      : AppColors.divider, // 未标记时灰色边框
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mistakeRecord.isImportant 
                        ? CupertinoIcons.star_fill 
                        : CupertinoIcons.star,
                    size: 16,
                    color: mistakeRecord.isImportant 
                        ? AppColors.warning 
                        : AppColors.textTertiary, // 未标记时灰色图标
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '标记为重点',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: mistakeRecord.isImportant 
                          ? AppColors.warning 
                          : AppColors.textTertiary, // 未标记时灰色文字
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

  // 切换重要标记
  Future<void> _toggleImportant(MistakeRecord mistakeRecord) async {
    final newImportantStatus = !mistakeRecord.isImportant;
    
    try {
      // 调用回调更新
      await widget.onToggleImportant(widget.recordId, newImportantStatus);
      
      // 服务内部会发送更新事件，UI 会自动刷新，并触发震动反馈
    } catch (e) {
      // 错误已在服务层处理
      print('切换重要标记失败: $e');
    }
  }
}
