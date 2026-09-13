import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/providers.dart';
import '../factories/scouting_form_factory.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import '../widgets/color_bar.dart';
import '../widgets/brand_mascot.dart';

/// Material 3 styled match details screen with comprehensive data display.
class MatchDetailsScreen extends ConsumerWidget {
  final MatchReport match;

  const MatchDetailsScreen({super.key, required this.match});

  /// Fetches the owning event (falling back to a dummy built from the match
  /// itself, mirroring dashboard.dart's "scout match" fallback) and pushes
  /// the scouting wizard pre-loaded with this match. On a successful save,
  /// pops this screen too — it holds a frozen snapshot of `match`, so
  /// leaving it up would show stale data until the matches list catches up.
  Future<void> _openEditForm(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(firestoreRepositoryProvider);
    Event? event;
    try {
      event = await repo
          .getEvent(match.eventId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (_) {
      event = null;
    }
    event ??= Event(
      id: match.eventId,
      name: match.eventId,
      programType: match.programType,
      tbaKey: match.eventId,
      startDate: match.createdAt,
      teamId: match.teamId,
    );

    if (!context.mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            ScoutingFormFactory.create(event!, existingMatch: match),
      ),
    );

    if (updated == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);
    final allianceColor = AppTheme.allianceColor(match.alliance);

    // Determine program type: prefer top-level field, fall back to key detection
    final isFtc =
        match.programType == 'FTC' ||
        (match.programType.isEmpty &&
            match.gameData.containsKey('artifacts_auto'));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Large app bar with team info
          SliverAppBar.large(
            expandedHeight: 200,
            backgroundColor: AppTheme.chrome(brand),
            foregroundColor: AppTheme.onChrome(brand),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: "edit match",
                onPressed: () => _openEditForm(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "team ${match.teamNumber}",
                // A bare TextStyle inherits no family — this was rendering in
                // the default face rather than Sushi Sans.
                style: AppTheme.display(
                  brand,
                  size: 24,
                  color: AppTheme.onChrome(brand),
                ),
              ),
              background: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(color: allianceColor),
                        child: Text(
                          "M${match.matchNumber}",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: brand.paper,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      // Alliance pill. Paper fill with ink text, per the
                      // design — an alliance-coloured outline around
                      // alliance-coloured text was unreadable on the chrome.
                      // The M-badge above already carries the alliance colour.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: brand.paper,
                          border: Border.all(
                            color: brand.ink,
                            width: AppTheme.ruleWidth,
                          ),
                        ),
                        child: Text(
                          "${match.alliance.toLowerCase()} alliance",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.onFill(brand, brand.paper),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // The brand band divides the alliance header from the report body,
          // as it does on every other screen.
          SliverToBoxAdapter(child: ColorBar(brand: brand)),

          // Scouter info and status chips
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
                  // The mascot mark is the scout avatar in the design, not a
                  // generic person glyph.
                  BrandMascot(
                    name: Mascots.nori,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    "scouted by ${match.scouterName}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // Program type chip — square and outlined from the chip
                  // theme; an accent tint on a surface is what the Initiative
                  // rules out, so no container fill here. No avatar: the
                  // design's FRC chip is the bare word in a box.
                  Chip(
                    label: Text(isFtc ? "FTC" : "FRC"),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  // Synced chip: the arita fill IS the state in the design —
                  // a solid mint chip, not an outlined one carrying a square.
                  // Label colour is derived from the fill (not the chip
                  // theme's default onSurface) so "synced" doesn't render as
                  // white-on-mint in dark mode.
                  Chip(
                    backgroundColor: match.isSynced
                        ? brand.accentSuccess
                        : null,
                    label: Text(
                      match.isSynced ? "synced" : "local",
                      style: match.isSynced
                          ? AppTheme.label(
                              brand,
                              color: AppTheme.onFill(
                                brand,
                                brand.accentSuccess,
                              ),
                            )
                          : null,
                    ),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
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
                  ..._buildFtcSections(context, allianceColor)
                else
                  ..._buildFrcSections(context, allianceColor),

                // Comments section
                if (match.comments.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _SectionCard(
                    title: "comments",
                    accentColor: allianceColor,
                    children: [
                      Text(match.comments, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],

                // Robot died warning
                if (match.robotDied) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Card(
                    color: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      side: BorderSide(
                        color: colorScheme.error,
                        width: AppTheme.ruleWidth,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: colorScheme.error),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            "Robot Died / Disabled During Match",
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.error,
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

  List<Widget> _buildFrcSections(BuildContext context, Color allianceColor) {
    final data = match.gameData;

    return [
      _SectionCard(
        title: "autonomous",
        accentColor: allianceColor,
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
        title: "teleop",
        accentColor: allianceColor,
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
        title: "traversal",
        accentColor: allianceColor,
        children: [
          _DataRow(
            label: "Trench Traverse",
            value: (data['trench_traverse'] ?? false) ? "Yes" : "No",
          ),
          _DataRow(
            label: "Bump Traverse",
            value: (data['bump_traverse'] ?? false) ? "Yes" : "No",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "shooting range",
        accentColor: allianceColor,
        children: [
          _DataRow(
            label: "Close Range",
            value: (data['shooting_range_close'] ?? false) ? "Yes" : "No",
          ),
          _DataRow(
            label: "Mid Range",
            value: (data['shooting_range_mid'] ?? false) ? "Yes" : "No",
          ),
          _DataRow(
            label: "Far Range",
            value: (data['shooting_range_far'] ?? false) ? "Yes" : "No",
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      _SectionCard(
        title: "performance",
        accentColor: allianceColor,
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

  List<Widget> _buildFtcSections(BuildContext context, Color allianceColor) {
    final data = match.gameData;

    return [
      _SectionCard(
        title: "autonomous",
        accentColor: allianceColor,
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
        title: "teleop",
        accentColor: allianceColor,
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
        title: "endgame",
        accentColor: allianceColor,
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

/// Section card with title and alliance-coloured accent strip.
///
/// No heading icon: the design's section cards are a lowercase word over a
/// rule, nothing else.
class _SectionCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      // Square, per the Initiative's geometry — a 12dp radius here was
      // overriding the theme's square cardTheme.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: colorScheme.outline, width: AppTheme.ruleWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alliance-colored accent strip
            Container(width: 4, color: accentColor),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const Divider(height: AppTheme.spacingLg),
                    ...children,
                  ],
                ),
              ),
            ),
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
          // The label/value distinction comes from colour — the label is
          // onSurfaceVariant, the value inherits onSurface — so no weight.
          Text(value, style: theme.textTheme.bodyMedium),
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
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isFilled
                          ? colorScheme.onSurface
                          : Colors.transparent,
                      border: isFilled
                          ? null
                          : Border.all(
                              color: colorScheme.outline,
                              width: AppTheme.ruleWidth,
                            ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
