# Scouting Form UX Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 10 scout-reported UX fixes from `docs/superpowers/specs/2026-09-19-scouting-form-ux-feedback-design.md` across the FRC and FTC scouting wizards, their shared widgets, and the one-way Sheets export.

**Architecture:** Additive changes to two existing hand-coded wizard screens (`frc_rebuilt_form.dart`, `ftc_decode_form.dart`) and the widgets/services they share (`counter_card.dart`, `match_timer.dart`, `scouting_form_widget.dart`, `form_validators.dart`, `match_report.dart`, `sheets_service.py`). No new screens, no new Firestore collections, no schema migration — every new field lands in the existing flexible `gameData` map.

**Tech Stack:** Flutter/Dart (Riverpod, Material 3), Python 3.11 Cloud Functions, `fake_cloud_firestore` for Dart repository tests, `unittest`/`pytest` for Python tests.

## Global Constraints

- Apply every UI change to **both** the FRC "Rebuilt" form and the FTC "DECODE" form (spec Scope section), except where game-specific wording differs (fuel vs. artifacts).
- The fuel/artifact hold-to-repeat rate is locked at **one step per second** — do not speed this up (spec §2).
- New `gameData` keys use snake_case; new `MatchReport` getters use camelCase, matching the existing convention in `match_report.dart`.
- Never hand-edit a generated file (`*.g.dart`, `*.mocks.dart`) — none of these tasks touch one.
- Run `flutter test` from `frontend/` and `./venv/bin/python -m pytest tests/` from `functions/` before considering any task done; both suites must stay green (per CLAUDE.md Testing section).
- After the `sheets_service.py` task, run the `sync-logic-reviewer` agent on that diff (spec's Review section, CLAUDE.md convention for touching `sheets_service`).

---

### Task 1: Rename the dashboard's primary action to "start scouting"

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart:370`
- Modify: `frontend/lib/presentation/screens/match_details.dart:19` (comment only)
- Test: `frontend/test/presentation/screens/dashboard_test.dart` (new)

**Interfaces:**
- Consumes: `BrandActionBar` (existing, `frontend/lib/presentation/widgets/color_bar.dart`) — no signature change.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/presentation/screens/dashboard_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/providers/event_providers.dart';
import 'package:frontend/presentation/screens/dashboard.dart';
import 'package:frontend/presentation/widgets/connection_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows "start scouting" as the primary action label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firestoreRepositoryProvider.overrideWithValue(
            FirestoreRepository(fake, teamId: 'teamA'),
          ),
          currentTeamIdProvider.overrideWithValue('teamA'),
          currentEventIdProvider.overrideWithValue('teamA_2026test'),
          matchesViewProvider.overrideWith(
            (ref) => Stream.value(
              const MatchesView(matches: [], isFromCache: false),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('start scouting'), findsOneWidget);
    expect(find.text('scout match'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/presentation/screens/dashboard_test.dart`
Expected: FAIL — `find.text('start scouting')` finds nothing (label is still "scout match").

- [ ] **Step 3: Rename the label**

In `frontend/lib/presentation/screens/dashboard.dart`, change:

```dart
      bottomNavigationBar: BrandActionBar(
        brand: BrandScope.of(context),
        label: 'scout match',
```

to:

```dart
      bottomNavigationBar: BrandActionBar(
        brand: BrandScope.of(context),
        label: 'start scouting',
```

In `frontend/lib/presentation/screens/match_details.dart`, update the now-stale doc comment:

```dart
  /// Fetches the owning event (falling back to a dummy built from the match
  /// itself, mirroring dashboard.dart's "scout match" fallback) and pushes
```

to:

```dart
  /// Fetches the owning event (falling back to a dummy built from the match
  /// itself, mirroring dashboard.dart's "start scouting" fallback) and pushes
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/presentation/screens/dashboard_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/screens/dashboard.dart frontend/lib/presentation/screens/match_details.dart frontend/test/presentation/screens/dashboard_test.dart
git commit -m "fix(ui): rename scout match button to start scouting"
```

---

### Task 2: Center the wizard's page-step indicator

**Files:**
- Modify: `frontend/lib/presentation/widgets/scouting_form_widget.dart` (add `kWizardBottomBarSlotWidth`, `ScoutingWizardBottomSlot`)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:282-323` (`_buildBottomBar`)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart:275-315` (`_buildBottomBar`)
- Test: `frontend/test/widgets/scouting_form_widget_test.dart` (new)

**Interfaces:**
- Produces: `const double kWizardBottomBarSlotWidth` and `class ScoutingWizardBottomSlot extends StatelessWidget({required Widget child})`, both in `scouting_form_widget.dart`. Later tasks do not depend on these.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/widgets/scouting_form_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/scouting_form_widget.dart';

void main() {
  group('ScoutingWizardBottomSlot', () {
    testWidgets('renders at the fixed slot width regardless of child size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ScoutingWizardBottomSlot(child: Text('back')),
                ScoutingWizardBottomSlot(
                  child: FilledButton(onPressed: null, child: Text('submit')),
                ),
              ],
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == kWizardBottomBarSlotWidth)
          .toList();

      expect(sizes.length, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: FAIL — `ScoutingWizardBottomSlot` and `kWizardBottomBarSlotWidth` are undefined.

- [ ] **Step 3: Add the shared slot widget**

In `frontend/lib/presentation/widgets/scouting_form_widget.dart`, add after the imports (before `ScoutingFormWidget`):

```dart
/// Fixed width for both sides of a wizard's bottom bar. Both
/// [FrcRebuiltForm] and [FtcDecodeForm] wrap their back-button slot and
/// their [ScoutingWizardNextButton] in a [ScoutingWizardBottomSlot] of this
/// width, so [ScoutingWizardPageIndicator] sits at the true center of the
/// bar. Before this constant existed, the back slot was a bare
/// `SizedBox(width: 100)` while the next/submit button sized itself to its
/// label ("next" vs. "submit"/"save") plus an optional spinner — unequal
/// widths pushed the indicator off center.
const double kWizardBottomBarSlotWidth = 112;

/// Wraps [child] in a fixed-width slot, scaling it down rather than letting
/// it overflow if it's ever wider than the slot. See
/// [kWizardBottomBarSlotWidth].
class ScoutingWizardBottomSlot extends StatelessWidget {
  final Widget child;

  const ScoutingWizardBottomSlot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kWizardBottomBarSlotWidth,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the slot into both forms' bottom bars**

In `frontend/lib/presentation/screens/frc_rebuilt_form.dart`, replace the `Row` body of `_buildBottomBar`:

```dart
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: _prevPage,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text("back"),
            )
          else
            const SizedBox(width: 100),

          const Spacer(),

          // Page indicator
          _buildPageIndicator(colorScheme),

          const Spacer(),

          // Next/Submit button
          ScoutingWizardNextButton(
            isLastPage: _currentPage == _pageCount - 1,
            submitting: _submitting,
            onPressed: _nextPage,
            finishLabel: _isEditing ? "save" : "submit",
          ),
        ],
      ),
```

with:

```dart
      child: Row(
        children: [
          ScoutingWizardBottomSlot(
            child: _currentPage > 0
                ? TextButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("back"),
                  )
                : const SizedBox.shrink(),
          ),

          const Spacer(),

          // Page indicator
          _buildPageIndicator(colorScheme),

          const Spacer(),

          ScoutingWizardBottomSlot(
            child: ScoutingWizardNextButton(
              isLastPage: _currentPage == _pageCount - 1,
              submitting: _submitting,
              onPressed: _nextPage,
              finishLabel: _isEditing ? "save" : "submit",
            ),
          ),
        ],
      ),
```

Apply the same structural change to `frontend/lib/presentation/screens/ftc_decode_form.dart`'s `_buildBottomBar` — the logic is identical, but its exact text differs (no `// Back button`/`// Page indicator` comments, and it has its own comment before `ScoutingWizardNextButton`), so match against its real text rather than FRC's snippet above. Change:

```dart
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: _prevPage,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text("back"),
            )
          else
            const SizedBox(width: 100),

          const Spacer(),

          _buildPageIndicator(colorScheme),

          const Spacer(),

          // Label then chevron, per the design's "next ›" — FilledButton.icon
          // puts the icon first, which read as "← next".
          ScoutingWizardNextButton(
            isLastPage: _currentPage == _pageCount - 1,
            submitting: _submitting,
            onPressed: _nextPage,
            finishLabel: _isEditing ? "save" : "submit",
          ),
        ],
      ),
```

to:

```dart
      child: Row(
        children: [
          ScoutingWizardBottomSlot(
            child: _currentPage > 0
                ? TextButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("back"),
                  )
                : const SizedBox.shrink(),
          ),

          const Spacer(),

          _buildPageIndicator(colorScheme),

          const Spacer(),

          // Label then chevron, per the design's "next ›" — FilledButton.icon
          // puts the icon first, which read as "← next".
          ScoutingWizardBottomSlot(
            child: ScoutingWizardNextButton(
              isLastPage: _currentPage == _pageCount - 1,
              submitting: _submitting,
              onPressed: _nextPage,
              finishLabel: _isEditing ? "save" : "submit",
            ),
          ),
        ],
      ),
```

- [ ] **Step 6: Run the full widget suite for both forms**

Run: `cd frontend && flutter test test/presentation/screens/frc_rebuilt_form_edit_test.dart test/presentation/screens/ftc_decode_form_edit_test.dart test/widgets/scouting_form_widget_test.dart`
Expected: PASS — the edit-mode tests don't assert on `SizedBox(width: 100)`, so this is a safe structural change.

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/presentation/widgets/scouting_form_widget.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart frontend/test/widgets/scouting_form_widget_test.dart
git commit -m "fix(ui): center the wizard page-step indicator"
```

---

### Task 3: Sharpen the team-number/match-number validation messages

**Files:**
- Modify: `frontend/lib/core/validation/form_validators.dart`
- Modify: `frontend/test/core/validation/form_validators_test.dart:91-96,119-123`

**Interfaces:**
- Produces: `FormValidators.number(..., {String? maxMessage})` — new optional named parameter, default `null` (falls back to today's generic message). `teamNumber`/`matchNumber` pass a `maxMessage`; every other caller is unaffected.

- [ ] **Step 1: Update the failing (pinned) tests to the new wording**

In `frontend/test/core/validation/form_validators_test.dart`, change:

```dart
    test('returns error for value above 200', () {
      expect(
        FormValidators.matchNumber('201'),
        'Match number must be at most 200',
      );
    });
```

to:

```dart
    test('returns error for value above 200', () {
      expect(
        FormValidators.matchNumber('201'),
        'Match number can be at most 3 digits',
      );
    });
```

and:

```dart
    test('returns error for value above 99999', () {
      expect(
        FormValidators.teamNumber('100000'),
        'Team number must be at most 99999',
      );
    });
```

to:

```dart
    test('returns error for value above 99999', () {
      expect(
        FormValidators.teamNumber('100000'),
        'Team number can be at most 5 digits',
      );
    });
