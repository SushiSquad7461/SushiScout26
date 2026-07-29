import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event.dart';
import '../../data/local/preferences.dart';
import '../../data/repositories/providers.dart';
import 'auth_provider.dart';

/// Composes the team-scoped event id used for `events` and `matches`.
///
/// Returns `"${teamId}_$eventCode"`. When no active team is known (pre-team
/// selection) it returns the bare code — no team-scoped write happens in
/// that state, so there is no cross-team leak.
String composeEventId(String? teamId, String eventCode) {
  if (teamId == null || teamId.isEmpty) return eventCode;
  return '${teamId}_$eventCode';
}

/// The raw event code the user entered. Use this for the PUBLIC schedule
/// and TBA/FTC lookups — those collections are keyed by raw code, not the
/// team-scoped composite.
final currentEventCodeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings[PrefKeys.eventCode] ?? '2026TEST';
});

/// The team-scoped composite event id. Use this for all `events`/`matches`
/// repository operations.
final currentEventIdProvider = Provider<String>((ref) {
  final teamId = ref.watch(currentTeamIdProvider);
  final eventCode = ref.watch(currentEventCodeProvider);
  return composeEventId(teamId, eventCode);
});

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
