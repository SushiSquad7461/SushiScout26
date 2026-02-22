enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsTeamSelection,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? userEmail;
  final String? displayName;
  final String? photoUrl;
  final String? currentTeamId;
  final Map<String, String> teamMemberships;
  final bool isMasterTeamMember;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userEmail,
    this.displayName,
    this.photoUrl,
    this.currentTeamId,
    this.teamMemberships = const {},
    this.isMasterTeamMember = false,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get needsTeam => status == AuthStatus.needsTeamSelection;
  bool get hasError => status == AuthStatus.error;
  
  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? userEmail,
    String? displayName,
    String? photoUrl,
    String? currentTeamId,
    Map<String, String>? teamMemberships,
    bool? isMasterTeamMember,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      currentTeamId: currentTeamId ?? this.currentTeamId,
      teamMemberships: teamMemberships ?? this.teamMemberships,
      isMasterTeamMember: isMasterTeamMember ?? this.isMasterTeamMember,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
