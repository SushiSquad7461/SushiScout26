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

`dashboard.dart`'s `BrandActionBar` already uses a bold, high-contrast
display style (`AppTheme.display`, size 21) inside a full-width 66dp ink
bar. The label text is the only weak point: it reads "scout match", which
does not say "this is how you begin." Change the label text to "start
scouting". Make no other visual change — the existing style already meets
the "obvious primary action" bar.

### 1b. Center the wizard page-step indicator

`_buildBottomBar` (in both forms) puts a `Spacer()` on each side of
`ScoutingWizardPageIndicator`. The left side is a fixed
`SizedBox(width: 100)` placeholder or a `TextButton.icon` ("back"). The
right side is `ScoutingWizardNextButton`. Its width changes with its label
("next" vs. "submit"/"save") and its spinner. Unequal side widths push the
indicator off center.

Fix: wrap both the left slot and `ScoutingWizardNextButton` in a
`SizedBox` of the same fixed width. Use one shared constant for both forms
(for example `kWizardBottomBarSlotWidth`). Size it to fit the longest label,
"submit". This keeps the indicator centered on every page, in both forms.

### 1c. Show the specific validation error, not just a range

`FormValidators.teamNumber` and `FormValidators.matchNumber` both delegate
their range check to a shared helper, `FormValidators.number()`. That
helper builds one generic message: `"$fieldName must be at most $max"`. A
scout who types six digits into the team-number field sees "Team number
must be at most 99999" — true, but it does not name the actual mistake
(too many digits).

Two separate problems need two separate fixes:

- **Nothing stops the extra digits from being typed.** Add
  `LengthLimitingTextInputFormatter(5)` to the team-number field in both
  scouting forms. Add `LengthLimitingTextInputFormatter(3)` to the
  match-number field in both scouting forms (its max value is 200). This
  physically blocks a scout from typing past the valid length.
- **The message still needs to name the real limit.** A pasted value can
  still exceed the length cap. Add an optional `maxLengthMessage`
  parameter to `FormValidators.number()`. Pass a digit-count message from
  `teamNumber()`: "Team number can be at most 5 digits". Pass a matching
  message from `matchNumber()`: "Match number can be at most 3 digits". Do
  not change `number()`'s default message. Other callers, such as the
  `Score`/`Field` cases in `form_validators_test.dart`, rely on the current
  range wording. Leave `min`-side messages ("must be at least N")
  unchanged too.

`team_select_screen.dart`'s create-team field is a separate, plain
`TextField` with no `inputFormatters` at all. It accepts any character
today and validates only on submit, via `FormValidators.teamName`. Add
`FilteringTextInputFormatter.digitsOnly` and
`LengthLimitingTextInputFormatter(5)` to this field too, matching the
scouting forms' team-number field. Leave its submit-time validation and
error-box display as they are — that path already surfaces
`FormValidators.teamName`'s specific message correctly.

This change updates existing assertions in
`frontend/test/core/validation/form_validators_test.dart` (lines 94 and
122 pin the current wording) — treat those as expected diffs, not
regressions.

## 2. Hold-to-repeat on the fuel/artifact counter

`CounterCard`'s `_CounterButton` only handles `onTap`. Add a
`GestureDetector` with `onLongPressStart` and `onLongPressEnd` around each
`+`/`-` button. On long-press start, begin a
`Timer.periodic(Duration(seconds: 1))` that calls the same `onChanged` step
logic as a single tap. This respects `stepSize` and the `minValue`/
`maxValue` clamps. Cancel the timer on long-press end and on dispose.

The user asked for exactly this rate: one step per second. Confirmed and
locked — do not speed this up during implementation without asking first,
since a faster rate was raised and explicitly not chosen.

The step-size buttons (`_StepControlButton`) do not get this treatment.
Repeatedly changing the step size during a hold is not a real use case.

## 3. Color flash on match-phase change

`MatchTimer`'s `_MatchTimerState` already computes `_currentPhase` and a
`_phaseFill` color per phase every rebuild. Add a phase-change hook:

- Track the previous phase in state. When `_currentPhase` changes (compare
  in the periodic timer callback, not `didUpdateWidget` — the phase is
  derived from `_secondsRemaining`, which only changes on the timer tick),
  call an `onPhaseChanged(Color)` callback passed in from the owning form.