```

Also add a new test in the `FormValidators.number` group (find it near the top of the file, alongside the existing `'returns error for value above max'`-style cases) verifying the generic message is unchanged when `maxMessage` isn't passed:

```dart
    test('uses the generic max message when maxMessage is not provided', () {
      expect(
        FormValidators.number('15', max: 10, fieldName: 'Score'),
        'Score must be at most 10',
      );
    });

    test('uses maxMessage when provided, overriding the generic wording', () {
      expect(
        FormValidators.number(
          '15',
          max: 10,
          fieldName: 'Score',
          maxMessage: 'Score can be at most 2 digits',
        ),
        'Score can be at most 2 digits',
      );
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd frontend && flutter test test/core/validation/form_validators_test.dart`
Expected: FAIL — `matchNumber('201')` and `teamNumber('100000')` still return the old generic wording; the new `maxMessage` test fails because the parameter doesn't exist yet.

- [ ] **Step 3: Add the `maxMessage` parameter and use it**

In `frontend/lib/core/validation/form_validators.dart`, change:

```dart
  /// Validates number fields
  static String? number(String? value, {int? min, int? max, String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Allow empty if not required
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'Value'} must be a number';
    }
    
    if (min != null && number < min) {
      return '${fieldName ?? 'Value'} must be at least $min';
    }
    
    if (max != null && number > max) {
      return '${fieldName ?? 'Value'} must be at most $max';
    }
    
    return null;
  }
```

to:

```dart
  /// Validates number fields. [maxMessage], when provided, replaces the
  /// generic "must be at most N" wording on a max-value violation — used by
  /// [teamNumber]/[matchNumber] to name the real mistake (too many digits)
  /// instead of just restating the numeric range.
  static String? number(
    String? value, {
    int? min,
    int? max,
    String? fieldName,
    String? maxMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return null; // Allow empty if not required
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'Value'} must be a number';
    }
    
    if (min != null && number < min) {
      return '${fieldName ?? 'Value'} must be at least $min';
    }
    
    if (max != null && number > max) {
      return maxMessage ?? '${fieldName ?? 'Value'} must be at most $max';
    }
    
    return null;
  }
```

Then change `matchNumber` and `teamNumber`:

```dart
  /// Validates match number format (e.g. 1-200)
  static String? matchNumber(String? value) {
    final requiredError = required(value, 'Match number');
    if (requiredError != null) return requiredError;
    
    return number(value, min: 1, max: 200, fieldName: 'Match number');
  }

  /// Validates team number format (e.g. 1-99999, supports FRC and FTC)
  static String? teamNumber(String? value) {
    final requiredError = required(value, 'Team number');
    if (requiredError != null) return requiredError;

    return number(value, min: 1, max: 99999, fieldName: 'Team number');
  }
```

to:

```dart
  /// Validates match number format (e.g. 1-200)
  static String? matchNumber(String? value) {
    final requiredError = required(value, 'Match number');
    if (requiredError != null) return requiredError;
    
    return number(
      value,
      min: 1,
      max: 200,
      fieldName: 'Match number',
      maxMessage: 'Match number can be at most 3 digits',
    );
  }

  /// Validates team number format (e.g. 1-99999, supports FRC and FTC)
  static String? teamNumber(String? value) {
    final requiredError = required(value, 'Team number');
    if (requiredError != null) return requiredError;

    return number(
      value,
      min: 1,
      max: 99999,
      fieldName: 'Team number',
      maxMessage: 'Team number can be at most 5 digits',
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/core/validation/form_validators_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/validation/form_validators.dart frontend/test/core/validation/form_validators_test.dart
git commit -m "fix(ui): name the actual mistake in team/match number errors"
```

---

### Task 4: Cap digit entry on team-number and match-number fields

**Files:**
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:379-408` (setup page team/match fields)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart:371-400` (setup page team/match fields)
- Modify: `frontend/lib/presentation/screens/auth/team_select_screen.dart:1-6,139-148` (add import, add formatters)
- Modify: `frontend/test/presentation/screens/auth/team_select_screen_test.dart:59-77`

**Interfaces:**
- Consumes: `FormValidators.teamNumber`/`matchNumber`/`teamName` (unchanged signatures from Task 3).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Update the existing team_select_screen test that this change breaks**

`team_select_screen_test.dart`'s current test types `'Sushi Robotics'` (a non-numeric string) into the Team Number field to trigger `FormValidators.teamName`'s "must be 1-5 digits" message. Once the field only accepts digits, `'Sushi Robotics'` filters down to an empty string as it's typed, which trips the *different* "Team number is required" message instead — a real behavior change, not a broken test. Split it into two tests that match the new behavior:

Replace:

```dart
  testWidgets('rejects a non-numeric team name inline; does not call createTeam',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), 'Sushi Robotics');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsOneWidget);
    verifyNever(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    ));
  });
```

with:

```dart
  testWidgets('filters non-digit characters as they are typed',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), 'Sushi254Robotics');
    await tester.pumpAndSettle();

    expect(find.text('254'), findsOneWidget);
  });

  testWidgets('rejects a leading-zero team number inline; does not call createTeam',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsOneWidget);
    verifyNever(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    ));
  });

  testWidgets('rejects a 6-digit team number inline; does not call createTeam',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), '999999');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    // The 6th digit is blocked at entry, so the field holds '99999' — the
    // max valid value — and creation proceeds rather than failing.
    verify(mockTeamRepository.createTeam(
      name: '99999',
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    )).called(1);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd frontend && flutter test test/presentation/screens/auth/team_select_screen_test.dart`
Expected: FAIL — the field has no formatters yet, so `'Sushi254Robotics'` stays as-is (no `'254'` text found), `'0'` and `'999999'` both still reach the validator unfiltered.

- [ ] **Step 3: Add formatters to team_select_screen.dart**

In `frontend/lib/presentation/screens/auth/team_select_screen.dart`, add the services import:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

becomes:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

Then change the Team Number field:

```dart
          TextField(
            controller: _teamNameController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Team Number',
              hintText: 'e.g., 254',
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(),
            ),
          ),
```

to:

```dart
          TextField(
            controller: _teamNameController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: const InputDecoration(
              labelText: 'Team Number',
              hintText: 'e.g., 254',
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(),
            ),
          ),
```

- [ ] **Step 4: Run team_select_screen tests to verify they pass**

Run: `cd frontend && flutter test test/presentation/screens/auth/team_select_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Add the same caps to both scouting forms**

In `frontend/lib/presentation/screens/frc_rebuilt_form.dart`, in `_buildSetup`, change:

```dart
              child: TextFormField(
                controller: _matchNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "match #",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormValidators.matchNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: TextFormField(
                controller: _teamNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "team #",
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormValidators.teamNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
```

to:

```dart
              child: TextFormField(
                controller: _matchNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "match #",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: FormValidators.matchNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: TextFormField(
                controller: _teamNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "team #",
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: FormValidators.teamNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
```

Apply the identical replacement to `frontend/lib/presentation/screens/ftc_decode_form.dart`'s `_buildSetup` (its match#/team# fields are byte-for-byte the same shape).

- [ ] **Step 6: Run the full scouting-form test suite**

Run: `cd frontend && flutter test test/presentation/screens/frc_rebuilt_form_edit_test.dart test/presentation/screens/ftc_decode_form_edit_test.dart`
Expected: PASS — edit mode skips the setup page entirely, so these fields aren't exercised there; this confirms nothing else broke.

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/presentation/screens/auth/team_select_screen.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart frontend/test/presentation/screens/auth/team_select_screen_test.dart
git commit -m "fix(ui): stop team/match number fields from accepting invalid length"
```

---

### Task 5: Hold-to-repeat on the fuel/artifact counter buttons

**Files:**
- Modify: `frontend/lib/presentation/widgets/counter_card.dart`
- Test: `frontend/test/widgets/counter_card_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new for later tasks — this is a self-contained behavior change to `_CounterButton`.

- [ ] **Step 1: Write the failing tests**

In `frontend/test/widgets/counter_card_test.dart`, add (inside the `CounterCard` group, alongside the other button tests) — this needs `import 'package:flutter/gestures.dart';` added to the file's imports for `kLongPressTimeout`:

```dart
import 'package:flutter/gestures.dart';
```

```dart
    testWidgets('holding the increment button repeats once per second', (
      tester,
    ) async {
      int currentValue = 0;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) => currentValue = v,
          maxValue: 999,
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(kLongPressTimeout);
      await tester.pump(const Duration(seconds: 3));
      await gesture.up();
      await tester.pump();

      expect(currentValue, 3);
    });

    testWidgets('releasing the button stops the repeat', (tester) async {
      int currentValue = 0;

      await tester.pumpWidget(
        buildTestWidget(value: currentValue, onChanged: (v) => currentValue = v),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(kLongPressTimeout);
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(currentValue, 1);
    });

    testWidgets('a plain tap still increments by one, not by the repeat timer', (
      tester,
    ) async {
      int currentValue = 5;

      await tester.pumpWidget(
        buildTestWidget(value: currentValue, onChanged: (v) => currentValue = v),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentValue, 6);
    });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd frontend && flutter test test/widgets/counter_card_test.dart`
Expected: FAIL on the two new hold tests — `currentValue` stays `0`/never increments past the initial tap-driven case, since `_CounterButton` has no long-press handling yet.

- [ ] **Step 3: Add hold-to-repeat to `_CounterButton`**

In `frontend/lib/presentation/widgets/counter_card.dart`, add `import 'dart:async';` to the imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
```

becomes:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
```

Then replace the `_CounterButton` class:

```dart
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
```

with:

```dart
class _CounterButton extends StatefulWidget {
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
  State<_CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<_CounterButton> {
  Timer? _repeatTimer;

  // Reads `widget.onPressed` fresh on every tick rather than capturing it
  // once — the enclosing CounterCard rebuilds this widget with a new
  // onPressed closure (bound to the latest value) every time a step fires,
  // and Flutter updates `widget` on the existing State across that rebuild.
  // Capturing the callback in a local at press-start would keep calling the
  // stale, first-press value forever instead of incrementing.
  void _startRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      widget.onPressed?.call();
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final buttonColor = widget.accentColor ?? widget.colorScheme.onSurface;
    final edge = isEnabled ? buttonColor : widget.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          side: BorderSide(color: edge, width: AppTheme.ruleWidth),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          onLongPressStart: isEnabled ? (_) => _startRepeating() : null,
          onLongPressEnd: isEnabled ? (_) => _stopRepeating() : null,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(widget.icon, size: 28, color: edge),
          ),
        ),
      ),
    );
  }
}
```

The step-size buttons (`_StepControlButton`) are untouched — repeatedly changing the step size during a hold isn't a real use case (spec §2).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/widgets/counter_card_test.dart`
Expected: PASS (all tests, old and new)

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/widgets/counter_card.dart frontend/test/widgets/counter_card_test.dart
git commit -m "feat(ui): hold the fuel counter button to add continuously"
```

---

### Task 6: Expose live countdown and phase-change events from MatchTimer

**Files:**
- Modify: `frontend/lib/presentation/widgets/match_timer.dart`
- Test: `frontend/test/widgets/match_timer_test.dart`

**Interfaces:**
- Produces:
  - `MatchTimer.totalDurationSeconds` (`static const int`, value `153`) — used by Task 8's died-at-time editor to clamp its range.
  - `MatchTimerController.secondsRemaining` (`ValueNotifier<int>`) — used by Task 8 to read the live countdown on demand.
  - `MatchTimer(..., onPhaseChanged: ValueChanged<Color>?)` — used by Task 7 to trigger the phase-flash overlay.

- [ ] **Step 1: Write the failing tests**

In `frontend/test/widgets/match_timer_test.dart`, update `buildTestWidget` to accept the new callback, and add new test groups. Change:

```dart
    Widget buildTestWidget({
      MatchTimerController? controller,
      VoidCallback? onMatchFinished,
    }) {
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Test'),
            bottom: MatchTimer(
              controller: controller,
              onMatchFinished: onMatchFinished,
            ),
          ),
          body: const SizedBox(),
        ),
      );
    }
