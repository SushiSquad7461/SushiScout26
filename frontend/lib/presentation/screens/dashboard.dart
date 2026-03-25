import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../core/animations.dart';
import '../../data/local/preferences.dart';
import '../../data/repositories/hybrid_repository.dart';
import '../../data/models/match_report.dart';
import '../../data/models/event.dart';
import 'match_details.dart';
import 'trash_screen.dart';
import '../factories/scouting_form_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/sync_status_indicator.dart';

import '../widgets/match_search_delegate.dart';

import '../../data/services/export_service.dart';
import '../../core/validation/form_validators.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Stream<List<MatchReport>> _matchesStream;

  @override
  void initState() {
    super.initState();
    final eventCode =
        ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
    _matchesStream = ref.read(hybridRepositoryProvider).watchMatches(eventCode);
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _SettingsSheet(),
    ).then((_) {
      final eventCode =
          ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
      setState(() {
        _matchesStream = ref.read(hybridRepositoryProvider).watchMatches(eventCode);
      });
    });
  }

  Future<void> _showExportOptions(BuildContext context, WidgetRef ref) async {
    final eventCode =
        ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
    final matches = await ref.read(hybridRepositoryProvider).getMatches(eventCode);

    if (!mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No matches to export.")),
      );
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
              title: const Text("Export as CSV"),
              onTap: () {
                Navigator.pop(context);
                _exportCsv(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text("Export as Excel"),
              onTap: () {
                Navigator.pop(context);
                _exportExcel(matches);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Export as PDF"),
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
    final eventCode =
        ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
    final matches = await ref.read(hybridRepositoryProvider).getMatches(eventCode);

    if (!mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No matches to export."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final header = "Match,Team,Alliance,GameData,Comments,Synced\n";
    final rows = matches
        .map(
          (m) =>
              "${m.matchNumber},${m.teamNumber},${m.alliance},\"${m.gameData.toString().replaceAll('"', "'")}\",\"${m.comments.replaceAll('\n', ' ')}\",${m.isSynced}",
        )
        .join("\n");

    final csvContent = header + rows;

    try {
      await _shareFile(csvContent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  Future<void> _shareFile(String content) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sushiscout26_export.csv');
      await file.writeAsString(content);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      debugPrint("Sharing failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error sharing file: $e")));
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
    final eventCode =
        ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
    // Force refresh by re-creating the stream
    setState(() {
      _matchesStream = ref.read(hybridRepositoryProvider).watchMatches(eventCode);
    });
    // Wait a moment for the stream to update
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final eventCode = settings[PrefKeys.eventCode] ?? "Unknown Event";
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              displacement: 80,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // M3 Large App Bar with collapsing behavior
                  SliverAppBar.medium(
            title: const Text("SushiScout 26"),
            actions: [
              // Sync status indicator
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: SyncStatusIndicator(compact: true)),
              ),
              // Search button
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: "Search Matches",
                onPressed: () async {
                  final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
                  final matches = await ref.read(hybridRepositoryProvider).getMatches(eventCode);
                  if (context.mounted) {
                    showSearch(
                      context: context,
                      delegate: MatchSearchDelegate(matches),
                    );
                  }
                },
              ),
              // Export button
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: "Export",
                onPressed: () => _showExportOptions(context, ref),
              ),
              // More options menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
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
                    case 'clear_local':
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear Local Data?'),
                          content: const Text(
                            'This will delete all locally stored matches, events, and sync queue. '
                            'This action cannot be undone. Firebase data will not be affected.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        try {
                          await ref.read(hybridRepositoryProvider).clearAllLocalData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Local data cleared successfully'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error clearing data: $e'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'trash',
                    child: ListTile(
                      leading: Icon(Icons.auto_delete_outlined),
                      title: Text("Trash"),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text("Settings"),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear_local',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                      title: Text("Clear Local Data", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingMd,
                  right: AppTheme.spacingMd,
                  bottom: AppTheme.spacingSm,
                ),
                child: Chip(
                  avatar: Icon(
                    Icons.event,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  label: Text(eventCode),
                  backgroundColor: colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                  ),
                  side: BorderSide.none,
                ),
              ),
            ),
          ),

          // Match list
          StreamBuilder<List<MatchReport>>(
            stream: _matchesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
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
                          "${snapshot.error}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final matches = snapshot.data ?? [];

              if (matches.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.ramen_dining_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(
                          "No matches scouted yet",
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        Text(
                          "Tap the button below to scout your first match",
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
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacingSm,
                        ),
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
            },
          ),

          // Bottom padding for FAB
          const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
        ],
      ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleAnimation(
        child: FloatingActionButton.extended(
          onPressed: () async {
            AppHaptics.medium();
            final eventCode =
                ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
            final programType =
                ref.read(settingsProvider)[PrefKeys.programType] ?? "FRC";
            final event = await ref.read(hybridRepositoryProvider).getEvent(eventCode);

            if (!mounted) return;

            if (event == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Event '$eventCode' not found. Defaulting to $programType.",
                  ),
                ),
              );
              final dummyEvent = Event(
                id: eventCode,
                name: "Dummy/Offline Event",
                programType: programType,
                tbaKey: eventCode,
                startDate: DateTime.now(),
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
              ref.read(settingsProvider.notifier).setProgramType(event.programType);
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ScoutingFormFactory.create(event),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text("Scout Match"),
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

    // Build summary from game data
    String summary = "";
    if (match.gameData.containsKey('auto_fuel')) {
      summary =
          "Auto: ${match.gameData['auto_fuel']} | Tele: ${match.gameData['teleop_fuel']}";
    } else if (match.gameData.containsKey('artifacts_auto')) {
      summary =
          "Auto: ${match.gameData['artifacts_auto']} | Tele: ${match.gameData['artifacts_teleop']}";
    } else {
      summary = "No data recorded";
    }

    final allianceColor = AppTheme.allianceColor(match.alliance);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
              Container(
                width: 4,
                color: allianceColor,
              ),

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
                        decoration: BoxDecoration(
                          color: allianceColor.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadius),
                        ),
                        child: Center(
                          child: Text(
                            "${match.matchNumber}",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: allianceColor,
                              fontWeight: FontWeight.bold,
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Q${match.matchNumber} \u2022 Team ${match.teamNumber}",
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        allianceColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    match.alliance,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: allianceColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
                                "Scouted by ${match.scouterName}",
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

                      // Sync status icon
                      Tooltip(
                        message:
                            match.isSynced ? "Synced" : "Pending sync",
                        child: Icon(
                          match.isSynced
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: match.isSynced
                              ? colorScheme.primary
                              : colorScheme.outline,
                          size: 20,
                        ),
                      ),
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
              title: const Text("View Details"),
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
    final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode];
    if (eventCode == null || eventCode.isEmpty) return;

    try {
      final repo = ref.read(hybridRepositoryProvider);
      await repo.trashMatch(eventCode, match.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Match moved to trash"),
            action: SnackBarAction(
              label: "Undo",
              onPressed: () async {
                try {
                  await repo.restoreMatch(eventCode, match.id);
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

/// Material 3 settings bottom sheet
class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _scouterNameCtrl = TextEditingController();
  final _eventCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
    _eventCodeCtrl.text = settings[PrefKeys.eventCode] ?? '';
  }

  @override
  void dispose() {
    _scouterNameCtrl.dispose();
    _eventCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacingSm),

            // Header
            Text(
              "Settings",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Profile section
            _SectionHeader(title: "Profile"),
            const SizedBox(height: AppTheme.spacingSm),

            TextField(
              controller: _scouterNameCtrl,
              decoration: const InputDecoration(
                labelText: "Your Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setScouterName(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            TextFormField(
              controller: _eventCodeCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: FormValidators.eventCode,
              decoration: const InputDecoration(
                labelText: "Event Code",
                prefixIcon: Icon(Icons.event_outlined),
                helperText: "e.g., 2026casj",
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setEventCode(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            Text(
              "Program Type",
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'FRC',
                  label: Text('FRC'),
                ),
                ButtonSegment(
                  value: 'FTC',
                  label: Text('FTC'),
                ),
              ],
              selected: {ref.watch(settingsProvider)[PrefKeys.programType] ?? 'FRC'},
              onSelectionChanged: (selection) {
                ref.read(settingsProvider.notifier).setProgramType(selection.first);
              },
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Appearance section
            _SectionHeader(title: "Appearance"),
            const SizedBox(height: AppTheme.spacingSm),

            _buildThemeSelector(context),

            const SizedBox(height: AppTheme.spacingMd),

            Text(
              "Color Theme",
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildColorSelector(context),

            const SizedBox(height: AppTheme.spacingXl),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme =
        ref.watch(settingsProvider)[PrefKeys.themeMode] ?? 'system';

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'system',
          icon: Icon(Icons.brightness_auto),
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: 'light',
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: 'dark',
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {currentTheme},
      onSelectionChanged: (selection) {
        ref.read(settingsProvider.notifier).setThemeMode(selection.first);
      },
    );
  }

  Widget _buildColorSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ColorSeedChip(
            label: 'Salmon',
            value: 'salmon',
            color: AppTheme.salmonSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Blue',
            value: 'blue',
            color: AppTheme.blueSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Green',
            value: 'green',
            color: AppTheme.greenSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Purple',
            value: 'purple',
            color: AppTheme.purpleSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Orange',
            value: 'orange',
            color: AppTheme.orangeSeed,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ColorSeedChip extends ConsumerWidget {
  final String label;
  final String value;
  final Color color;

  const _ColorSeedChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed =
        ref.watch(settingsProvider)[PrefKeys.colorSeed] ?? 'salmon';
    final isSelected = currentSeed == value;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      checkmarkColor: Colors.white,
      selectedColor: color,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: colorScheme.outline),
      onSelected: (selected) {
        if (selected) {
          ref.read(settingsProvider.notifier).setColorSeed(value);
        }
      },
    );
  }
}
