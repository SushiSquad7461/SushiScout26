# Team Settings section — design

**Date:** 2026-07-23
**Status:** Approved (brainstorm), pending implementation plan

## Goal

Add a **Team** section to the settings bottom sheet (`settings_sheet.dart`) that lets a
signed-in user:

1. See their **current (active) team** — name, their role, member count.
2. See and copy the **current team's invite code** (all members); admins can **regenerate** it.
3. See **all teams they belong to** and **switch** the active team.
4. **Join** another team (invite code) or **create** a new team, without leaving the sheet.

This is almost entirely UI wiring over capabilities that already exist. No backend/Cloud
Function/Firestore-rule changes are required.

## What already exists (reused as-is)

- `AuthNotifier.switchTeam(teamId)` — persists `currentTeamId` to Firestore, updates state.
  **Does not** set `status = loading`, so it never triggers `AuthWrapper`'s screen swap.
- `AuthNotifier.joinTeam(code)` / `createTeam(name)` — do the real work (callable →
  `waitForTeamClaim` → `_loadUserProfile`) but **do** set `status = loading`.
- `TeamRepository.getUserTeams(userId)` — returns `List<Team>` for every membership.
- `TeamRepository.regenerateInviteCode(teamId, requestingUserId)` — client-side Firestore
  transaction, enforces creator-only. Firestore rules allow it
  (`teams/{id}` `allow update: if isTeamMember(teamId)`; comment: "invite-code regen").
- `Team` model exposes `name`, `inviteCode`, `createdBy`, `memberCount`.
- Providers: `currentTeamIdProvider`, `isTeamAdminProvider` (`teamMemberships[current] == 'admin'`),
  `authProvider` (`teamMemberships` = `{teamId: role}`, `userId`).

## Key constraint: the AuthWrapper loading-screen swap

`AuthWrapper` (`presentation/widgets/auth_wrapper.dart`) watches `authProvider.status`.
When status is `loading` it replaces the **entire** widget tree with `_LoadingScreen`.

The settings sheet is a modal over `DashboardScreen`. `switchTeam` is safe (no `loading`),
but the existing `joinTeam`/`createTeam` flip global status to `loading`, which would flash
the dashboard-behind-the-sheet to a full-screen spinner. To avoid this, join/create invoked
from inside the app use **new notifier methods that never set global `status`** and report
loading/errors locally in the section instead.

## Architecture

### New file: `presentation/widgets/team_settings_section.dart`

A `ConsumerStatefulWidget` (`TeamSettingsSection`) embedded by `settings_sheet.dart` under a
new `_SectionHeader("Team")` block, following the existing section pattern. Extracted rather
than inlined because `settings_sheet.dart` is already ~440 lines; a separate widget keeps it
focused and unit-testable in isolation.

### New reactive provider: `userTeamsProvider`

```dart
// In auth_provider.dart (or a small teams_provider.dart next to it).
final userTeamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return const [];
  // Re-runs when currentTeamId changes so the active highlight + invite code stay in sync.
  ref.watch(currentTeamIdProvider);
  return ref.read(teamRepositoryProvider).getUserTeams(userId);
});
```

The section watches this for the team list; the current team's invite code is read from the
matching `Team` in that same list (no extra fetch).

### New `AuthNotifier` methods (no global `status` mutation)

```dart
/// Same work as joinTeam, but leaves global AuthStatus untouched so the
/// settings sheet (a modal over the dashboard) is not torn down by
/// AuthWrapper's loading-screen swap. Throws on failure; caller shows the
/// error inline. On success, auto-switches to the joined team.
Future<void> joinTeamInApp(String inviteCode);

/// As above, for creating a team. Auto-switches to the new team on success.
Future<void> createTeamInApp(String name);
```

Both: call `teamRepo` → `waitForTeamClaim` (join/create) → `_loadUserProfile` → `switchTeam(newTeamId)`
→ invalidate `userTeamsProvider`. They surface failures by throwing (or returning a `Result`),
never by setting `status = error`, so `AuthWrapper` stays on the dashboard. The onboarding
`TeamSelectScreen` keeps using the existing status-driven `joinTeam`/`createTeam` unchanged.

## Section UI

Order within the section:

1. **Current team** — name (title), your role chip (admin/member), member count. Visually marked
   active.
2. **Invite code** — `SelectableText` of the code + a copy-to-clipboard icon button (shown to all
   members). **Regenerate** button rendered only when `isTeamAdminProvider` is true; on tap calls
   `regenerateInviteCode`, then invalidates `userTeamsProvider` to refresh the displayed code.
   Confirmation dialog first ("old code stops working").
3. **Your teams** — one tappable row per team from `userTeamsProvider`. Active team shows a check
   and is non-tappable; tapping another calls `switchTeam(teamId)`. Uses `.when(...)` for
   loading/error states.
4. **Add a team** (inline, collapsible to keep the section tidy):
   - "Join with invite code": text field + button → `joinTeamInApp(code)`.
   - "Create team": text field + button → `createTeamInApp(name)`.
   - Each button shows a **local** spinner while awaiting; errors render inline beneath the field.
     On success (auto-switch), the section rebuilds with the new team active and fields clear.

## Behavior decisions

- **Auto-switch on join/create:** yes — the new team becomes active immediately.
- **Invite code visibility:** all members see and can copy it; only admins see Regenerate.
- **Add-team presentation:** inline expandable fields (not dialogs).
- **Loading:** join/create show local spinners; switch is instant. No full-screen swap.
- **Errors:** shown inline in the section, never as a global error state.

## Edge cases

- **User in exactly one team:** "Your teams" shows just that team (active); switch is a no-op.
  Join/create still available.
- **Leaving a team** is out of scope here (a `leaveTeam` flow already exists elsewhere); not added
  to this section unless requested later.
- **Invite code copy on desktop/web:** use `Clipboard.setData`; also `SelectableText` as fallback.
- **`getUserTeams` skips missing team docs** (already handled in the repo) — list only shows
  resolvable teams.
- **Switch failure** (network): the existing `switchTeam` sets a global error state, which would
  swap the screen via `AuthWrapper`. From the section we call switch through a wrapper that
  catches the failure and shows it inline, preserving the open modal (same principle as
  join/create).

## Testing

Widget tests (`fake_cloud_firestore` + `authProvider` overridden via `overrideWith`, per CLAUDE.md):

- Renders the current team, role, and invite code.
- Invite code visible to non-admin; Regenerate hidden for non-admin, shown for admin.
- Team list renders all memberships; tapping a non-active team calls `switchTeam`.
- Join happy path: `joinTeamInApp` called, section reflects new active team.
- Create happy path likewise.
- Join/create failure renders an inline error and does **not** change `authProvider.status`.

Unit test: `joinTeamInApp` / `createTeamInApp` never set `status = loading` or `status = error`
(assert status stays `authenticated` across the call, including on failure).

## Out of scope

- Backend, Cloud Function, or Firestore-rule changes (none needed).
- Leaving a team from this section.
- Renaming a team / managing other members' roles.
