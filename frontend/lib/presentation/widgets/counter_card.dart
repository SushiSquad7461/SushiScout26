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

  const CounterCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accentColor,
    this.helperText,
    this.minValue = 0,
    this.maxValue = 999,
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
                  onPressed: value > minValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(value - 1);
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

                // Increment button
                _CounterButton(
                  icon: Icons.add,
                  onPressed: value < maxValue
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(value + 1);
                        }
                      : null,
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                ),
              ],
            ),
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

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final buttonColor = accentColor ?? colorScheme.primary;

    return Material(
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
    );
  }
}
