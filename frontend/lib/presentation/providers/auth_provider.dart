import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/auth_exceptions.dart';
import '../../core/auth/claims_refresher.dart';
import '../../data/models/team.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/team_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  GoogleSignIn? googleSignIn;
  
  if (kIsWeb) {
    // Web must be checked first — on a Windows machine, defaultTargetPlatform
    // is TargetPlatform.windows even when running in Chrome.
    googleSignIn = GoogleSignIn(
      clientId: '80003441956-f6ses5oufoeiatcvvrmrn3malkmts4be.apps.googleusercontent.com',
      scopes: [
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ],
    );
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    googleSignIn = null;
  } else {
    googleSignIn = GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ],
    );
  }
  
  return AuthService(googleSignIn: googleSignIn);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(authService: ref.read(authServiceProvider));
});

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository();
});

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSub;

  @override
  AuthState build() {
    _initAuthListener();
    ref.onDispose(() {
      _authSub?.cancel();
      _authSub = null;
    });
    return const AuthState(status: AuthStatus.loading);
  }

  void _initAuthListener() {
    final authRepo = ref.read(authRepositoryProvider);
    // Cancel previous subscription if build runs again (provider invalidation).
    _authSub?.cancel();
    _authSub = authRepo.authStateChanges.listen((User? user) async {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        await _loadUserProfile();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final firebaseUser = authRepo.currentUser;
      final profile = await authRepo.getCurrentUserProfile();
      
      if (profile == null) {
        state = AuthState(
          status: AuthStatus.needsTeamSelection,
          userId: firebaseUser?.uid,
          userEmail: firebaseUser?.email,
          displayName: firebaseUser?.displayName,
          photoUrl: firebaseUser?.photoURL,
        );
        return;
      }
      
      if (profile.currentTeamId == null) {
        state = AuthState(
          status: AuthStatus.needsTeamSelection,
          userId: profile.id,
          userEmail: profile.email,
          displayName: profile.displayName,
          photoUrl: profile.photoUrl,
          teamMemberships: profile.teamMemberships,
        );
        return;
      }
      
      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.getTeam(profile.currentTeamId!);
      
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: profile.id,
        userEmail: profile.email,
        displayName: profile.displayName,
        photoUrl: profile.photoUrl,
        currentTeamId: profile.currentTeamId,
        teamMemberships: profile.teamMemberships,
        isMasterTeamMember: team?.isMasterTeam ?? false,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      
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

  Future<void> signOut() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      // Preserve identity — the user is still signed in if signOut threw.
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sign out failed: ${e.toString()}',
      );
    }
  }

  Future<void> createTeam(String name, {bool isMasterTeam = false}) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      final userId = state.userId;
      if (userId == null) {
        throw const AuthException('Not signed in');
      }
      
      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.createTeam(
        name: name,
        createdBy: userId,
        isMasterTeam: isMasterTeam,
      );

      final authService = ref.read(authServiceProvider);
      await waitForTeamClaim(
        fetchClaims: authService.forceRefreshClaims,
        expectedTeamId: team.id,
      );

      await _loadUserProfile();
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
        userId: state.userId,
        userEmail: state.userEmail,
        displayName: state.displayName,
        photoUrl: state.photoUrl,
        teamMemberships: state.teamMemberships,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Failed to create team: ${e.toString()}',
        userId: state.userId,
        userEmail: state.userEmail,
        displayName: state.displayName,
        photoUrl: state.photoUrl,
        teamMemberships: state.teamMemberships,
      );
    }
  }

  Future<void> joinTeam(String inviteCode) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      final userId = state.userId;
      if (userId == null) {
        throw const AuthException('Not signed in');
      }
      
      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.joinTeamByCode(
        inviteCode: inviteCode,
        userId: userId,
      );

      if (team != null) {
        final authService = ref.read(authServiceProvider);
        await waitForTeamClaim(
          fetchClaims: authService.forceRefreshClaims,
          expectedTeamId: team.id,
        );
      }

      await _loadUserProfile();
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
        userId: state.userId,
        userEmail: state.userEmail,
        displayName: state.displayName,
        photoUrl: state.photoUrl,
        teamMemberships: state.teamMemberships,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Failed to join team: ${e.toString()}',
        userId: state.userId,
        userEmail: state.userEmail,
        displayName: state.displayName,
        photoUrl: state.photoUrl,
        teamMemberships: state.teamMemberships,
      );
    }
  }

  Future<void> leaveTeam(String teamId) async {
    try {
      final userId = state.userId;
      if (userId == null) return;

      final teamRepo = ref.read(teamRepositoryProvider);
      await teamRepo.leaveTeam(teamId: teamId, userId: userId);

      // Force-refresh the token so the reduced claim (team removed
      // server-side) takes effect immediately, closing the isolation seam
      // where a stale token would still grant access to the left team's
      // data until the natural ~1h refresh. Unlike join, we're waiting for
      // a claim to disappear, so a single forced refresh (not
      // waitForTeamClaim's polling-for-presence) is what fits here.
      try {
        await ref.read(authServiceProvider).forceRefreshClaims();
      } catch (_) {
        // A failed refresh should not crash the leave — the profile reload
        // below still reflects the server-side membership change, and the
        // token will naturally refresh later.
      }

      await _loadUserProfile();
    } catch (e) {
      // Preserve identity — leave failed so the user is still in their teams.
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Switches the active team. Persists the new `currentTeamId` to Firestore
  /// so it survives restarts. NOTE: this deliberately does NOT catch failures
  /// into a global `AuthStatus.error` — its only callers are the in-app team
  /// flows (`joinTeamInApp`/`createTeamInApp` and the settings section), which
  /// surface errors inline and must not tear the settings modal down via a
  /// global status flip. On failure the exception propagates and state is left
  /// unchanged (identity + previous active team preserved).
  Future<void> switchTeam(String teamId) async {
    final userId = state.userId;
    if (userId == null) return;

    final teamRepo = ref.read(teamRepositoryProvider);
    final team = await teamRepo.getTeam(teamId);

    // Persist to Firestore so it survives app restarts.
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.updateCurrentTeamId(teamId);

    state = state.copyWith(
      currentTeamId: teamId,
      isMasterTeamMember: team?.isMasterTeam ?? false,
    );
  }

  /// Joins a team from inside the authenticated app. Same work as [joinTeam]
  /// (callable -> wait for claim -> reload profile) but deliberately never
  /// sets `status = loading`/`error`: the caller is the settings sheet, a
  /// modal over the dashboard, and AuthWrapper swaps the whole screen to a
  /// spinner whenever status is loading — which would tear the sheet down.
  /// Reports failure by throwing so the section can show it inline. Auto-
  /// switches the active team to the joined one on success.
  Future<void> joinTeamInApp(String inviteCode) async {
    final userId = state.userId;
    if (userId == null) throw const AuthException('Not signed in');

    final teamRepo = ref.read(teamRepositoryProvider);
    final team = await teamRepo.joinTeamByCode(
      inviteCode: inviteCode,
      userId: userId,
    );
    if (team == null) throw const AuthException('Could not join team');

    await waitForTeamClaim(
      fetchClaims: ref.read(authServiceProvider).forceRefreshClaims,
      expectedTeamId: team.id,
    );
    await _loadUserProfile();
    await switchTeam(team.id);
  }

  /// Creates a team from inside the authenticated app. See [joinTeamInApp]
  /// for why this avoids the global loading/error status. Auto-switches to
  /// the new team on success.
  Future<void> createTeamInApp(String name) async {
    final userId = state.userId;
    if (userId == null) throw const AuthException('Not signed in');

    final teamRepo = ref.read(teamRepositoryProvider);
    final team = await teamRepo.createTeam(name: name, createdBy: userId);

    await waitForTeamClaim(
      fetchClaims: ref.read(authServiceProvider).forceRefreshClaims,
      expectedTeamId: team.id,
    );
    await _loadUserProfile();
    await switchTeam(team.id);
  }

  void clearError() {
    if (state.userId != null) {
      if (state.currentTeamId != null) {
        state = state.copyWith(status: AuthStatus.authenticated, errorMessage: null);
      } else {
        state = state.copyWith(status: AuthStatus.needsTeamSelection, errorMessage: null);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentTeamIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).currentTeamId;
});

final isMasterTeamProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isMasterTeamMember;
});

/// Admin-ness comes from AuthState.teamMemberships (teamId -> role), which
/// is populated from the `users/{uid}` Firestore doc's `teamMemberships`
/// field (`profile.teamMemberships`) — NOT from the `teams` custom claim.
/// That's fine, not a trust gap: both the claim and this Firestore field
/// are written only by the create_team/join_team/leave_team Admin-SDK
/// callables, and Firestore rules deny clients from writing this field
/// directly. But keep the distinction straight — the claim is what
/// Firestore rules trust for isolation; this field is what the UI reads
/// for "is this user an admin of their active team".
final isTeamAdminProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  final teamId = auth.currentTeamId;
  if (teamId == null) return false;
  return auth.teamMemberships[teamId] == 'admin';
});

/// Every team the signed-in user belongs to, for the Team settings section.
/// Re-runs when the active team changes (join/create/switch) so the list and
/// the active highlight stay in sync. autoDispose so it refetches each time
/// the settings sheet reopens.
final userTeamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return const <Team>[];
  ref.watch(currentTeamIdProvider); // refresh when the active team changes
  return ref.read(teamRepositoryProvider).getUserTeams(userId);
});
