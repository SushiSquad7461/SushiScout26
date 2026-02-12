import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/preferences.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/scouting_repository.dart';
import '../theme/app_theme.dart';

/// Material 3 styled trash/recovery screen.
class TrashScreen extends ConsumerStatefulWidget {
  final ScoutingRepository repository;
  const TrashScreen({super.key, required this.repository});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  late Stream<List<MatchReport>> _trashStream;

  @override
  void initState() {
    super.initState();
    final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode] ?? "";
    _trashStream = widget.repository.watchTrash(eventCode);
  }

  Future<void> _restore(MatchReport match) async {
    final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode] ?? "";
    await widget.repository.restoreMatch(eventCode, match.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Restored Match ${match.matchNumber}"),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () async {
              await widget.repository.trashMatch(eventCode, match.id);
            },
          ),
        ),
      );
    }
  }

  Future<void> _deleteForever(MatchReport match) async {
    final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode] ?? "";
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

    if (confirm == true) {
      await widget.repository.deleteMatch(eventCode, match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permanently deleted match.")),
        );
      }
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

          return ListView.builder(
            itemCount: matches.length,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            itemBuilder: (context, index) {
              final match = matches[index];
              return _TrashCard(
                match: match,
                onRestore: () => _restore(match),
                onDelete: () => _deleteForever(match),
              );
            },
          );
        },
      ),
    );
  }
}

/// Trash card with swipe-to-restore and delete actions
class _TrashCard extends StatelessWidget {
  final MatchReport match;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashCard({
    required this.match,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allianceColor = match.alliance == 'Red' ? Colors.red : Colors.blue;

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
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onRestore();
            return false; // Don't actually dismiss, show snackbar instead
          } else {
            onDelete();
            return false;
          }
        },
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
