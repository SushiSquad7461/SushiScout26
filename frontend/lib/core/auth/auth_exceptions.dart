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
  const AuthExceptionNetworkError([String message = 'Network error']) : super(message);
}
