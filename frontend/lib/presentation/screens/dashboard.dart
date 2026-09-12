import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/animations.dart';
import '../../data/local/preferences.dart';
import '../../data/repositories/providers.dart';
import '../../data/models/match_report.dart';
import '../../data/models/event.dart';
import 'match_details.dart';
import 'trash_screen.dart';
import '../factories/scouting_form_factory.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import '../widgets/connection_status.dart';
import '../widgets/color_bar.dart';
import '../widgets/brand_mascot.dart';
import 'settings_screen.dart';

import '../widgets/match_search_delegate.dart';

import '../../data/services/export_service.dart';
import '../providers/auth_provider.dart';
import '../providers/event_providers.dart';
import 'dart:async';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _showExportOptions(BuildContext context, WidgetRef ref) async {
    final matches =
        ref.read(matchesViewProvider).value?.matches ?? const <MatchReport>[];

    if (!context.mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No matches to export.")));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text("export as csv"),
              onTap: () {
                Navigator.pop(context);
                _exportCsv(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text("export as excel"),
              onTap: () {
                Navigator.pop(context);
                _exportExcel(matches);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("export as pdf"),
              onTap: () {
                Navigator.pop(context);
                _exportPdf(matches);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final matches =
        ref.read(matchesViewProvider).value?.matches ?? const <MatchReport>[];

    if (!context.mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No matches to export."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Built by ExportService rather than string-interpolated here: the old
    // inline version quoted `comments` without doubling embedded quotes (so a
    // comment could break out of its field and inject columns) and escaped no
    // formula triggers, letting a scout's comment run as a formula in whoever
    // opened the export.
    try {
      await ExportService.exportToCsv(matches);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  Future<void> _exportExcel(List<MatchReport> matches) async {
    try {
      await ExportService.exportToExcel(matches);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Excel export failed: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportPdf(List<MatchReport> matches) async {
    try {
      await ExportService.exportToPdf(matches);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF export failed: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    AppHaptics.medium();
    // Await the re-subscribed stream's first emission so the RefreshIndicator
    // spinner stays up until fresh data actually arrives, rather than
    // collapsing the instant invalidate() returns.
    ref.invalidate(matchesViewProvider);
    await ref.read(matchesViewProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final eventCode = settings[PrefKeys.eventCode] ?? "Unknown Event";
    final brand = BrandScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final matchesAsync = ref.watch(matchesViewProvider);

    return Scaffold(
      body: Column(
        children: [
          const ConnectionStatusBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              displacement: 80,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Slim ink bar: mascot + wordmark, then only the two
                  // actions the design carries — the status circle and the
                  // menu. Search and export moved into the menu rather than
                  // being dropped.
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppTheme.chrome(brand),
                    foregroundColor: AppTheme.onChrome(brand),
                    titleSpacing: 0,
                    leading: Center(
                      child: BrandMascot(
                        name: Mascots.nori,
                        size: 30,
                        color: AppTheme.onChrome(brand),
                      ),
                    ),
                    title: const Text("sushiscout 26"),
                    actions: [
                      // No status chip here: EventSyncRow below the band now
                      // carries the synced/pending count persistently, and the
                      // chip rendered nothing at all on the happy path.
                      // More options menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.menu),
                        onSelected: (value) async {
                          switch (value) {
                            case 'search':
                              final matches =
                                  ref
                                      .read(matchesViewProvider)
                                      .value
                                      ?.matches ??
                                  const <MatchReport>[];
                              showSearch(
                                context: context,
                                delegate: MatchSearchDelegate(matches),
                              );
                              break;
                            case 'export':
                              _showExportOptions(context, ref);
                              break;
                            case 'trash':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TrashScreen(),
                                ),
                              );
                              break;
                            case 'settings':
                              _openSettings(context);
                              break;
                            case 'sign_out':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  // '?' has no glyph in Sushi Sans and the dialog title
                          // is the display face, so it would render as a gap.
                          title: const Text('sign out'),
                                  content: const Text(
                                    'You will need to sign in again to access your team data.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('sign out'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref.read(authProvider.notifier).signOut();
                              }
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'search',
                            child: ListTile(
                              leading: Icon(Icons.search),
                              title: Text("search matches"),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.download_rounded),
                              title: Text("export"),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'trash',
                            child: ListTile(
                              leading: Icon(Icons.auto_delete_outlined),
                              title: Text("trash"),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'settings',
                            child: ListTile(
                              leading: Icon(Icons.settings_outlined),
                              title: Text("settings"),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'sign_out',
                            child: ListTile(
                              leading: Icon(Icons.logout),
                              title: Text("sign out"),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Band immediately under the ink bar; the event row sits
                    // BELOW it on paper, not above it on chrome.
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(
                        AppTheme.colorBarThickness,
                      ),
                      child: ColorBar(brand: brand),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: EventSyncRow(brand: brand, eventCode: eventCode),
                  ),

                  // Match list
                  matchesAsync.when(
                    data: (view) => _buildMatchList(context, view.matches),
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text(
                              "Error loading matches",
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              "$error",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BrandActionBar(
        brand: BrandScope.of(context),
        label: 'scout match',
        onPressed: () async {
          try {
            AppHaptics.medium();
            final eventId = ref.read(currentEventIdProvider);
            final eventCode = ref.read(currentEventCodeProvider);
            final programType =
                ref.read(settingsProvider)[PrefKeys.programType] ?? "FRC";

            // Timeout prevents hanging when Firestore is slow/offline
            final event = await ref
                .read(firestoreRepositoryProvider)
                .getEvent(eventId)
                .timeout(const Duration(seconds: 5), onTimeout: () => null);

            if (!context.mounted) return;

            if (event == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Event '$eventCode' not found. Defaulting to $programType.",
                  ),
                ),
              );
              final dummyEvent = Event(
                id: eventId, // composite: events/matches
                name: eventCode,
                programType: programType,
                tbaKey: eventCode, // raw code: schedule/TBA
                startDate: DateTime.now(),
                teamId: ref.read(currentTeamIdProvider) ?? '',
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ScoutingFormFactory.create(dummyEvent),
                ),
              );
              return;
            }

            // Firestore-wins: sync local preference to match event
            if (event.programType != programType) {
              ref
                  .read(settingsProvider.notifier)
                  .setProgramType(event.programType);
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ScoutingFormFactory.create(event),
              ),
            );
          } catch (e, stackTrace) {
            debugPrint('Scout Match error: $e\n$stackTrace');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to open scouting form: $e")),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildMatchList(BuildContext context, List<MatchReport> matches) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);

    if (matches.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MascotPlate(
                brand: brand,
                name: Mascots.daimler,
                width: double.infinity,
                height: 260,
              ),
              // The 15° cut. An empty state is a splash-like page, which is
              // where the Initiative puts the motif — not on the match list
              // itself, which is a dense data surface.
              BrandSkewField(
                brand: brand,
                height: 56,
                background: colorScheme.surface,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                "no matches yet",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                "scout your first match and it lands here, synced to the team.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: _MatchCard(match: matches[index]),
            ),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: child,
                ),
              );
            },
          ),
          childCount: matches.length,
        ),
      ),
    );
  }
}

/// Material 3 styled match card with alliance color strip and sync indicator
class _MatchCard extends ConsumerWidget {
  final MatchReport match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);

    // Build summary from game data
    String summary = "";
    if (match.gameData.containsKey('auto_fuel')) {
      summary =
          "auto ${match.gameData['auto_fuel']} · tele ${match.gameData['teleop_fuel']}";
    } else if (match.gameData.containsKey('artifacts_auto')) {
      summary =
          "auto ${match.gameData['artifacts_auto']} · tele ${match.gameData['artifacts_teleop']}";
    } else {
      summary = "no data recorded";
    }

    final allianceColor = AppTheme.allianceColor(match.alliance);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      // Carry the 2.5px rule explicitly — a bare RoundedRectangleBorder here
      // overrode the theme's side and left the card with no visible edge.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: colorScheme.outline, width: AppTheme.ruleWidth),
      ),
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(match: match),
            ),
          );
        },
        onLongPress: () {
          AppHaptics.medium();
          _showContextMenu(context, ref);
        },
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left border strip showing alliance color
              Container(width: 4, color: allianceColor),

              // Main card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Row(
                    children: [
                      // Match number badge
                      Container(
                        width: 48,
                        height: 48,
                        // An ink plate with paper digits in BOTH brightnesses.
                        // colorScheme.onSurface inverted this to a white slab
                        // on dark; the design keeps it black either way, so in
                        // dark it reads as a bare numeral on the card.
                        decoration: BoxDecoration(
                          color: AppTheme.chrome(brand),
                          borderRadius: BorderRadius.circular(
                            AppTheme.buttonRadius,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "${match.matchNumber}",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.onChrome(brand),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: AppTheme.spacingMd),

                      // Match info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Alliance is carried by the coloured left rail
                            // alone \u2014 the design has no separate chip here.
                            Text(
                              "q${match.matchNumber} \u2022 team ${match.teamNumber}",
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (match.scouterName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                "scouted by ${match.scouterName}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: AppTheme.spacingSm),

                      // Sync status square
                      SyncSquare(brand: brand, synced: match.isSynced),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header showing which match this menu is for
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              child: Row(
                children: [
                  Text(
                    "Q${match.matchNumber} \u2022 Team ${match.teamNumber}",
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.info_outline, color: colorScheme.primary),
              title: const Text("view details"),
              onTap: () {
                AppHaptics.selection();
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MatchDetailsScreen(match: match),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text(
                "Move to Trash",
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                AppHaptics.heavy();
                Navigator.pop(sheetContext);
                _moveToTrash(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToTrash(BuildContext context, WidgetRef ref) async {
    final eventId = ref.read(currentEventIdProvider);
    if (eventId.isEmpty) return;

    try {
      final repo = ref.read(firestoreRepositoryProvider);
      await repo.trashMatch(eventId, match.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Match moved to trash"),
            action: SnackBarAction(
              label: "Undo",
              onPressed: () async {
                try {
                  await repo.restoreMatch(eventId, match.id);
                } catch (_) {
                  // Silently fail undo — user can restore from trash screen
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to trash match: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