- Both `FrcRebuiltForm` and `FtcDecodeForm` add a new `_PhaseFlashOverlay`
  widget: an `IgnorePointer` plus `AnimatedOpacity` colored border/glow
  (using the phase's `_phaseFill` color), fading from full opacity to 0
  over about 400ms whenever triggered.
- The flash fires on every phase change detected after the timer starts
  running: AUTO→TRANSITION, TRANSITION→TELEOP, TELEOP→ENDGAME,
  ENDGAME→FINISHED. It does not fire for the very first frame's `PRE-MATCH`
  value at mount, since that is not a change, just the starting state.
- Pressing reset (`_resetTimer`) also sends `_currentPhase` back to
  `PRE-MATCH`. Treat this the same as any other phase change. Flash it,
  using `PRE-MATCH`'s own color. A scout who taps reset needs the same
  clear signal that the state actually changed.
- Nesting: each form's widget tree becomes
  `PopScope > dismissKeyboardOnTap(GestureDetector) > Stack([Scaffold,
  _PhaseFlashOverlay])`. `PopScope` and the keyboard-dismiss
  `GestureDetector` wrap the whole screen, as they do today. The new
  `Stack` sits between the `GestureDetector` and the `Scaffold`. The flash
  overlay paints above the `Scaffold`.

## 4. Robot died/disabled: time and reason

- `MatchTimerController` gains a way to read the current countdown value on
  demand. Add a `ValueNotifier<int>` (or an exposed getter) that
  `_MatchTimerState` keeps in sync on each tick. Capturing "when" needs the
  live timer value at the moment the scout acts, not just at submit time.
- In both forms' teleop page, once "Robot Died / Disabled" is checked, show:
  - A "mark now" button that captures the controller's current remaining
    seconds into `_diedAtSeconds`, displayed as `mm:ss`.
  - The same display is tappable afterward, to open a small manual
    override. Use two number fields (minutes and seconds), or a
    `showTimePicker`-style custom dialog scoped to 0:00–2:33. This
    satisfies "mark now but editable to a custom time as well."
  - A short (1-2 line) `TextFormField` underneath, for the reason. Keep it
    separate from the form's main Comments field.
- New `gameData` keys (both forms): `died_at_seconds` and `died_reason`.
  Store `died_at_seconds` as the seconds *remaining* on the match clock
  when marked or edited. This matches the timer's own countdown
  convention. Store `died_reason` as a String. New `MatchReport` getters:
  `diedAtSeconds`, `diedReason`.

## 5. Subsystem sliders and defense-cause switch

- Both forms' endgame/qualitative page gets three new 1-5 sliders:
  Drivetrain Speed, Intake Speed, Shooter Speed. Add them alongside the
  existing Driver Skill/Driver Quality slider and Defense Rating, reusing
  each form's existing `_buildSlider` helper. These sliders are additive,
  not a replacement for the existing ones.
- FTC's form gains a Defense Rating slider. This is new — FTC has no
  defense concept today. Match FRC's range and presentation exactly.
- A defense-cause control (`SegmentedButton<String>`, "Robot Broke" /
  "Strategic") appears directly under Defense Rating in both forms. Show it
  (or enable it, keeping a `null` value otherwise) only when Defense Rating
  is above 0. A cause is meaningless at a rating of 0.
- New `gameData` keys (both forms): `drivetrain_speed`, `intake_speed`,
  `shooter_speed` (int, 1-5), `defense_cause` (`'broke'` | `'strategic'` |
  absent). FTC additionally writes `defense_rating` (int, 1-5) — the same
  key name FRC already uses, for schema consistency across programs.
- New `MatchReport` getters: `drivetrainSpeed`, `intakeSpeed`,
  `shooterSpeed`, `defenseCause`. `MatchReport.defenseRating` already
  exists as a shared getter (it is not FRC-only, despite sitting under a
  comment labeled "FRC getters") — FTC needs no new getter for it, only the
  new `defense_rating` key written into its `gameData` map.

## 6. Phone back button steps to the previous phase

Both form screens gain a `PopScope` at the outermost level of the tree
described in section 3's nesting note:

```dart
PopScope(
  canPop: _currentPage == 0,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) _prevPage();
  },
  child: dismissKeyboardOnTap(child: Stack([Scaffold(...), _PhaseFlashOverlay()])),
)
```

On the first wizard page, back exits the form as it does today. This
matches existing behavior — no confirmation dialog. On any later page,
back moves to the previous page instead of closing the match.

## 7. Backend: Sheets export column additions

`functions/services/sheets_service.py` builds one row per match, with a
fixed column count per program and a matching header row. Today `FRC_HEADERS`
has 19 entries and `FTC_HEADERS` has 15 — not 13. A comment at line 292
(`# FRC has 19 columns, FTC has 13 columns`) is itself stale against the
real 15-entry `FTC_HEADERS`/`ftc_widths` lists. Fix that comment while
touching this file, so it does not mislead the next person.

The new fields need columns added to both the FRC and FTC header lists and
row builders:

- Drivetrain Speed, Intake Speed, Shooter Speed (both programs)
- Defense Cause (both programs)
- Died At (both programs) — format the stored `died_at_seconds` back to
  `mm:ss` for the sheet, the same way the UI displays it
- Died Reason (both programs)
- Defense Rating (FTC only — FRC already exports this)

Add every new column **before** "Comments" in each header list, not after.
`_format_headers` hardcodes wrap-text formatting onto column
`column_count - 1` — today that is "Comments." Appending new columns after
Comments would silently move the wrap formatting onto the wrong column and
strip it from Comments. Inserting the new columns before Comments keeps
Comments as the last column and keeps its existing wrap formatting correct
with no change to `_format_headers` itself.

This is additive to the existing row-building logic. It does not change the
one-way, `RAW`-value, idempotent-by-report-id export model, or the
`on_match_written` trigger's create/update/delete handling — only the row
shape. Update the header lists and the row builders in the same change, or
the header row and data rows drift out of sync.

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
