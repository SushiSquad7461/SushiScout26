import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/event.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/screens/frc_rebuilt_form.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _eventId = 'teamA_2026test';

final _event = Event(
  id: _eventId,
  name: '2026 Test Event',
  programType: 'FRC',
  tbaKey: '2026test',
  startDate: DateTime(2026, 7, 1),
  teamId: 'teamA',
);

/// Simulates the phone's hardware back button — the platform callback a
/// real device sends — as distinct from tapping an AppBar's back chevron.
/// `PopScope` intercepts this route-pop callback, which is exactly what
/// this task wires up.
Future<void> _pressHardwareBackButton(WidgetTester tester) async {
  final widgetsAppState =
      tester.state<State>(find.byType(WidgetsApp)) as dynamic;
  await widgetsAppState.didPopRoute();
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  // A single outer MaterialApp/Navigator with a button that pushes the form
  // as a route — needed so the hardware-back simulation pops the SAME
  // Navigator the form's PopScope sits in, rather than nesting a second,
  // independent MaterialApp/Navigator inside a pushed route.
  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(AppTheme.brandFor(null)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FrcRebuiltForm(eventId: _eventId, event: _event),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('FrcRebuiltForm back navigation', () {
    testWidgets(
      'the hardware back button moves to the previous page instead of closing the form',
      (tester) async {
        await tester.pumpWidget(await buildApp());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'scouter name'),
          'Test Scouter',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'match #'),
          '1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'team #'),
          '4198',
        );
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
        expect(find.text('autonomous'), findsOneWidget);

        await _pressHardwareBackButton(tester);
        await tester.pumpAndSettle();

        expect(find.text('setup'), findsOneWidget);
        expect(find.byType(FrcRebuiltForm), findsOneWidget);
      },
    );

    testWidgets('the hardware back button exits the form from the first page', (
      tester,
    ) async {
      await tester.pumpWidget(await buildApp());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(FrcRebuiltForm), findsOneWidget);

      await _pressHardwareBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.byType(FrcRebuiltForm), findsNothing);
    });
  });

  group('FrcRebuiltForm setup validation messages', () {
    testWidgets('the whole match number error renders without truncation', (
      tester,
    ) async {
      await tester.pumpWidget(await buildApp());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'match #'),
        '300',
      );
      await tester.pumpAndSettle();

      final error = find.text('Match number can be at most 200');
      expect(error, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('the whole team number error renders without truncation', (
      tester,
    ) async {
      await tester.pumpWidget(await buildApp());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'team #'), '0');
      await tester.pumpAndSettle();

      final error = find.text('Team number must be at least 1');
      expect(error, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        isFalse,
      );
    });
  });
}
