# Firebase Google Authentication with Team Isolation - Design Document

**Date:** 2026-02-22
**Status:** Approved
**Branch:** `feature/auth`
**Scope:** Full authentication system with multi-team support

## Overview

Add Firebase Authentication with Google Sign-In to SushiScout 26. Users must log in to access the app. Data is organized by teams with complete isolation between teams. A master team capability allows access to all data for administrative purposes.

## Requirements

### Functional Requirements
1. **Google Sign-In:** Users authenticate via Google accounts
2. **Required Login:** App is unusable without authentication
3. **Team Isolation:** Each team's data is completely separate
4. **Team Creation:** Users can create new teams
5. **Team Joining:** Users join teams via invite codes
6. **Master Team:** Special team with access to all data
7. **Google Sheets Per Team:** Each team has their own Google Sheet for exports
8. **Centralized Schema:** Single migration point for form structure changes

### Non-Functional Requirements
1. **Security:** Firestore Security Rules enforce data isolation
2. **Robustness:** Graceful handling of all error states
3. **Testability:** Unit and widget tests for auth flows
4. **Offline Support:** Auth state persists locally

## Data Model

### Collections

```
/teams/{teamId}
├── name: string
├── inviteCode: string (unique, 6-8 alphanumeric chars)
├── createdBy: uid
├── createdAt: timestamp
├── isMasterTeam: boolean (default: false)
├── memberCount: number
└── updatedAt: timestamp

/users/{uid}
├── email: string
├── displayName: string
├── photoURL: string (from Google)
├── currentTeamId: string | null
├── teamMemberships: { [teamId]: "admin" | "member" }
├── createdAt: timestamp
├── lastLoginAt: timestamp
└── updatedAt: timestamp

/teamSettings/{teamId}
├── googleSheetId: string | null
├── defaultEventCode: string
├── customFormConfig: map (reserved for future)
├── createdBy: uid
├── createdAt: timestamp
└── updatedAt: timestamp

/events/{eventId} (updated)
├── teamId: string (NEW)
├── name: string
├── programType: "FRC" | "FTC"
├── tbaKey: string
├── startDate: timestamp
├── createdBy: uid (NEW)
├── createdAt: timestamp
└── isDeleted: boolean

/matches/{matchId} (updated)
├── teamId: string (NEW)
├── eventId: string
├── matchId: string
├── matchNumber: number
├── teamNumber: number
├── alliance: "Red" | "Blue"
├── scouterName: string
├── gameData: map
├── robotDied: boolean
├── comments: string
├── images: array
├── createdBy: uid (NEW)
├── createdAt: timestamp
├── isSynced: boolean
└── isDeleted: boolean
```

## Security Rules

### Core Principles
1. Users can only read/write documents where `teamId` matches their `currentTeamId`
2. Master team members bypass `teamId` restrictions
3. Team admins can manage team settings and members
4. Invite codes must be unique globally