```

to:

```dart
    Widget buildTestWidget({
      MatchTimerController? controller,
      VoidCallback? onMatchFinished,
      ValueChanged<Color>? onPhaseChanged,
    }) {
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Test'),
            bottom: MatchTimer(
              controller: controller,
              onMatchFinished: onMatchFinished,
              onPhaseChanged: onPhaseChanged,
            ),
          ),
          body: const SizedBox(),
        ),
      );
    }
```

Then add, after the existing `MatchTimer` group's last test (`'can pause running timer'`) but still inside that `group('MatchTimer', ...)`:

```dart
    testWidgets('exposes the total duration as a public constant', (
      tester,
    ) async {
      expect(MatchTimer.totalDurationSeconds, 153);
    });

    testWidgets(
      'does not call onPhaseChanged for the initial PRE-MATCH -> AUTO transition',
      (tester) async {
        Color? flashed;
        await tester.pumpWidget(
          buildTestWidget(onPhaseChanged: (c) => flashed = c),
        );

        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();

        expect(flashed, isNull);
      },
    );

    testWidgets('calls onPhaseChanged when AUTO changes to TRANSITION', (
      tester,
    ) async {
      Color? flashed;
      await tester.pumpWidget(
        buildTestWidget(onPhaseChanged: (c) => flashed = c),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 15));

      expect(find.text('transition'), findsOneWidget);
      expect(flashed, isNotNull);
    });

    testWidgets('calls onPhaseChanged when reset returns the phase to PRE-MATCH', (
      tester,
    ) async {
      Color? flashed;
      await tester.pumpWidget(
        buildTestWidget(onPhaseChanged: (c) => flashed = c),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 1));
      flashed = null;

      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pump();

      expect(find.text('pre-match'), findsOneWidget);
      expect(flashed, isNotNull);
    });
```

And, inside `group('MatchTimerController', ...)`, add:

```dart
    test('secondsRemaining starts at the total match duration', () {
      final controller = MatchTimerController();
      expect(controller.secondsRemaining.value, MatchTimer.totalDurationSeconds);
    });
```

and, inside `group('MatchTimer', ...)`, add:

```dart
    testWidgets("controller's secondsRemaining updates as the timer ticks", (
      tester,
    ) async {
      final controller = MatchTimerController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 3));

      expect(
        controller.secondsRemaining.value,
        MatchTimer.totalDurationSeconds - 3,
      );
    });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd frontend && flutter test test/widgets/match_timer_test.dart`
Expected: FAIL — `onPhaseChanged` and `totalDurationSeconds` don't exist yet; `secondsRemaining` isn't defined on `MatchTimerController`.

- [ ] **Step 3: Hoist the total-duration constant and add the controller field**

In `frontend/lib/presentation/widgets/match_timer.dart`, change:

```dart
class MatchTimerController extends ChangeNotifier {
  void start() {
    notifyListeners();
  }
}

class MatchTimer extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onMatchFinished;
  final MatchTimerController? controller;

  const MatchTimer({super.key, this.onMatchFinished, this.controller});

  @override
  State<MatchTimer> createState() => _MatchTimerState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _MatchTimerState extends State<MatchTimer> {
  Timer? _timer;
  // 15s auto + 3s field-disabled transition + 2:15 teleop (incl. 30s endgame).
  int _secondsRemaining = 153;
  bool _isRunning = false;
  static const int _totalDuration = 153;
  static const int _autoDuration = 15;
  static const int _transitionDuration = 3;
```

to:

```dart
class MatchTimerController extends ChangeNotifier {
  /// The timer's live countdown, updated every tick. Lets an owning form
  /// read "how much time is left" on demand — for example to timestamp the
  /// moment a robot died — without polling MatchTimer's private state.
  final ValueNotifier<int> secondsRemaining = ValueNotifier<int>(
    MatchTimer.totalDurationSeconds,
  );

  void start() {
    notifyListeners();
  }

  @override
  void dispose() {
    secondsRemaining.dispose();
    super.dispose();
  }
}

class MatchTimer extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onMatchFinished;
  final MatchTimerController? controller;

  /// Fires once per phase change, after the match has started, with the
  /// color the new phase's chip renders in — the owning form uses this to
  /// drive a brief screen-edge flash. Does not fire for the initial
  /// PRE-MATCH -> AUTO transition (starting the match already has its own
  /// UI cue); does fire for every other transition, including a reset back
  /// to PRE-MATCH.
  final ValueChanged<Color>? onPhaseChanged;

  const MatchTimer({
    super.key,
    this.onMatchFinished,
    this.controller,
    this.onPhaseChanged,
  });

  /// Total match length: 15s auto + 3s field-disabled transition + 2:15
  /// teleop (including the 30s endgame window).
  static const int totalDurationSeconds = 153;

  @override
  State<MatchTimer> createState() => _MatchTimerState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _MatchTimerState extends State<MatchTimer> {
  Timer? _timer;
  int _secondsRemaining = MatchTimer.totalDurationSeconds;
  bool _isRunning = false;
  static const int _totalDuration = MatchTimer.totalDurationSeconds;
  static const int _autoDuration = 15;
  static const int _transitionDuration = 3;
  String? _lastNotifiedPhase;
```

- [ ] **Step 4: Sync the controller and notify phase changes on every tick**

In the same file, change `initState`:

```dart
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerStart);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerStart);
    _lastNotifiedPhase = _currentPhase;
    widget.controller?.secondsRemaining.value = _secondsRemaining;
  }

  /// Keeps [MatchTimerController.secondsRemaining] in sync and fires
  /// [MatchTimer.onPhaseChanged] when the phase actually changed since the
  /// last tick. Suppresses the notification when the *previous* phase was
  /// PRE-MATCH: that covers both the very first AUTO transition (no real
  /// change to announce yet) and every subsequent "start" after a reset,
  /// which get their own UI cue from pressing play. A reset landing back on
  /// PRE-MATCH from any other phase still notifies, matching every other
  /// phase change.
  void _syncControllerAndNotifyPhase() {
    widget.controller?.secondsRemaining.value = _secondsRemaining;
    final newPhase = _currentPhase;
    if (_lastNotifiedPhase != null &&
        _lastNotifiedPhase != newPhase &&
        _lastNotifiedPhase != "PRE-MATCH") {
      final brand = BrandScope.of(context);
      final colorScheme = Theme.of(context).colorScheme;
      widget.onPhaseChanged?.call(_phaseFill(brand, colorScheme));
    }
    _lastNotifiedPhase = newPhase;
  }
```

Then change `_startTimer`:

```dart
  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _stopTimer();
        AppHaptics.heavy();
        widget.onMatchFinished?.call();
      }
    });
  }
```

to:

```dart
  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _stopTimer();
        AppHaptics.heavy();
        widget.onMatchFinished?.call();
      }
      _syncControllerAndNotifyPhase();
    });
  }
```

And `_resetTimer`:

```dart
  void _resetTimer() {
    _stopTimer();
    AppHaptics.error();
    if (mounted) setState(() => _secondsRemaining = _totalDuration);
  }
