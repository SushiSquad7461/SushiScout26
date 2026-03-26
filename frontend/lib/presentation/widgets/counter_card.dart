import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Material 3 styled counter card with mobile-optimized touch targets.
///
/// Features:
/// - 56dp buttons (M3 FAB mini size) for easy touch interaction
/// - Haptic feedback on value changes
/// - M3 filled card styling with surface tint
/// - Optional accent color and helper text
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color:
          accentColor?.withValues(alpha: 0.1) ??
          colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: accentColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            // Helper text
            if (helperText != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                helperText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppTheme.spacingMd),

            // Counter row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement button (56dp - M3 FAB mini size)
                _CounterButton(
                  icon: Icons.remove,
                  semanticLabel: 'Decrease $label by $stepSize',
                  onPressed: value > minValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged((value - stepSize).clamp(minValue, maxValue));
                        }
                      : null,
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                ),

                // Value display
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: SizedBox(
                    width: 80,
                    child: Semantics(
                      liveRegion: true,
                      label: '$label: $value',
                      child: Text(
                        value.toString(),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: accentColor ?? colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // Increment button
                _CounterButton(
                  icon: Icons.add,
                  semanticLabel: 'Increase $label by $stepSize',
                  onPressed: value < maxValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged((value + stepSize).clamp(minValue, maxValue));
                        }
                      : null,
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                ),
              ],
            ),

            if (showStepControl && onStepChanged != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Step:',
                    style: theme.textTheme.bodySmall?.copyWith(
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
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                    child: Semantics(
                      label: 'Step size: $stepSize',
                      child: Text(
                        stepSize.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accentColor ?? colorScheme.onSurface,
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

/// Individual counter button with M3 styling
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
    final buttonColor = accentColor ?? colorScheme.primary;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Material(
        color: isEnabled
            ? buttonColor.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          child: SizedBox(
            width: 56, // M3 FAB mini size
            height: 56,
            child: Icon(
              icon,
              size: 28,
              color: isEnabled
                  ? buttonColor
                  : colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step control button for meta-counter
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
    final buttonColor = accentColor ?? colorScheme.primary;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Material(
        color: isEnabled
            ? buttonColor.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius - 2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius - 2),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 22,
              color: isEnabled
                  ? buttonColor
                  : colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
    );
  }
}