### Rules Structure

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function currentUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function isMasterTeamMember() {
      let userTeamId = currentUserData().currentTeamId;
      let teamData = get(/databases/$(database)/documents/teams/$(userTeamId)).data;
      return teamData.isMasterTeam == true;
    }
    
    function isTeamMember(teamId) {
      return currentUserData().currentTeamId == teamId || isMasterTeamMember();
    }
    
    function isTeamAdmin(teamId) {
      let memberships = currentUserData().teamMemberships;
      return memberships[teamId] == 'admin' || isMasterTeamMember();
    }
    
    function isValidInviteCode(code) {
      return code is string && code.size() >= 6 && code.size() <= 8;
    }
    
    // Users collection
    match /users/{uid} {
      allow read: if isAuthenticated() && (
        request.auth.uid == uid || 
        isMasterTeamMember()
      );
      allow create: if isAuthenticated() && request.auth.uid == uid;
      allow update: if isAuthenticated() && request.auth.uid == uid;
      allow delete: if false; // Users cannot be deleted via client
    }
    
    // Teams collection
    match /teams/{teamId} {
      allow read: if isAuthenticated() && isTeamMember(teamId);
      allow create: if isAuthenticated() && isValidInviteCode(resource.data.inviteCode);
      allow update: if isAuthenticated() && isTeamAdmin(teamId);
      allow delete: if false; // Teams cannot be deleted via client
    }
    
    // Team settings collection
    match /teamSettings/{teamId} {
      allow read: if isAuthenticated() && isTeamMember(teamId);
      allow create: if isAuthenticated() && isTeamAdmin(teamId);
      allow update: if isAuthenticated() && isTeamAdmin(teamId);
      allow delete: if false;
    }
    
    // Events collection
    match /events/{eventId} {
      allow read: if isAuthenticated() && isTeamMember(resource.data.teamId);
      allow create: if isAuthenticated() && 
        isTeamMember(request.resource.data.teamId) &&
        request.resource.data.createdBy == request.auth.uid;
      allow update: if isAuthenticated() && isTeamMember(resource.data.teamId);
      allow delete: if false; // Use soft delete
    }
    
    // Matches collection
    match /matches/{matchId} {
      allow read: if isAuthenticated() && isTeamMember(resource.data.teamId);
      allow create: if isAuthenticated() && 
        isTeamMember(request.resource.data.teamId) &&
        request.resource.data.createdBy == request.auth.uid;
      allow update: if isAuthenticated() && isTeamMember(resource.data.teamId);
      allow delete: if false; // Use soft delete
    }
  }
}
```

## App Flow

### Launch Flow
```
App Launch
├── Check Firebase Auth State
│   ├── Not logged in
│   │   └── Show LoginScreen
│   ├── Logged in, no currentTeamId
│   │   └── Show TeamSelectScreen
│   └── Logged in, has currentTeamId
│       └── Show DashboardScreen
```

### First-Time User Flow
```
Google Sign-In
├── Success
│   ├── Check if user document exists
│   │   ├── No → Create user document
│   │   └── Yes → Update lastLoginAt
│   └── Check currentTeamId
│       ├── null → TeamSelectScreen
│       │   ├── Create Team → Become admin → Dashboard
│       │   └── Join Team → Enter code → Become member → Dashboard
│       └── exists → Dashboard
└── Failure → Show error, retry option
```

### Team Switching Flow (Master Team)
```
Master Team User
├── Sees "All Teams" in team selector
├── Can select any team to view their data
├── Current team context stored in user.currentTeamId
└── All queries filtered by selected team
```

## Component Architecture

### New Files
```
lib/
├── core/
│   └── auth/
│       ├── auth_service.dart           # Firebase Auth wrapper
│       ├── auth_state.dart             # Auth state models
│       └── auth_exceptions.dart        # Custom auth exceptions
├── data/
│   ├── models/
│   │   ├── user_profile.dart           # User model
│   │   └── team.dart                   # Team model
│   └── repositories/
│       ├── auth_repository.dart        # Auth operations
│       └── team_repository.dart        # Team CRUD operations
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart          # Auth state provider
│   │   └── team_provider.dart          # Current team provider
│   └── screens/
│       ├── auth/
│       │   ├── login_screen.dart       # Google Sign-In UI
│       │   ├── team_select_screen.dart # Create/Join team
│       │   └── team_settings_screen.dart # Team management
│       └── widgets/
│           └── auth_wrapper.dart       # Auth gate widget
└── firebase_security_rules.json        # Exported security rules
```

### Updated Files
```
lib/
├── main.dart                           # Add auth initialization
├── data/
│   ├── models/
│   │   ├── event.dart                  # Add teamId, createdBy
│   │   └── match_report.dart           # Add teamId, createdBy
│   ├── repositories/
│   │   ├── hybrid_repository.dart      # Add teamId to all methods
│   │   └── firestore_repository.dart   # Add teamId queries
│   └── local/
│       ├── database/
│       │   └── tables.dart             # Add teamId columns
│       └── sync/
│           └── sync_manager.dart       # Include teamId in sync
├── presentation/
│   └── screens/
│       └── dashboard.dart              # Filter by teamId
```

## Google Sheets Integration

### Per-Team Configuration
- Each team stores `googleSheetId` in `/teamSettings/{teamId}`
- Export creates subsheet named after event within team's sheet
- If subsheet exists, user chooses: append, replace, or cancel

### Master Team Export
- Option to export all teams to a master sheet
- Subsheets named `{teamName}_{eventName}`
- Batch export with progress indicator

### Edge Cases
| Scenario | Handling |
|----------|----------|
| Sheet deleted externally | Show error, prompt to reconfigure |
| No write permission | Show error with instructions |
| Subsheet name conflict | Append timestamp |
| Rate limit hit | Retry with exponential backoff |

## Migration Strategy

### Existing Data Migration
1. Create "Legacy Team" with known invite code
2. Migration script adds `teamId: "legacy-team-id"` to all existing events/matches
3. Existing users auto-joined to legacy team
4. Legacy team can be renamed by admin

### Migration Script (Cloud Function or Flutter)
```dart
Future<void> migrateExistingData(String legacyTeamId) async {
  final batch = _firestore.batch();
  
  // Migrate events
  final events = await _firestore.collection('events').get();
  for (final doc in events.docs) {
    if (doc.data()['teamId'] == null) {
      batch.update(doc.reference, {
        'teamId': legacyTeamId,
        'createdBy': 'migration',
      });
    }
  }
  
  // Migrate matches
  final matches = await _firestore.collection('matches').get();
  for (final doc in matches.docs) {
    if (doc.data()['teamId'] == null) {
      batch.update(doc.reference, {
        'teamId': legacyTeamId,
        'createdBy': 'migration',
      });
    }
  }
  
  await batch.commit();
}
```

## Edge Cases and Error Handling

### Authentication Errors
| Error | Handling |
|-------|----------|
| Network error | Show retry button, queue offline |
| Invalid credentials | Show error message, retry |
| Account disabled | Show contact admin message |
| Too many attempts | Show cooldown timer |

### Team Errors
| Error | Handling |
|-------|----------|
| Invalid invite code | Show "Code not found" |
| Invite code expired | Show "Code expired, contact admin" |
| Already member | Show "Already a member of this team" |
| Last admin leaving | Block with "Transfer admin first" |
| Team deleted | Redirect to team select |

### Data Errors
| Error | Handling |
|-------|----------|
| No teamId on document | Fallback to legacy team |
| Permission denied | Refresh auth token, retry |
| Team not found | Redirect to team select |

## Testing Strategy

### Unit Tests
- `AuthService` - Mock Firebase Auth, test sign-in/sign-out
- `AuthRepository` - Test user creation, team joining
- `TeamRepository` - Test CRUD operations, invite code generation
- Security rules logic (via Firebase Emulator)

### Widget Tests
- `LoginScreen` - UI renders, button interactions
- `TeamSelectScreen` - Create/join flows
- `AuthWrapper` - Redirect logic based on auth state

### Integration Tests
- Full sign-in flow with Firebase Emulator
- Team creation and joining
- Data isolation between teams

### Test Coverage Goals
- Auth layer: 90%+
- Repository layer: 85%+
- Widget layer: 70%+

## Dependencies

### New Dependencies
```yaml
firebase_auth: ^6.0.0
google_sign_in: ^7.0.0
```

### Platform Configuration Required
1. **Android:** SHA-1 fingerprint in Firebase Console
2. **iOS:** URL schemes in Info.plist
3. **macOS:** URL schemes in Info.plist
4. **Windows:** Redirect URI configuration

## Rollout Plan

### Phase 1: Core Auth (feature/auth branch)
- Add dependencies
- Create auth service and repository
- Create login screen
- Create team select screen
- Basic security rules

### Phase 2: Team Management
- Team settings screen
- Invite code management
- Member management
- Master team support

### Phase 3: Data Migration
- Add teamId to all models
- Update all repositories
- Create migration script
- Test with existing data

### Phase 4: Security Hardening
- Deploy security rules
- Penetration testing
- Audit logging

### Phase 5: Polish & Testing
- Error handling refinement
- Loading states
- Test coverage
- Documentation

## Success Criteria

- [ ] Users can sign in with Google
- [ ] Users can create teams
- [ ] Users can join teams via invite code
- [ ] Data is isolated between teams
- [ ] Master team can access all data
- [ ] Google Sheets export works per team
- [ ] Security rules enforce isolation
- [ ] All edge cases handled gracefully
- [ ] Test coverage meets goals
- [ ] No existing data lost during migration
