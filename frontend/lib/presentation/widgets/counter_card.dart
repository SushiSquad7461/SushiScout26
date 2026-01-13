import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  final Color? color;
  final String? helperText;

  const CounterCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.headlineSmall),
            if (helperText != null) ...[
              const SizedBox(height: 4),
              Text(helperText!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: value > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(value - 1);
                        }
                      : null,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 24),
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(width: 24),
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onChanged(value + 1);
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
