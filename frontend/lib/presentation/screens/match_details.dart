import 'package:flutter/material.dart';
import '../../data/models/match_report.dart';
import '../theme/app_theme.dart';

/// Material 3 styled match details screen with comprehensive data display.
class MatchDetailsScreen extends StatelessWidget {
  final MatchReport match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allianceColor = match.alliance == 'Red' ? Colors.red : Colors.blue;

    // Determine program type based on data keys
    final isFtc = match.gameData.containsKey('artifacts_auto');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Large app bar with team info
          SliverAppBar.large(
            expandedHeight: 200,
            backgroundColor: allianceColor.withValues(alpha: 0.15),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Team ${match.teamNumber}",
                style: TextStyle(
                  color: allianceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: allianceColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "M${match.matchNumber}",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: allianceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        "${match.alliance} Alliance",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: allianceColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Scouter info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    "Scouted by ${match.scouterName}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (match.isSynced)
                    Chip(
                      avatar: Icon(
                        Icons.cloud_done,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: const Text("Synced"),
                      backgroundColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.only(
                        right: AppTheme.spacingSm,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content sections
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isFtc)
                  ..._buildFtcSections(context)
                else
                  ..._buildFrcSections(context),

                // Comments section
                if (match.comments.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _SectionCard(
                    title: "Comments",
                    icon: Icons.comment_outlined,
                    children: [
                      Text(match.comments, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],

                // Robot died warning
                if (match.robotDied) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: colorScheme.error),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            "Robot Died / Disabled During Match",
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingXxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFrcSections(BuildContext context) {
    final data = match.gameData;

    return [
      _SectionCard(
        title: "Autonomous",
        icon: Icons.smart_toy_outlined,
        children: [
          _DataRow(label: "Fuel Scored", value: "${data['auto_fuel'] ?? 0}"),
          _DataRow(
            label: "Left Start Line (L1)",
            value: (data['auto_tower_l1'] ?? false) ? "Yes" : "No",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "Teleop",
        icon: Icons.sports_esports_outlined,
        children: [
          _DataRow(label: "Fuel Scored", value: "${data['teleop_fuel'] ?? 0}"),
          _DataRow(
            label: "Climb Level",
            value: "Level ${data['teleop_tower_level'] ?? 0}",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "Performance",
        icon: Icons.analytics_outlined,
        children: [
          _RatingRow(
            label: "Defense Rating",
            value: data['defense_rating'] ?? 0,
          ),
          _RatingRow(label: "Driver Skill", value: data['driver_skill'] ?? 0),
        ],
      ),
    ];
  }

  List<Widget> _buildFtcSections(BuildContext context) {
    final data = match.gameData;

    return [
      _SectionCard(
        title: "Autonomous",
        icon: Icons.smart_toy_outlined,
        children: [
          _DataRow(
            label: "Leave",
            value: (data['leave'] ?? false) ? "Yes" : "No",
          ),
          _DataRow(label: "Artifacts", value: "${data['artifacts_auto'] ?? 0}"),
          _DataRow(
            label: "Indexing",
            value: (data['indexing_auto'] ?? false) ? "Yes" : "No",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "Teleop",
        icon: Icons.sports_esports_outlined,
        children: [
          _DataRow(
            label: "Artifacts",
            value: "${data['artifacts_teleop'] ?? 0}",
          ),
          _DataRow(
            label: "Indexing",
            value: (data['indexing_teleop'] ?? false) ? "Yes" : "No",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "Endgame",
        icon: Icons.flag_outlined,
        children: [
          _DataRow(
            label: "Base Expansion",
            value: "${data['base_expansion'] ?? 'None'}",
          ),
          _RatingRow(
            label: "Driver Quality",
            value: (data['driver_quality'] ?? 0).toInt(),
          ),
        ],
      ),
    ];
  }
}

/// Section card with title and icon
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Data row for label/value pairs
class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating row with visual indicator
class _RatingRow extends StatelessWidget {
  final String label;
  final int value;

  const _RatingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              final isFilled = index < value;
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: 18,
                  color: isFilled
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
