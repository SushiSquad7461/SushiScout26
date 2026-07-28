import 'package:flutter/material.dart';

/// A team's complete visual identity.
///
/// The app used to derive every colour from a single seed, which is why it
/// looked like a Flutter template. A brand is a *system* of elements, so the
/// whole system lives here and screens read from it.
///
/// Adding a second team is one new `TeamBrand` const plus one entry in
/// [TeamBrands.all] — no screen changes.
@immutable
class TeamBrand {
  /// Stable id persisted in SharedPreferences (`PrefKeys.colorSeed`).
  final String id;

  /// Full name, standard capitalisation.
  final String name;

  /// Short nickname for tight spaces.
  final String shortName;

  final String teamNumber;

  /// The two primaries. These carry the majority of every surface.
  final Color ink;
  final Color paper;

  /// The secondary — rules, dividers, de-emphasised text.
  final Color neutral;

  /// De-emphasised text on top of [ink] (dark mode secondary text).
  final Color neutralOnInk;

  /// The accents, in canonical colour-bar order. Used only to highlight an
  /// element or add brand presence — never as a surface fill.
  final List<Color> accents;

  /// Semantic accents, pulled out of [accents] so screens don't index by hand.
  final Color accentSuccess;
  final Color accentHighlight;

  /// Alliance colours deliberately sit OUTSIDE the accent set: red and blue
  /// have to read as red and blue in the stands.
  final Color allianceRed;
  final Color allianceBlue;

  final Color danger;

  /// Bundled display family, or null to fall back to [displayFallbackGoogle].
  final String? displayFamily;

  /// Google Fonts family names.
  final String displayFallbackGoogle;
  final String bodyGoogle;

  /// Mascot asset keys. Team 7461 is deliberately logoless — any of these
  /// stands in for a logo.
  final List<String> mascots;

  const TeamBrand({
    required this.id,
    required this.name,
    required this.shortName,
    required this.teamNumber,
    required this.ink,
    required this.paper,
    required this.neutral,
    required this.neutralOnInk,
    required this.accents,
    required this.accentSuccess,
    required this.accentHighlight,
    required this.allianceRed,
    required this.allianceBlue,
    required this.danger,
    required this.displayFamily,
    required this.displayFallbackGoogle,
    required this.bodyGoogle,
    required this.mascots,
  });

  /// Sushi Squad 7461 — "Bubblegum Forest", from the Sushi Squad Design
  /// Initiative. High contrast, vibrant accents: pure black and white are the
  /// primaries and are used in majority; the four accents exist to highlight
  /// particular elements or add brand presence.
  static const TeamBrand sushiSquad7461 = TeamBrand(
    id: 'sushi7461',
    name: 'Sushi Squad 7461',
    shortName: 'Sushi Squad',
    teamNumber: '7461',
    ink: Color(0xFF000000), // black / primary
    paper: Color(0xFFFFFFFF), // white / primary
    neutral: Color(0xFF4F4F4F), // oyster / secondary
    neutralOnInk: Color(0xFFC4C4C4),
    accents: [
      Color(0xFF81F4E1), // arita
      Color(0xFF56CBF9), // dodger
      Color(0xFFFF729F), // french
      Color(0xFFFCD6F6), // lilac
    ],
    accentSuccess: Color(0xFF81F4E1), // arita — synced, confirmed
    accentHighlight: Color(0xFFFF729F), // french — selection, emphasis
    allianceRed: Color(0xFFC10000),
    allianceBlue: Color(0xFF56CBF9), // dodger already serves blue
    danger: Color(0xFFC10000),
    // Sushi Sans, the team face, bundled at assets/fonts/SushiSans-Regular.ttf
    // under `family: SushiSans`. Poppins stays declared as the fallback
    // because it is the Initiative's own designated substitute.
    displayFamily: 'SushiSans',
    displayFallbackGoogle: 'Poppins',
    bodyGoogle: 'Mohave',
    mascots: ['nori', 'peepo', 'sparkie', 'daimler'],
  );

  /// The colour bar: the four accents beside each other, forward or reverse.
  /// It substitutes for a logo and indicates team ownership of a product.
  List<Color> colorBar({bool reversed = false}) =>
      reversed ? accents.reversed.toList() : accents;

  Color allianceColor(String alliance) =>
      alliance == 'Red' ? allianceRed : allianceBlue;

  /// Surface / on-surface for the current brightness.
  Color surfaceFor(Brightness b) => b == Brightness.light ? paper : ink;
  Color onSurfaceFor(Brightness b) => b == Brightness.light ? ink : paper;

  /// Rule and divider colour — pure contrast, not a tint.
  Color ruleFor(Brightness b) => b == Brightness.light ? ink : paper;

  /// De-emphasised text.
  Color mutedFor(Brightness b) =>
      b == Brightness.light ? neutral : neutralOnInk;
}

/// Makes the active brand available to any widget without threading it through
/// constructors. Wrap the app once in `main.dart`; every brand widget then
/// picks it up, so existing call sites need no new arguments.
class BrandScope extends InheritedWidget {
  final TeamBrand brand;

  const BrandScope({super.key, required this.brand, required super.child});

  static TeamBrand of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrandScope>()?.brand ??
      TeamBrands.fallback;

  @override
  bool updateShouldNotify(BrandScope oldWidget) =>
      oldWidget.brand.id != brand.id;
}

/// Registry of brands the app can wear. The settings picker reads this, so a
/// new team appears in the UI with no further wiring.
abstract final class TeamBrands {
  static const List<TeamBrand> all = [TeamBrand.sushiSquad7461];

  static const TeamBrand fallback = TeamBrand.sushiSquad7461;

  static TeamBrand byId(String? id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return fallback;
  }
}
