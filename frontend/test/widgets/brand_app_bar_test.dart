import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:frontend/presentation/widgets/color_bar.dart';

/// Regression guard, not a reproduction: BrandAppBar declares preferredSize
/// 56 + colourBar while wrapping the 56dp bar in a SafeArea(bottom: false),
/// which looks like it should overflow once a status-bar inset is added. It
/// does not — Scaffold accounts for the inset itself — and this test pins that,
/// so a future change to either the preferredSize maths or the SafeArea fails
/// loudly instead of silently painting the bar over the body.
void main() {
  const brand = TeamBrands.fallback;
  // Any non-zero inset exercises the same path; 48 is realistic for a
  // 1280x2856 @480dpi phone.
  const statusBar = 48.0;

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
