import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/hybrid_repository.dart';
import '../../data/local/preferences.dart';
import '../theme/app_theme.dart';
import '../../core/animations.dart';

class TeamComparisonScreen extends ConsumerStatefulWidget {
  const TeamComparisonScreen({super.key});

  @override
  ConsumerState<TeamComparisonScreen> createState() => _TeamComparisonScreenState();
}

class _TeamComparisonScreenState extends ConsumerState<TeamComparisonScreen> {
  int? _team1;
  int? _team2;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final eventCode = settings[PrefKeys.eventCode] ?? "Unknown";
    final repo = ref.watch(hybridRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Team Comparison"),
      ),
      body: FutureBuilder<List<MatchReport>>(
        future: repo.getMatches(eventCode),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data!;
          final teams = matches.map((m) => m.teamNumber).toSet().toList()..sort();

          if (teams.isEmpty) {
            return const Center(child: Text("No data available to compare."));
          }

          return Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                _buildTeamSelectors(teams),
                const SizedBox(height: AppTheme.spacingLg),
                if (_team1 != null && _team2 != null)
                  Expanded(child: _buildComparisonView(matches))
                else
                  const Expanded(
                    child: Center(
                      child: Text("Select two teams to compare"),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamSelectors(List<int> teams) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: "Team A", border: OutlineInputBorder()),
            value: _team1,
            items: teams.map((t) => DropdownMenuItem(value: t, child: Text("$t"))).toList(),
            onChanged: (v) => setState(() => _team1 = v),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: "Team B", border: OutlineInputBorder()),
            value: _team2,
            items: teams.map((t) => DropdownMenuItem(value: t, child: Text("$t"))).toList(),
            onChanged: (v) => setState(() => _team2 = v),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonView(List<MatchReport> allMatches) {
    final stats1 = _calculateStats(allMatches, _team1!);
    final stats2 = _calculateStats(allMatches, _team2!);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildRadarChart(stats1, stats2),
          const SizedBox(height: AppTheme.spacingLg),
          _buildStatTable(stats1, stats2),
        ],
      ),
    );
  }

  Map<String, double> _calculateStats(List<MatchReport> matches, int team) {
    final teamMatches = matches.where((m) => m.teamNumber == team).toList();
    if (teamMatches.isEmpty) return {};

    double auto = 0, teleop = 0, defense = 0, climb = 0;
    
    for (var m in teamMatches) {
      auto += (m.gameData['auto_fuel'] as num?)?.toDouble() ?? 0;
      teleop += (m.gameData['teleop_fuel'] as num?)?.toDouble() ?? 0;
      defense += (m.gameData['defense_rating'] as num?)?.toDouble() ?? 0;
      // Normalize climb to max 3
      final climbVal = (m.gameData['teleop_tower_level'] as num?)?.toDouble() ?? 0;
      climb += climbVal;
    }

    final count = teamMatches.length;
    return {
      'Auto': auto / count,
      'Teleop': teleop / count,
      'Defense': defense / count,
      'Climb': climb / count,
    };
  }

  Widget _buildRadarChart(Map<String, double> s1, Map<String, double> s2) {
    // Normalize data for radar chart (0-1 range roughly, assuming max values)
    // Auto max ~10, Teleop max ~20, Defense max 5, Climb max 3
    final autoMax = 10.0;
    final teleopMax = 20.0;
    final defenseMax = 5.0;
    final climbMax = 3.0;

    return SizedBox(
      height: 300,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          gridBorderData: const BorderSide(color: Colors.black26),
          titlePositionPercentageOffset: 0.2,
          getTitle: (index, angle) {
            switch (index) {
              case 0: return RadarChartTitle(text: 'Auto');
              case 1: return RadarChartTitle(text: 'Teleop');
              case 2: return RadarChartTitle(text: 'Defense');
              case 3: return RadarChartTitle(text: 'Climb');
              default: return const RadarChartTitle(text: '');
            }
          },
          dataSets: [
            RadarDataSet(
              fillColor: Colors.blue.withOpacity(0.2),
              borderColor: Colors.blue,
              entryRadius: 2,
              dataEntries: [
                RadarEntry(value: (s1['Auto'] ?? 0) / autoMax * 5), // Scale to 0-5
                RadarEntry(value: (s1['Teleop'] ?? 0) / teleopMax * 5),
                RadarEntry(value: (s1['Defense'] ?? 0) / defenseMax * 5),
                RadarEntry(value: (s1['Climb'] ?? 0) / climbMax * 5),
              ],
            ),
            RadarDataSet(
              fillColor: Colors.red.withOpacity(0.2),
              borderColor: Colors.red,
              entryRadius: 2,
              dataEntries: [
                RadarEntry(value: (s2['Auto'] ?? 0) / autoMax * 5),
                RadarEntry(value: (s2['Teleop'] ?? 0) / teleopMax * 5),
                RadarEntry(value: (s2['Defense'] ?? 0) / defenseMax * 5),
                RadarEntry(value: (s2['Climb'] ?? 0) / climbMax * 5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTable(Map<String, double> s1, Map<String, double> s2) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Metric", style: Theme.of(context).textTheme.titleSmall),
                Text("Team $_team1", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text("Team $_team2", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _buildStatRow("Avg Auto", s1['Auto'], s2['Auto']),
            _buildStatRow("Avg Teleop", s1['Teleop'], s2['Teleop']),
            _buildStatRow("Avg Defense", s1['Defense'], s2['Defense']),
            _buildStatRow("Avg Climb", s1['Climb'], s2['Climb']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double? v1, double? v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text((v1 ?? 0).toStringAsFixed(1)),
          Text((v2 ?? 0).toStringAsFixed(1)),
        ],
      ),
    );
  }
}
