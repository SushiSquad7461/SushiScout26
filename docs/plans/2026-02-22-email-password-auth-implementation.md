# Email/Password Auth for Windows/Linux Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable Windows/Linux users to sign in with email/password while maintaining account unity with Google Sign-In on mobile/web.

**Architecture:** Add email/password sign-in methods to AuthService and AuthNotifier. Update LoginScreen with conditional UI - Google button for mobile/web, email/password form for Windows/Linux. Firebase handles automatic account linking via email.

**Tech Stack:** Flutter, Dart, Firebase Auth, reCAPTCHA

---

### Task 1: Add Email/Password Auth Exceptions

**Files:**
- Modify: `frontend/lib/core/auth/auth_exceptions.dart`

**Step 1: Write the failing test**

Create `frontend/test/core/auth/auth_exceptions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sushiscout/core/auth/auth_exceptions.dart';

void main() {
  group('AuthException', () {
    test('AuthExceptionWeakPassword has correct message', () {
      const exception = AuthExceptionWeakPassword();
      expect(exception.message, contains('8 characters'));
      expect(exception.message, contains('uppercase'));
      expect(exception.message, contains('lowercase'));
      expect(exception.message, contains('number'));
    });

    test('AuthExceptionInvalidEmail has correct message', () {
      const exception = AuthExceptionInvalidEmail();
      expect(exception.message, contains('valid email'));
    });

    test('AuthExceptionWrongPassword has correct message', () {
      const exception = AuthExceptionWrongPassword();
      expect(exception.message, contains('incorrect'));
    });

    test('AuthExceptionTooManyAttempts has correct message', () {
      const exception = AuthExceptionTooManyAttempts();
      expect(exception.message, contains('too many'));
    });

    test('AuthExceptionUserNotFound has correct message', () {
      const exception = AuthExceptionUserNotFound();
      expect(exception.message, contains('not found'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/core/auth/auth_exceptions_test.dart`
Expected: FAIL - classes not defined

**Step 3: Add the new exceptions**

Add to `frontend/lib/core/auth/auth_exceptions.dart` after existing exceptions:

```dart
class AuthExceptionWeakPassword extends AuthException {
  const AuthExceptionWeakPassword()
      : super('Password must be at least 8 characters with uppercase, lowercase, and number');
}

class AuthExceptionInvalidEmail extends AuthException {
  const AuthExceptionInvalidEmail() : super('Please enter a valid email address');
}

class AuthExceptionWrongPassword extends AuthException {
  const AuthExceptionWrongPassword() : super('Incorrect password');
}

class AuthExceptionTooManyAttempts extends AuthException {
  const AuthExceptionTooManyAttempts()
      : super('Too many failed attempts. Please try again later');
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/core/auth/auth_exceptions_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/core/auth/auth_exceptions.dart frontend/test/core/auth/auth_exceptions_test.dart
git commit -m "feat(auth): add email/password auth exceptions"
```

---

### Task 2: Add Password Validation to AuthService

**Files:**
- Modify: `frontend/lib/core/auth/auth_service.dart`
- Create: `frontend/test/core/auth/auth_service_password_test.dart`

**Step 1: Write the failing test**

Create `frontend/test/core/auth/auth_service_password_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sushiscout/core/auth/auth_service.dart';

void main() {
  group('AuthService.isValidPassword', () {
    test('rejects password shorter than 8 characters', () {
      expect(AuthService.isValidPassword('Abc123'), isFalse);
    });

    test('rejects password without uppercase', () {
      expect(AuthService.isValidPassword('abcdefgh1'), isFalse);
    });

    test('rejects password without lowercase', () {
      expect(AuthService.isValidPassword('ABCDEFGH1'), isFalse);
    });

    test('rejects password without number', () {
      expect(AuthService.isValidPassword('Abcdefgh'), isFalse);
    });

    test('accepts valid password', () {
      expect(AuthService.isValidPassword('Password1'), isTrue);
    });

    test('accepts complex valid password', () {
      expect(AuthService.isValidPassword('MySecure123'), isTrue);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/core/auth/auth_service_password_test.dart`
Expected: FAIL - method not defined

**Step 3: Add the validation method**

Add to `frontend/lib/core/auth/auth_service.dart` (inside the class):

```dart
static bool isValidPassword(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[a-z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  return true;
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/core/auth/auth_service_password_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/core/auth/auth_service.dart frontend/test/core/auth/auth_service_password_test.dart
git commit -m "feat(auth): add password validation helper"
```

---

### Task 3: Add signInWithEmailAndPassword to AuthService

**Files:**
- Modify: `frontend/lib/core/auth/auth_service.dart`
- Create: `frontend/test/core/auth/auth_service_email_test.dart`

**Step 1: Write the failing test**

