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

  /// Sentinel used by [copyWith] so callers can distinguish "leave this field
  /// alone" from "explicitly set this nullable field to null".
  static const Object _unset = Object();

  AuthState copyWith({
    AuthStatus? status,
    Object? userId = _unset,
    Object? userEmail = _unset,
    Object? displayName = _unset,
    Object? photoUrl = _unset,
    Object? currentTeamId = _unset,
    Map<String, String>? teamMemberships,
    bool? isMasterTeamMember,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      userEmail:
          identical(userEmail, _unset) ? this.userEmail : userEmail as String?,
      displayName: identical(displayName, _unset)
          ? this.displayName
          : displayName as String?,
      photoUrl:
          identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
      currentTeamId: identical(currentTeamId, _unset)
          ? this.currentTeamId
          : currentTeamId as String?,
      teamMemberships: teamMemberships ?? this.teamMemberships,
      isMasterTeamMember: isMasterTeamMember ?? this.isMasterTeamMember,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
