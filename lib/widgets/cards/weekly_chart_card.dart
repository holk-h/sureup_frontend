import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/colors.dart';

/// 本周数据图表卡片 - 展示错题和练习题目的每日数据
class WeeklyChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;

  const WeeklyChartCard({
    super.key,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 错题记录图表
        _buildChartCard(
          title: '错题记录',
          color: AppColors.mistake,
          dataKey: 'mistakeCount',
        ),
        const SizedBox(height: 16),
        // 练习题目图表
        _buildChartCard(
          title: '练习题目',
          color: AppColors.accent,
          dataKey: 'practiceCount',
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required Color color,
    required String dataKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和统计
            _buildHeader(title, color, dataKey),
            const SizedBox(height: 20),
            
            // 图表
            SizedBox(
              height: 180,
              child: _buildLineChart(color, dataKey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, Color color, String dataKey) {
    // 计算5天总数和日均值
    final total = weeklyData.fold<double>(
      0, 
      (sum, data) {
        final value = data[dataKey] as double?;
        return sum + (value ?? 0);
      },
    );
    final count = weeklyData.where((data) {
      final value = data[dataKey] as double?;
      return value != null && value > 0;
    }).length;
    final average = count > 0 ? total / count : 0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildStatItem('5天', total.toInt().toString()),
            const SizedBox(width: 16),
            _buildStatItem('日均', average.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(Color color, String dataKey) {
    final spots = <FlSpot>[];
    int? lastDataIndex;
    
    for (int i = 0; i < weeklyData.length; i++) {
      final value = weeklyData[i][dataKey] as double?;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
        lastDataIndex = i; // 记录最后一个有数据的索引
      }
    }

    final maxY = _getMaxY(dataKey);
    final interval = _getInterval(maxY);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => color,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = weeklyData[spot.x.toInt()]['day'] as String;
                final value = spot.y.toInt();
                return LineTooltipItem(
                  '$day\n',
                  const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '$value 题',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < weeklyData.length) {
                  final day = weeklyData[index]['day'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        // 在最新数据点位置添加标记线和标签（显示具体数值）
        extraLinesData: lastDataIndex != null && spots.isNotEmpty ? ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: lastDataIndex.toDouble(),
              color: color.withOpacity(0.2),
              strokeWidth: 1.5,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(bottom: 4),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                labelResolver: (line) => '${spots[spots.length - 1].y.toInt()}',
              ),
            ),
          ],
        ) : null,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // 最新数据点使用更大的圆点
                final isLastPoint = spot.x.toInt() == lastDataIndex;
                return FlDotCirclePainter(
                  radius: isLastPoint ? 6 : 5,
                  color: color,
                  strokeWidth: isLastPoint ? 4 : 3,
                  strokeColor: AppColors.cardBackground,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                  color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY(String dataKey) {
    double max = 0;
    for (var data in weeklyData) {
      final value = data[dataKey] as double?;
      if (value != null && value > max) max = value;
    }
    // 向上取整到最近的5的倍数，并添加一些padding
    return max == 0 ? 10 : ((max / 5).ceil() * 5 + 2).toDouble();
  }

  double _getInterval(double maxY) {
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return 20;
  }
}

