import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/match_report.dart';
import '../theme/app_theme.dart';

import '../../data/repositories/hybrid_repository.dart';
import '../providers/event_providers.dart';

/// Material 3 styled trash/recovery screen.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  late Stream<List<MatchReport>> _trashStream;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final eventId = ref.read(currentEventIdProvider);
    _trashStream = ref.read(hybridRepositoryProvider).watchTrash(eventId);
  }

  Future<void> _restore(MatchReport match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.restore, color: Colors.green, size: 48),
        title: const Text("Restore Match?"),
        content: Text(
          "Match ${match.matchNumber} (Team ${match.teamNumber}) will be moved back to your match list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final eventId = ref.read(currentEventIdProvider);
      final repo = ref.read(hybridRepositoryProvider);
      await repo.restoreMatch(eventId, match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Restored Match ${match.matchNumber}"),
            action: SnackBarAction(
              label: "Undo",
              onPressed: () async {
                await repo.trashMatch(eventId, match.id);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteForever(MatchReport match) async {
    final eventId = ref.read(currentEventIdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: colorScheme.error, size: 48),
        title: const Text("Delete Forever?"),
        content: const Text(
          "This action cannot be undone. The match data will be permanently removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(hybridRepositoryProvider).deleteMatch(eventId, match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permanently deleted match.")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Trash")),
      body: StreamBuilder<List<MatchReport>>(
        stream: _trashStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    "Error loading trash",
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
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    "Trash is empty",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    "Deleted matches will appear here",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                itemCount: matches.length,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _TrashCard(
                    match: match,
                    onRestore: _loading ? null : () => _restore(match),
                    onDelete: _loading ? null : () => _deleteForever(match),
                    enabled: !_loading,
                  );
                },
              ),
              if (_loading)
                Positioned(
                  top: AppTheme.spacingSm,
                  left: 0,
                  right: 0,
                  child: const Center(child: LinearProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Trash card with swipe-to-restore and delete actions
class _TrashCard extends StatelessWidget {
  final MatchReport match;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final bool enabled;

  const _TrashCard({
    required this.match,
    required this.onRestore,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allianceColor = AppTheme.allianceColor(match.alliance);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Dismissible(
        key: Key(match.id),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: const Icon(Icons.restore, color: Colors.white, size: 28),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: const Icon(
            Icons.delete_forever,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: enabled
            ? (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  onRestore?.call();
                } else {
                  onDelete?.call();
                }
                return false; // Don't actually dismiss; actions handle UI
              }
            : (_) async => false,
        child: Card(
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
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
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
                    children: [
                      Text(
                        "Team ${match.teamNumber}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Scouted by ${match.scouterName}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore),
                      color: Colors.green,
                      tooltip: "Restore",
                      onPressed: onRestore,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: colorScheme.error,
                      tooltip: "Delete Forever",
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
