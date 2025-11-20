import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';

/// 知识点星系图 - 气泡云可视化
class KnowledgeGalaxyView extends StatefulWidget {
  final List<KnowledgePoint> points;
  final Function(KnowledgePoint) onPointTap;

  const KnowledgeGalaxyView({
    super.key,
    required this.points,
    required this.onPointTap,
  });

  @override
  State<KnowledgeGalaxyView> createState() => _KnowledgeGalaxyViewState();
}

class _Bubble {
  final KnowledgePoint point;
  final double radius;
  Offset position = Offset.zero;
  final Color color;

  _Bubble({
    required this.point,
    required this.radius,
    required this.color,
  });
}

class _ClusterLabel {
  final String name;
  final Offset position;
  final Color color;
  _ClusterLabel(this.name, this.position, this.color);
}

class _KnowledgeGalaxyViewState extends State<KnowledgeGalaxyView> with SingleTickerProviderStateMixin {
  String? _selectedSubject;
  List<_Bubble> _bubbles = [];
  List<_ClusterLabel> _clusterLabels = [];
  List<_GroupCluster> _clusters = [];
  Size _contentSize = const Size(300, 300);
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // 是否需要自动适应屏幕（初始化或数据更新时）
  bool _shouldAutoFit = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _calculateLayout();
    _animationController.forward();
  }

  @override
  void didUpdateWidget(KnowledgeGalaxyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _calculateLayout();
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _calculateLayout() {
    // 设置需要重新适应屏幕
    _shouldAutoFit = true;

    if (widget.points.isEmpty) {
      setState(() {
        _bubbles = [];
        _clusterLabels = [];
        _clusters = [];
        _contentSize = const Size(300, 300);
      });
      return;
    }

    // 1. 确定分组
    Map<String, List<KnowledgePoint>> groups = {};
    if (_selectedSubject != null) {
      // 如果选中了某个学科，就只显示这个学科的数据（作为一个单组）
      groups[_selectedSubject!] = widget.points
          .where((p) => p.subject.displayName == _selectedSubject)
          .toList();
    } else {
      // 否则按学科分组
      for (var p in widget.points) {
        groups.putIfAbsent(p.subject.displayName, () => []).add(p);
      }
    }

    if (groups.isEmpty || groups.values.every((l) => l.isEmpty)) {
      setState(() {
        _bubbles = [];
        _clusterLabels = [];
        _clusters = [];
        _contentSize = const Size(300, 300);
      });
      return;
    }

    // 计算全局最大错题数，用于统一气泡大小比例
    double maxMistakes = 1;
    for (var p in widget.points) {
      if (p.mistakeCount > maxMistakes) maxMistakes = p.mistakeCount.toDouble();
    }

    List<_Bubble> allBubbles = [];
    List<_ClusterLabel> labels = [];
    
    // 2. 对每个组进行内部布局
    // 这里我们将每个组视为一个“大圆”，然后对大圆进行布局
    List<_GroupCluster> groupClusters = [];

    for (var entry in groups.entries) {
      final subjectName = entry.key;
      final points = entry.value;
      if (points.isEmpty) continue;

      // 创建该组的所有气泡
      final bubbles = points.map((point) {
        double r = 36 + (point.mistakeCount / maxMistakes) * 34;
        if (point.importance == KnowledgePointImportance.high) r *= 1.1;
        return _Bubble(
          point: point,
          radius: r,
          color: _getMasteryColor(point.masteryLevel),
        );
      }).toList();

      // 组内气泡排序
      bubbles.sort((a, b) => b.radius.compareTo(a.radius));

      // 组内布局（螺旋）
      final layoutResult = _packBubbles(bubbles);
      
      // 获取学科颜色
      final subject = Subject.fromString(subjectName);
      final color = subject?.color ?? AppColors.primary;

      groupClusters.add(_GroupCluster(
        name: subjectName,
        bubbles: bubbles,
        radius: layoutResult.radius, // 组半径
        color: color,
      ));
    }

    // 3. 对组进行布局（如果是多组）
    if (groupClusters.length > 1) {
      // 同样使用螺旋算法布局这些“大圆”
      
      // 先按半径排序
      groupClusters.sort((a, b) => b.radius.compareTo(a.radius));
      
      List<_GroupCluster> placedClusters = [];
      double minX = 0, maxX = 0, minY = 0, maxY = 0;
      const double stepAngle = 0.5;

      for (var i = 0; i < groupClusters.length; i++) {
        final cluster = groupClusters[i];
        
        if (i == 0) {
          cluster.position = Offset.zero;
          placedClusters.add(cluster);
          minX = -cluster.radius; maxX = cluster.radius;
          minY = -cluster.radius; maxY = cluster.radius;
          continue;
        }

        double angle = i * 1.0;
        double dist = 0;
        bool collision = true;
        
        while (collision) {
          dist += 5.0; // 步长稍大
          angle += stepAngle / (dist / 100 + 1); // 距离越远角度步长越小
          
          final x = dist * math.cos(angle);
          final y = dist * math.sin(angle);
          
          bool hit = false;
          for (var other in placedClusters) {
            final dx = x - other.position.dx;
            final dy = y - other.position.dy;
            final d = math.sqrt(dx * dx + dy * dy);
            // 组间距稍大一些 (80) 以便区分和放标签
            if (d < (cluster.radius + other.radius + 60)) {
              hit = true;
              break;
            }
          }
          
          if (!hit) {
            cluster.position = Offset(x, y);
            placedClusters.add(cluster);
            collision = false;
            
            minX = math.min(minX, x - cluster.radius);
            maxX = math.max(maxX, x + cluster.radius);
            minY = math.min(minY, y - cluster.radius);
            maxY = math.max(maxY, y + cluster.radius);
          }
          if (dist > 10000) break;
        }
      }

      // 4. 合并结果
      // 更新边界
      final width = maxX - minX + 100;
      final height = maxY - minY + 100;
      
      final centerOffsetX = (minX + maxX) / 2;
      final centerOffsetY = (minY + maxY) / 2;
      final centerOffset = Offset(centerOffsetX, centerOffsetY);
      
      // 整体居中并生成气泡和标签
      for (var cluster in placedClusters) {
        // 更新 cluster 位置
        cluster.position -= centerOffset;
        
        // 将组位置应用到气泡
        for (var b in cluster.bubbles) {
          b.position += cluster.position;
          allBubbles.add(b);
        }
        // 添加标签（放在组的上方或中心）
        labels.add(_ClusterLabel(
          cluster.name, 
          cluster.position + Offset(0, -cluster.radius - 20), 
          cluster.color
        ));
      }
      
      setState(() {
        _bubbles = allBubbles;
        _clusterLabels = labels; // labels already centered
        _clusters = placedClusters;
        _contentSize = Size(math.max(width, 300), math.max(height, 300));
      });

    } else {
      // 单组情况
      final cluster = groupClusters.first;
      // 气泡位置已经是相对于 (0,0) 的了.
      // cluster.position is Offset.zero.
      
      allBubbles = cluster.bubbles;
      
      // 计算边界
      double maxR = 0;
      for (var b in allBubbles) {
        final d = b.position.distance + b.radius;
        if (d > maxR) maxR = d;
      }
      
      final size = maxR * 2 + 40;

      setState(() {
        _bubbles = allBubbles;
        _clusterLabels = []; // 单组时不显示标签
        _clusters = [cluster]; // Save the single cluster
        _contentSize = Size(math.max(size, 300), math.max(size, 300));
      });
    }
  }

  // 辅助类：组布局中间态
  
  // 气泡打包算法 (返回半径)
  _PackResult _packBubbles(List<_Bubble> bubbles) {
    if (bubbles.isEmpty) return _PackResult(0);
    
    List<_Bubble> placed = [];
    double maxDist = 0;
    const double stepAngle = 0.1;

    for (var i = 0; i < bubbles.length; i++) {
      final bubble = bubbles[i];
      
      if (i == 0) {
        bubble.position = Offset.zero;
        placed.add(bubble);
        maxDist = bubble.radius;
        continue;
      }

      double angle = i * 0.5;
      double dist = 0;
      bool collision = true;

      while (collision) {
        dist += 1.0;
        angle += stepAngle;
        
        final x = dist * math.cos(angle);
        final y = dist * math.sin(angle);
        
        bool hit = false;
        for (var other in placed) {
          final dx = x - other.position.dx;
          final dy = y - other.position.dy;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < (bubble.radius + other.radius + 4)) {
            hit = true;
            break;
          }
        }
        
        if (!hit) {
          bubble.position = Offset(x, y);
          placed.add(bubble);
          collision = false;
          final d = math.sqrt(x*x + y*y) + bubble.radius;
          if (d > maxDist) maxDist = d;
        }
        if (dist > 5000) break;
      }
    }
    return _PackResult(maxDist);
  }

  @override
  Widget build(BuildContext context) {
    // 获取唯一学科列表
    final subjects = widget.points.map((p) => p.subject.displayName).toSet().toList()..sort();

    return Container(
      height: 450, // 增加高度以容纳多组
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '知识星系',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subjects.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showSubjectFilter(context, subjects),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedSubject ?? '全部学科',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Galaxy Content
          Expanded(
            child: _bubbles.isEmpty
                ? const Center(
                    child: Text(
                      '暂无知识点数据',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    // 自动适应屏幕逻辑
                    if (_shouldAutoFit && _contentSize.width > 0) {
                      // 在下一帧执行缩放，避免 build 期间 setState
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        
                        final viewportWidth = constraints.maxWidth;
                        final viewportHeight = constraints.maxHeight;
                        
                        // 计算缩放比例 (留 10% 边距)
                        final scaleX = viewportWidth / _contentSize.width;
                        final scaleY = viewportHeight / _contentSize.height;
                        final scale = math.min(scaleX, scaleY) * 0.9;
                        
                        // 居中矩阵
                        final matrix = Matrix4.identity()
                          ..translate(
                            viewportWidth / 2,
                            viewportHeight / 2,
                          )
                          ..scale(scale)
                          ..translate(
                            -_contentSize.width / 2,
                            -_contentSize.height / 2,
                          );
                          
                        _transformationController.value = matrix;
                        
                        setState(() {
                          _shouldAutoFit = false;
                        });
                      });
                    }
                    
                    return Stack(
                      children: [
                        ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            minScale: 0.1, // 允许缩小更多以看清全貌
                            maxScale: 4.0,
                            constrained: false, // 允许无限滚动区域
                            child: SizedBox(
                              width: _contentSize.width,
                              height: _contentSize.height,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 聚类背景圈 (最底层)
                                  ..._clusters.map((cluster) {
                                    // 稍微扩大一点半径，包住气泡
                                    final visualRadius = cluster.radius + 15.0;
                                    return Positioned(
                                      left: _contentSize.width / 2 + cluster.position.dx - visualRadius,
                                      top: _contentSize.height / 2 + cluster.position.dy - visualRadius,
                                      width: visualRadius * 2,
                                      height: visualRadius * 2,
                                      child: ScaleTransition(
                                        scale: _scaleAnimation,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            // 极淡的背景色
                                            color: cluster.color.withOpacity(0.03),
                                            // 虚线边框效果可以用 dotted_border 包，但这里用简单边框即可
                                            border: Border.all(
                                              color: cluster.color.withOpacity(0.15),
                                              width: 1.5,
                                              style: BorderStyle.solid,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  // 标签层
                                  ..._clusterLabels.map((label) => Positioned(
                                    left: _contentSize.width / 2 + label.position.dx - 100, // 居中
                                    top: _contentSize.height / 2 + label.position.dy - 15,
                                    width: 200,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: label.color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: label.color.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          label.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: label.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                                  
                                  // 气泡层
                                  ..._bubbles.map((bubble) => Positioned(
                                    left: _contentSize.width / 2 + bubble.position.dx - bubble.radius,
                                    top: _contentSize.height / 2 + bubble.position.dy - bubble.radius,
                                    child: ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: _buildBubble(bubble),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.move,
                                  size: 14,
                                  color: AppColors.textSecondary.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '双指缩放 · 自由拖拽',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
          ),
          
          // Legend
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(AppColors.error, '需攻克'),
                const SizedBox(width: 16),
                _buildLegendItem(AppColors.warning, '加强中'),
                const SizedBox(width: 16),
                _buildLegendItem(AppColors.success, '已掌握'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Bubble bubble) {
    final isLarge = bubble.radius > 50;
    
    return GestureDetector(
      onTap: () => widget.onPointTap(bubble.point),
      child: Container(
        width: bubble.radius * 2,
        height: bubble.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              bubble.color.withOpacity(0.2),
              bubble.color.withOpacity(0.1),
            ],
            stops: const [0.3, 1.0],
          ),
          border: Border.all(
            color: bubble.color.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: bubble.color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bubble.point.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isLarge ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (isLarge) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${bubble.point.mistakeCount}错',
                    style: TextStyle(
                      fontSize: 9,
                      color: bubble.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showSubjectFilter(BuildContext context, List<String> subjects) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('选择学科'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('全部学科'),
            onPressed: () {
              setState(() {
                _selectedSubject = null;
                _calculateLayout();
              });
              Navigator.pop(context);
            },
          ),
          ...subjects.map((subject) => CupertinoActionSheetAction(
            child: Text(subject),
            onPressed: () {
              setState(() {
                _selectedSubject = subject;
                _calculateLayout();
              });
              Navigator.pop(context);
            },
          )),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Color _getMasteryColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.accent;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

class _GroupCluster {
  final String name;
  final List<_Bubble> bubbles;
  final double radius;
  final Color color;
  Offset position = Offset.zero;
  
  _GroupCluster({
    required this.name,
    required this.bubbles,
    required this.radius,
    required this.color,
  });
}

class _PackResult {
  final double radius;
  _PackResult(this.radius);
}