Create `frontend/test/core/auth/auth_service_email_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sushiscout/core/auth/auth_service.dart';
import 'package:sushiscout/core/auth/auth_exceptions.dart';

import 'auth_service_email_test.mocks.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('AuthService.signInWithEmailAndPassword', () {
    test('throws AuthExceptionWeakPassword for invalid password', () async {
      expect(
        () => authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'weak',
        ),
        throwsA(isA<AuthExceptionWeakPassword>()),
      );
    });

    test('throws AuthExceptionInvalidEmail for invalid email format', () async {
      expect(
        () => authService.signInWithEmailAndPassword(
          email: 'not-an-email',
          password: 'ValidPass1',
        ),
        throwsA(isA<AuthExceptionInvalidEmail>()),
      );
    });

    test('calls FirebaseAuth.signInWithEmailAndPassword', () async {
      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      await authService.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      );

      verify(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      )).called(1);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/core/auth/auth_service_email_test.dart`
Expected: FAIL - method not defined

**Step 3: Add the signInWithEmailAndPassword method**

Add to `frontend/lib/core/auth/auth_service.dart`:

```dart
Future<UserCredential> signInWithEmailAndPassword({
  required String email,
  required String password,
}) async {
  if (!_isValidEmail(email)) {
    throw const AuthExceptionInvalidEmail();
  }

  if (!isValidPassword(password)) {
    throw const AuthExceptionWeakPassword();
  }

  try {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    await _ensureUserDocument(credential.user!);
    
    return credential;
  } on FirebaseAuthException catch (e) {
    throw _mapFirebaseAuthException(e);
  } catch (e) {
    if (e is AuthException) rethrow;
    throw AuthExceptionNetworkError(e.toString());
  }
}

static bool _isValidEmail(String email) {
  return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
}

AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return const AuthExceptionUserNotFound();
    case 'wrong-password':
      return const AuthExceptionWrongPassword();
    case 'too-many-requests':
      return const AuthExceptionTooManyAttempts();
    case 'invalid-email':
      return const AuthExceptionInvalidEmail();
    default:
      return AuthException(_getAuthErrorMessage(e.code), code: e.code);
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/core/auth/auth_service_email_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/core/auth/auth_service.dart frontend/test/core/auth/auth_service_email_test.dart
git commit -m "feat(auth): add signInWithEmailAndPassword method"
```

---

### Task 4: Add Password Reset to AuthService

**Files:**
- Modify: `frontend/lib/core/auth/auth_service.dart`
- Create: `frontend/test/core/auth/auth_service_reset_test.dart`

**Step 1: Write the failing test**

Create `frontend/test/core/auth/auth_service_reset_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sushiscout/core/auth/auth_service.dart';

import 'auth_service_reset_test.mocks.dart';

@GenerateMocks([FirebaseAuth])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('AuthService.sendPasswordResetEmail', () {
    test('calls FirebaseAuth.sendPasswordResetEmail', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenAnswer((_) async {});

      await authService.sendPasswordResetEmail('test@example.com');

      verify(mockAuth.sendPasswordResetEmail(email: 'test@example.com'))
          .called(1);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/core/auth/auth_service_reset_test.dart`
Expected: FAIL - method not defined

**Step 3: Add the sendPasswordResetEmail method**

Add to `frontend/lib/core/auth/auth_service.dart`:

```dart
Future<void> sendPasswordResetEmail(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (e) {
    throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/core/auth/auth_service_reset_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/core/auth/auth_service.dart frontend/test/core/auth/auth_service_reset_test.dart
git commit -m "feat(auth): add sendPasswordResetEmail method"
```

---

### Task 5: Update AuthNotifier with Email/Password Methods

**Files:**
- Modify: `frontend/lib/presentation/providers/auth_provider.dart`
- Create: `frontend/test/presentation/providers/auth_provider_email_test.dart`

**Step 1: Write the failing test**

Create `frontend/test/presentation/providers/auth_provider_email_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sushiscout/core/auth/auth_state.dart';
import 'package:sushiscout/presentation/providers/auth_provider.dart';
import 'package:sushiscout/core/auth/auth_service.dart';
import 'package:sushiscout/core/auth/auth_exceptions.dart';

import 'auth_provider_email_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late ProviderContainer container;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(mockAuthService),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier.signInWithEmailAndPassword', () {
    test('calls AuthService.signInWithEmailAndPassword', () async {
      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => MockUserCredential());

      await container
          .read(authProvider.notifier)
          .signInWithEmailAndPassword('test@example.com', 'ValidPass1');

      verify(mockAuthService.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      )).called(1);
    });
  });

  group('AuthNotifier.sendPasswordResetEmail', () {
    test('calls AuthService.sendPasswordResetEmail', () async {
      when(mockAuthService.sendPasswordResetEmail(anyNamed('email')))
          .thenAnswer((_) async {});

      await container
          .read(authProvider.notifier)
          .sendPasswordResetEmail('test@example.com');

      verify(mockAuthService.sendPasswordResetEmail('test@example.com'))
          .called(1);
    });
  });
}

class MockUserCredential implements UserCredential {
  @override
  User? get user => null;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/presentation/providers/auth_provider_email_test.dart`
