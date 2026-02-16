# Fuel Counter Increment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a configurable increment control to fuel counters with a meta-counter, and rename "Left Start Line" to "L1 Hang"

**Architecture:** Add `fuelIncrement` preference to settings, enhance CounterCard with optional step control UI, enable on both Auto and Teleop fuel counters

**Tech Stack:** Flutter, Riverpod, SharedPreferences

---

## Task 1: Add Fuel Increment Preference

**Files:**
- Modify: `frontend/lib/data/local/preferences.dart:5-12` (add key)
- Modify: `frontend/lib/data/local/preferences.dart:24-34` (add to build)
- Modify: `frontend/lib/data/local/preferences.dart:36-59` (add setter)

**Step 1: Add preference key**

Add to `PrefKeys` class:
```dart
static const String fuelIncrement = 'fuel_increment';
```

**Step 2: Add default value in build()**

Add to the map returned by `build()`:
```dart
PrefKeys.fuelIncrement: _prefs.getString(PrefKeys.fuelIncrement) ?? '1',
```

**Step 3: Add setter method**

Add after `setColorSeed()`:
```dart
Future<void> setFuelIncrement(String value) async {
  await _prefs.setString(PrefKeys.fuelIncrement, value);
  state = {...state, PrefKeys.fuelIncrement: value};
}
```

**Step 4: Run tests**

Run: `flutter test`
Expected: All 75 tests pass

**Step 5: Commit**

```bash
git add frontend/lib/data/local/preferences.dart
git commit -m "feat(settings): add fuel increment preference"
```

---

## Task 2: Enhance CounterCard with Step Control

**Files:**
- Modify: `frontend/lib/presentation/widgets/counter_card.dart:12-30` (add parameters)
- Modify: `frontend/lib/presentation/widgets/counter_card.dart:32-125` (update build)
- Modify: `frontend/lib/presentation/widgets/counter_card.dart:127-168` (add step button)

**Step 1: Add new parameters**

Add to CounterCard constructor:
```dart
final bool showStepControl;
final int stepSize;
final Function(int)? onStepChanged;
```

With defaults:
```dart
this.showStepControl = false,
this.stepSize = 1,
this.onStepChanged,
```

**Step 2: Update increment/decrement to use stepSize**

Change onChanged calls:
```dart
// Decrement
onChanged(value - stepSize)

// Increment  
onChanged(value + stepSize)
```

**Step 3: Add step control UI when showStepControl is true**

After the main counter row (after line ~120), add:
```dart
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
        child: Text(
          stepSize.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentColor ?? colorScheme.onSurface,
          ),
        ),
      ),
      _StepControlButton(
        icon: Icons.add,
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
```

**Step 4: Add _StepControlButton widget**

After `_CounterButton` class (around line 168), add:
```dart
class _StepControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final Color? accentColor;

  const _StepControlButton({
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
    );
  }
}
```

**Step 5: Run tests**

Run: `flutter test`
Expected: All 75 tests pass

**Step 6: Commit**

```bash
git add frontend/lib/presentation/widgets/counter_card.dart
git commit -m "feat(ui): add configurable step control to CounterCard"
```

---

## Task 3: Update FRC Form to Use Step Control

**Files:**
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:1-15` (add import)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:313-335` (update Auto Fuel)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:337-367` (update Teleop Fuel)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:325-332` (rename label)

**Step 1: Add settings import**

Add import if not present:
```dart
import '../../data/local/preferences.dart';
```

**Step 2: Read settings in build methods**

In `_buildAuto`, add at the start:
```dart
final settings = ref.watch(settingsProvider);
final fuelIncrement = int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;
```

In `_buildTeleop`, add at the start:
```dart
final settings = ref.watch(settingsProvider);
final fuelIncrement = int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;
```

**Step 3: Update Auto Fuel CounterCard**

Change the Auto Fuel CounterCard to:
```dart
CounterCard(
  label: "Auto Fuel",
  helperText: "Pieces scored during autonomous",
  value: _autoFuel,
  onChanged: (v) => setState(() => _autoFuel = v),
  stepSize: fuelIncrement,
  showStepControl: true,
  onStepChanged: (step) => ref.read(settingsProvider.notifier).setFuelIncrement(step.toString()),
  accentColor: Theme.of(context).colorScheme.tertiary,
),
```

**Step 4: Update Teleop Fuel CounterCard**

Change the Teleop Fuel CounterCard to:
```dart
CounterCard(
  label: "Teleop Fuel",
  helperText: "Pieces scored during teleop",
  value: _teleopFuel,
  onChanged: (v) => setState(() => _teleopFuel = v),
  stepSize: fuelIncrement,
  showStepControl: true,
  onStepChanged: (step) => ref.read(settingsProvider.notifier).setFuelIncrement(step.toString()),
),
```

**Step 5: Rename "Left Start Line" to "L1 Hang"**

In `_buildAuto`, change the SwitchListTile:
```dart
SwitchListTile(
  title: const Text("L1 Hang"),
  subtitle: const Text("Robot achieved L1 hang"),
  value: _autoTowerL1,
  onChanged: (v) => setState(() => _autoTowerL1 = v),
),
```

**Step 6: Run tests**

Run: `flutter test`
Expected: All 75 tests pass

**Step 7: Commit**

```bash
git add frontend/lib/presentation/screens/frc_rebuilt_form.dart
git commit -m "feat(forms): enable fuel step control and rename to L1 Hang"
```

---

## Task 4: Verify Integration

**Step 1: Check for any analysis errors**

Run: `flutter analyze`
Expected: No issues

**Step 2: Run all tests**

Run: `flutter test`
Expected: All 75 tests pass

**Step 3: Final commit if all tests pass**

```bash
git commit --amend -m "feat(forms): add configurable fuel increment and rename L1 Hang

- Add fuelIncrement preference to settings
- Add step control UI to CounterCard widget
- Enable step control on Auto and Teleop fuel counters
- Step value persists across screens and sessions
- Rename 'Left Start Line' to 'L1 Hang'"
```

---

## Testing Checklist

- [ ] Step control appears on Auto Fuel counter
- [ ] Step control appears on Teleop Fuel counter  
- [ ] Changing step on Auto updates Teleop immediately
- [ ] Step value persists after app restart
- [ ] Counter increments by selected step amount
- [ ] Label shows "L1 Hang" not "Left Start Line"
- [ ] All existing tests pass
- [ ] No analyzer warnings

## Files Summary

**Modified:**
1. `frontend/lib/data/local/preferences.dart` - Add fuel increment preference
2. `frontend/lib/presentation/widgets/counter_card.dart` - Add step control UI
3. `frontend/lib/presentation/screens/frc_rebuilt_form.dart` - Enable step control, rename label
