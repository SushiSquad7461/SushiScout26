import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/team.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/providers/event_providers.dart';
import 'package:frontend/presentation/widgets/settings_sheet.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_sheet_test.mocks.dart';

@GenerateNiceMocks([MockSpec<TeamRepository>()])
void main() {
  late MockTeamRepository mockTeamRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTeamRepository = MockTeamRepository();
    when(mockTeamRepository.getTeamSettings(any))
        .thenAnswer((_) async => null);
  });

  Widget wrap(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      );

  // The DraggableScrollableSheet lays out its content taller than the
  // default 800x600 test surface, which pushes the Save/Backfill buttons
  // below the visible viewport and makes tester.tap() miss them. Grow the
  // surface so every control in the sheet is reachable without scrolling.
  Future<void> growViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<List<Override>> baseOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      isTeamAdminProvider.overrideWith((ref) => true),
      currentTeamIdProvider.overrideWith((ref) => 'team1'),
      currentEventIdProvider.overrideWith((ref) => 'team1_2026test'),
      teamRepositoryProvider.overrideWith((ref) => mockTeamRepository),
    ];
  }

  testWidgets('shows the Sheets export section for a team admin',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(wrap([
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      isTeamAdminProvider.overrideWith((ref) => true),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsOneWidget);
  });

  testWidgets('hides the Sheets export section for a non-admin member',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(wrap([
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      isTeamAdminProvider.overrideWith((ref) => false),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsNothing);
  });

  testWidgets(
      'surfaces the service-account address verbatim when save fails '
      'with failed-precondition', (tester) async {
    await growViewport(tester);
    const serviceAccountMessage =
        "Can't open that sheet. Share it as Editor with "
        "sushiscout-sync@sushiscout26.iam.gserviceaccount.com, then try again.";
    when(mockTeamRepository.setTeamSheet(
      teamId: anyNamed('teamId'),
      sheetId: anyNamed('sheetId'),
    )).thenThrow(FirebaseFunctionsException(
      code: 'failed-precondition',
      message: serviceAccountMessage,
    ));

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Google Sheet link or id'),
        'https://docs.google.com/spreadsheets/d/abc123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
          'sushiscout-sync@sushiscout26.iam.gserviceaccount.com'),
      findsOneWidget,
    );
    // The technical FirebaseFunctionsException prefix must not leak.
    expect(find.textContaining('[firebase_functions/'), findsNothing);
  });

  testWidgets('shows connected state after a successful save',
      (tester) async {
    await growViewport(tester);
    when(mockTeamRepository.setTeamSheet(
      teamId: anyNamed('teamId'),
      sheetId: anyNamed('sheetId'),
    )).thenAnswer((_) async => 'abc123');

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Google Sheet link or id'),
        'abc123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('backfill success shows completion snackbar', (tester) async {
    await growViewport(tester);
    when(mockTeamRepository.getTeamSettings(any)).thenAnswer((_) async =>
        TeamSettings(
          teamId: 'team1',
          googleSheetId: 'abc123',
          createdBy: 'alice',
          createdAt: DateTime(2026, 1, 1),
        ));
    when(mockTeamRepository.backfillEventToSheets(eventId: anyNamed('eventId')))
        .thenAnswer((_) async => {'synced': 5});

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Backfill this event'));
    await tester.pumpAndSettle();

    expect(find.text('Backfill complete'), findsOneWidget);
  });

  testWidgets('backfill failure shows failure snackbar', (tester) async {
    await growViewport(tester);
    when(mockTeamRepository.getTeamSettings(any)).thenAnswer((_) async =>
        TeamSettings(
          teamId: 'team1',
          googleSheetId: 'abc123',
          createdBy: 'alice',
          createdAt: DateTime(2026, 1, 1),
        ));
    when(mockTeamRepository.backfillEventToSheets(eventId: anyNamed('eventId')))
        .thenThrow(Exception('network error'));

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Backfill this event'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Backfill failed'), findsOneWidget);
  });

  testWidgets('Backfill button is disabled when no sheet id is configured',
      (tester) async {
    await growViewport(tester);
    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Backfill this event'));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'shows a distinct status when loading the sheet fails, not '
      '"Not configured"', (tester) async {
    when(mockTeamRepository.getTeamSettings(any))
        .thenAnswer((_) async => throw Exception('permission-denied'));

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check export status"), findsOneWidget);
    expect(find.text("Not configured — matches aren't being exported."),
        findsNothing);
  });
}
