import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/auth_exceptions.dart';
import '../../core/auth/claims_refresher.dart';
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

      await _loadUserProfile();
    } catch (e) {
      // Preserve identity — leave failed so the user is still in their teams.
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> switchTeam(String teamId) async {
    try {
      final userId = state.userId;
      if (userId == null) return;

      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.getTeam(teamId);

      // Persist to Firestore so it survives app restarts
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.updateCurrentTeamId(teamId);

      state = state.copyWith(
        currentTeamId: teamId,
        isMasterTeamMember: team?.isMasterTeam ?? false,
      );
    } catch (e) {
      // Preserve identity — switch failed so the user is still on the
      // previous team.
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
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
