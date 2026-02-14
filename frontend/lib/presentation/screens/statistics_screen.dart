import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/hybrid_repository.dart';
import '../../data/local/preferences.dart';
import '../theme/app_theme.dart';
import '../../core/animations.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final eventCode = settings[PrefKeys.eventCode] ?? "Unknown";
    final repo = ref.watch(hybridRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics"),
      ),
      body: StreamBuilder<List<MatchReport>>(
        stream: repo.watchMatches(eventCode),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ShimmerLoading(isLoading: true, child: SizedBox(width: double.infinity, height: 300)));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const Center(child: Text("No matches recorded yet."));
          }

          // Sort by match number for trends
          matches.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: StaggeredListAnimation(
              children: [
                _buildScoreTrendChart(matches),
                const SizedBox(height: AppTheme.spacingLg),
                _buildClimbPieChart(matches),
                const SizedBox(height: AppTheme.spacingLg),
                _buildAveragesCard(matches),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreTrendChart(List<MatchReport> matches) {
    // Extract data points: Match Number vs (Auto + Teleop Fuel)
    final points = matches.asMap().entries.map((e) {
      final index = e.key;
      final m = e.value;
      // FRC specific fallback
      final auto = (m.gameData['auto_fuel'] as num?)?.toDouble() ?? 0;
      final teleop = (m.gameData['teleop_fuel'] as num?)?.toDouble() ?? 0;
      return FlSpot(index.toDouble(), auto + teleop);
    }).toList();

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Fuel Scoring Trend", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClimbPieChart(List<MatchReport> matches) {
    int none = 0;
    int level1 = 0;
    int level2 = 0;
    int level3 = 0;

    for (var m in matches) {
      final climb = m.gameData['teleop_tower_level'] as int? ?? 0;
      if (climb == 0) none++;
      else if (climb == 1) level1++;
      else if (climb == 2) level2++;
      else if (climb == 3) level3++;
    }

    final total = matches.length;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Climb Distribution", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    _buildPieSection(0, none, "None", Colors.grey),
                    _buildPieSection(1, level1, "L1", Colors.orange),
                    _buildPieSection(2, level2, "L2", Colors.blue),
                    _buildPieSection(3, level3, "L3", Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildPieSection(int index, int value, String title, Color color) {
    final isTouched = index == _touchedIndex;
    final fontSize = isTouched ? 18.0 : 14.0;
    final radius = isTouched ? 60.0 : 50.0;

    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: value > 0 ? title : '',
      radius: radius,
      titleStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAveragesCard(List<MatchReport> matches) {
    double totalAuto = 0;
    double totalTeleop = 0;
    double totalDefense = 0;

    for (var m in matches) {
      totalAuto += (m.gameData['auto_fuel'] as num?)?.toDouble() ?? 0;
      totalTeleop += (m.gameData['teleop_fuel'] as num?)?.toDouble() ?? 0;
      totalDefense += (m.gameData['defense_rating'] as num?)?.toDouble() ?? 0;
    }

    final avgAuto = matches.isEmpty ? 0 : totalAuto / matches.length;
    final avgTeleop = matches.isEmpty ? 0 : totalTeleop / matches.length;
    final avgDefense = matches.isEmpty ? 0 : totalDefense / matches.length;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem("Avg Auto", avgAuto.toStringAsFixed(1)),
            _buildStatItem("Avg Teleop", avgTeleop.toStringAsFixed(1)),
            _buildStatItem("Avg Defense", avgDefense.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
