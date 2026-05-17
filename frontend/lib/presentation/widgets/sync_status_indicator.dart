import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/animations.dart';
import '../../data/local/sync/sync_manager.dart' as manager;

/// Provider for sync status
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    // On web, Firebase handles sync automatically - always idle/success
    if (kIsWeb) {
      return const SyncStatus.success();
    }
    
    // Listen to SyncManager stream and update state
    final syncManager = ref.watch(manager.syncManagerProvider);
    syncManager.syncStream.listen((status) {
      if (status is manager.SyncInProgress) {
        state = const SyncStatus.syncing();
      } else if (status is manager.SyncCompleted) {
        state = const SyncStatus.success();
      } else if (status is manager.SyncErrorStatus) {
        state = SyncStatus.error(status.error.message);
      }
    });
    return const SyncStatus.idle();
  }

  void setStatus(SyncStatus status) => state = status;
}

/// Provider for pending sync count
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  // On web, Firebase handles sync automatically - no pending count
  if (kIsWeb) {
    return Stream.value(0);
  }
  
  final syncManager = ref.watch(manager.syncManagerProvider);
  return syncManager.pendingCountStream;
});

/// Sync status indicator widget showing online/offline state and pending changes
class SyncStatusIndicator extends ConsumerWidget {
  final bool compact;

  const SyncStatusIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On web, Firebase handles sync automatically - show simplified indicator
    if (kIsWeb) {
      return _buildWebIndicator(context);
    }

    final isOnline = ref.watch(manager.isOnlineProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine icon and color based on state
    IconData icon;
    Color color;
    String label;
    bool showBadge = false;

    if (!isOnline) {
      icon = Icons.cloud_off;
      color = colorScheme.error;
      label = 'Offline';
      showBadge = pendingCount > 0;
    } else if (syncStatus is SyncStatusSyncing) {
      icon = Icons.sync;
      color = colorScheme.primary;
      label = 'Syncing...';
    } else if (pendingCount > 0) {
      icon = Icons.cloud_upload;
      color = colorScheme.tertiary;
      label = '$pendingCount pending';
      showBadge = true;
    } else {
      icon = Icons.cloud_done;
      color = colorScheme.primary;
      label = 'Synced';
    }

    return GestureDetector(
      onTap: isOnline ? () {
        ref.read(manager.syncManagerProvider).forceSync();
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Syncing...'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } : null,
      child: Tooltip(
        message: isOnline
          ? (pendingCount > 0 ? '$pendingCount changes pending sync. Tap to sync now.' : 'All changes synced. Tap to force sync.')
          : 'Working offline - changes will sync when connection is restored',
        child: compact
          ? _buildCompactIndicator(context, icon, color, showBadge, pendingCount)
          : _buildFullIndicator(context, icon, color, label, showBadge, pendingCount),
      ),
    );
  }

  Widget _buildCompactIndicator(
    BuildContext context,
    IconData icon,
    Color color,
    bool showBadge,
    int pendingCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 20),
        if (showBadge && pendingCount > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.surface,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.error.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 16,
              ),
              child: AnimatedSwitcher(
                duration: AppAnimations.quick,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Text(
                  pendingCount > 99 ? '99+' : '$pendingCount',
                  key: ValueKey<int>(pendingCount),
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullIndicator(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    bool showBadge,
    int pendingCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 16),
              if (showBadge && pendingCount > 0)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: AppAnimations.quick,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey<String>(label),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Simplified indicator for web - Firebase handles sync automatically
  Widget _buildWebIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (compact) {
      return Icon(Icons.cloud_done, color: colorScheme.primary, size: 20);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, color: colorScheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            'Synced',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating sync status bar that appears at the top
class SyncStatusBar extends ConsumerStatefulWidget {
  const SyncStatusBar({super.key});

  @override
  ConsumerState<SyncStatusBar> createState() => _SyncStatusBarState();
}

class _SyncStatusBarState extends ConsumerState<SyncStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On web, Firebase handles sync automatically - don't show the bar
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final isOnline = ref.watch(manager.isOnlineProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

    if (isOnline && pendingCount == 0) {
      // Stop animation when nothing is pending
      _pulseController.stop();
      return const SizedBox.shrink();
    }

    // Pulse when there are pending syncs
    if (pendingCount > 0 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (pendingCount == 0) {
      _pulseController.stop();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isOnline
      ? colorScheme.tertiaryContainer
      : colorScheme.errorContainer;
    final textColor = isOnline
      ? colorScheme.onTertiaryContainer
      : colorScheme.onErrorContainer;
    final accentColor = isOnline
      ? colorScheme.tertiary
      : colorScheme.error;

    return AnimatedContainer(
      duration: AppAnimations.normal,
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress-style bar at the top that pulses
          if (pendingCount > 0)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.6 + _pulseAnimation.value * 0.4),
                        accentColor.withValues(alpha: 0.3),
                      ],
                      stops: [
                        0.0,
                        0.3 + _pulseAnimation.value * 0.4,
                        1.0,
                      ],
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.cloud_upload : Icons.cloud_off,
                    size: 16,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppAnimations.quick,
                      child: Text(
                        isOnline
                          ? '$pendingCount ${pendingCount == 1 ? 'change' : 'changes'} pending sync'
                          : 'Working offline - changes will sync when connected',
                        key: ValueKey<String>('$isOnline-$pendingCount'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (isOnline)
                    TextButton.icon(
                      onPressed: () => _triggerSync(),
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync Now'),
                      style: TextButton.styleFrom(
                        foregroundColor: textColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerSync() {
    ref.read(manager.syncManagerProvider).forceSync();
    AppHaptics.medium();
  }
}

/// Pulse animation for syncing indicator
class SyncingPulseIndicator extends StatefulWidget {
  const SyncingPulseIndicator({super.key});

  @override
  State<SyncingPulseIndicator> createState() => _SyncingPulseIndicatorState();
}

class _SyncingPulseIndicatorState extends State<SyncingPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(Icons.sync, color: colorScheme.primary),
        );
      },
    );
  }
}

/// Sealed class for sync status
sealed class SyncStatus {
  const SyncStatus();

  const factory SyncStatus.idle() = SyncStatusIdle;
  const factory SyncStatus.syncing() = SyncStatusSyncing;
  const factory SyncStatus.error(String message) = SyncStatusError;
  const factory SyncStatus.success() = SyncStatusSuccess;
}

class SyncStatusIdle extends SyncStatus {
  const SyncStatusIdle();
}

class SyncStatusSyncing extends SyncStatus {
  const SyncStatusSyncing();
}

class SyncStatusError extends SyncStatus {
  final String message;
  const SyncStatusError(this.message);
}

class SyncStatusSuccess extends SyncStatus {
  const SyncStatusSuccess();
}
