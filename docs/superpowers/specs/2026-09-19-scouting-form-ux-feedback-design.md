# Scouting form UX feedback — design

**Date:** 2026-09-19
**Status:** Approved (brainstorm), pending implementation plan

## Goal

A scout gave 10 pieces of feedback on the FRC and FTC scouting wizards. This
spec groups the feedback into one coherent set of changes to
`frc_rebuilt_form.dart`, `ftc_decode_form.dart`, and the widgets they share.
Each item below states the problem, the fix, and the exact files it touches.

## Scope

Apply every change to **both** the FRC "Rebuilt" form and the FTC "DECODE"
form, except where a game-specific term (fuel vs. artifacts) makes the wording
differ. The two forms share widgets (`ScoutingFormWidget`,
`ScoutingWizardPageIndicator`, `ScoutingWizardNextButton`, `CounterCard`,
`MatchTimer`), so most fixes land once in shared code.

## 1. Wizard chrome polish

### 1a. Make the start-scouting button more obvious

`dashboard.dart`'s `BrandActionBar` currently reads "scout match" in a plain
label style. Rename it to "start scouting" and give it a bolder,
higher-contrast label style (the existing `AppTheme.label`/`display` treatment
used elsewhere for primary actions), so it stands out as the dashboard's main
call to action.

### 1b. Center the wizard page-step indicator

`_buildBottomBar` (in both forms) puts a `Spacer()` on each side of
`ScoutingWizardPageIndicator`. The left side is a fixed
`SizedBox(width: 100)` placeholder or a `TextButton.icon` ("back"); the right
side is `ScoutingWizardNextButton`, whose width changes with its label
("next" vs. "submit"/"save") and its spinner. Unequal side widths push the
indicator off-center.

Fix: give both the left slot and `ScoutingWizardNextButton` the same fixed
width, using a shared constant (`SizedBox(width: kWizardBottomBarSlotWidth)`
wrapping each side), sized to fit the longest label ("submit"). This keeps
the indicator centered on every page and both forms.

### 1c. Show the specific validation error, not just a range

`FormValidators.teamNumber`/`matchNumber` already show a message inline
under the field (`TextFormField.validator`,
`AutovalidateMode.onUserInteraction`). Two gaps remain:

- Nothing stops a scout from typing more digits than the field accepts, so
  the error only appears after the fact, worded as a range ("must be at most
  99999") instead of the real problem (too many digits).
- The scouting forms and `team_select_screen.dart`'s create-team field both
  accept digit input with no length cap.

Fix:

- Add `LengthLimitingTextInputFormatter(5)` to the team-number field (in both
  scouting forms and `team_select_screen.dart`) and
  `LengthLimitingTextInputFormatter(3)` to the match-number field (max value
  is 200), so a scout physically cannot type past the valid length.
- Reword `FormValidators.teamNumber`'s and `matchNumber`'s max-length
  messages to name the real constraint: "Team number can be at most 5
  digits", "Match number can be at most 3 digits", instead of "must be at
  most <n>".

## 2. Hold-to-repeat on the fuel/artifact counter

`CounterCard`'s `_CounterButton` only handles `onTap`. Add
`GestureDetector(onLongPressStart, onLongPressEnd)` around each `+`/`-`
button: on long-press start, begin a `Timer.periodic(Duration(seconds: 1))`
that calls the same `onChanged` step logic as a single tap (respecting
`stepSize`, `minValue`/`maxValue` clamping); cancel the timer on long-press
end or if the widget is disposed. The step-size adjustment buttons
(`_StepControlButton`) are unaffected — repeatedly changing the step size
during a hold isn't a real use case.

## 3. Color flash on match-phase change

`MatchTimer`'s `_MatchTimerState` already computes `_currentPhase` and a
`_phaseFill` color per phase every rebuild. Add a phase-change hook:

- Track the previous phase in state. When `_currentPhase` changes (compare
  in the periodic timer callback, not `didUpdateWidget` — the phase is
  derived from `_secondsRemaining`, which only changes on the timer tick),
  call an `onPhaseChanged(Color)` callback passed in from the owning form.
- Both `FrcRebuiltForm` and `FtcDecodeForm` wrap their `Scaffold` in a
  `Stack`, with a new `_PhaseFlashOverlay` widget on top: an
  `IgnorePointer` + `AnimatedOpacity` colored border/glow (using the phase's
  `_phaseFill` color) that fades from full opacity to 0 over ~400ms whenever
  triggered. It never fires for the initial `PRE-MATCH` state — only on an
  actual transition (AUTO→TRANSITION→TELEOP→ENDGAME→FINISHED).

## 4. Robot died/disabled: time and reason

- `MatchTimerController` gains a way to read the current countdown value on
  demand — add a `ValueNotifier<int>` (or an exposed getter) that the
  `_MatchTimerState` keeps in sync each tick, since capturing "when" needs
  the live timer value at the moment the scout acts, not just at submit time.
- In both forms' teleop page, once "Robot Died / Disabled" is checked, show:
  - A "mark now" button that captures the controller's current remaining
    seconds into `_diedAtSeconds`, displayed as `mm:ss`.
  - The same display is tappable afterward to open a small manual override
    (two number fields, minutes and seconds, or a
    `showTimePicker`-style custom dialog scoped to 0:00–2:33) — satisfies
    "mark now but editable to a custom time as well."
  - A short (1–2 line) `TextFormField` underneath for the reason, separate
    from the form's main Comments field.
- New `gameData` keys (both forms): `died_at_seconds` (int, seconds
  *remaining* on the match clock when marked/edited — matches the timer's
  own countdown convention) and `died_reason` (String). New `MatchReport`
  getters: `diedAtSeconds`, `diedReason`.

## 5. Subsystem sliders and defense-cause switch

- Both forms' endgame/qualitative page gets three new sliders — Drivetrain
  Speed, Intake Speed, Shooter Speed, 1-5 — added alongside the existing
  Driver Skill/Driver Quality slider (and Defense Rating), reusing each
  form's existing `_buildSlider` helper. These are additive, not a
  replacement.
- FTC's form gains a Defense Rating slider (new — FTC has no defense concept
  today), matching FRC's in range and presentation.
