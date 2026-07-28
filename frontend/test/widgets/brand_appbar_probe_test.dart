import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:frontend/presentation/widgets/color_bar.dart';

/// BrandAppBar declares preferredSize 56 + colourBar, but wraps the 56dp bar in
/// a SafeArea(bottom: false), which adds the status-bar inset on a real device.
/// Scaffold allots exactly preferredSize.height, so the bar overflows into the
/// body. Reproduced with the reporting device's status bar inset.
void main() {
  const brand = TeamBrands.fallback;
  const statusBar = 48.0; // realistic for a 1280x2856 @480dpi phone

  testWidgets('BrandAppBar fits its preferredSize under a status bar inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1280, 2856);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: statusBar)),
          child: Scaffold(
            appBar: BrandAppBar(brand: brand, title: 'Settings'),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'BrandAppBar overflowed its allotted preferredSize',
    );
  });
}