```

to:

```dart
  void _resetTimer() {
    _stopTimer();
    AppHaptics.error();
    if (mounted) {
      setState(() => _secondsRemaining = _totalDuration);
      _syncControllerAndNotifyPhase();
    }
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd frontend && flutter test test/widgets/match_timer_test.dart`
Expected: PASS (all tests, old and new)

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/presentation/widgets/match_timer.dart frontend/test/widgets/match_timer_test.dart
git commit -m "feat(ui): expose match timer countdown and phase-change events"
```

---

### Task 7: Phase-flash overlay and back-button-to-previous-page, wired into both forms

**Files:**
- Modify: `frontend/lib/presentation/widgets/scouting_form_widget.dart` (add `PhaseFlashController`, `PhaseFlashOverlay`; add `onPhaseChanged` to `ScoutingFormBrandBand`)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart` (wire `PopScope` + `PhaseFlashOverlay`)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart` (same)
- Test: `frontend/test/widgets/scouting_form_widget_test.dart` (extend)
- Test: `frontend/test/presentation/screens/frc_rebuilt_form_test.dart` (new)
- Test: `frontend/test/presentation/screens/ftc_decode_form_test.dart` (new)

**Interfaces:**
- Consumes: `MatchTimer.onPhaseChanged` (Task 6).
- Produces: `PhaseFlashController extends ChangeNotifier { void flash(Color color); Color? get color; }` and `PhaseFlashOverlay({required PhaseFlashController controller, required Widget child})`, both in `scouting_form_widget.dart`. Not consumed by later tasks.

- [ ] **Step 1: Write the failing widget tests for the new overlay**

Append to `frontend/test/widgets/scouting_form_widget_test.dart`:

```dart
  group('PhaseFlashOverlay', () {
    testWidgets('shows no flash before controller.flash is called', (
      tester,
    ) async {
      final controller = PhaseFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('shows a colored glow once controller.flash is called', (
      tester,
    ) async {
      final controller = PhaseFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      );

      controller.flash(Colors.red);
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect(
        decoratedBoxes.any((box) {
          final decoration = box.decoration as BoxDecoration;
          return decoration.border?.top.color == Colors.red;
        }),
        isTrue,
      );
    });

    testWidgets('the glow ignores pointer events', (tester) async {
      final controller = PhaseFlashController();
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: Scaffold(
              body: GestureDetector(
                onTap: () => tapped = true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      controller.flash(Colors.red);
      await tester.pump();

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: FAIL — `PhaseFlashController`/`PhaseFlashOverlay` are undefined.

- [ ] **Step 3: Add `PhaseFlashController` and `PhaseFlashOverlay`**

In `frontend/lib/presentation/widgets/scouting_form_widget.dart`, add after the `ScoutingWizardBottomSlot` class from Task 2:

```dart
/// Drives [PhaseFlashOverlay]: call [flash] with a phase's color to trigger
/// a brief edge glow. Owned by the form screen, with the same lifecycle as
/// [MatchTimerController].
class PhaseFlashController extends ChangeNotifier {
  Color? _color;
  Color? get color => _color;

  void flash(Color color) {
    _color = color;
    notifyListeners();
  }
}

/// Wraps [child] with a brief colored edge glow whenever
/// [controller.flash] fires — the visual cue for a match-phase change. The
/// glow ignores pointer events, so it never blocks the form underneath.
class PhaseFlashOverlay extends StatefulWidget {
  final PhaseFlashController controller;
  final Widget child;

  const PhaseFlashOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<PhaseFlashOverlay> createState() => _PhaseFlashOverlayState();
}

class _PhaseFlashOverlayState extends State<PhaseFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleFlash);
  }

  void _handleFlash() {
    setState(() => _flashColor = widget.controller.color);
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleFlash);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_flashColor != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Opacity(
                opacity: 1.0 - _animation.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _flashColor!, width: 6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: PASS

- [ ] **Step 5: Plumb `onPhaseChanged` through `ScoutingFormBrandBand`**

In the same file, change:

```dart
class ScoutingFormBrandBand extends StatelessWidget
    implements PreferredSizeWidget {
  final MatchTimerController timerController;

  const ScoutingFormBrandBand({super.key, required this.timerController});

  @override
  Size get preferredSize => Size.fromHeight(
    MatchTimer(controller: timerController).preferredSize.height +
        AppTheme.colorBarThickness,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorBar(brand: BrandScope.of(context)),
        MatchTimer(controller: timerController),
      ],
    );
  }
}
```

to:

```dart
class ScoutingFormBrandBand extends StatelessWidget
    implements PreferredSizeWidget {
  final MatchTimerController timerController;
  final ValueChanged<Color>? onPhaseChanged;

  const ScoutingFormBrandBand({
    super.key,
    required this.timerController,
    this.onPhaseChanged,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    MatchTimer(controller: timerController).preferredSize.height +
        AppTheme.colorBarThickness,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorBar(brand: BrandScope.of(context)),
        MatchTimer(controller: timerController, onPhaseChanged: onPhaseChanged),
      ],
    );
  }
}
```

- [ ] **Step 6: Write the failing form-level tests**

Create `frontend/test/presentation/screens/frc_rebuilt_form_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/event.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/screens/frc_rebuilt_form.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _eventId = 'teamA_2026test';

final _event = Event(
  id: _eventId,
  name: '2026 Test Event',
  programType: 'FRC',
  tbaKey: '2026test',
  startDate: DateTime(2026, 7, 1),
  teamId: 'teamA',
);

/// Simulates the phone's hardware back button — the platform callback a
/// real device sends — as distinct from tapping an AppBar's back chevron.
/// `PopScope` intercepts this route-pop callback, which is exactly what
/// this task wires up.
Future<void> _pressHardwareBackButton(WidgetTester tester) async {
  final widgetsAppState = tester.state<dynamic>(find.byType(WidgetsApp));
  await widgetsAppState.didPopRoute();
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  // A single outer MaterialApp/Navigator with a button that pushes the form
  // as a route — needed so the hardware-back simulation pops the SAME
  // Navigator the form's PopScope sits in, rather than nesting a second,
  // independent MaterialApp/Navigator inside a pushed route.
  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(AppTheme.brandFor(null)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FrcRebuiltForm(eventId: _eventId, event: _event),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('FrcRebuiltForm back navigation', () {
    testWidgets(
      'the hardware back button moves to the previous page instead of closing the form',
      (tester) async {
        await tester.pumpWidget(await buildApp());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'scouter name'),
          'Test Scouter',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'match #'),
          '1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'team #'),
          '4198',
        );
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
        expect(find.text('autonomous'), findsOneWidget);

        await _pressHardwareBackButton(tester);
        await tester.pumpAndSettle();

        expect(find.text('setup'), findsOneWidget);
        expect(find.byType(FrcRebuiltForm), findsOneWidget);
      },
    );

    testWidgets(
      'the hardware back button exits the form from the first page',
      (tester) async {
        await tester.pumpWidget(await buildApp());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(FrcRebuiltForm), findsOneWidget);

        await _pressHardwareBackButton(tester);
        await tester.pumpAndSettle();

        expect(find.byType(FrcRebuiltForm), findsNothing);
      },
    );
  });
}
```

Create `frontend/test/presentation/screens/ftc_decode_form_test.dart` with the identical structure, substituting `FtcDecodeForm` for `FrcRebuiltForm`, `'FTC'` for `programType`, and `Event(... programType: 'FTC' ...)`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/event.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/screens/ftc_decode_form.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _eventId = 'teamA_2026ftctest';

final _event = Event(
  id: _eventId,
  name: '2026 FTC Test Event',
  programType: 'FTC',
  tbaKey: '2026ftctest',
  startDate: DateTime(2026, 7, 1),
  teamId: 'teamA',
);

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  Future<void> _pressHardwareBackButton(WidgetTester tester) async {
    final widgetsAppState = tester.state<dynamic>(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
  }

  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(AppTheme.brandFor(null)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FtcDecodeForm(eventId: _eventId, event: _event),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('FtcDecodeForm back navigation', () {
    testWidgets(
      'the hardware back button moves to the previous page instead of closing the form',
      (tester) async {
        await tester.pumpWidget(await buildApp());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'scouter name'),
          'Test Scouter',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'match #'),
          '1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'team #'),
          '12345',
        );
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
        expect(find.text('autonomous'), findsOneWidget);

        await _pressHardwareBackButton(tester);
        await tester.pumpAndSettle();

        expect(find.text('setup'), findsOneWidget);
        expect(find.byType(FtcDecodeForm), findsOneWidget);
      },
    );
  });
}
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `cd frontend && flutter test test/presentation/screens/frc_rebuilt_form_test.dart test/presentation/screens/ftc_decode_form_test.dart`
Expected: FAIL — with no `PopScope` yet, the simulated hardware back pops the pushed route unconditionally, so after `_pressHardwareBackButton` the form is gone and `find.text('setup')` finds nothing.

- [ ] **Step 8: Wire `PopScope` and `PhaseFlashOverlay` into `FrcRebuiltForm`**

In `frontend/lib/presentation/screens/frc_rebuilt_form.dart`, add the controller field next to the existing ones:

```dart
  final PageController _pageController = PageController();
  final MatchTimerController _timerController = MatchTimerController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
```

becomes:

```dart
  final PageController _pageController = PageController();
  final MatchTimerController _timerController = MatchTimerController();
  final PhaseFlashController _phaseFlashController = PhaseFlashController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
```

Add disposal in `dispose()`:

```dart
  @override
  void dispose() {
    _pageController.dispose();
    _timerController.dispose();
```

becomes:

```dart
  @override
  void dispose() {
    _pageController.dispose();
    _timerController.dispose();
    _phaseFlashController.dispose();
```

Then change `build()`:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return dismissKeyboardOnTap(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? "edit • ${widget.event.name}" : widget.event.name,
          ),
          // Brand band sits between the app bar and the timer, as in the
          // design — the scout screen was the one screen missing it.
          bottom: ScoutingFormBrandBand(timerController: _timerController),
        ),
        body: SafeArea(
```

to:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _prevPage();
      },
      child: dismissKeyboardOnTap(
        child: PhaseFlashOverlay(
          controller: _phaseFlashController,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditing ? "edit • ${widget.event.name}" : widget.event.name,
              ),
              // Brand band sits between the app bar and the timer, as in the
              // design — the scout screen was the one screen missing it.
              bottom: ScoutingFormBrandBand(
                timerController: _timerController,
                onPhaseChanged: _phaseFlashController.flash,
              ),
            ),
            body: SafeArea(
```

...and close the two newly-opened widgets at the end of `build()`. Change:

```dart
        bottomNavigationBar: _buildBottomBar(context, colorScheme),
      ),
    );
  }
```

to:

```dart
            bottomNavigationBar: _buildBottomBar(context, colorScheme),
          ),
        ),
      ),
    );
  }
```

Every line strictly between the opening `AppBar(` and the closing `bottomNavigationBar:` (i.e. `body: SafeArea(...)` and everything it contains) needs its indentation increased by 4 spaces to match the two new wrapping widgets — a plain re-indent, no logic change. Run `dart format lib/presentation/screens/frc_rebuilt_form.dart` after this edit to normalize it exactly, rather than hand-indenting every line.

- [ ] **Step 9: Apply the identical wiring to `FtcDecodeForm`**

Repeat step 8's four edits verbatim in `frontend/lib/presentation/screens/ftc_decode_form.dart` — its `dispose()`, field declarations, and `build()` are byte-for-byte the same shape as FRC's. Run `dart format lib/presentation/screens/ftc_decode_form.dart` afterward too.

- [ ] **Step 10: Run tests to verify they pass**

Run: `cd frontend && flutter test test/presentation/screens/frc_rebuilt_form_test.dart test/presentation/screens/ftc_decode_form_test.dart test/presentation/screens/frc_rebuilt_form_edit_test.dart test/presentation/screens/ftc_decode_form_edit_test.dart`
Expected: PASS

- [ ] **Step 11: Run `flutter analyze` to catch any indentation/formatting drift**

Run: `cd frontend && flutter analyze`
Expected: no new warnings introduced by this task.

- [ ] **Step 12: Commit**

```bash
git add frontend/lib/presentation/widgets/scouting_form_widget.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart frontend/test/widgets/scouting_form_widget_test.dart frontend/test/presentation/screens/frc_rebuilt_form_test.dart frontend/test/presentation/screens/ftc_decode_form_test.dart
git commit -m "feat(ui): flash on match-phase change, back button steps to previous page"
```

---

### Task 8: Robot died/disabled — capture and edit the time, add a reason field

**Files:**
- Modify: `frontend/lib/data/models/match_report.dart` (new getters)
- Modify: `frontend/lib/presentation/widgets/scouting_form_widget.dart` (new `RobotDiedTimeAndReason` widget)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart` (state, UI, submit, restore)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart` (same)
- Test: `frontend/test/unit/models/match_report_test.dart`
- Test: `frontend/test/widgets/scouting_form_widget_test.dart` (extend)
- Test: `frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart` (extend)
- Test: `frontend/test/presentation/screens/ftc_decode_form_edit_test.dart` (extend)

**Interfaces:**
- Consumes: `MatchTimer.totalDurationSeconds`, `MatchTimerController.secondsRemaining` (Task 6).
- Produces: `MatchReport.diedAtSeconds` (`int?`), `MatchReport.diedReason` (`String`) — consumed by Task 10's Sheets export.

- [ ] **Step 1: Write the failing MatchReport tests**

In `frontend/test/unit/models/match_report_test.dart`, add a new test inside the `MatchReport` group:

```dart
    test('diedAtSeconds and diedReason default when absent, read back when present', () {
      final withoutDeath = MatchReport(
        id: 'm1',
        matchId: 'qm1',
        matchNumber: 1,
        teamNumber: 1,
        alliance: 'Red',
        scouterName: 'Scouter',
        gameData: const {},
        createdAt: DateTime.now(),
      );
      expect(withoutDeath.diedAtSeconds, isNull);
      expect(withoutDeath.diedReason, '');

      final withDeath = MatchReport(
        id: 'm2',
        matchId: 'qm2',
        matchNumber: 2,
        teamNumber: 2,
        alliance: 'Blue',
        scouterName: 'Scouter',
        gameData: const {'died_at_seconds': 42, 'died_reason': 'tipped over'},
        createdAt: DateTime.now(),
      );
      expect(withDeath.diedAtSeconds, 42);
      expect(withDeath.diedReason, 'tipped over');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart`
Expected: FAIL — `diedAtSeconds`/`diedReason` are undefined getters.

- [ ] **Step 3: Add the getters**

In `frontend/lib/data/models/match_report.dart`, change:

```dart
  // Common
  bool get robotDied => gameData['robot_died'] ?? false;
  bool get isFtc => programType == 'FTC' || gameData.containsKey('artifacts_auto');
```

to:

```dart
  // Common
  bool get robotDied => gameData['robot_died'] ?? false;
  bool get isFtc => programType == 'FTC' || gameData.containsKey('artifacts_auto');
  int? get diedAtSeconds => gameData['died_at_seconds'] as int?;
  String get diedReason => gameData['died_reason'] ?? '';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart`
Expected: PASS

- [ ] **Step 5: Write the failing widget test for the shared control**

Append to `frontend/test/widgets/scouting_form_widget_test.dart`:

```dart
  group('RobotDiedTimeAndReason', () {
    testWidgets('shows a "mark now" button when no time is set yet', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(120);
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: null,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (s) => captured = s,
              reasonController: TextEditingController(),
            ),
          ),
        ),
      );

      expect(find.text('mark now'), findsOneWidget);

      await tester.tap(find.text('mark now'));
      await tester.pump();

      expect(captured, 120);
    });

    testWidgets('shows the formatted mm:ss once a time is set', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(90);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: 65,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (_) {},
              reasonController: TextEditingController(),
            ),
          ),
        ),
      );

      expect(find.textContaining('1:05'), findsOneWidget);
    });

    testWidgets('reason text field forwards input to its controller', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(120);
      final reasonController = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: 100,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (_) {},
              reasonController: reasonController,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'defense collision');
      expect(reasonController.text, 'defense collision');
    });
  });
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: FAIL — `RobotDiedTimeAndReason` is undefined.

- [ ] **Step 7: Add the shared `RobotDiedTimeAndReason` widget**

In `frontend/lib/presentation/widgets/scouting_form_widget.dart`, add near the top-level imports:

```dart
import 'match_timer.dart';
```

is already present; also add:

```dart
import '../theme/app_theme.dart';
```

is already present. Then add the widget after `PhaseFlashOverlay`'s state class:

```dart
/// The "mark now"/edit control and reason field shown under the Robot
/// Died toggle on both forms' teleop page. Shared so the two copies can't
/// drift.
class RobotDiedTimeAndReason extends StatelessWidget {
  final int? diedAtSeconds;
  final ValueListenable<int> liveSecondsRemaining;
  final ValueChanged<int> onDiedAtSecondsChanged;
  final TextEditingController reasonController;

  const RobotDiedTimeAndReason({
    super.key,
    required this.diedAtSeconds,
    required this.liveSecondsRemaining,
    required this.onDiedAtSecondsChanged,
    required this.reasonController,
  });

  static String formatMmSs(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _editTime(BuildContext context) async {
    final current = diedAtSeconds ?? liveSecondsRemaining.value;
    final minutesCtrl = TextEditingController(text: '${current ~/ 60}');
    final secondsCtrl = TextEditingController(text: '${current % 60}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('set died/disabled time'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'min'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: TextField(
                controller: secondsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'sec'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('cancel'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(minutesCtrl.text) ?? 0;
              final seconds = int.tryParse(secondsCtrl.text) ?? 0;
              final total = (minutes * 60 + seconds).clamp(
                0,
                MatchTimer.totalDurationSeconds,
              );
              Navigator.pop(ctx, total);
            },
            child: const Text('set'),
          ),
        ],
      ),
    );
    if (result != null) onDiedAtSecondsChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diedAtSeconds == null)
          OutlinedButton.icon(
            icon: const Icon(Icons.timer_outlined),
            label: const Text('mark now'),
            onPressed: () => onDiedAtSecondsChanged(liveSecondsRemaining.value),
          )
        else
          InkWell(
            onTap: () => _editTime(context),
            child: Chip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: Text('died at ${formatMmSs(diedAtSeconds!)}'),
            ),
          ),
        const SizedBox(height: AppTheme.spacingSm),
        TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
