import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';

/// Diagnostic probe for the "garbled" settings screen, at the reporting
/// device's real logical size (1280x2856 @480dpi => 427x952).
void main() {
  const brand = TeamBrands.fallback;
  const phone = Size(426.7, 952.0);

  Future<void> pumpAt(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1280, 2856);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: BrandScope(
          brand: brand,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Sheets export button row fits the phone width', (tester) async {
    await pumpAt(
      tester,
      Wrap(
        spacing: AppTheme.spacingSm,
        runSpacing: AppTheme.spacingSm,
        children: [
          FilledButton(onPressed: () {}, child: const Text('Save')),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Backfill this event'),
          ),
        ],
      ),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'overflowed at width ${phone.width}',
    );
  });

  testWidgets('Brand selector row fits the phone width', (tester) async {
    await pumpAt(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in TeamBrands.all) ...[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all()),
                child: SizedBox(height: 90, child: Text(b.name)),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
          ],
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: const SizedBox(
                height: 90,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.add), Text('add a team')],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
