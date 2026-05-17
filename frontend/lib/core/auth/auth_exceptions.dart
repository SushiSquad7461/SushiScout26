class AuthException implements Exception {
  final String message;
  final String? code;
  
  const AuthException(this.message, {this.code});
  
  @override
  String toString() => 'AuthException: $message';
}

class AuthExceptionNotSignedIn extends AuthException {
  const AuthExceptionNotSignedIn() : super('User is not signed in');
}

class AuthExceptionUserNotFound extends AuthException {
  const AuthExceptionUserNotFound() : super('User profile not found');
}

class AuthExceptionTeamNotFound extends AuthException {
  const AuthExceptionTeamNotFound() : super('Team not found');
}

class AuthExceptionInvalidInviteCode extends AuthException {
  const AuthExceptionInvalidInviteCode() : super('Invalid invite code');
}

class AuthExceptionAlreadyInTeam extends AuthException {
  const AuthExceptionAlreadyInTeam() : super('Already a member of this team');
}

class AuthExceptionCannotLeaveTeam extends AuthException {
  const AuthExceptionCannotLeaveTeam() : super('Cannot leave team: transfer admin role first');
}

class AuthExceptionNetworkError extends AuthException {
  const AuthExceptionNetworkError([super.message = 'Network error']);
}

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