```

This needs `import 'package:flutter/foundation.dart';` for `ValueListenable` — add it if not already transitively available; check the top of the file first, and add it only if `flutter analyze` (step 9) flags it missing.

- [ ] **Step 8: Run test to verify it passes**

Run: `cd frontend && flutter test test/widgets/scouting_form_widget_test.dart`
Expected: PASS

- [ ] **Step 9: Wire the control into `FrcRebuiltForm`**

Add state fields next to the existing qualitative fields:

```dart
  // Qualitative
  int _defense = 0;
  int _skill = 0;
  bool _died = false;
  final _commentsCtrl = TextEditingController();
```

becomes:

```dart
  // Qualitative
  int _defense = 0;
  int _skill = 0;
  bool _died = false;
  int? _diedAtSeconds;
  final _diedReasonCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
```

Restore from an existing match, in `initState`:

```dart
      _died = existing.robotDied;
      _commentsCtrl.text = existing.comments;
```

becomes:

```dart
      _died = existing.robotDied;
      _diedAtSeconds = existing.diedAtSeconds;
      _diedReasonCtrl.text = existing.diedReason;
      _commentsCtrl.text = existing.comments;
```

Dispose:

```dart
    _scouterNameCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
```

becomes:

```dart
    _scouterNameCtrl.dispose();
    _diedReasonCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
```

In `_buildTeleop`, change the died-toggle `Card`:

```dart
        Card(
          color: _died
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : null,
          child: CheckboxListTile(
            title: Text(
              "Robot Died / Disabled",
              style: TextStyle(color: _died ? colorScheme.error : null),
            ),
            subtitle: const Text("Robot was inactive during match"),
            value: _died,
            onChanged: (v) => setState(() => _died = v!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
```

to:

```dart
        Card(
          color: _died
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : null,
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(
                  "Robot Died / Disabled",
                  style: TextStyle(color: _died ? colorScheme.error : null),
                ),
                subtitle: const Text("Robot was inactive during match"),
                value: _died,
                onChanged: (v) => setState(() => _died = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_died)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                  ),
                  child: RobotDiedTimeAndReason(
                    diedAtSeconds: _diedAtSeconds,
                    liveSecondsRemaining: _timerController.secondsRemaining,
                    onDiedAtSecondsChanged: (s) =>
                        setState(() => _diedAtSeconds = s),
                    reasonController: _diedReasonCtrl,
                  ),
                ),
            ],
          ),
        ),
```

In `_submit`, add to the `gameData` map:

```dart
      'robot_died': _died,
```

becomes:

```dart
      'robot_died': _died,
      'died_at_seconds': _diedAtSeconds,
      'died_reason': _diedReasonCtrl.text,
```

In `_buildReview`, add a row inside the `if (_died) ...` block, right after the "Robot Died" `Container`:

```dart
                if (_died) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          "Robot Died",
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
```

to:

```dart
                if (_died) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          "Robot Died",
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_diedAtSeconds != null)
                    _ReviewRow(
                      label: "Died At",
                      value: RobotDiedTimeAndReason.formatMmSs(_diedAtSeconds!),
                    ),
                ],
```

- [ ] **Step 10: Apply the identical wiring to `FtcDecodeForm`**

Repeat step 9's edits verbatim in `frontend/lib/presentation/screens/ftc_decode_form.dart`, with one name substitution: FTC's died flag is `_robotDied`, not `_died` (its state field, `initState` restore, `_buildTeleop` toggle, `_submit` gameData key, and `_buildReview` block all use `_robotDied` already — apply the same shape of change, using `_robotDied` everywhere this plan's FRC snippets say `_died`).

- [ ] **Step 11: Extend the edit-mode tests for both forms**

In `frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart`, add a new test inside `group('FrcRebuiltForm edit mode', ...)`:

```dart
    testWidgets(
      'restores a saved died-at time and reason, and lets the scout edit the reason',
      (tester) async {
        final match = _frcMatch();
        final diedMatch = match.copyWith(
          gameData: {
            ...match.gameData,
            'robot_died': true,
            'died_at_seconds': 65,
            'died_reason': 'tipped over on the ramp',
          },
        );

        await tester.pumpWidget(await buildForm(existingMatch: diedMatch));
        await tester.pumpAndSettle();

        // Edit mode's 4 pages are autonomous(0) -> teleop(1) -> endgame(2)
        // -> review(3) — one tap of "next" from the initial page reaches
        // teleop, where the Robot Died toggle and this control live. (Task
        // 9's sibling tests tap twice because their assertions target the
        // endgame page instead.)
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1:05'), findsOneWidget);
        expect(find.text('tipped over on the ramp'), findsOneWidget);
      },
    );
```

In `frontend/test/presentation/screens/ftc_decode_form_edit_test.dart`, add the equivalent test using that file's existing fixture function (find its match-builder helper, e.g. `_ftcMatch()`, and follow the same `gameData` override pattern) — same assertions, but tap `next` **once**, not the 3 times this file's other tests use to reach `review`. FTC's edit-mode pages are the same order as FRC's — autonomous(0) -> teleop(1) -> endgame(2) -> review(3) — and the Robot Died toggle and this control live on teleop, one tap in.

- [ ] **Step 12: Run tests to verify they pass**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart test/widgets/scouting_form_widget_test.dart test/presentation/screens/frc_rebuilt_form_edit_test.dart test/presentation/screens/ftc_decode_form_edit_test.dart`
Expected: PASS

- [ ] **Step 13: Run `flutter analyze`**

Run: `cd frontend && flutter analyze`
Expected: no new warnings.

- [ ] **Step 14: Commit**

```bash
git add frontend/lib/data/models/match_report.dart frontend/lib/presentation/widgets/scouting_form_widget.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart frontend/test/unit/models/match_report_test.dart frontend/test/widgets/scouting_form_widget_test.dart frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart frontend/test/presentation/screens/ftc_decode_form_edit_test.dart
git commit -m "feat(ui): capture and edit the robot died/disabled time and reason"
```

---

### Task 9: Subsystem speed sliders, FTC defense rating, and the defense-cause switch

**Files:**
- Modify: `frontend/lib/data/models/match_report.dart` (new getters)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart`
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart`
- Test: `frontend/test/unit/models/match_report_test.dart`
- Test: `frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart`
- Test: `frontend/test/presentation/screens/ftc_decode_form_edit_test.dart`

**Interfaces:**
- Produces: `MatchReport.drivetrainSpeed`, `.intakeSpeed`, `.shooterSpeed` (`int`), `.defenseCause` (`String?`) — consumed by Task 10. `MatchReport.defenseRating` already exists and needs no change; FTC just starts writing the `defense_rating` key.

- [ ] **Step 1: Write the failing MatchReport tests**

In `frontend/test/unit/models/match_report_test.dart`, add:

```dart
    test('subsystem speed and defense-cause getters default when absent, read back when present', () {
      final defaults = MatchReport(
        id: 'm3',
        matchId: 'qm3',
        matchNumber: 3,
        teamNumber: 3,
        alliance: 'Red',
        scouterName: 'Scouter',
        gameData: const {},
        createdAt: DateTime.now(),
      );
      expect(defaults.drivetrainSpeed, 0);
      expect(defaults.intakeSpeed, 0);
      expect(defaults.shooterSpeed, 0);
      expect(defaults.defenseCause, isNull);

      final populated = MatchReport(
        id: 'm4',
        matchId: 'qm4',
        matchNumber: 4,
        teamNumber: 4,
        alliance: 'Blue',
        scouterName: 'Scouter',
        gameData: const {
          'drivetrain_speed': 4,
          'intake_speed': 3,
          'shooter_speed': 5,
          'defense_cause': 'strategic',
        },
        createdAt: DateTime.now(),
      );
      expect(populated.drivetrainSpeed, 4);
      expect(populated.intakeSpeed, 3);
      expect(populated.shooterSpeed, 5);
      expect(populated.defenseCause, 'strategic');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart`
