import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';

/// The colour bar — Team 7461's substitute for a logo.
///
/// From the Initiative: "geometric shapes and fills containing the colour
/// scheme's four accent colours in forward or reverse order (arita, dodger,
/// french, lilac). Despite its name, the colour bar does not have to be a bar,
/// as the significance stands in featuring the colours beside each other. The
/// colour bar stands to briefly indicate ownership of a document or product by
/// Team 7461."
///
/// That last sentence is why it sits under every app bar.
class ColorBar extends StatelessWidget {
  final TeamBrand brand;
  final double thickness;
  final bool reversed;
  final Axis axis;

  /// Fixed extent along the main axis. Null fills the parent.
  final double? extent;

  const ColorBar({
    super.key,
    required this.brand,
    this.thickness = AppTheme.colorBarThickness,
    this.reversed = false,
    this.axis = Axis.horizontal,
    this.extent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = brand.colorBar(reversed: reversed);
    final bar = Flex(
      direction: axis,
      // stretch is required: with the default (center) the cross-axis
      // constraint is loose, and a childless ColoredBox collapses to zero in
      // that axis — the bar occupied its space but painted nothing.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in colors) Expanded(child: ColoredBox(color: c))],
    );

    return ExcludeSemantics(
      child: axis == Axis.horizontal
          ? SizedBox(height: thickness, width: extent, child: bar)
          : SizedBox(width: thickness, height: extent, child: bar),
    );
  }
}

/// App bar with the brand mark, the wordmark and the colour bar beneath it.
///
/// Replaces `SliverAppBar.medium` + a tinted event Chip. The old bar had no
/// team presence at all; this one carries a mascot and the ownership mark.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TeamBrand brand;
  final String title;

  /// Rendered under the title in Mohave Light Italic.
  final String? subtitle;

  /// A mascot mark shown at the leading edge. Team 7461 is logoless, so any
  /// mascot may stand in — this is normally the signed-in scout's mascot.
  final Widget? mark;

  final List<Widget> actions;
  final Widget? leading;
  final bool showColorBar;

  const BrandAppBar({
    super.key,
    required this.brand,
    required this.title,
    this.subtitle,
    this.mark,
    this.actions = const [],
    this.leading,
    this.showColorBar = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    (subtitle == null ? 56 : 68) +
        (showColorBar ? AppTheme.colorBarThickness : 0),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: cs.onSurface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: subtitle == null ? 56 : 68,
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (mark != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 11),
                      child: mark!,
                    )
                  else
                    const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(
                            brand,
                            size: 21,
                            letterSpacing: 0.01,
                            color: cs.surface,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.helper(
                              brand,
                              color: brand.accents.last,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        if (showColorBar) ColorBar(brand: brand),
      ],
    );
  }
}

/// The signature 15° cut.
///
/// The Initiative composes its splash pages as a diagonal slice: a flat field of
/// colour rotated 15° and sized to bleed past every edge, so the composition
/// reads as a cut rather than a rectangle. This is the single most recognisable
/// thing about the brand, and it belongs on splash-like surfaces — sign-in,
/// empty states, section covers — not on dense data screens.
///
/// Defaults to the colour bar as the field, since the guide notes the bar "does
/// not have to be a bar … the significance is the colours sitting together".
/// Pass a single [color] for a one-colour slice instead.
class BrandSkewField extends StatelessWidget {
  final TeamBrand brand;
  final double height;

  /// A single flat colour instead of the four accents.
  final Color? color;

  final bool reversed;

  /// Background the slice is cut out of.
  final Color? background;

