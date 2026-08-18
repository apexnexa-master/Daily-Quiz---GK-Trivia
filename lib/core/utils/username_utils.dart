import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsernameUtils {
  UsernameUtils._();

  static const int minLength = 3;
  static const int maxLength = 20;
  static const int displayMaxLength = 16;

  static final _allowedPattern = RegExp(r'^[a-zA-Z0-9_.]+$');
  static const _reserved = {
    'admin', 'moderator', 'support', 'system', 'official',
    'test', 'guest', 'anonymous', 'null', 'undefined',
  };

  static String? validate(String raw) {
    final name = raw.trim();

    if (name.isEmpty) return 'Username cannot be empty';
    if (name.length < minLength) return 'At least $minLength characters required';
    if (name.length > maxLength) return 'Max $maxLength characters allowed';
    if (!_allowedPattern.hasMatch(name)) {
      return 'Only letters, numbers, _ and . allowed';
    }
    if (_reserved.contains(name.toLowerCase())) return 'This username is reserved';
    return null;
  }

  static Future<bool> isTaken(String name) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('display_name', isEqualTo: name.trim())
          .limit(1)
          .get();

      for (final doc in result.docs) {
        if (doc.id != uid) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> validateWithUniqueness(String raw) async {
    final localError = validate(raw);
    if (localError != null) return localError;

    final taken = await isTaken(raw.trim());
    if (taken) return 'Username already taken';
    return null;
  }

  static String truncate(String name) {
    if (name.length <= displayMaxLength) return name;
    return '${name.substring(0, displayMaxLength - 1)}\u2026';
  }
}
