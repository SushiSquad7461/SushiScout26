import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/preferences.dart';
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