  const BrandSkewField({
    super.key,
    required this.brand,
    this.height = 96,
    this.color,
    this.reversed = false,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = color != null
        ? <Color>[color!]
        : brand.colorBar(reversed: reversed);

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: background ?? cs.onSurface,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Oversize the field and rotate about its centre so the slice
                // bleeds past all four edges at any width.
                final w = constraints.maxWidth * 1.6;
                final h = height * 2.2;
                return OverflowBox(
                  maxWidth: w,
                  maxHeight: h,
                  child: Transform.rotate(
                    angle: -AppTheme.skewDegrees * math.pi / 180,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Column(
                        children: [
                          for (final c in colors)
                            Expanded(child: ColoredBox(color: c)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The event bar that goes in `SliverAppBar.medium`'s `bottom:` slot.
///
/// IMPORTANT: the dashboard's app bar is a *sliver* with collapsing behaviour,
/// and it carries the connection chip, search, export and the overflow menu.
/// Do NOT replace it with [BrandAppBar] — that would delete all four. Instead
/// keep the `SliverAppBar.medium` exactly as it is and swap only its `bottom:`
/// for this, which puts the event code in brand type and hangs the colour bar
/// off the bottom edge of the bar.
class BrandEventBar extends StatelessWidget implements PreferredSizeWidget {
  final TeamBrand brand;
  final String eventCode;

  const BrandEventBar({
    super.key,
    required this.brand,
    required this.eventCode,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(40 + AppTheme.colorBarThickness);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingMd,
              right: AppTheme.spacingMd,
              bottom: AppTheme.spacingSm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                eventCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Sits inside the app bar, so it reads against chrome — not
                // against the surface (which made it white-on-white in dark).
                style: AppTheme.label(brand, color: AppTheme.onChrome(brand)),
              ),
            ),
          ),
        ),
        ColorBar(brand: brand),
      ],
    );
  }
}

/// The full-width action bar that replaces the floating action button.
///
/// A 66dp ink bar spanning the screen is a bigger, faster target than a FAB
/// during a 2.5-minute match, and a rectangle spanning edge to edge is the
/// Initiative's geometry rather than Material's.
class BrandActionBar extends StatelessWidget {
  final TeamBrand brand;
  final String label;
  final VoidCallback? onPressed;

  /// Optional secondary action rendered as an outlined block on the left.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// The colour bar sits inside the button, next to the label.
  final bool showColorBar;

  const BrandActionBar({
    super.key,
    required this.brand,
    required this.label,
    this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
    this.showColorBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    // The bar is ink chrome in BOTH brightnesses, and the ColoredBox extends
    // that ink through the bottom safe-area inset so the bar reaches the screen
    // edge instead of floating above a strip of background.
    final barColor = enabled
        ? AppTheme.chrome(brand)
        : AppTheme.mutedOnChrome(brand);

    return ColoredBox(
      color: barColor,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 0),
        child: SizedBox(
          height: 66,
          child: Row(
          children: [
            if (secondaryLabel != null)
              InkWell(
                onTap: onSecondary,
                child: Container(
                  width: 116,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.mutedOnChrome(brand),
                        width: AppTheme.ruleWidth,
                      ),
                      right: BorderSide(
                        color: AppTheme.mutedOnChrome(brand),
                        width: AppTheme.ruleWidth,
                      ),
                    ),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: AppTheme.display(
                      brand,
                      size: 17,
                      letterSpacing: 0.1,
                      color: AppTheme.mutedOnChrome(brand),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Material(
                color: barColor,
                child: InkWell(
                  onTap: onPressed,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTheme.display(
                          brand,
                          size: 21,
                          letterSpacing: 0.1,
                          color: AppTheme.onChrome(brand),
                        ),
                      ),
                      if (showColorBar) ...[
                        const SizedBox(width: 14),
                        ColorBar(brand: brand, thickness: 7, extent: 44),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// A section label: display face, uppercase, wide tracking, oyster.
class BrandSectionLabel extends StatelessWidget {
  final TeamBrand brand;
  final String text;

  const BrandSectionLabel({super.key, required this.brand, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.label(
        brand,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The sync indicator: a filled arita square when synced, a hollow oyster
/// square when pending. Replaces the two circular Material icons — a square
/// reads instantly at 12dp and matches the geometry.
class SyncSquare extends StatelessWidget {
  final TeamBrand brand;
  final bool synced;
  final double size;

  const SyncSquare({
    super.key,
    required this.brand,
    required this.synced,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: synced ? 'Synced' : 'Pending sync',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: synced ? brand.accentSuccess : Colors.transparent,
            border: synced
                ? null
                : Border.all(color: brand.neutral, width: AppTheme.ruleWidth),
          ),
        ),
      ),
    );
  }
}
