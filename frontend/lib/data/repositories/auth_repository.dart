import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_exceptions.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final AuthService _authService;
  final FirebaseFirestore _firestore;

  AuthRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  User? get currentUser => _authService.currentUser;

  Future<UserProfile> signInWithGoogle() async {
    final credential = await _authService.signInWithGoogle();
    if (credential.user == null) {
      throw const AuthException('Failed to sign in');
    }
    
    final profile = await _authService.getUserProfile(credential.user!.uid);
    if (profile == null) {
      throw const AuthExceptionUserNotFound();
    }
    return profile;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    return _authService.getUserProfile(user.uid);
  }

  Future<UserProfile?> refreshUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserProfile.fromFirestore(doc);
    }
    return null;
  }
}
