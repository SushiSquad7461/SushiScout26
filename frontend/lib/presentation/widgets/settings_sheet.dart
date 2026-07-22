import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/validation/form_validators.dart';
import '../../data/local/preferences.dart';
import '../theme/app_theme.dart';

/// Material 3 settings bottom sheet
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  final _scouterNameCtrl = TextEditingController();
  final _eventCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
    _eventCodeCtrl.text = settings[PrefKeys.eventCode] ?? '';
  }

  @override
  void dispose() {
    _scouterNameCtrl.dispose();
    _eventCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacingSm),

            // Header
            Text(
              "Settings",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Profile section
            _SectionHeader(title: "Profile"),
            const SizedBox(height: AppTheme.spacingSm),

            TextField(
              controller: _scouterNameCtrl,
              decoration: const InputDecoration(
                labelText: "Your Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setScouterName(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            TextFormField(
              controller: _eventCodeCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: FormValidators.eventCode,
              decoration: const InputDecoration(
                labelText: "Event Code",
                prefixIcon: Icon(Icons.event_outlined),
                helperText: "e.g., 2026casj",
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setEventCode(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            Text(
              "Program Type",
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'FRC',
                  label: Text('FRC'),
                ),
                ButtonSegment(
                  value: 'FTC',
                  label: Text('FTC'),
                ),
              ],
              selected: {ref.watch(settingsProvider)[PrefKeys.programType] ?? 'FRC'},
              onSelectionChanged: (selection) {
                ref.read(settingsProvider.notifier).setProgramType(selection.first);
              },
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Appearance section
            _SectionHeader(title: "Appearance"),
            const SizedBox(height: AppTheme.spacingSm),

            _buildThemeSelector(context),

            const SizedBox(height: AppTheme.spacingMd),

            Text(
              "Color Theme",
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildColorSelector(context),

            const SizedBox(height: AppTheme.spacingXl),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme =
        ref.watch(settingsProvider)[PrefKeys.themeMode] ?? 'system';

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'system',
          icon: Icon(Icons.brightness_auto),
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: 'light',
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: 'dark',
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {currentTheme},
      onSelectionChanged: (selection) {
        ref.read(settingsProvider.notifier).setThemeMode(selection.first);
      },
    );
  }

  Widget _buildColorSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ColorSeedChip(
            label: 'Salmon',
            value: 'salmon',
            color: AppTheme.salmonSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Blue',
            value: 'blue',
            color: AppTheme.blueSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Green',
            value: 'green',
            color: AppTheme.greenSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Purple',
            value: 'purple',
            color: AppTheme.purpleSeed,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _ColorSeedChip(
            label: 'Orange',
            value: 'orange',
            color: AppTheme.orangeSeed,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ColorSeedChip extends ConsumerWidget {
  final String label;
  final String value;
  final Color color;

  const _ColorSeedChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed =
        ref.watch(settingsProvider)[PrefKeys.colorSeed] ?? 'salmon';
    final isSelected = currentSeed == value;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      checkmarkColor: Colors.white,
      selectedColor: color,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: colorScheme.outline),
      onSelected: (selected) {
        if (selected) {
          ref.read(settingsProvider.notifier).setColorSeed(value);
        }
      },
    );
  }
}
