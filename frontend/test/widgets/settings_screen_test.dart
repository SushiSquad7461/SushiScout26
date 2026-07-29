import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/event.dart';
import 'package:frontend/data/models/team.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/providers/event_providers.dart';
import 'package:frontend/presentation/screens/settings_screen.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen_test.mocks.dart';

/// Behavioural coverage for `SettingsScreen`, ported from the deleted
/// `settings_sheet_test.dart` when the bottom sheet became a pushed route.
/// The container changed; the behaviour under test did not — admin gating on
/// the Sheets export section, the verbatim service-account error, the backfill
/// paths, and the load-failure status are all security- or data-adjacent.
///
/// The final test is the layout guard: the brand picker once used
/// CrossAxisAlignment.stretch inside a SingleChildScrollView, which threw
/// "BoxConstraints forces an infinite height" and left every widget below it
/// unlaid-out, painting them stacked at the top of the screen.
@GenerateNiceMocks([MockSpec<TeamRepository>()])
void main() {
  const brand = TeamBrands.fallback;
  late MockTeamRepository mockTeamRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTeamRepository = MockTeamRepository();
    when(mockTeamRepository.getTeamSettings(any)).thenAnswer((_) async => null);
  });

  Widget wrap(List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(brand),
      home: const BrandScope(brand: brand, child: SettingsScreen()),
    ),
  );

  // SettingsScreen scrolls, and its Scaffold spends height on the app bar and
  // the Done action bar, so the Save/Backfill controls sit below the default
  // 800x600 test surface and tester.tap() would miss them. Grow the surface so
  // every control is reachable without scrolling.
  Future<void> growViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<Override> overridesWith({required bool isAdmin}) => [
    isTeamAdminProvider.overrideWith((ref) => isAdmin),
    currentTeamIdProvider.overrideWith((ref) => 'team1'),
    currentEventIdProvider.overrideWith((ref) => 'team1_2026test'),
    teamRepositoryProvider.overrideWith((ref) => mockTeamRepository),
    userTeamsProvider.overrideWith(
      (ref) async => [
        Team(
          id: 'team1',
          name: 'Team One',
          inviteCode: 'ABC123',
          createdBy: 'alice',
          createdAt: DateTime(2026, 1, 1),
          memberCount: 4,
        ),
      ],
    ),
  ];

  Future<List<Override>> baseOverrides({bool isAdmin = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      ...overridesWith(isAdmin: isAdmin),
    ];
  }

  TeamSettings connectedSettings() => TeamSettings(
    teamId: 'team1',
    googleSheetId: 'abc123',
    createdBy: 'alice',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets('shows the Sheets export section for a team admin', (
    tester,
  ) async {
    await growViewport(tester);
    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsOneWidget);
  });

  testWidgets('hides the Sheets export section for a non-admin member', (
    tester,
  ) async {
    await growViewport(tester);
    await tester.pumpWidget(wrap(await baseOverrides(isAdmin: false)));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsNothing);
  });

  testWidgets(
    'surfaces the service-account address verbatim when save fails '
    'with failed-precondition',
    (tester) async {
      await growViewport(tester);
      const serviceAccountMessage =
          "Can't open that sheet. Share it as Editor with "
          "sushiscout-sync@sushiscout26.iam.gserviceaccount.com, then try again.";
      when(
        mockTeamRepository.setTeamSheet(
          teamId: anyNamed('teamId'),
          sheetId: anyNamed('sheetId'),
        ),
      ).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: serviceAccountMessage,
        ),
      );

      await tester.pumpWidget(wrap(await baseOverrides()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Google Sheet link or id'),
        'https://docs.google.com/spreadsheets/d/abc123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'sushiscout-sync@sushiscout26.iam.gserviceaccount.com',
        ),
        findsOneWidget,
      );
      // The technical FirebaseFunctionsException prefix must not leak.
      expect(find.textContaining('[firebase_functions/'), findsNothing);
    },
  );

  testWidgets(
    'service-account address is rendered without a line/overflow limit '
    'that would truncate it',
    (tester) async {
      // find.textContaining above passes even when the on-screen text is
      // ellipsized, because it inspects widget data, not layout — it would NOT
      // have caught the original bug. This pins the actual rendering
      // constraint: the message must live in a widget that isn't configured to
      // clip it, i.e. outside InputDecoration.errorText.
      await growViewport(tester);
      const serviceAccountMessage =
          "Can't open that sheet. Share it as Editor with "
          "sushiscout-sync@sushiscout26.iam.gserviceaccount.com, then try again.";
      when(
        mockTeamRepository.setTeamSheet(
          teamId: anyNamed('teamId'),
          sheetId: anyNamed('sheetId'),
        ),
      ).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: serviceAccountMessage,
        ),
      );

      await tester.pumpWidget(wrap(await baseOverrides()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Google Sheet link or id'),
        'https://docs.google.com/spreadsheets/d/abc123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final errorFinder = find.widgetWithText(
        SelectableText,
        serviceAccountMessage,
      );
      expect(errorFinder, findsOneWidget);
      final selectable = tester.widget<SelectableText>(errorFinder);
      expect(selectable.maxLines, isNull);

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Google Sheet link or id'),
      );
      expect(textField.decoration?.errorText, isNull);
    },
  );

  testWidgets('Connected status links to the spreadsheet', (tester) async {
    await growViewport(tester);
    when(
      mockTeamRepository.getTeamSettings(any),
    ).thenAnswer((_) async => connectedSettings());

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(
      find.textContaining('https://docs.google.com/spreadsheets/d/abc123'),
      findsOneWidget,
    );
  });

  testWidgets('shows connected state after a successful save', (tester) async {
    await growViewport(tester);
    when(
      mockTeamRepository.setTeamSheet(
        teamId: anyNamed('teamId'),
        sheetId: anyNamed('sheetId'),
      ),
    ).thenAnswer((_) async => 'abc123');

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Google Sheet link or id'),
      'abc123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('backfill success shows completion snackbar', (tester) async {
    await growViewport(tester);
    when(
      mockTeamRepository.getTeamSettings(any),
    ).thenAnswer((_) async => connectedSettings());
    when(
      mockTeamRepository.backfillEventToSheets(eventId: anyNamed('eventId')),
    ).thenAnswer((_) async => {'synced': 5});

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Backfill this event'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backfill complete'), findsOneWidget);
  });

  testWidgets('backfill failure shows failure snackbar', (tester) async {
    await growViewport(tester);
    when(
      mockTeamRepository.getTeamSettings(any),
    ).thenAnswer((_) async => connectedSettings());
    when(
      mockTeamRepository.backfillEventToSheets(eventId: anyNamed('eventId')),
    ).thenThrow(Exception('network error'));

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Backfill this event'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Backfill failed'), findsOneWidget);
  });

  testWidgets('Backfill button is disabled when no sheet id is configured', (
    tester,
  ) async {
    await growViewport(tester);
    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Backfill this event'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'shows a distinct status when loading the sheet fails, not '
    '"Not configured"',
    (tester) async {
      await growViewport(tester);
      when(
        mockTeamRepository.getTeamSettings(any),
      ).thenAnswer((_) async => throw Exception('permission-denied'));

      await tester.pumpWidget(wrap(await baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't check export status"), findsOneWidget);
      expect(
        find.text("Not configured — matches aren't being exported."),
        findsNothing,
      );
    },
  );

  testWidgets('shows the Team section', (tester) async {
    await growViewport(tester);
    when(mockTeamRepository.getUserTeams(any)).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Team'), findsOneWidget);
    expect(find.textContaining('ABC123'), findsOneWidget);
  });

  testWidgets('lays out at phone width without throwing a layout error', (
    tester,
  ) async {
    // The reporting device: 1280x2856 @480dpi => 427x952 logical. Drives the
    // real screen, so a reintroduced infinite-height constraint fails here.
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1280, 2856);
    addTearDown(tester.view.reset);

    when(
      mockTeamRepository.getTeamSettings(any),
    ).thenAnswer((_) async => connectedSettings());

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'settings screen threw during layout',
    );
  });

  // Program Type is a property of the EVENT, not the scout: dashboard.dart
  // overwrites the preference with the event document's programType on every
  // Scout Match tap. An always-editable SegmentedButton therefore lied — pick
  // FTC against an FRC event and it silently reverted. The control must only
  // offer a choice while that choice is still real.
  group('program type', () {
    Event frcEvent() => Event(
      id: 'team1_2026test',
      name: '2026TEST',
      programType: 'FRC',
      tbaKey: '2026test',
      startDate: DateTime(2026, 1, 1),
      teamId: 'team1',
    );

    testWidgets('is a read-only block once the event document exists', (
      tester,
    ) async {
      await growViewport(tester);
      await tester.pumpWidget(
        wrap([
          ...await baseOverrides(),
          currentEventProvider.overrideWith((ref) async => frcEvent()),
        ]),
      );
      await tester.pumpAndSettle();

      // Only the Appearance selector is left — the program-type one is gone.
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.textContaining('set by event'), findsOneWidget);
      expect(
        find.textContaining('An event is one program'),
        findsOneWidget,
      );
    });

    testWidgets('stays editable when no event document exists yet', (
      tester,
    ) async {
      await growViewport(tester);
      await tester.pumpWidget(
        wrap([
          ...await baseOverrides(),
          currentEventProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('set by event'), findsNothing);
      expect(find.textContaining('the first one you save creates it'),
          findsOneWidget);
      expect(find.text('FRC'), findsWidgets);
      expect(find.text('FTC'), findsWidgets);
    });

    testWidgets('a failed event load leaves the control editable', (
      tester,
    ) async {
      // A wrong lock would strand an offline scout with no way to pick their
      // program; a wrong unlock only means the document wins, as it does today.
      await growViewport(tester);
      await tester.pumpWidget(
        wrap([
          ...await baseOverrides(),
          currentEventProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('set by event'), findsNothing);
    });
  });
}