- A defense-cause control (`SegmentedButton<String>`, "Robot Broke" /
  "Strategic") appears directly under Defense Rating in both forms. It's
  only shown (or only enabled, with a `null` value otherwise) when Defense
  Rating > 0 — a cause is meaningless at a rating of 0.
- New `gameData` keys (both forms): `drivetrain_speed`, `intake_speed`,
  `shooter_speed` (int, 1-5), `defense_cause` (`'broke'` | `'strategic'` |
  absent). FTC additionally gets `defense_rating` (int, 1-5, matching FRC's
  key name for schema consistency across programs). New `MatchReport`
  getters: `drivetrainSpeed`, `intakeSpeed`, `shooterSpeed`, `defenseCause`,
  and (FTC) `defenseRating` reusing the same getter name FRC already has.

## 6. Phone back button steps to the previous phase

Both form screens wrap their `Scaffold` in `PopScope`:

```dart
PopScope(
  canPop: _currentPage == 0,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) _prevPage();
  },
  child: Scaffold(...),
)
```

On the first wizard page, back exits the form as it does today (matches
existing behavior — no confirmation dialog). On any later page, back moves
to the previous page instead of closing the match.

## 7. Backend: Sheets export column additions

`functions/services/sheets_service.py` builds one row per match, with a
fixed column count per program (FRC 19 columns, FTC 13 columns) and a
matching header row. The new fields need columns added to both the FRC and
FTC row-builder and header lists:

- Drivetrain Speed, Intake Speed, Shooter Speed (both programs)
- Defense Cause (both programs)
- Died At (both programs) — format the stored `died_at_seconds` back to
  `mm:ss` for the sheet, the same way the UI displays it
- Died Reason (both programs)
- Defense Rating (FTC only — FRC already exports this)

This is additive to the existing row-building logic. It does not change the
one-way, `RAW`-value, idempotent-by-report-id export model, or the
`on_match_written` trigger's create/update/delete handling — only the row
shape. Column-count constants (currently hardcoded 19/13) and header lists
need updating together, or the header row and data rows drift out of sync.

## Testing

- Dart: new/updated widget tests for `CounterCard` (long-press repeat timer),
  `MatchTimer` (phase-change callback firing exactly once per transition,
  not on `PRE-MATCH`), `ScoutingWizardPageIndicator` centering, `PopScope`
  back-navigation in both forms, the new sliders/switch/died-time fields
  round-tripping through `gameData`, and the tightened `FormValidators`
  messages and length formatters.
- Python: `tests/` gets new cases for the FRC and FTC row builders covering
  the new columns, and for the header-row/column-count constants staying in
  sync.
- Manual: verify the phase-flash timing and the hold-to-repeat feel on a
  device before calling this done — both are UX-feel details a unit test
  can't fully validate.

## Review

After implementation, run `sync-logic-reviewer` on the `sheets_service.py`
changes (export idempotency/team-scoping is its job), per this repo's
`CLAUDE.md` convention for touching `on_match_written` /
`backfill_event_to_sheets` / `sheets_service`.
