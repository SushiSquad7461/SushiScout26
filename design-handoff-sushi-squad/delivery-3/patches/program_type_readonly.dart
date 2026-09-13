/// Program type belongs to the EVENT, not the scout.
///
/// Paste-in patch for `settings_screen.dart` and `event_providers.dart`.
/// DO NOT replace either file wholesale — the current `settings_screen.dart`
/// contains three layout fixes (IntrinsicHeight on the brand row, Wrap on the
/// export buttons, and the removed placeholder tile) that must survive.

// ─────────────────────────────────────────────────────────────────────────────
// 1. ADD to `lib/presentation/providers/event_providers.dart`
// ─────────────────────────────────────────────────────────────────────────────
//
// Add these two imports at the top:
//
//     import '../../data/models/event.dart';
//     import '../../data/repositories/providers.dart';
//
// Then append:

/// The event document for the current event id, or `null` when none exists yet.
///
/// `programType` is a property of the event, not of the scout: `dashboard.dart`
/// reads this document on every Scout Match tap and, when it exists, overwrites
/// the scout's `programType` with the event's. Settings watches this so it can
/// state that fact rather than offer a control that silently reverts.
///
/// Failures resolve to `null` rather than propagating. Offline or
/// permission-denied means "no event document known", which leaves the control
/// editable — the safe direction, since a wrong lock would strand a scout with
/// no way to pick their program.
final currentEventProvider = FutureProvider<Event?>((ref) async {
  final eventId = ref.watch(currentEventIdProvider);
  try {
    return await ref
        .read(firestoreRepositoryProvider)
        .getEvent(eventId)
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. REPLACE in `lib/presentation/screens/settings_screen.dart`
// ─────────────────────────────────────────────────────────────────────────────
//
// Replace this whole block in `build` — the "Program Type" Text, the SizedBox,
// and the SegmentedButton<String> that follows it:
//
//     Text(
//       "Program Type",
//       style: AppTheme.label(...),
//     ),
//     const SizedBox(height: AppTheme.spacingSm),
//     SegmentedButton<String>(
//       segments: const [
//         ButtonSegment(value: 'FRC', label: Text('FRC')),
//         ButtonSegment(value: 'FTC', label: Text('FTC')),
//       ],
//       selected: {...},
//       onSelectionChanged: (selection) {...},
//     ),
//
// with a single call:

            _buildProgramTypeSelector(context),

// ─────────────────────────────────────────────────────────────────────────────
// 3. ADD as a method on `_SettingsScreenState`
// ─────────────────────────────────────────────────────────────────────────────

  /// Program type: editable only while the event document doesn't exist yet.
  ///
  /// `dashboard.dart` lets the event document win over this preference, so an
  /// always-editable control lies to the scout — pick FTC against an FRC event
  /// and it reverts on the next Scout Match tap, with no feedback. That is the
  /// actual bug behind "FTC support doesn't work".
  ///
  /// While no document exists, the choice is real: the first saved match creates
  /// the event from this value (`FirestoreRepository._getOrCreateEvent`, which
  /// takes the match's `programType` as its fallback). Once the document exists,
  /// this becomes a read-only statement of what the event *is*.
  Widget _buildProgramTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);

    final scoutValue =
        ref.watch(settingsProvider)[PrefKeys.programType] ?? 'FRC';
    final eventCode = ref.watch(currentEventCodeProvider);

    // valueOrNull, not `.when`: a spinner here would flash on every open, and
    // "still loading" and "no document" want the same treatment — editable.
    final event = ref.watch(currentEventProvider).valueOrNull;
    final locked = event != null;
    final value = locked ? event.programType : scoutValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Program Type",
          style: AppTheme.label(
            brand,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),

        if (locked)
          // A solid block, per the brand's geometry — this is a value, not a
          // control, and it should not look tappable.
          Row(
            children: [
              ColoredBox(
                color: colorScheme.onSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm + 2,
                  ),
                  child: Text(
                    value,
                    style: AppTheme.display(
                      brand,
                      size: 17,
                      letterSpacing: 0.1,
                      color: colorScheme.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'set by event $eventCode',
                  style: AppTheme.helper(
                    brand,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        else
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FRC', label: Text('FRC')),
              ButtonSegment(value: 'FTC', label: Text('FTC')),
            ],
            selected: {value},
            onSelectionChanged: (selection) {
              ref
                  .read(settingsProvider.notifier)
                  .setProgramType(selection.first);
            },
          ),

        const SizedBox(height: AppTheme.spacingXs),
        Text(
          locked
              ? 'An event is one program. To scout the other, enter a new event code above.'
              : "No matches yet for $eventCode — the first one you save creates it as $value.",
          style: AppTheme.helper(brand, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
