import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';

/// Counter card — rebranded, not redesigned.
///
/// The structure, the API and the field wiring are byte-for-byte the original:
/// centred label, optional helper, a centred [− value +] row with a fixed 80dp
/// value slot and 56dp buttons, and the same opt-in step control underneath.
/// Only the paint changed:
///
///  * the 10%-alpha accent wash behind the whole card is gone — the Initiative
///    uses accents to highlight an element, not to tint a surface — so the card
///    is the surface colour with the theme's 2px rule, and the accent moves to
///    the label and the buttons, which the original already coloured;
///  * the buttons are square outlines in the accent rather than 12%-alpha
///    rounded fills, which holds up in the stands;
///  * type is Sushi Sans / Mohave via the theme.
///
/// [brand] is optional and resolves from [BrandScope], so existing call sites
/// compile unchanged.
class CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  final Color? accentColor;
  final String? helperText;
  final int minValue;
  final int maxValue;
  final bool showStepControl;
  final int stepSize;
  final Function(int)? onStepChanged;
  final TeamBrand? brand;

  const CounterCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accentColor,
    this.helperText,
    this.minValue = 0,
    this.maxValue = 999,
    this.showStepControl = false,
    this.stepSize = 1,
    this.onStepChanged,
    this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final b = brand ?? BrandScope.of(context);
    final accent = accentColor ?? colorScheme.onSurface;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Text(
              label,
              style: AppTheme.label(b, size: 16, color: accent),
              textAlign: TextAlign.center,
            ),

            // Helper text
            if (helperText != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                helperText!,
                style: AppTheme.helper(b, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppTheme.spacingMd),

            // Counter row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CounterButton(
                  icon: Icons.remove,
                  semanticLabel: 'Decrease $label by $stepSize',
                  onPressed: value > minValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(
                            (value - stepSize).clamp(minValue, maxValue),
                          );
                        }
                      : null,
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                ),

                // Value display — fixed slot so 3-digit values stay on one row.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: SizedBox(
                    width: 80,
                    child: Semantics(
                      liveRegion: true,
                      label: '$label: $value',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value.toString(),
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                _CounterButton(
                  icon: Icons.add,
                  semanticLabel: 'Increase $label by $stepSize',
                  onPressed: value < maxValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(
                            (value + stepSize).clamp(minValue, maxValue),
                          );
                        }
                      : null,
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                ),
              ],
            ),

            if (showStepControl && onStepChanged != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Divider(height: AppTheme.ruleWidth, color: colorScheme.outline),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'step',
                    style: AppTheme.label(
                      b,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _StepControlButton(
                    icon: Icons.remove,
                    semanticLabel: 'Decrease step size',
                    onPressed: stepSize > 1
                        ? () {
                            HapticFeedback.lightImpact();
                            onStepChanged!(stepSize - 1);
                          }
                        : null,
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                    ),
                    child: Semantics(
                      label: 'Step size: $stepSize',
                      child: Text(
                        stepSize.toString(),
                        style: AppTheme.display(
                          b,
                          size: 19,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  _StepControlButton(
                    icon: Icons.add,
                    semanticLabel: 'Increase step size',
                    onPressed: stepSize < 10
                        ? () {
                            HapticFeedback.lightImpact();
                            onStepChanged!(stepSize + 1);
                          }
                        : null,
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 56dp square, outlined in the accent. Same size and position as before.
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final Color? accentColor;
  final String semanticLabel;

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    required this.semanticLabel,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final buttonColor = accentColor ?? colorScheme.onSurface;
    final edge = isEnabled ? buttonColor : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          side: BorderSide(color: edge, width: AppTheme.ruleWidth),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, size: 28, color: edge),
          ),
        ),
      ),
    );
  }
}

class _StepControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final Color? accentColor;
  final String semanticLabel;

  const _StepControlButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    required this.semanticLabel,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final buttonColor = accentColor ?? colorScheme.onSurface;
    final edge = isEnabled ? buttonColor : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          side: BorderSide(color: edge, width: AppTheme.ruleWidth),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: edge),
          ),
        ),
      ),
    );
  }
}
