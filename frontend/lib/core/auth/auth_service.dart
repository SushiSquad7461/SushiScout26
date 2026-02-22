import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_exceptions.dart';
import '../../data/models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn? _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isGoogleSignInSupported => _googleSignIn != null;

  Future<UserCredential> signInWithGoogle() async {
    if (_googleSignIn == null) {
      throw const AuthException('Google Sign-In is not supported on this platform');
    }
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        throw const AuthException('Sign in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      await _ensureUserDocument(userCredential.user!);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthExceptionNetworkError(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn?.signOut();
  }

  Future<void> _ensureUserDocument(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'teamMemberships': {},
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      await userRef.update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromFirestore(doc);
    }
    return null;
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-disabled':
        return 'This account has been disabled';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'invalid-credential':
        return 'Invalid credentials';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed';
    }
  }
}
