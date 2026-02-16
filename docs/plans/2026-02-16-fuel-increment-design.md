# Fuel Counter Increment Feature Design

**Date:** 2026-02-16  
**Status:** Approved  
**Scope:** FRC Rebuilt Form - Auto and Teleop screens

## Overview

Add a configurable increment control to fuel counter widgets that allows scouters to adjust how many pieces are added/removed with each button press. The increment value persists across both Auto and Teleop screens.

## Requirements

1. **Adjustable Increment:** Users can set increment value from 1-10
2. **Persistent Setting:** Increment value persists across screens and sessions
3. **Shared State:** Same increment used for both Auto Fuel and Teleop Fuel counters
4. **UI Integration:** Compact inline control within CounterCard widget
5. **Label Update:** Rename "Left Start Line" to "L1 Hang"

## Architecture

### State Management

**Preferences Layer (`preferences.dart`)**
- Add `fuelIncrement` key to `PrefKeys` class
- Default value: 1
- Storage: Integer in SharedPreferences
- Methods: `setFuelIncrement(int)`, `getFuelIncrement()`

**Provider Integration**
- Access via existing `settingsProvider`
- Reactive updates across all consumers

### Component Design

**Enhanced CounterCard (`counter_card.dart`)**

New optional parameter:
```dart
final bool showStepControl;  // Default: false
```

When `showStepControl` is true:
- Display compact step selector below main counter value
- Horizontal layout: [-] [Step: N] [+]
- Mini buttons: 40dp touch target
- Value chip displays current step size
- Range: 1-10 (inclusive)
- Visual separation from main counter via subtle styling

**Layout Structure:**
```
┌─────────────────────────────┐
│       Auto Fuel             │
│   Pieces scored during...   │
│                             │
│   [−]      15      [+]      │
│                             │
│   Step: [−]  [3]  [+]       │
└─────────────────────────────┘
```

### Form Integration

**FRC Rebuilt Form (`frc_rebuilt_form.dart`)**

1. **Auto Screen (`_buildAuto`):**
   - Enable `showStepControl: true` on Auto Fuel CounterCard
   - Rename "Left Start Line (L1)" → "L1 Hang"

2. **Teleop Screen (`_buildTeleop`):**
   - Enable `showStepControl: true` on Teleop Fuel CounterCard
   - Shares same increment value from settings

## Implementation Details

### CounterCard Enhancement

The step control uses the same haptic feedback and visual patterns as the main counter:
- Light haptic on step change
- Disabled state when at min (1) or max (10)
- Inherits accent color from parent card

### Data Flow

```
User taps step +/−
    ↓
Update settingsProvider state
    ↓
Persist to SharedPreferences
    ↓
Both Auto and Teleop counters reflect new step
```

### Edge Cases

- **Minimum:** Step cannot go below 1
- **Maximum:** Step capped at 10
- **Persistence:** Setting survives app restart
- **Validation:** Invalid stored values default to 1

## Testing Considerations

1. Verify step change updates both screens
2. Confirm persistence across app restart
3. Test boundary values (1 and 10)
4. Validate CounterCard without step control still works
5. Check haptic feedback on step change

## Files Modified

1. `lib/data/local/preferences.dart` - Add fuelIncrement preference
2. `lib/presentation/widgets/counter_card.dart` - Add step control UI
3. `lib/presentation/screens/frc_rebuilt_form.dart` - Enable step control, rename label

## Success Criteria

- [ ] Step control appears on both fuel counters
- [ ] Step value persists when switching between Auto/Teleop
- [ ] Step value persists after app restart
- [ ] Counter respects selected step value
- [ ] Label reads "L1 Hang" instead of "Left Start Line"
