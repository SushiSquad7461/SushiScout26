# Fix Frontend LSP Errors Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve all analysis errors in the frontend by creating missing files for the auth/team feature and regenerating mocks.

**Architecture:** The approach is to stub out the missing interfaces, models, and UI components with minimal placeholder content to satisfy the Dart analyzer. This will be followed by running the build runner to update generated mock files, ensuring the test helpers are in sync with the repository interfaces.

**Tech Stack:** Flutter, Dart, `build_runner`, `mockito`.

---

### Task 1: Create Missing Auth Exception File

**Files:**
- Create: `frontend/lib/core/auth/auth_exceptions.dart`

**Step 1: Write the placeholder exception file**

This file will contain the basic `AuthException` and its subclasses that are referenced throughout the app.

```dart
// frontend/lib/core/auth/auth_exceptions.dart

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthExceptionInvalidInviteCode extends AuthException {
  AuthExceptionInvalidInviteCode() : super('Invalid invite code.');
}

class AuthExceptionAlreadyInTeam extends AuthException {
  AuthExceptionAlreadyInTeam() : super('User is already in this team.');
}

class AuthExceptionCannotLeaveTeam extends AuthException {
  AuthExceptionCannotLeaveTeam() : super('Cannot leave this team.');
}
```

**Step 2: Commit the new file**

```bash
git add frontend/lib/core/auth/auth_exceptions.dart
git commit -m "feat(auth): create placeholder auth exceptions"
```

---

### Task 2: Create Missing Team Model

**Files:**
- Create: `frontend/lib/data/models/team.dart`

**Step 1: Write the placeholder Team model file**

This file defines the data structures for `Team` and `TeamSettings`.

```dart
// frontend/lib/data/models/team.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

@freezed
class Team with _$Team {
  const factory Team({
    required String id,
    required String name,
    required List<String> members,
    required TeamSettings settings,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}

@freezed
class TeamSettings with _$TeamSettings {
  const factory TeamSettings({
    required String exportSheetId,
  }) = _TeamSettings;

  factory TeamSettings.fromJson(Map<String, dynamic> json) => _$TeamSettingsFromJson(json);
}
```

**Step 2: Commit the new file**

```bash
git add frontend/lib/data/models/team.dart
git commit -m "feat(data): create placeholder team model"
```

---

### Task 3: Create Missing Core Auth and Repository Interfaces

**Files:**
- Create: `frontend/lib/core/auth/auth_service.dart`
- Create: `frontend/lib/data/repositories/auth_repository.dart`

**Step 1: Write the placeholder `AuthService`**

```dart
// frontend/lib/core/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthService {
  Stream<User?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  User? get currentUser;
}
```

**Step 2: Write the placeholder `AuthRepository`**

```dart
// frontend/lib/data/repositories/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  User? get currentUser;
}
```

**Step 3: Commit the new files**

```bash
git add frontend/lib/core/auth/auth_service.dart frontend/lib/data/repositories/auth_repository.dart
git commit -m "feat(auth): create placeholder auth service and repository"
```

---

### Task 4: Create Missing Login Screen UI

**Files:**
- Create: `frontend/lib/presentation/screens/auth/login_screen.dart`

**Step 1: Write the placeholder Login Screen widget**

```dart
// frontend/lib/presentation/screens/auth/login_screen.dart

import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Login Screen'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: null, // Logic to be added
              child: Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit the new file**

```bash
git add frontend/lib/presentation/screens/auth/login_screen.dart
git commit -m "feat(ui): create placeholder login screen"
```

---

### Task 5: Regenerate Generated Files

**Files:**
- Modify: `frontend/lib/data/models/team.freezed.dart`
- Modify: `frontend/lib/data/models/team.g.dart`
- Modify: `frontend/test/helpers/mocks.mocks.dart`

**Step 1: Run build_runner**

This command will generate the `.freezed.dart` and `.g.dart` files for the new `Team` model, and it will update the mock files to match the latest repository interfaces.

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`
Expected: Successful build with no errors.

**Step 2: Commit the generated files**

```bash
git add frontend/lib/data/models/team.freezed.dart frontend/lib/data/models/team.g.dart frontend/test/helpers/mocks.mocks.dart
git commit -m "chore: regenerate generated files"
```

---

### Task 6: Verify All Errors are Resolved

**Step 1: Run the Dart analyzer**

Run: `cd frontend && dart analyze`
Expected: The command should complete with "No issues found!".

**Step 2: Push all changes**

```bash
git push
```
