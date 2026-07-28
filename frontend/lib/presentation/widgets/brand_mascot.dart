import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';

/// Sushi Squad 7461's mascots, used in place of a logo.
///
/// From the Initiative: "Team 7461 does not feature a single, set logo—rather,
/// any of the team's four mascots can be used in lieu of one. This supports the
/// team's principles of unity in individualism as opposed to a stoic,
/// undynamic image."
///
/// Guidelines enforced by these widgets:
///  * a mascot may sit on a solid background of any palette colour;
///  * in small form it must not feature multiple colours — [BrandMascot] tints
///    the whole mark one colour;
///  * it keeps a margin on all sides of 1/8 its own width;
///  * it may be rotated or scaled but never non-uniformly stretched, so the
///    art is always fitted with BoxFit.contain.
///
/// Assets expected at `assets/mascots/<name>.svg`, declared in pubspec.yaml.
abstract final class Mascots {
  static const String nori = 'nori';
  static const String peepo = 'peepo';
  static const String sparkie = 'sparkie';
  static const String daimler = 'daimler';

  static const List<String> all = [nori, peepo, sparkie, daimler];

  static String assetPath(String name) => 'assets/mascots/$name.svg';

  /// The palette colour each mascot is presented on in the Initiative.
  static Color plate(TeamBrand brand, String name) => switch (name) {
    nori => brand.accents[0], // arita
    daimler => brand.accents[1], // dodger
    sparkie => brand.accents[2], // french
    _ => brand.accents[3], // lilac — peepo
  };
}

/// A mascot as a single-colour mark. Use for app bars, scout avatars, list
/// leading icons — anywhere small.
class BrandMascot extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  /// The 1/8-width clearance the Initiative requires. Turn off only when the
  /// surrounding layout already provides it.
  final bool margin;

  const BrandMascot({
    super.key,
    required this.name,
    required this.color,
    this.size = 30,
    this.margin = true,
  });

  @override
  Widget build(BuildContext context) {
    final pad = margin ? size / 8 : 0.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: SvgPicture.asset(
            Mascots.assetPath(name),
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// The mascot "plate": the Initiative's full presentation of a mascot — a
/// solid palette background, the mascot's name repeated behind it in
/// soft-light, and the art on top.
///
/// Use for the sign-in hero and empty states, where a large graphic is wanted
/// and a mascot may overlap several colours.
class MascotPlate extends StatelessWidget {
  final TeamBrand brand;
  final String name;
  final double? width;
  final double height;

  const MascotPlate({
    super.key,
    required this.brand,
    required this.name,
    this.width,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final plate = Mascots.plate(brand, name);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: ColoredBox(
          color: plate,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Repeated wordmark, soft-light against the plate. Sized to the
              // plate WIDTH so the whole name reads at any plate size; the row
              // count follows from the height.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fontSize =
                        constraints.maxWidth / (name.length * 0.645);
                    final rows = (constraints.maxHeight / (fontSize * 0.805))
                        .round()
                        .clamp(1, 12);
                    return Opacity(
                      opacity: 0.45,
                      // The wash is meant to bleed past the plate; let the row
                      // stack take its natural height (rather than asserting a
                      // RenderFlex overflow when the width-derived font size
                      // makes the rows taller than the plate) and rely on the
                      // enclosing ClipRect to trim it.
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < rows; i++)
                              Text(
                                name,
                                maxLines: 1,
                                softWrap: false,
                                style: AppTheme.display(
                                  brand,
                                  size: fontSize,
                                  letterSpacing: -0.015,
                                  height: 0.805,
                                  color: brand.paper,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(height * 0.11),
                child: SvgPicture.asset(
                  Mascots.assetPath(name),
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(brand.ink, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mascot picker for the settings sheet — "your mascot", the mark that stamps
/// the reports a scout files. Unity in individualism, in a settings row.
class MascotPicker extends StatelessWidget {
  final TeamBrand brand;
  final String selected;
  final ValueChanged<String> onChanged;

  const MascotPicker({
    super.key,
    required this.brand,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final name in Mascots.all) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: name == selected,
              label: 'Use the $name mascot',
              child: InkWell(
                onTap: () => onChanged(name),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: name == selected
                          ? Mascots.plate(brand, name)
                          : Colors.transparent,
                      border: Border.all(
                        color: name == selected ? cs.onSurface : brand.neutral,
                        width: AppTheme.ruleWidth,
                      ),
                    ),
                    child: Center(
                      child: BrandMascot(
                        name: name,
                        size: 52,
                        color: name == selected ? brand.ink : brand.neutral,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (name != Mascots.all.last) const SizedBox(width: 9),
        ],
      ],
    );
  }
}