Expected: FAIL - methods not defined

**Step 3: Add the methods to AuthNotifier**

Add to `frontend/lib/presentation/providers/auth_provider.dart` in the `AuthNotifier` class:

```dart
Future<void> signInWithEmailAndPassword(String email, String password) async {
  state = state.copyWith(status: AuthStatus.loading);

  try {
    final authService = ref.read(authServiceProvider);
    await authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } on AuthException catch (e) {
    state = AuthState(
      status: AuthStatus.error,
      errorMessage: e.message,
    );
  } catch (e) {
    state = AuthState(
      status: AuthStatus.error,
      errorMessage: 'Sign in failed: ${e.toString()}',
    );
  }
}

Future<void> sendPasswordResetEmail(String email) async {
  try {
    final authService = ref.read(authServiceProvider);
    await authService.sendPasswordResetEmail(email);
  } catch (e) {
    state = AuthState(
      status: AuthStatus.error,
      errorMessage: 'Failed to send reset email: ${e.toString()}',
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/presentation/providers/auth_provider_email_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/presentation/providers/auth_provider.dart frontend/test/presentation/providers/auth_provider_email_test.dart
git commit -m "feat(auth): add email/password methods to AuthNotifier"
```

---

### Task 6: Update LoginScreen with Conditional Platform UI

**Files:**
- Modify: `frontend/lib/presentation/screens/auth/login_screen.dart`
- Create: `frontend/test/presentation/screens/auth/login_screen_test.dart`

**Step 1: Write the failing test**

Create `frontend/test/presentation/screens/auth/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sushiscout/presentation/screens/auth/login_screen.dart';
import 'package:sushiscout/core/auth/auth_state.dart';
import 'package:sushiscout/presentation/providers/auth_provider.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('shows Google Sign-In button on mobile platforms', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Google'), findsOneWidget);
    });

    testWidgets('shows email and password fields on Windows/Linux', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.byType(TextField), findsWidgets);
      expect(find.textContaining('Email'), findsOneWidget);
      expect(find.textContaining('Password'), findsOneWidget);
    });

    testWidgets('shows Forgot Password button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Forgot'), findsOneWidget);
    });

    testWidgets('shows Sign In button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Sign In'), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/presentation/screens/auth/login_screen_test.dart`
Expected: FAIL - UI elements not found

**Step 3: Update LoginScreen with conditional UI**

Replace `frontend/lib/presentation/screens/auth/login_screen.dart`:

```dart
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                Icon(
                  Icons.sports_soccer,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'SushiScout 26',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'FRC & FTC Scouting',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const Spacer(),

                if (authState.hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.error),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text(
                            authState.errorMessage ?? 'An error occurred',
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                ],

                if (_isDesktop) ...[
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => _sendPasswordReset(context),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: authState.status == AuthStatus.loading
                          ? null
                          : () =>
                              ref.read(authProvider.notifier).signInWithGoogle(),
                      icon: authState.status == AuthStatus.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        authState.status == AuthStatus.loading
                            ? 'Signing in...'
                            : 'Sign in with Google',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingLg),

                Text(
                  _isDesktop
                      ? 'First time? Sign in on mobile/web with Google first'
                      : 'Sign in required for team-based data',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.spacingLg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    await ref.read(authProvider.notifier).sendPasswordResetEmail(email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    }
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/presentation/screens/auth/login_screen_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add frontend/lib/presentation/screens/auth/login_screen.dart frontend/test/presentation/screens/auth/login_screen_test.dart
git commit -m "feat(ui): add conditional email/password UI for desktop platforms"
```

---

### Task 7: Regenerate Mock Files

**Files:**
- Modified: `frontend/test/helpers/mocks.mocks.dart`

**Step 1: Run build_runner**

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`
Expected: Successful build

**Step 2: Commit**

```bash
git add frontend/test/helpers/mocks.mocks.dart
git commit -m "chore: regenerate mock files for new auth methods"
```

---

### Task 8: Verify All Tests Pass

**Step 1: Run all tests**

Run: `cd frontend && flutter test`
Expected: All tests pass

**Step 2: Run analyzer**

Run: `cd frontend && flutter analyze`
Expected: No issues found

**Step 3: Push all changes**

```bash
git push
```
