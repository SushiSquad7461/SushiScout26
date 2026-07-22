import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/widgets/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      );

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
}
