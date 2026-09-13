import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/providers.dart';
import '../providers/event_providers.dart';
import '../../data/models/match_report.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import 'color_bar.dart';

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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The event row that sits under the brand band on the dashboard: the active
/// event code on the left, a running "N synced · M pending" on the right.
///
/// This is the design's persistent counter, and it is deliberately NOT the
/// same thing as [ConnectionStatusBar] — that bar is a transient alert that
/// hides itself on the happy path, so with everything uploaded the scout saw
/// no confirmation at all that their reports had landed.
class EventSyncRow extends ConsumerWidget {
  final TeamBrand brand;
  final String eventCode;

  const EventSyncRow({super.key, required this.brand, required this.eventCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final view = ref.watch(matchesViewProvider);
    // Reuse connectionStatusProvider's count (and its error state) instead of
    // re-filtering the match list here — a stream failure must show as a
    // failure, not as a stale "N synced" carried over from the last good
    // snapshot.
    final status = ref.watch(connectionStatusProvider);
    final matches = view.value?.matches ?? const <MatchReport>[];
    final pending = status.pendingCount;
    final synced = matches.length - pending;
    final countLabel = status.hasError
        ? "can't reach server"
        : (pending == 0
              ? '$synced synced'
              : '$synced synced · $pending pending');

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              eventCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label(brand, color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          SyncSquare(brand: brand, synced: !status.hasError && pending == 0),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            countLabel,
            style: AppTheme.helper(
              brand,
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
