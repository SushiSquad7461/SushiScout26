import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'team_brand.dart';

/// Theme configuration for SushiScout 26.
///
/// Material 3 bones, Sushi Squad skin. Three things changed from the previous
/// seed-based theme and they are the whole rebrand:
///
///  1. Colour is no longer generated. `ColorScheme.fromSeed` invented ~30
///     tinted surfaces from one salmon hex; the Initiative asks for pure
///     black and white in majority with four accents used sparingly, so the
///     scheme is written by hand from [TeamBrand].
///  2. Type is Sushi Sans / Poppins for headings and Mohave for body,
///     replacing Inter everywhere.
///  3. Geometry is square. The Initiative is built from hard rectangles and
///     rotated bars — nothing in it is soft — so radii go to 0 and a 2px rule
///     does the work tinted elevation used to.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Brand resolution
  // ---------------------------------------------------------------------------

  /// Resolve the persisted `colorSeed` preference to a brand. Legacy seed
  /// names ('salmon', 'blue', …) all resolve to the fallback brand.
  static TeamBrand brandFor(String? id) => TeamBrands.byId(id);

  static ThemeData light(TeamBrand brand) => _build(brand, Brightness.light);

  static ThemeData dark(TeamBrand brand) => _build(brand, Brightness.dark);

  /// Chrome — the app bar, the match-details header and the action bar.
  ///
  /// These are "ink" in the Initiative's sense, which means ink in BOTH
  /// brightnesses. Reading them from `colorScheme.onSurface` inverts them to
  /// solid white on a black screen in dark mode, which is what produced the
  /// white slabs; [chrome] / [onChrome] are deliberately brightness-independent.
  static Color chrome(TeamBrand brand) => brand.ink;

  static Color onChrome(TeamBrand brand) => brand.paper;

  /// De-emphasised text on [chrome]. Always the on-ink neutral, since chrome
  /// is ink in both modes.
  static Color mutedOnChrome(TeamBrand brand) => brand.neutralOnInk;

  /// Text or icon colour that reads on an arbitrary [fill].
  ///
  /// Derive a label from its own fill rather than hardcoding one, so a phase
  /// chip can never come out black-on-black or black-on-dark-red.
  static Color onFill(TeamBrand brand, Color fill) =>
      fill.computeLuminance() > 0.42 ? brand.ink : brand.paper;

  /// [candidate] if it reads against [background], otherwise [fallback].
  ///
  /// For thin lines and icons, where a dark accent on ink disappears: a 4px
  /// progress line in #c10000 on black is 2.2:1.
  static Color legibleOn(Color background, Color candidate, Color fallback) {
    final bg = background.computeLuminance();
    final fg = candidate.computeLuminance();
    final ratio = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
    return ratio >= 3.0 ? candidate : fallback;
  }

  // ---------------------------------------------------------------------------
  // Colour scheme — written, not generated
  // ---------------------------------------------------------------------------

  static ColorScheme colorScheme(TeamBrand brand, Brightness brightness) {
    final light = brightness == Brightness.light;
    final surface = brand.surfaceFor(brightness);
    final onSurface = brand.onSurfaceFor(brightness);
    final rule = brand.ruleFor(brightness);
    final muted = brand.mutedFor(brightness);

    return ColorScheme(
      brightness: brightness,
      // The primary action is a solid ink (light) or paper (dark) bar.
      primary: onSurface,
      onPrimary: surface,
      primaryContainer: onSurface,
      onPrimaryContainer: surface,
      secondary: brand.neutral,
      onSecondary: brand.paper,
      // ConnectionStatusBar and ConnectionStatusChip paint themselves with
      // these, so the pair has to be a visible band in both brightnesses:
      // lilac with ink on top. Mapping it to the surface colour made the
      // "Uploading N reports…" bar invisible.
      secondaryContainer: brand.accents[3],
      onSecondaryContainer: brand.ink,
      tertiary: brand.accentHighlight,
      onTertiary: brand.ink,
      tertiaryContainer: light ? brand.accents.last : brand.accentHighlight,
      onTertiaryContainer: brand.ink,
      error: brand.danger,
      onError: brand.paper,
      errorContainer: brand.danger,
      onErrorContainer: brand.paper,
      surface: surface,
      onSurface: onSurface,
      // No tonal surface ladder: every container is the surface itself and is
      // separated by a rule instead of a tint.
      surfaceDim: surface,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      onSurfaceVariant: muted,
      outline: rule,
      outlineVariant: brand.neutral,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: surface,
      shadow: brand.ink,
      scrim: brand.ink,
      surfaceTint: Colors.transparent,
    );
  }

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  /// Heading face. Uppercase, tight, geometric — every screen title, section
  /// label, counter label and numeral.
  static TextStyle display(
    TeamBrand brand, {
    required double size,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.0,
    Color? color,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * letterSpacing,
      height: height,
      color: color,
    );
    final bundled = brand.displayFamily;
    if (bundled != null) {
      return base.copyWith(
        fontFamily: bundled,
        fontFamilyFallback: [brand.displayFallbackGoogle],
      );
    }
    return GoogleFonts.getFont(
      brand.displayFallbackGoogle,
      textStyle: base,
      fontWeight: weight,
    );
  }

  /// Body face. Light italic carries helper and secondary text, exactly as it
  /// does throughout the Initiative.
  static TextStyle body(
    TeamBrand brand, {
    required double size,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.2,
    bool italic = false,
    Color? color,
  }) {
    return GoogleFonts.getFont(
      brand.bodyGoogle,
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * letterSpacing,
        height: height,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
      ),
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
  }

  /// Helper / secondary text: Mohave Light Italic.
  static TextStyle helper(TeamBrand brand, {double size = 14, Color? color}) =>
      body(
        brand,
        size: size,
        weight: FontWeight.w300,
        italic: true,
        height: 1.28,
        color: color,
      );

  /// A section or control label. Lowercase — the Initiative sets headings and
  /// section titles in lowercase ("about this document", "color palette",
  /// "logoless") — at the caption tracking, the only small-text tracking token.
  static TextStyle label(TeamBrand brand, {double size = 15, Color? color}) =>
      display(brand, size: size, letterSpacing: 0.02, color: color);

  /// A counter or statistic numeral. Tabular so digits don't jitter.
  static TextStyle numeral(TeamBrand brand, {double size = 54, Color? color}) =>
      display(
        brand,
        size: size,
        color: color,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Codepoints Sushi Sans declares an advance width for but draws no outline
  /// for. Measured on canvas at 80px: 0 ink pixels each, against 1327 for "a".
  /// Flutter will NOT fall back for a glyph that exists-but-is-empty — it draws
  /// nothing and leaves a gap — so these must never be set in the display face.
  static const String displayMissingGlyphs = r"""·/-'"+:;,?<>""";

  /// Builds a line of display type whose separators are set in the body face.
  ///
  /// Use for anything that mixes words with punctuation from
  /// [displayMissingGlyphs] — match titles ("Q28 · Team 254"), a timer
  /// ("2:03"), a date. [parts] are set in Sushi Sans; [separator] in Mohave.
  ///
  ///     Text.rich(AppTheme.displayRun(
  ///       brand, ['Q${m.matchNumber}', 'Team ${m.teamNumber}'],
  ///       separator: ' · ', size: 17, color: cs.onSurface,
  ///     ))
  static TextSpan displayRun(
    TeamBrand brand,
    List<String> parts, {
    String separator = ' · ',
    required double size,
    Color? color,
    double letterSpacing = 0.02,
  }) {
    final display = AppTheme.display(
      brand,
      size: size,
      letterSpacing: letterSpacing,
      color: color,
    );
    final body = AppTheme.body(brand, size: size, color: color);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(TextSpan(text: separator, style: body));
      spans.add(TextSpan(text: parts[i], style: display));
    }
    return TextSpan(children: spans);
  }

  static TextTheme textTheme(TeamBrand brand, Color onSurface, Color muted) {
    return TextTheme(
      displayLarge: display(
        brand,
        size: 46,
        letterSpacing: -0.01,
        height: 0.94,
        color: onSurface,
      ),
      displayMedium: display(
        brand,
        size: 40,
        letterSpacing: -0.01,
        height: 0.96,
        color: onSurface,
      ),
      displaySmall: display(brand, size: 30, height: 1.0, color: onSurface),
      headlineLarge: display(brand, size: 28, color: onSurface),
      headlineMedium: display(brand, size: 24, color: onSurface),
      headlineSmall: display(brand, size: 21, color: onSurface),
      titleLarge: display(
        brand,
        size: 21,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      titleMedium: display(
        brand,
        size: 17,
        letterSpacing: 0.02,
        color: onSurface,
      ),
      titleSmall: display(
        brand,
        size: 15,
        letterSpacing: 0.02,
        color: onSurface,
      ),
      bodyLarge: body(brand, size: 17, height: 1.28, color: onSurface),
      bodyMedium: body(brand, size: 15, height: 1.28, color: onSurface),
      bodySmall: body(brand, size: 14, height: 1.28, color: muted),
      labelLarge: display(
        brand,
        size: 17,
        letterSpacing: 0.02,
        color: onSurface,
      ),
      labelMedium: display(
        brand,
        size: 15,
        letterSpacing: 0.02,
        color: onSurface,
      ),
      labelSmall: display(brand, size: 14, letterSpacing: 0.02, color: muted),
    );
  }

  // ---------------------------------------------------------------------------
  // Component themes
  // ---------------------------------------------------------------------------

  static ThemeData _build(TeamBrand brand, Brightness brightness) {
    final cs = colorScheme(brand, brightness);
    final rule = cs.outline;
    final tt = textTheme(brand, cs.onSurface, cs.onSurfaceVariant);

    const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      textTheme: tt,
      scaffoldBackgroundColor: cs.surface,
      // The source is a static print document and specifies no press behaviour;
      // the coherent extension is an instant, hard state change rather than a
      // travelling ripple.
      splashFactory: NoSplash.splashFactory,
      // No tonal overlays anywhere — contrast carries hierarchy.
      applyElevationOverlayColor: false,

      // App bar: solid ink, brand mark on the left, colour bar beneath (see
      // BrandAppBar in widgets/color_bar.dart).
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: chrome(brand),
        foregroundColor: onChrome(brand),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: onChrome(brand), size: 22),
        actionsIconTheme: IconThemeData(color: onChrome(brand), size: 22),
        titleTextStyle: display(
          brand,
          size: 21,
          letterSpacing: 0.01,
          color: onChrome(brand),
        ),
      ),

      // Cards: square, surface-coloured, defined by a 2px rule.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: rule, width: ruleWidth),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: square,
          backgroundColor: cs.onSurface,
          foregroundColor: cs.surface,
          textStyle: display(brand, size: 17, letterSpacing: 0.1),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: square,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: rule, width: ruleWidth),
          textStyle: display(brand, size: 17, letterSpacing: 0.1),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: square,
          foregroundColor: cs.onSurface,
          textStyle: display(brand, size: 15, letterSpacing: 0.12),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: square,
        ),
      ),

      // The FAB is replaced by a full-width bottom action bar on the
      // dashboard and the forms; this keeps any remaining FAB on-brand.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: square,
        backgroundColor: cs.onSurface,
        foregroundColor: cs.surface,
        extendedTextStyle: display(brand, size: 17, letterSpacing: 0.1),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: rule, width: ruleWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: rule, width: ruleWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: brand.accentHighlight, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: cs.error, width: ruleWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: cs.error, width: 3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: label(brand, color: cs.onSurfaceVariant),
        floatingLabelStyle: label(brand, color: cs.onSurface),
        hintStyle: helper(brand, size: 15, color: cs.onSurfaceVariant),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        showDragHandle: true,
        dragHandleColor: cs.onSurface,
        dragHandleSize: const Size(40, 4),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: cs.onSurface,
        indicatorColor: brand.accentHighlight,
        indicatorShape: square,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? brand.ink : cs.surface,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return display(
            brand,
            size: 13,
            letterSpacing: 0.02,
            color: selected ? cs.surface : brand.neutralOnInk,
          );
        }),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: rule, width: ruleWidth),
        ),
        backgroundColor: cs.surface,
        selectedColor: cs.onSurface,
        side: BorderSide(color: rule, width: ruleWidth),
        labelStyle: label(brand, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 52)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14),
          ),
          shape: WidgetStateProperty.all(square),
          side: WidgetStateProperty.all(
            BorderSide(color: rule, width: ruleWidth),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? cs.onSurface
                : cs.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? cs.surface
                : cs.onSurfaceVariant,
          ),
          textStyle: WidgetStateProperty.all(
            display(brand, size: 16, letterSpacing: 0.12),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        minVerticalPadding: 12,
        shape: square,
        titleTextStyle: tt.titleMedium,
        subtitleTextStyle: helper(brand, color: cs.onSurfaceVariant),
        iconColor: cs.onSurface,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.surface : cs.onSurface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.onSurface : cs.surface,
        ),
        trackOutlineColor: WidgetStateProperty.all(rule),
        trackOutlineWidth: WidgetStateProperty.all(ruleWidth),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: square,
        side: BorderSide(color: rule, width: ruleWidth),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.onSurface
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(brand.accentSuccess),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: brand.accentHighlight,
        inactiveTrackColor: cs.onSurface,
        thumbColor: cs.onSurface,
        overlayColor: brand.accentHighlight.withValues(alpha: 0.2),
        trackHeight: 8,
        trackShape: const RectangularSliderTrackShape(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: rule, width: ruleWidth),
        ),
        titleTextStyle: display(brand, size: 24, color: cs.onSurface),
        contentTextStyle: body(brand, size: 17, color: cs.onSurface),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.onSurface,
        contentTextStyle: body(brand, size: 15, color: cs.surface),
        actionTextColor: brand.accentHighlight,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      dividerTheme: DividerThemeData(
        color: rule,
        thickness: ruleWidth,
        space: ruleWidth,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand.accentHighlight,
        linearTrackColor: cs.onSurface,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 8,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: rule, width: ruleWidth),
        ),
        textStyle: tt.bodyMedium,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: cs.onSurface),
        textStyle: body(brand, size: 14, color: cs.surface),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  /// The hairline rule that replaced tinted elevation (--ss-rule-hairline).
  static const double ruleWidth = 2.5;

  /// The heavy section rule the Initiative hangs under a page header
  /// (--ss-rule-weight). Use for a full-width divider between major blocks.
  static const double sectionRuleWeight = 10;

  /// Colour-bar thickness (--ss-colorbar-h).
  static const double colorBarThickness = 10;

  /// The signature 15° cut (--ss-skew): large fields of flat colour rotated
  /// and sized to bleed past every edge, so a composition reads as a diagonal
  /// slice rather than a rectangle. See [BrandSkewField].
  static const double skewDegrees = 15;

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  static const double minTouchTarget = 48;

  /// Counter increment/decrement blocks. Larger than the old 56dp so a scout
  /// can hit them at pace during a 2.5-minute match.
  static const double counterButtonSize = 68;

  /// Square, per the Initiative's geometry. Kept as named constants so
  /// existing `BorderRadius.circular(AppTheme.cardRadius)` call sites go
  /// square without edits.
  static const double cardRadius = 0;
  static const double buttonRadius = 0;

  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 840;
  static const double expandedBreakpoint = 1200;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compactBreakpoint && w < expandedBreakpoint;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expandedBreakpoint;

  // ---------------------------------------------------------------------------
  // Back-compat shims — existing screens keep compiling
  // ---------------------------------------------------------------------------

  // Kept `const` (matching TeamBrands.fallback's alliance colours) so the
  // untouched scouting forms' `const` ButtonSegment lists still compile.
  static const Color allianceRed = Color(0xFFC10000);
  static const Color allianceBlue = Color(0xFF56CBF9);

  static Color allianceColor(String alliance) =>
      TeamBrands.fallback.allianceColor(alliance);
}
