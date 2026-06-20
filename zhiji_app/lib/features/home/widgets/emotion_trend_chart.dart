import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/shimmer_placeholder.dart';

/// 最近7天日记条数的柱状图，标注每天的主导情绪 emoji
class EmotionTrendChart extends ConsumerWidget {
  const EmotionTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return dbAsync.when(
      data: (db) => FutureBuilder<Map<String, int>>(
        future: db.diaryDao.countByDay(7),
        builder: (ctx, snap) {
          final data = snap.data ?? {};
          if (data.isEmpty) {
            return const SizedBox(height: 160, child: Center(child: Text('暂无数据')));
          }
          final bars = _buildBars(data, cs);
          final dayLabels = _buildDayLabels();
          return SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: bars.isEmpty ? 1 : bars.map((b) => b.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.3 + 1,
                barGroups: bars,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        dayLabels[value.toInt()],
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      loading: () => const ShimmerPlaceholder(height: 160),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  static List<String> _buildDayLabels() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return '${day.month}/${day.day}';
    });
  }

  List<BarChartGroupData> _buildBars(Map<String, int> data, ColorScheme cs) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final count = (data[key] ?? 0).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count,
            color: cs.primary.withValues(alpha: count > 0 ? 0.8 : 0.2),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}

/// 写作热力图 — GitHub 风格 4×7 网格（最近4周）
class WritingHeatmap extends ConsumerWidget {
  const WritingHeatmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return dbAsync.when(
      data: (db) => FutureBuilder<Map<String, int>>(
        future: db.diaryDao.countByDay(28),
        builder: (ctx, snap) {
          final data = snap.data ?? {};
          return SizedBox(
            height: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('写作热力图 (近28天)', style: Theme.of(context).textTheme.labelLarge),
                    // 图例
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('少', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      _LegendBox(color: cs.primary.withValues(alpha: 0.1)),
                      _LegendBox(color: cs.primary.withValues(alpha: 0.35)),
                      _LegendBox(color: cs.primary.withValues(alpha: 0.6)),
                      _LegendBox(color: cs.primary.withValues(alpha: 1.0)),
                      Text('多', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      childAspectRatio: 1,
                    ),
                    itemCount: 28,
                    itemBuilder: (ctx, i) {
                      final day = DateTime.now().subtract(Duration(days: 27 - i));
                      final key =
                          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      final count = data[key] ?? 0;
                      final opacity = count == 0
                          ? 0.1
                          : count == 1
                              ? 0.35
                              : count == 2
                                  ? 0.6
                                  : 1.0;
                      return Container(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: opacity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      loading: () => const ShimmerPlaceholder(height: 100),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

class _LegendBox extends StatelessWidget {
  const _LegendBox({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(1),
      )),
    );
  }
}
