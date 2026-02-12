import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    group('getSeedColor', () {
      test('returns salmon for null', () {
        expect(AppTheme.getSeedColor(null), AppTheme.salmonSeed);
      });

      test('returns salmon for unknown value', () {
        expect(AppTheme.getSeedColor('unknown'), AppTheme.salmonSeed);
      });

      test('returns blue for blue', () {
        expect(AppTheme.getSeedColor('blue'), AppTheme.blueSeed);
      });

      test('returns green for green', () {
        expect(AppTheme.getSeedColor('green'), AppTheme.greenSeed);
      });

      test('returns purple for purple', () {
        expect(AppTheme.getSeedColor('purple'), AppTheme.purpleSeed);
      });

      test('returns orange for orange', () {
        expect(AppTheme.getSeedColor('orange'), AppTheme.orangeSeed);
      });
    });

    group('spacing constants', () {
      test('spacing values are properly defined', () {
        expect(AppTheme.spacingXs, 4);
        expect(AppTheme.spacingSm, 8);
        expect(AppTheme.spacingMd, 16);
        expect(AppTheme.spacingLg, 24);
        expect(AppTheme.spacingXl, 32);
        expect(AppTheme.spacingXxl, 48);
      });

      test('minTouchTarget is 48dp', () {
        expect(AppTheme.minTouchTarget, 48);
      });

      test('cardRadius is 16', () {
        expect(AppTheme.cardRadius, 16);
      });

      test('buttonRadius is 12', () {
        expect(AppTheme.buttonRadius, 12);
      });
    });

    group('breakpoints', () {
      test('breakpoint values are properly defined', () {
        expect(AppTheme.compactBreakpoint, 600);
        expect(AppTheme.mediumBreakpoint, 840);
        expect(AppTheme.expandedBreakpoint, 1200);
      });
    });

    group('breakpoint helpers', () {
      testWidgets('isCompact returns true for narrow screens', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Builder(
              builder: (context) {
                expect(AppTheme.isCompact(context), isTrue);
                expect(AppTheme.isMedium(context), isFalse);
                expect(AppTheme.isExpanded(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('isMedium returns true for tablet-sized screens', (
        tester,
      ) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 1024)),
            child: Builder(
              builder: (context) {
                expect(AppTheme.isCompact(context), isFalse);
                expect(AppTheme.isMedium(context), isTrue);
                expect(AppTheme.isExpanded(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('isExpanded returns true for large screens', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)),
            child: Builder(
              builder: (context) {
                expect(AppTheme.isCompact(context), isFalse);
                expect(AppTheme.isMedium(context), isFalse);
                expect(AppTheme.isExpanded(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('edge case: exactly at compact breakpoint', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)),
            child: Builder(
              builder: (context) {
                // At 600, it's no longer compact but is medium
                expect(AppTheme.isCompact(context), isFalse);
                expect(AppTheme.isMedium(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('edge case: exactly at expanded breakpoint', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                expect(AppTheme.isExpanded(context), isTrue);
                expect(AppTheme.isMedium(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('seed colors', () {
      test('salmon seed color is correct', () {
        expect(AppTheme.salmonSeed, const Color(0xFFFA8072));
      });

      test('all seed colors are distinct', () {
        final colors = {
          AppTheme.salmonSeed,
          AppTheme.blueSeed,
          AppTheme.greenSeed,
          AppTheme.purpleSeed,
          AppTheme.orangeSeed,
        };
        expect(colors.length, 5); // All unique
      });
    });
  });
}
