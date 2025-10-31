import 'package:flutter/cupertino.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/text_styles.dart';
import '../models/models.dart';
import '../widgets/cards/knowledge_point_card.dart';

/// 发现页 - 错题地图
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _selectedSubject = '全部';

  @override
  Widget build(BuildContext context) {
    // TODO: 接入真实的知识点数据
    final filteredPoints = <KnowledgePoint>[];

    // 按学科分组
    final Map<String, List<dynamic>> groupedPoints = <String, List<dynamic>>{};

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // 透明背景
      child: CustomScrollView(
        slivers: [
          // Large Title导航栏
          CupertinoSliverNavigationBar(
            backgroundColor: const Color(0x00000000), // 透明背景
            border: null,
            largeTitle: const Text('发现'),
            heroTag: 'map_nav_bar', // 唯一的 Hero tag
            trailing: GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 14,
                      color: AppColors.cardBackground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedSubject,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.cardBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 主内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 统计概览卡片 - 改进版
                  _buildStatsOverviewCard(filteredPoints),
                  
                  const SizedBox(height: AppConstants.spacingL),
                  
                  // 知识点列表
                  if (_selectedSubject == '全部')
                    ...groupedPoints.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(entry.key, entry.value.length),
                          const SizedBox(height: AppConstants.spacingM),
                          ...entry.value.map((point) => KnowledgePointCard(
                            point: point,
                            onTap: () {
                              // TODO: 导航到知识点详情
                            },
                          )),
                          const SizedBox(height: AppConstants.spacingM),
                        ],
                      );
                    })
                  else
                    ...filteredPoints.map((point) => KnowledgePointCard(
                      point: point,
                      onTap: () {
                        // TODO: 导航到知识点详情
                      },
                    )),
                  
                  const SizedBox(height: AppConstants.spacingXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverviewCard(List filteredPoints) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('知识点', '${filteredPoints.length}'),
              Container(
                width: 1,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
              _buildStatItem(
                '错题总数',
                '${filteredPoints.isEmpty ? 0 : filteredPoints.map((p) => p.mistakeCount).reduce((a, b) => a + b)}',
              ),
              Container(
                width: 1,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
              _buildStatItem(
                '平均掌握度',
                '${filteredPoints.isEmpty ? 0 : (filteredPoints.fold<double>(0.0, (sum, p) => sum + p.masteryLevel) / filteredPoints.length).round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String subjectName, int count) {
    final subject = Subject.fromString(subjectName);
    final subjectColor = subject?.color ?? AppColors.subjectDefault;
    final subjectIcon = subject?.icon ?? '📚';
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: subjectColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
          child: Text(
            subjectIcon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$count个知识点',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.mediumTitle.copyWith(
            color: AppColors.cardBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.cardBackground.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    final subjects = ['全部', '数学', '物理', '化学', '英语'];
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 280,
          color: AppColors.cardBackground,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('取消'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('筛选学科', style: AppTextStyles.smallTitle),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('确定'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 44,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedSubject = subjects[index];
                    });
                  },
                  children: subjects.map((subject) {
                    return Center(
                      child: Text(
                        subject,
                        style: AppTextStyles.body,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