Expected: FAIL — the new getters are undefined.

- [ ] **Step 3: Add the getters**

In `frontend/lib/data/models/match_report.dart`, change:

```dart
  int get defenseRating => gameData['defense_rating'] ?? 0;
  int get driverSkill => gameData['driver_skill'] ?? 0;
```

to:

```dart
  int get defenseRating => gameData['defense_rating'] ?? 0;
  int get driverSkill => gameData['driver_skill'] ?? 0;
  int get drivetrainSpeed => gameData['drivetrain_speed'] ?? 0;
  int get intakeSpeed => gameData['intake_speed'] ?? 0;
  int get shooterSpeed => gameData['shooter_speed'] ?? 0;
  String? get defenseCause => gameData['defense_cause'] as String?;
```

(`defenseRating` already lives here despite sitting under the "FRC getters" comment — it's shared, so FTC reading/writing it needs no new getter.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart`
Expected: PASS

- [ ] **Step 5: Add the sliders and defense-cause switch to `FrcRebuiltForm`**

Add state fields:

```dart
  // Qualitative
  int _defense = 0;
  int _skill = 0;
  bool _died = false;
  int? _diedAtSeconds;
  final _diedReasonCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
```

becomes:

```dart
  // Qualitative
  int _defense = 0;
  int _skill = 0;
  String? _defenseCause;
  int _drivetrainSpeed = 0;
  int _intakeSpeed = 0;
  int _shooterSpeed = 0;
  bool _died = false;
  int? _diedAtSeconds;
  final _diedReasonCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
```

Restore from an existing match, in `initState`:

```dart
      _defense = existing.defenseRating;
      _skill = existing.driverSkill;
```

becomes:

```dart
      _defense = existing.defenseRating;
      _skill = existing.driverSkill;
      _defenseCause = existing.defenseCause;
      _drivetrainSpeed = existing.drivetrainSpeed;
      _intakeSpeed = existing.intakeSpeed;
      _shooterSpeed = existing.shooterSpeed;
```

In `_buildEndgame`, change:

```dart
        _buildSlider(
          context,
          label: "Defense Rating",
          value: _defense,
          onChanged: (v) => setState(() => _defense = v),
        ),

        _buildSlider(
          context,
          label: "Driver Skill",
          value: _skill,
          onChanged: (v) => setState(() => _skill = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),
```

to:

```dart
        _buildSlider(
          context,
          label: "Defense Rating",
          value: _defense,
          onChanged: (v) => setState(() => _defense = v),
        ),

        if (_defense > 0) ...[
          Text(
            "cause of defense",
            style: theme.textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'broke', label: Text('robot broke')),
              ButtonSegment(value: 'strategic', label: Text('strategic')),
            ],
            selected: _defenseCause == null ? const {} : {_defenseCause!},
            emptySelectionAllowed: true,
            onSelectionChanged: (val) => setState(
              () => _defenseCause = val.isEmpty ? null : val.first,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        _buildSlider(
          context,
          label: "Driver Skill",
          value: _skill,
          onChanged: (v) => setState(() => _skill = v),
        ),

        _buildSlider(
          context,
          label: "Drivetrain Speed",
          value: _drivetrainSpeed,
          onChanged: (v) => setState(() => _drivetrainSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Intake Speed",
          value: _intakeSpeed,
          onChanged: (v) => setState(() => _intakeSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Shooter Speed",
          value: _shooterSpeed,
          onChanged: (v) => setState(() => _shooterSpeed = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),
```

In `_submit`, add to `gameData`:

```dart
      'defense_rating': _defense,
      'driver_skill': _skill,
```

becomes:

```dart
      'defense_rating': _defense,
      'defense_cause': _defenseCause,
      'driver_skill': _skill,
      'drivetrain_speed': _drivetrainSpeed,
      'intake_speed': _intakeSpeed,
      'shooter_speed': _shooterSpeed,
```

In `_buildReview`, add rows next to the existing Defense/Driver Skill rows:

```dart
                _ReviewRow(label: "Defense", value: "$_defense/5"),
                _ReviewRow(label: "Driver Skill", value: "$_skill/5"),
```

to:

```dart
                _ReviewRow(label: "Defense", value: "$_defense/5"),
                if (_defenseCause != null)
                  _ReviewRow(
                    label: "Defense Cause",
                    value: _defenseCause == 'broke' ? "Robot Broke" : "Strategic",
                  ),
                _ReviewRow(label: "Driver Skill", value: "$_skill/5"),
                _ReviewRow(label: "Drivetrain Speed", value: "$_drivetrainSpeed/5"),
                _ReviewRow(label: "Intake Speed", value: "$_intakeSpeed/5"),
                _ReviewRow(label: "Shooter Speed", value: "$_shooterSpeed/5"),
```

- [ ] **Step 6: Apply the equivalent change to `FtcDecodeForm`, adding Defense Rating from scratch**

FTC has no Defense Rating today. Add state fields:

```dart
  // Endgame
  String _baseExpansion = 'None';
  double _driverQuality = 0;
  final _commentsCtrl = TextEditingController();
```

becomes:

```dart
  // Endgame
  String _baseExpansion = 'None';
  double _driverQuality = 0;
  int _defenseRating = 0;
  String? _defenseCause;
  int _drivetrainSpeed = 0;
  int _intakeSpeed = 0;
  int _shooterSpeed = 0;
  final _commentsCtrl = TextEditingController();
```

Restore from an existing match, in `initState`:

```dart
      _baseExpansion = existing.baseExpansion;
      _driverQuality = existing.driverQuality;
```

becomes:

```dart
      _baseExpansion = existing.baseExpansion;
      _driverQuality = existing.driverQuality;
      _defenseRating = existing.defenseRating;
      _defenseCause = existing.defenseCause;
      _drivetrainSpeed = existing.drivetrainSpeed;
      _intakeSpeed = existing.intakeSpeed;
      _shooterSpeed = existing.shooterSpeed;
```

In `_buildEndgame`, change:

```dart
        Text("Qualitative Metrics", style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingMd),

        _buildSlider(
          context,
          label: "Driver Quality",
          value: _driverQuality.toInt(),
          onChanged: (v) => setState(() => _driverQuality = v.toDouble()),
        ),

        const SizedBox(height: AppTheme.spacingMd),
```

to:

```dart
        Text("Qualitative Metrics", style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingMd),

        _buildSlider(
          context,
          label: "Driver Quality",
          value: _driverQuality.toInt(),
          onChanged: (v) => setState(() => _driverQuality = v.toDouble()),
        ),

        _buildSlider(
          context,
          label: "Defense Rating",
          value: _defenseRating,
          onChanged: (v) => setState(() => _defenseRating = v),
        ),

        if (_defenseRating > 0) ...[
          Text(
            "cause of defense",
            style: theme.textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'broke', label: Text('robot broke')),
              ButtonSegment(value: 'strategic', label: Text('strategic')),
            ],
            selected: _defenseCause == null ? const {} : {_defenseCause!},
            emptySelectionAllowed: true,
            onSelectionChanged: (val) => setState(
              () => _defenseCause = val.isEmpty ? null : val.first,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        _buildSlider(
          context,
          label: "Drivetrain Speed",
          value: _drivetrainSpeed,
          onChanged: (v) => setState(() => _drivetrainSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Intake Speed",
          value: _intakeSpeed,
          onChanged: (v) => setState(() => _intakeSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Shooter Speed",
          value: _shooterSpeed,
          onChanged: (v) => setState(() => _shooterSpeed = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),
```

In `_submit`, add to `gameData`:

```dart
      'base_expansion': _baseExpansion,
      'driver_quality': _driverQuality,
      'robot_died': _robotDied,
```

becomes:

```dart
      'base_expansion': _baseExpansion,
      'driver_quality': _driverQuality,
      'defense_rating': _defenseRating,
      'defense_cause': _defenseCause,
      'drivetrain_speed': _drivetrainSpeed,
      'intake_speed': _intakeSpeed,
      'shooter_speed': _shooterSpeed,
      'robot_died': _robotDied,
```

In `_buildReview`, add rows next to Driver Quality:

```dart
                _ReviewRow(label: "Base Expansion", value: _baseExpansion),
                _ReviewRow(
                  label: "Driver Quality",
                  value: "${_driverQuality.toInt()}/5",
                ),
```

to:

```dart
                _ReviewRow(label: "Base Expansion", value: _baseExpansion),
                _ReviewRow(
                  label: "Driver Quality",
                  value: "${_driverQuality.toInt()}/5",
                ),
                _ReviewRow(label: "Defense Rating", value: "$_defenseRating/5"),
                if (_defenseCause != null)
                  _ReviewRow(
                    label: "Defense Cause",
                    value: _defenseCause == 'broke' ? "Robot Broke" : "Strategic",
                  ),
                _ReviewRow(label: "Drivetrain Speed", value: "$_drivetrainSpeed/5"),
                _ReviewRow(label: "Intake Speed", value: "$_intakeSpeed/5"),
                _ReviewRow(label: "Shooter Speed", value: "$_shooterSpeed/5"),
```

- [ ] **Step 7: Extend the edit-mode tests for both forms**

In `frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart`, add:

```dart
    testWidgets(
      'restores subsystem speeds and defense cause, and lets the scout change them',
      (tester) async {
        final match = _frcMatch();
        final tunedMatch = match.copyWith(
          gameData: {
            ...match.gameData,
            'defense_rating': 3,
            'defense_cause': 'strategic',
            'drivetrain_speed': 2,
            'intake_speed': 4,
            'shooter_speed': 5,
          },
        );

        await tester.pumpWidget(await buildForm(existingMatch: tunedMatch));
        await tester.pumpAndSettle();

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }

        expect(find.text('robot broke'), findsOneWidget);
        expect(find.text('strategic'), findsOneWidget);
        expect(find.text('Drivetrain Speed'), findsOneWidget);
        expect(find.text('Intake Speed'), findsOneWidget);
        expect(find.text('Shooter Speed'), findsOneWidget);
      },
    );
```

In `frontend/test/presentation/screens/ftc_decode_form_edit_test.dart`, add the equivalent test using that file's fixture helper, additionally asserting `find.text('Defense Rating')` now appears (it didn't exist on FTC before this task).

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd frontend && flutter test test/unit/models/match_report_test.dart test/presentation/screens/frc_rebuilt_form_edit_test.dart test/presentation/screens/ftc_decode_form_edit_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full Dart suite and `flutter analyze`**

Run: `cd frontend && flutter test && flutter analyze`
Expected: all tests PASS, no new analyzer warnings.

- [ ] **Step 10: Commit**

