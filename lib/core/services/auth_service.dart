// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import 'admin_service.dart';

class AuthResult {
  final UserCredential credential;
  final bool isAdminEmail; // email matches admin
  final bool isAdmin; // fully verified

  AuthResult({
    required this.credential,
    this.isAdminEmail = false,
    this.isAdmin = false,
  });
}

class AuthService {
  AuthService();

  static Future<void>? _googleReady;

  static Future<void> _ensureGoogleSignIn() async {
    _googleReady ??= GoogleSignIn.instance.initialize();
    await _googleReady!;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  Future<GoogleSignInAccount?> _authenticateInteractive() async {
    await _ensureGoogleSignIn();
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      throw AuthException(e.description ?? e.toString());
    }
  }

  OAuthCredential _firebaseCredentialFromGoogleAccount(
      GoogleSignInAccount account) {
    final gAuth = account.authentication;
    return GoogleAuthProvider.credential(idToken: gAuth.idToken);
  }

  Future<AuthResult?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _authenticateInteractive();
      if (account == null) return null;

      final credential = _firebaseCredentialFromGoogleAccount(account);
      final userCred = await _auth.signInWithCredential(credential);
      await _upsertUserDoc(userCred.user!, isAnonymous: false);
      await _syncLocalToCloud(userCred.user!.uid);

      bool isAdminEmail = false;
      try {
        isAdminEmail = await AdminService.instance.verifyEmailOnly(
          userCred.user!.email ?? '',
        );
      } catch (_) {
        // If Firestore fails, treat as normal user
        isAdminEmail = false;
      }

      return AuthResult(
        credential: userCred,
        isAdminEmail: isAdminEmail,
        isAdmin: false,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed');
    }
  }

  Future<bool> verifyAdminPassword(String email, String password) async {
    try {
      return await AdminService.instance.verifyAdmin(
        email: email,
        password: password,
      );
    } catch (_) {
      return false;
    }
  }

  Future<UserCredential> signInAnonymously() async {
    try {
      final userCred = await _auth.signInAnonymously();
      await _upsertUserDoc(userCred.user!, isAnonymous: true);
      return userCred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Anonymous sign-in failed');
    }
  }

  Future<UserCredential?> upgradeAnonymousAccount() async {
    try {
      final GoogleSignInAccount? account = await _authenticateInteractive();
      if (account == null) return null;

      final credential = _firebaseCredentialFromGoogleAccount(account);
      final userCred = await currentUser!.linkWithCredential(credential);
      await _upsertUserDoc(userCred.user!, isAnonymous: false);
      await _syncLocalToCloud(userCred.user!.uid);
      return userCred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        final result = await signInWithGoogle();
        return result?.credential;
      }
      throw AuthException(e.message ?? 'Upgrade failed');
    }
  }

  Future<void> signOut() async {
    await _ensureGoogleSignIn();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  Future<void> _upsertUserDoc(User user, {required bool isAnonymous}) async {
    final ref = _db.collection(AppConstants.colUsers).doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'display_name': isAnonymous ? 'Guest' : (user.displayName ?? 'User'),
        'email': user.email,
        'photo_url': user.photoURL,
        'language': AppConstants.defaultLanguage,
        'is_pro': false,
        'is_anonymous': isAnonymous,
        'fcm_token': null,
        'created_at': FieldValue.serverTimestamp(),
        'last_seen': FieldValue.serverTimestamp(),
        'total_score': 0,
        'total_attempts': 0,
        'exam_mode': 'GENERAL',
        'xp': 0,
        'level': 1,
        'coins': 100,
        'current_streak': 0,
        'longest_streak': 0,
        'lives': 3,
        'referral_code':
            'GKQ${const Uuid().v4().substring(0, 6).toUpperCase()}',
        'referral_count': 0,
        'unlocked_achievements': [],
        'last_daily_reward': null,
      });
    } else {
      await ref.update({
        'last_seen': FieldValue.serverTimestamp(),
        'is_anonymous': isAnonymous,
      });
    }
  }

  Future<void> updateFcmToken(String token) async {
    if (currentUser == null) return;
    await _db
        .collection(AppConstants.colUsers)
        .doc(currentUser!.uid)
        .update({'fcm_token': token});
  }

  Future<void> _syncLocalToCloud(String uid) async {
    // Implementation will be in cloud sync service
  }

  Future<void> updateUserStats(Map<String, dynamic> stats) async {
    if (currentUser == null) return;
    await _db
        .collection(AppConstants.colUsers)
        .doc(currentUser!.uid)
        .update(stats);
  }

  Future<Map<String, dynamic>?> fetchUserStatsFromCloud() async {
    if (currentUser == null) return null;
    final doc =
        await _db.collection(AppConstants.colUsers).doc(currentUser!.uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw AuthException('No user logged in');

    await _db.collection(AppConstants.colUsers).doc(user.uid).delete();

    final batch = _db.batch();
    final attempts = await _db
        .collection(AppConstants.colAttempts)
        .where('uid', isEqualTo: user.uid)
        .get();
    for (final doc in attempts.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await user.delete();

    await _ensureGoogleSignIn();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
