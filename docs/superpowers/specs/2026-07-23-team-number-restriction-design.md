# Restrict team creation to team numbers — design

**Date:** 2026-07-23
**Status:** Approved (brainstorm), pending implementation plan

## Goal

Team creation currently accepts any non-empty free-form name. Restrict it so a new team's
name must be a **team number**: 1–5 digits, `1`–`99999`, no leading zeros. Enforced on both
client create paths and in the server `create_team` callable.

Later (once TBA + FTC API integrations exist) the same server enforcement point will be
tightened to require a *registered* team number. That is out of scope here.

## The rule

A valid team name matches `^[1-9]\d{0,4}$`:
- Accepts every real FRC/FTC number: `254`, `1114`, `9999`, `99999`.
- Rejects: empty, non-numeric (`Sushi Robotics`), 6+ digits (`123456`), `0`, and leading-zero
  forms (`00042`) — so a team stored now matches the future registered-team lookup, which keys
  on the canonical number.

Rationale for 1–5 digits (not the originally-stated 4–5): a strict 4–5 digit rule rejects real
low-numbered teams (FRC 254, 118, 33). The registered-team check added later is the real filter;
this step only blocks garbage/non-numeric names.

## Enforcement (3 sites, one shared rule)

### 1. `FormValidators.teamName` (new) — single source of truth
`frontend/lib/core/validation/form_validators.dart`. Returns `null` when valid, else the
message `"Team number must be 1–5 digits"`. Signature mirrors the existing validators:

```dart
static String? teamName(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'Team number is required';
  if (!RegExp(r'^[1-9]\d{0,4}$').hasMatch(trimmed)) {
    return 'Team number must be 1–5 digits';
  }
  return null;
}
```

Leave the existing `FormValidators.teamNumber` (1–99999, used by match reports) untouched —
different call site, different tolerance (it accepts leading zeros; team creation must not).

### 2. `TeamSettingsSection._create` (the new in-app create field)
`frontend/lib/presentation/widgets/team_settings_section.dart`. On submit, validate
`_createCtrl.text` with `FormValidators.teamName`; on failure set the existing inline `_error`
and return **without** calling `createTeamInApp`. On success, proceed as today.

### 3. `TeamSelectScreen` create tab (onboarding)
`frontend/lib/presentation/screens/auth/team_select_screen.dart`. The Create button currently
only checks `name.isNotEmpty`. Validate with `FormValidators.teamName` on press; on failure show
the message inline (a local `String? _createError` rendered below the field, matching the tab's
existing error-container styling) and do not call `createTeam`.

### 4. `create_team` callable (the real guard)
`functions/main.py`. After reading `name`, reject a value not matching `^[1-9]\d{0,4}$` with
`INVALID_ARGUMENT` and store `name.strip()`:

```python
name = (data.get('name') or '').strip()
if not re.fullmatch(r'[1-9]\d{0,4}', name):
    raise https_fn.HttpsError(
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
        "Team number must be 1–5 digits")
```

The client already maps callable errors: `_mapFunctionsError`'s default case throws
`AuthException(e.message)`, so the server message surfaces if a crafted request bypasses the
client. Add `import re` if not already present.

## Not touched
- `join_team` — you join by invite code, not number.
- Existing team docs in Firestore (`7461`, `23404` are already valid).
- `FormValidators.teamNumber` (match reports).

## Testing
- **Dart unit** (`form_validators` test): `teamName` accepts `1`, `254`, `99999`; rejects ``,
  `0`, `00042`, `123456`, `abc`, `12a`, `  ` (whitespace).
- **Dart widget** (`team_settings_section_test`): invalid create input shows the inline error and
  `createTeamInApp` is NOT called (verify on the mocked notifier path / repo); valid input calls
  it. (`team_select_screen` create-tab: invalid shows inline error, does not call `createTeam`.)
- **Python** (`functions/tests`): `create_team` raises `INVALID_ARGUMENT` for non-numeric /
  6-digit / leading-zero / empty names; accepts a valid number and stores the stripped value.

## Deploy
Server half requires `firebase deploy --only functions:create_team` (subset deploy avoids the
all-secrets-validated blocker). Run as the final step and report the result. Client half ships
with the normal app build; no rules changes.

## Future (out of scope)
Once TBA + FTC API integrations exist, `create_team` additionally verifies the number is a
registered FRC/FTC team — same enforcement point, stricter predicate.
