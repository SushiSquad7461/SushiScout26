import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/providers.dart';
import '../providers/event_providers.dart';

/// What the app can honestly say about its connection.
///
/// Derived from Firestore snapshot metadata rather than link-layer state:
/// `connectivity_plus` reports "wifi" whenever the device is associated with an
/// access point, which is true on a captive portal that blocks every request.
class ConnectionStatus {
  final bool isOffline;
  final int pendingCount;
  final bool hasError;

  const ConnectionStatus({
    required this.isOffline,
    required this.pendingCount,
    this.hasError = false,
  });

  bool get isFullySynced => !hasError && !isOffline && pendingCount == 0;

  String get message {
    final noun = pendingCount == 1 ? 'report' : 'reports';
    if (hasError) {
      return "Can't reach the server — recent reports may not be uploaded";
    }
    if (isOffline) {
      if (pendingCount == 0) return 'Offline — showing saved data';
      return 'Offline — $pendingCount $noun saved on this device';
    }
    if (pendingCount == 0) return 'All reports uploaded';
    return 'Uploading $pendingCount $noun…';
  }
}

ConnectionStatus connectionStatusFrom({
  required bool isFromCache,
  required int pendingCount,
}) {
  return ConnectionStatus(isOffline: isFromCache, pendingCount: pendingCount);
}

/// The single matches subscription for the active event. Both the match list
/// and the connection status read from this, so only one listener is open.
final matchesViewProvider = StreamProvider<MatchesView>((ref) {
  final eventId = ref.watch(currentEventIdProvider);
  return ref.watch(firestoreRepositoryProvider).watchMatchesView(eventId);
});

/// Connection status for the active event.
///
/// Known bound: pending writes are counted only across the current event's
/// matches, because that is the query we already subscribe to. A report saved
/// against a different event is not counted. Scouts work one event at a time.
final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final view = ref.watch(matchesViewProvider);
  return view.when(
    data: (v) => connectionStatusFrom(
      isFromCache: v.isFromCache,
      pendingCount: v.matches.where((m) => !m.isSynced).length,
    ),
    loading: () => const ConnectionStatus(isOffline: false, pendingCount: 0),
    error: (error, stackTrace) => const ConnectionStatus(
      isOffline: false,
      pendingCount: 0,
      hasError: true,
    ),
  );
});

/// A full-width bar shown above the dashboard content. Hidden entirely when
/// everything is uploaded — no chrome for the happy path.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    if (status.isFullySynced) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final background = (status.isOffline || status.hasError)
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = (status.isOffline || status.hasError)
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                status.hasError
                    ? Icons.sync_problem
                    : status.isOffline
                        ? Icons.cloud_off
                        : Icons.cloud_upload,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact indicator for the app bar. Shows nothing when fully synced.
class ConnectionStatusChip extends ConsumerWidget {
  final bool compact;

  const ConnectionStatusChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    if (status.isFullySynced) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final color = (status.isOffline || status.hasError)
        ? colorScheme.error
        : colorScheme.primary;
    final icon = status.hasError
        ? Icons.sync_problem
        : status.isOffline
            ? Icons.cloud_off
            : Icons.cloud_upload;

    if (compact) {
      return Tooltip(
        message: status.message,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (status.pendingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${status.pendingCount}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          status.message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
