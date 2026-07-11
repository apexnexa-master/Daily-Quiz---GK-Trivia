// lib/core/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class AdminService {
  static final AdminService instance = AdminService._();
  AdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _verifiedAdminEmail;

  bool get isVerified => _verifiedAdminEmail != null;
  String? get verifiedEmail => _verifiedAdminEmail;

  /// Check if email matches any active admin in 'admin' collection
  /// Each doc has: username, pass, status ("A" = active)
  Future<bool> verifyEmailOnly(String email) async {
    try {
      if (email.isEmpty) return false;

      final snapshot = await _db.collection('admin').get();
      final emailLower = email.toLowerCase().trim();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final username =
            (data['username'] as String?)?.toLowerCase().trim() ?? '';
        final status = (data['status'] as String?)?.toUpperCase() ?? '';

        if (username == emailLower && status == 'A') {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  /// Verify admin email and password
  Future<bool> verifyAdmin({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        _lastError = 'Email or password is empty';
        return false;
      }

      final snapshot = await _db.collection('admin').get();

      if (snapshot.docs.isEmpty) {
        _lastError = 'No admin documents found in Firestore';
        return false;
      }

      final emailLower = email.toLowerCase().trim();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final username =
            (data['username'] as String?)?.toLowerCase().trim() ?? '';
        final pass = data['pass'] as String? ?? '';
        final status = (data['status'] as String?)?.toUpperCase() ?? '';

        AppLogger.info('Checking admin: username=$username, status=$status', name: 'ADMIN');

        if (username == emailLower && pass == password && status == 'A') {
          _verifiedAdminEmail = emailLower;
          _lastError = null;
          return true;
        }
      }
      _lastError = 'Invalid email or password';
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  void logout() {
    _verifiedAdminEmail = null;
  }
}