```bash
git add frontend/lib/data/models/match_report.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart frontend/test/unit/models/match_report_test.dart frontend/test/presentation/screens/frc_rebuilt_form_edit_test.dart frontend/test/presentation/screens/ftc_decode_form_edit_test.dart
git commit -m "feat(ui): add subsystem speed sliders and defense-cause switch"
```

---

### Task 10: Sheets export — add the new columns for FRC and FTC

**Files:**
- Modify: `functions/services/sheets_service.py`
- Modify: `functions/tests/test_sheets_service.py`

**Interfaces:**
- Consumes: the `gameData` keys from Tasks 8 and 9 (`died_at_seconds`, `died_reason`, `drivetrain_speed`, `intake_speed`, `shooter_speed`, `defense_cause`, and FTC's new `defense_rating`).
- Produces: nothing consumed by a later task — this is the last content task.

- [ ] **Step 1: Update the pinned header/row tests to the new column layout**

In `functions/tests/test_sheets_service.py`, change:

```python
    def test_frc_headers(self):
        """Test that FRC headers match the 19-column schema."""
        self.assertEqual(len(FRC_HEADERS), 19)
        self.assertEqual(FRC_HEADERS[0], "Timestamp")
        self.assertEqual(FRC_HEADERS[1], "Match ID")
        self.assertEqual(FRC_HEADERS[6], "Auto Fuel")
        self.assertEqual(FRC_HEADERS[13], "Trench Traverse")
        self.assertEqual(FRC_HEADERS[18], "Comments")

    def test_ftc_headers(self):
        """Test that FTC headers match the 15-column schema."""
        self.assertEqual(len(FTC_HEADERS), 15)
        self.assertEqual(FTC_HEADERS[0], "Timestamp")
        self.assertEqual(FTC_HEADERS[6], "Leave")
        self.assertEqual(FTC_HEADERS[7], "Auto Artifacts")
        self.assertEqual(FTC_HEADERS[11], "Base Expansion")
        self.assertEqual(FTC_HEADERS[14], "Comments")
```

to:

```python
    def test_frc_headers(self):
        """Test that FRC headers match the 25-column schema."""
        self.assertEqual(len(FRC_HEADERS), 25)
        self.assertEqual(FRC_HEADERS[0], "Timestamp")
        self.assertEqual(FRC_HEADERS[1], "Match ID")
        self.assertEqual(FRC_HEADERS[6], "Auto Fuel")
        self.assertEqual(FRC_HEADERS[13], "Trench Traverse")
        self.assertEqual(FRC_HEADERS[18], "Drivetrain Speed")
        self.assertEqual(FRC_HEADERS[19], "Intake Speed")
        self.assertEqual(FRC_HEADERS[20], "Shooter Speed")
        self.assertEqual(FRC_HEADERS[21], "Defense Cause")
        self.assertEqual(FRC_HEADERS[22], "Died At")
        self.assertEqual(FRC_HEADERS[23], "Died Reason")
        self.assertEqual(FRC_HEADERS[24], "Comments")

    def test_ftc_headers(self):
        """Test that FTC headers match the 22-column schema."""
        self.assertEqual(len(FTC_HEADERS), 22)
        self.assertEqual(FTC_HEADERS[0], "Timestamp")
        self.assertEqual(FTC_HEADERS[6], "Leave")
        self.assertEqual(FTC_HEADERS[7], "Auto Artifacts")
        self.assertEqual(FTC_HEADERS[11], "Base Expansion")
        self.assertEqual(FTC_HEADERS[14], "Defense Rating")
        self.assertEqual(FTC_HEADERS[15], "Drivetrain Speed")
        self.assertEqual(FTC_HEADERS[16], "Intake Speed")
        self.assertEqual(FTC_HEADERS[17], "Shooter Speed")
        self.assertEqual(FTC_HEADERS[18], "Defense Cause")
        self.assertEqual(FTC_HEADERS[19], "Died At")
        self.assertEqual(FTC_HEADERS[20], "Died Reason")
        self.assertEqual(FTC_HEADERS[21], "Comments")
```

Then change `test_transform_frc_report`:

```python
        report_data = {
            'matchId': 'qm1_254',
            'matchNumber': 1,
            'teamNumber': 254,
            'alliance': 'Red',
            'scouterName': 'Test Scouter',
            'gameData': {
                'auto_fuel': 5,
                'auto_tower_l1': True,
                'teleop_fuel': 15,
                'teleop_tower_level': 3,
                'defense_rating': 3,
                'driver_skill': 4,
                'robot_died': False,
                'trench_traverse': True,
                'bump_traverse': False,
                'shooting_range_close': True,
                'shooting_range_mid': False,
                'shooting_range_far': False,
            },
            'comments': 'Great performance',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FRC_HEADERS))  # 19 columns
        self.assertEqual(result[1], 'qm1_254')       # Match ID
        self.assertEqual(result[2], 1)                 # Match #
        self.assertEqual(result[3], 254)               # Team #
        self.assertEqual(result[4], 'Red')             # Alliance
        self.assertEqual(result[5], 'Test Scouter')    # Scouter
        self.assertEqual(result[6], 5)                 # Auto Fuel
        self.assertEqual(result[7], 'Yes')             # Auto L1 Hang
        self.assertEqual(result[8], 15)                # Teleop Fuel
        self.assertEqual(result[9], 'Level 3')         # Climb Level
        self.assertEqual(result[10], '3/5')            # Defense Rating
        self.assertEqual(result[11], '4/5')            # Driver Skill
        self.assertEqual(result[12], 'No')             # Robot Died
        self.assertEqual(result[13], 'Yes')            # Trench Traverse
        self.assertEqual(result[14], 'No')             # Bump Traverse
        self.assertEqual(result[15], 'Yes')            # Shooting Close
        self.assertEqual(result[16], 'No')             # Shooting Mid
        self.assertEqual(result[17], 'No')             # Shooting Far
        self.assertEqual(result[18], 'Great performance')  # Comments
```

to:

```python
        report_data = {
            'matchId': 'qm1_254',
            'matchNumber': 1,
            'teamNumber': 254,
            'alliance': 'Red',
            'scouterName': 'Test Scouter',
            'gameData': {
                'auto_fuel': 5,
                'auto_tower_l1': True,
                'teleop_fuel': 15,
                'teleop_tower_level': 3,
                'defense_rating': 3,
                'driver_skill': 4,
                'robot_died': True,
                'trench_traverse': True,
                'bump_traverse': False,
                'shooting_range_close': True,
                'shooting_range_mid': False,
                'shooting_range_far': False,
                'drivetrain_speed': 4,
                'intake_speed': 2,
                'shooter_speed': 5,
                'defense_cause': 'broke',
                'died_at_seconds': 65,
                'died_reason': 'tipped on the ramp',
            },
            'comments': 'Great performance',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FRC_HEADERS))  # 25 columns
        self.assertEqual(result[1], 'qm1_254')       # Match ID
        self.assertEqual(result[2], 1)                 # Match #
        self.assertEqual(result[3], 254)               # Team #
        self.assertEqual(result[4], 'Red')             # Alliance
        self.assertEqual(result[5], 'Test Scouter')    # Scouter
        self.assertEqual(result[6], 5)                 # Auto Fuel
        self.assertEqual(result[7], 'Yes')             # Auto L1 Hang
        self.assertEqual(result[8], 15)                # Teleop Fuel
        self.assertEqual(result[9], 'Level 3')         # Climb Level
        self.assertEqual(result[10], '3/5')            # Defense Rating
        self.assertEqual(result[11], '4/5')            # Driver Skill
        self.assertEqual(result[12], 'Yes')            # Robot Died
        self.assertEqual(result[13], 'Yes')            # Trench Traverse
        self.assertEqual(result[14], 'No')             # Bump Traverse
        self.assertEqual(result[15], 'Yes')            # Shooting Close
        self.assertEqual(result[16], 'No')             # Shooting Mid
        self.assertEqual(result[17], 'No')             # Shooting Far
        self.assertEqual(result[18], '4/5')            # Drivetrain Speed
        self.assertEqual(result[19], '2/5')            # Intake Speed
        self.assertEqual(result[20], '5/5')            # Shooter Speed
        self.assertEqual(result[21], 'Robot Broke')    # Defense Cause
        self.assertEqual(result[22], '1:05')           # Died At
        self.assertEqual(result[23], 'tipped on the ramp')  # Died Reason
        self.assertEqual(result[24], 'Great performance')  # Comments

    def test_transform_frc_report_without_a_defense_cause_or_death(self):
        """Cause/died columns stay blank when the robot never died and no
        cause was recorded — the common case, most matches have neither."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)

        report_data = {
            'matchId': 'qm2_254',
            'matchNumber': 2,
            'teamNumber': 254,
            'alliance': 'Red',
            'scouterName': 'Test Scouter',
            'gameData': {
                'defense_rating': 0,
                'robot_died': False,
            },
            'comments': '',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(result[21], '')  # Defense Cause
        self.assertEqual(result[22], '')  # Died At
        self.assertEqual(result[23], '')  # Died Reason
```

Then change `test_transform_ftc_report`:

```python
        report_data = {
            'matchId': 'ftc_qm1_12345',
            'matchNumber': 1,
            'teamNumber': 12345,
            'alliance': 'Blue',
            'scouterName': 'FTC Scouter',
            'programType': 'FTC',
            'gameData': {
                'leave': True,
                'artifacts_auto': 3,
                'indexing_auto': True,
                'artifacts_teleop': 8,
                'indexing_teleop': False,
                'base_expansion': 'Full',
                'driver_quality': 4.0,
                'robot_died': False,
            },
            'comments': 'Solid match',
            'createdAt': datetime(2026, 3, 1, 14, 0, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FTC_HEADERS))  # 15 columns
        self.assertEqual(result[1], 'ftc_qm1_12345')  # Match ID
        self.assertEqual(result[4], 'Blue')             # Alliance
        self.assertEqual(result[6], 'Yes')              # Leave
        self.assertEqual(result[7], 3)                  # Auto Artifacts
        self.assertEqual(result[8], 'Yes')              # Auto Indexing
        self.assertEqual(result[9], 8)                  # Teleop Artifacts
        self.assertEqual(result[10], 'No')              # Teleop Indexing
```

to:

```python
        report_data = {
            'matchId': 'ftc_qm1_12345',
            'matchNumber': 1,
            'teamNumber': 12345,
            'alliance': 'Blue',
            'scouterName': 'FTC Scouter',
            'programType': 'FTC',
            'gameData': {
                'leave': True,
                'artifacts_auto': 3,
                'indexing_auto': True,
                'artifacts_teleop': 8,
                'indexing_teleop': False,
                'base_expansion': 'Full',
                'driver_quality': 4.0,
                'robot_died': False,
                'defense_rating': 2,
                'drivetrain_speed': 3,
                'intake_speed': 3,
                'shooter_speed': 3,
                'defense_cause': 'strategic',
            },
            'comments': 'Solid match',
            'createdAt': datetime(2026, 3, 1, 14, 0, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FTC_HEADERS))  # 22 columns
        self.assertEqual(result[1], 'ftc_qm1_12345')  # Match ID
        self.assertEqual(result[4], 'Blue')             # Alliance
        self.assertEqual(result[6], 'Yes')              # Leave
        self.assertEqual(result[7], 3)                  # Auto Artifacts
        self.assertEqual(result[8], 'Yes')              # Auto Indexing
        self.assertEqual(result[9], 8)                  # Teleop Artifacts
        self.assertEqual(result[10], 'No')              # Teleop Indexing
        self.assertEqual(result[14], '2/5')             # Defense Rating
        self.assertEqual(result[15], '3/5')             # Drivetrain Speed
        self.assertEqual(result[16], '3/5')             # Intake Speed
        self.assertEqual(result[17], '3/5')             # Shooter Speed
        self.assertEqual(result[18], 'Strategic')       # Defense Cause
        self.assertEqual(result[19], '')                # Died At (not set)
        self.assertEqual(result[20], '')                # Died Reason (not set)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && ./venv/bin/python -m pytest tests/test_sheets_service.py -v`
Expected: FAIL — `FRC_HEADERS`/`FTC_HEADERS` still have their old lengths, `_transform_frc_report`/`_transform_ftc_report` don't emit the new columns.

- [ ] **Step 3: Update the header lists, add the new columns before "Comments"**

In `functions/services/sheets_service.py`, change:

```python
# Column headers for FRC match reports
FRC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Auto Fuel",
    "Auto L1 Hang",
    "Teleop Fuel",
    "Climb Level",
    "Defense Rating",
    "Driver Skill",
    "Robot Died",
    "Trench Traverse",
    "Bump Traverse",
    "Shooting Close",
    "Shooting Mid",
    "Shooting Far",
    "Comments"
]

# Column headers for FTC match reports
FTC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Leave",
    "Auto Artifacts",
    "Auto Indexing",
    "Teleop Artifacts",
    "Teleop Indexing",
    "Base Expansion",
    "Driver Quality",
    "Robot Died",
    "Comments"
]
```

to:

```python
# Column headers for FRC match reports
FRC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Auto Fuel",
    "Auto L1 Hang",
    "Teleop Fuel",
    "Climb Level",
    "Defense Rating",
    "Driver Skill",
    "Robot Died",
    "Trench Traverse",
    "Bump Traverse",
    "Shooting Close",
    "Shooting Mid",
    "Shooting Far",
    "Drivetrain Speed",
    "Intake Speed",
    "Shooter Speed",
    "Defense Cause",
    "Died At",
    "Died Reason",
    "Comments"
]

# Column headers for FTC match reports
FTC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Leave",
    "Auto Artifacts",
    "Auto Indexing",
    "Teleop Artifacts",
    "Teleop Indexing",
    "Base Expansion",
    "Driver Quality",
    "Robot Died",
    "Defense Rating",
    "Drivetrain Speed",
    "Intake Speed",
    "Shooter Speed",
    "Defense Cause",
    "Died At",
    "Died Reason",
    "Comments"
]
```

Every new column sits before "Comments" in both lists, not after — `_format_headers` (line 233) hardcodes wrap-text formatting onto `column_count - 1`, today's Comments column. Appending after Comments would silently move that formatting to the wrong column.

- [ ] **Step 4: Add the `_format_died_at` helper**

Add this module-level function right after `_col_letter`:

```python
def _format_died_at(seconds_remaining: Optional[int]) -> str:
    """Format a stored died_at_seconds value (seconds remaining on the
    match clock, matching MatchTimer's own countdown convention) as mm:ss
    for the sheet — the same format the app itself displays. Returns an
    empty string when the robot never died."""
    if seconds_remaining is None:
        return ''
    minutes, seconds = divmod(int(seconds_remaining), 60)
    return f'{minutes}:{seconds:02d}'
```

- [ ] **Step 5: Update `_transform_frc_report` and `_transform_ftc_report`**

Change:

```python
    def _transform_frc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FRC match report to row format."""
        # Climb level mapping
        climb_level = game_data.get('teleop_tower_level', 0)
        climb_map = {0: 'No Climb', 1: 'Level 1', 2: 'Level 2', 3: 'Level 3'}
        climb_str = climb_map.get(climb_level, f'Level {climb_level}')
        
        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            game_data.get('auto_fuel', 0),
            'Yes' if game_data.get('auto_tower_l1', False) else 'No',
            game_data.get('teleop_fuel', 0),
            climb_str,
            f"{game_data.get('defense_rating', 0)}/5",
            f"{game_data.get('driver_skill', 0)}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
            'Yes' if game_data.get('trench_traverse', False) else 'No',
            'Yes' if game_data.get('bump_traverse', False) else 'No',
            'Yes' if game_data.get('shooting_range_close', False) else 'No',
            'Yes' if game_data.get('shooting_range_mid', False) else 'No',
            'Yes' if game_data.get('shooting_range_far', False) else 'No',
            report_data.get('comments', '')
        ]
    
    def _transform_ftc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FTC match report to row format."""
        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            'Yes' if game_data.get('leave', False) else 'No',
            game_data.get('artifacts_auto', 0),
            'Yes' if game_data.get('indexing_auto', False) else 'No',
            game_data.get('artifacts_teleop', 0),
            'Yes' if game_data.get('indexing_teleop', False) else 'No',
            game_data.get('base_expansion', 'None'),
            f"{int(game_data.get('driver_quality', 0))}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
            report_data.get('comments', '')
        ]
```

to:

```python
    def _transform_frc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FRC match report to row format."""
        # Climb level mapping
        climb_level = game_data.get('teleop_tower_level', 0)
        climb_map = {0: 'No Climb', 1: 'Level 1', 2: 'Level 2', 3: 'Level 3'}
        climb_str = climb_map.get(climb_level, f'Level {climb_level}')
        defense_cause_map = {'broke': 'Robot Broke', 'strategic': 'Strategic'}

        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            game_data.get('auto_fuel', 0),
            'Yes' if game_data.get('auto_tower_l1', False) else 'No',
            game_data.get('teleop_fuel', 0),
            climb_str,
            f"{game_data.get('defense_rating', 0)}/5",
            f"{game_data.get('driver_skill', 0)}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
            'Yes' if game_data.get('trench_traverse', False) else 'No',
            'Yes' if game_data.get('bump_traverse', False) else 'No',
            'Yes' if game_data.get('shooting_range_close', False) else 'No',
            'Yes' if game_data.get('shooting_range_mid', False) else 'No',
            'Yes' if game_data.get('shooting_range_far', False) else 'No',
            f"{game_data.get('drivetrain_speed', 0)}/5",
            f"{game_data.get('intake_speed', 0)}/5",
            f"{game_data.get('shooter_speed', 0)}/5",
            defense_cause_map.get(game_data.get('defense_cause'), ''),
            _format_died_at(game_data.get('died_at_seconds')),
            game_data.get('died_reason', ''),
            report_data.get('comments', '')
        ]
    
    def _transform_ftc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FTC match report to row format."""
        defense_cause_map = {'broke': 'Robot Broke', 'strategic': 'Strategic'}

        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            'Yes' if game_data.get('leave', False) else 'No',
            game_data.get('artifacts_auto', 0),
            'Yes' if game_data.get('indexing_auto', False) else 'No',
            game_data.get('artifacts_teleop', 0),
            'Yes' if game_data.get('indexing_teleop', False) else 'No',
            game_data.get('base_expansion', 'None'),
            f"{int(game_data.get('driver_quality', 0))}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
            f"{game_data.get('defense_rating', 0)}/5",
            f"{game_data.get('drivetrain_speed', 0)}/5",
            f"{game_data.get('intake_speed', 0)}/5",
            f"{game_data.get('shooter_speed', 0)}/5",
            defense_cause_map.get(game_data.get('defense_cause'), ''),
            _format_died_at(game_data.get('died_at_seconds')),
            game_data.get('died_reason', ''),
            report_data.get('comments', '')
        ]
```

- [ ] **Step 6: Update the column-width arrays and fix the stale comment**

Change:

```python
            # FRC has 19 columns, FTC has 13 columns
            frc_widths = [160, 140, 60, 70, 70, 100, 80, 90, 90, 90, 100, 100, 85, 90, 90, 90, 90, 90, 250]
            ftc_widths = [160, 140, 60, 70, 70, 100, 70, 100, 90, 110, 100, 110, 100, 85, 250]
```

to:

```python
            # FRC has 25 columns, FTC has 22 columns
            frc_widths = [160, 140, 60, 70, 70, 100, 80, 90, 90, 90, 100, 100, 85, 90, 90, 90, 90, 90, 90, 90, 90, 110, 90, 160, 250]
            ftc_widths = [160, 140, 60, 70, 70, 100, 70, 100, 90, 110, 100, 110, 100, 85, 85, 90, 90, 90, 110, 90, 160, 250]
```

(The `# FRC has 19 columns, FTC has 13 columns` comment was already stale before this task — `FTC_HEADERS`/`ftc_widths` had 15 entries, not 13 — this fixes both the count and the pre-existing drift.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd functions && ./venv/bin/python -m pytest tests/test_sheets_service.py -v`
Expected: PASS (all tests, old and new)

- [ ] **Step 8: Run the full Python suite**

Run: `cd functions && ./venv/bin/python -m pytest tests/`
Expected: PASS — this file's changes don't touch any other module.

- [ ] **Step 9: Commit**

```bash
git add functions/services/sheets_service.py functions/tests/test_sheets_service.py
git commit -m "feat(backend): export subsystem speeds, defense cause, and died-at time to sheets"
```

---

### Task 11: Full-suite verification and sync-logic review

**Files:** none (verification only)

- [ ] **Step 1: Run the full Dart suite**

Run: `cd frontend && flutter test`
Expected: all tests PASS (371 pre-existing + the new tests from Tasks 1-9).

- [ ] **Step 2: Run `flutter analyze`**

Run: `cd frontend && flutter analyze`
Expected: no warnings.

- [ ] **Step 3: Run the full Python suite**

Run: `cd functions && ./venv/bin/python -m pytest tests/`
Expected: all tests PASS (117 pre-existing + the new tests from Task 10).

- [ ] **Step 4: Dispatch `sync-logic-reviewer` on the Sheets export change**

Per this repo's CLAUDE.md convention for touching `sheets_service.py`, run the `sync-logic-reviewer` agent against the diff from Task 10 (`functions/services/sheets_service.py`, `functions/tests/test_sheets_service.py`). It checks export idempotency and team-scoping — this task's changes are row-shape-only (no change to the idempotent-by-report-id resolution or the one-way trigger), but the review should confirm that directly rather than assume it.

- [ ] **Step 5: Manual on-device verification (call out, don't skip)**

The spec's Testing section flags two UX-feel details a unit test can't fully validate:
- The phase-flash timing (does a ~400ms edge glow read as noticeable but not jarring on a real phone screen in bright venue lighting?).
- The hold-to-repeat feel (does one step per second feel right during a live match, or does it need revisiting after the user tries it?).

Do not report this plan complete without a device pass on these two — build the app (`flutter build web --release` and/or an APK per CLAUDE.md's build guidance) and try both interactions live.

- [ ] **Step 6: Report back**

Summarize: which of the 10 spec items shipped, full-suite pass/fail status, `sync-logic-reviewer`'s verdict, and the outcome of the two manual checks in Step 5.
