import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:frontend/presentation/widgets/color_bar.dart';

/// Diagnostic probe: is the colour bar actually painting at a non-zero size
/// inside BrandEventBar and BrandActionBar? Both render a ColorBar in code but
/// neither showed one on device.
void main() {
  const brand = TeamBrands.fallback;

  testWidgets('ColorBar standalone has non-zero size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: const Scaffold(body: ColorBar(brand: brand)),
      ),
    );
    final size = tester.getSize(find.byType(ColorBar));
    expect(size.height, greaterThan(0), reason: 'height was ${size.height}');
    expect(size.width, greaterThan(0), reason: 'width was ${size.width}');
  });

  // The outer SizedBox reporting height 10 is NOT enough: a childless
  // ColoredBox under a Row's default (loose) cross-axis constraints collapses
  // to zero height and paints nothing, which is exactly what shipped.
  testWidgets('each ColorBar segment actually fills the bar height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: const Scaffold(body: ColorBar(brand: brand)),
      ),
    );
    final segments = find.descendant(
      of: find.byType(ColorBar),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(brand.accents.length));
    for (var i = 0; i < brand.accents.length; i++) {
      final s = tester.getSize(segments.at(i));
      expect(
        s.height,
        AppTheme.colorBarThickness,
        reason: 'segment $i painted at height ${s.height}',
      );
      expect(s.width, greaterThan(0), reason: 'segment $i width ${s.width}');
    }
  });

  testWidgets('BrandEventBar renders a ColorBar with non-zero size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('SushiScout 26'),
            bottom: const BrandEventBar(brand: brand, eventCode: '2026test'),
          ),
        ),
      ),
    );
    expect(find.byType(ColorBar), findsOneWidget);
    final size = tester.getSize(find.byType(ColorBar));
    expect(size.height, greaterThan(0), reason: 'height was ${size.height}');
    expect(size.width, greaterThan(0), reason: 'width was ${size.width}');
  });

  testWidgets('SliverAppBar.medium (as dashboard uses it) shows the ColorBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.medium(
                title: const Text('SushiScout 26'),
                bottom: const BrandEventBar(
                  brand: brand,
                  eventCode: '2026test',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ColorBar), findsOneWidget);
    final size = tester.getSize(find.byType(ColorBar));
    final rect = tester.getRect(find.byType(ColorBar));
    expect(
      size.height,
      greaterThan(0),
      reason: 'height was ${size.height}, rect $rect',
    );
    // Must be on screen, not pushed past the bottom of the app bar.
    expect(rect.top, lessThan(300), reason: 'rect was $rect');
  });

  testWidgets('BrandActionBar renders its inline ColorBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(brand),
        home: Scaffold(
          bottomNavigationBar: BrandActionBar(
            brand: brand,
            label: 'Scout Match',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.byType(ColorBar), findsOneWidget);
    final size = tester.getSize(find.byType(ColorBar));
    expect(size.height, greaterThan(0), reason: 'height was ${size.height}');
    expect(size.width, greaterThan(0), reason: 'width was ${size.width}');
  });
}
