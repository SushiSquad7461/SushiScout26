# Email/Password Auth for Windows/Linux Design

**Goal:** Enable Windows/Linux users to sign in with email/password while maintaining account unity with Google Sign-In on mobile/web.

**Branch:** feature/auth

## Architecture

### Flow Summary
- **Mobile/Web:** Google Sign-In (existing, unchanged)
- **Windows/Linux:** Email/password sign-in only (no registration)
- **Account Linking:** Firebase automatic - same email = same user
- **Password Setup:** Users trigger password reset email from Windows/Linux login screen
- **Security:** 8+ chars, mixed case, number required + reCAPTCHA v3

### Key Components

1. **AuthService** - add `signInWithEmailAndPassword()` method
2. **LoginScreen** - conditional UI based on platform
3. **AuthNotifier** - add email/password sign-in action
4. **AuthExceptions** - add email/password specific errors

## Component Details

### AuthService Changes

```dart
// Add to existing AuthService class
Future<UserCredential> signInWithEmailAndPassword({
  required String email,
  required String password,
});

// Add password validation helper
static bool isValidPassword(String password) {
  return password.length >= 8 &&
         password.contains(RegExp(r'[A-Z]')) &&
         password.contains(RegExp(r'[a-z]')) &&
         password.contains(RegExp(r'[0-9]'));
}
```

### New AuthExceptions

```dart
class AuthExceptionWeakPassword extends AuthException
class AuthExceptionInvalidEmail extends AuthException
class AuthExceptionWrongPassword extends AuthException
class AuthExceptionTooManyAttempts extends AuthException
```

### LoginScreen UI (Windows/Linux)

- Email input field
- Password input field (obscured)
- "Sign In" button
- "Forgot Password?" link → triggers Firebase password reset
- Error display area
- Logout button (visible when authenticated)

### reCAPTCHA Integration

- Use `firebase_auth` built-in reCAPTCHA verifier
- For desktop, Firebase handles via invisible reCAPTCHA during sign-in

## Account Linking Behavior

Firebase Auth automatically links accounts with the same email address:
1. User signs in with Google on mobile (email: bob@example.com)
2. Firebase creates user with Google provider
3. User goes to Windows, clicks "Forgot Password"
4. Firebase sends password reset email to bob@example.com
5. User sets password
6. User signs in on Windows with email/password
7. Firebase recognizes same email, links credentials automatically
8. Same UID, same Firestore data, seamless experience

## Security Requirements

1. **Password Rules:**
   - Minimum 8 characters
   - At least one uppercase letter
   - At least one lowercase letter
   - At least one number

2. **reCAPTCHA v3:**
   - Invisible verification during sign-in
   - Blocks bot/automated attacks

3. **Rate Limiting:**
   - Firebase handles brute-force protection
   - Too many failed attempts → temporary lockout

## User Experience Flow

### First Time on Windows/Linux
1. User sees email/password form
2. User enters email, clicks "Forgot Password?"
3. Firebase sends reset email
4. User sets password via email link
5. User returns to app, signs in with email/password

### Subsequent Sign-ins
1. User enters email and password
2. App validates password format locally
3. Firebase Auth with reCAPTCHA
4. Success → authenticated

### Logout
- Logout button visible when authenticated
- Clears both Firebase and any local session state
