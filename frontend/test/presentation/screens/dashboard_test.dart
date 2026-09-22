import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/providers/event_providers.dart';
import 'package:frontend/presentation/screens/dashboard.dart';
import 'package:frontend/presentation/widgets/connection_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows "start scouting" as the primary action label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firestoreRepositoryProvider.overrideWithValue(
            FirestoreRepository(fake, teamId: 'teamA'),
          ),
          currentTeamIdProvider.overrideWithValue('teamA'),
          currentEventIdProvider.overrideWithValue('teamA_2026test'),
          matchesViewProvider.overrideWith(
            (ref) => Stream.value(
              const MatchesView(matches: [], isFromCache: false),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('start scouting'), findsOneWidget);
    expect(find.text('scout match'), findsNothing);
  });
}
