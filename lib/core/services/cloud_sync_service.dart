// lib/core/services/cloud_sync_service.dart
// Sync local gamification data to Firebase Firestore

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._();
  CloudSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late Box _statsBox;

  Future<void> init() async {
    _statsBox = await Hive.openBox('gamification_stats');
  }

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> syncStatsToCloud() async {
    if (_currentUser == null) return;

    final localData = _statsBox.get('user_stats');
    if (localData == null) return;

    final localStats = _parseLocalStats(localData);
    final cloudData = await _fetchCloudStats();

    if (cloudData == null) {
      await _uploadStatsToCloud(localStats);
    } else {
      final merged = _mergeStats(localStats, cloudData);
      await _uploadStatsToCloud(merged);
    }
  }

  Future<void> _uploadStatsToCloud(Map<String, dynamic> stats) async {
    if (_currentUser == null) return;

    await _db.collection('users').doc(_currentUser!.uid).update({
      'xp': stats['xp'] ?? 0,
      'level': stats['level'] ?? 1,
      'coins': stats['coins'] ?? 100,
      'current_streak': stats['currentStreak'] ?? 0,
      'longest_streak': stats['longestStreak'] ?? 0,
      'lives': stats['lives'] ?? 3,
      'referral_count': stats['referralCount'] ?? 0,
      'last_sync': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> _fetchCloudStats() async {
    if (_currentUser == null) return null;
    final doc = await _db.collection('users').doc(_currentUser!.uid).get();
    return doc.exists ? doc.data() : null;
  }

  Map<String, dynamic> _parseLocalStats(dynamic data) {
    if (data is String && data.startsWith('{')) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, dynamic> _mergeStats(
      Map<String, dynamic> local, Map<String, dynamic> cloud) {
    return {
      'xp': (local['xp'] ?? 0) > (cloud['xp'] ?? 0) ? local['xp'] : cloud['xp'],
      'level': (local['level'] ?? 1) > (cloud['level'] ?? 1)
          ? local['level']
          : cloud['level'],
      'coins': (local['coins'] ?? 100) > (cloud['coins'] ?? 100)
          ? local['coins']
          : cloud['coins'],
      'currentStreak':
          (local['currentStreak'] ?? 0) > (cloud['current_streak'] ?? 0)
              ? local['currentStreak']
              : cloud['current_streak'],
      'longestStreak':
          (local['longestStreak'] ?? 0) > (cloud['longest_streak'] ?? 0)
              ? local['longestStreak']
              : cloud['longest_streak'],
      'lives': (local['lives'] ?? 3) > (cloud['lives'] ?? 3)
          ? local['lives']
          : cloud['lives'],
      'referralCount':
          (local['referralCount'] ?? 0) > (cloud['referral_count'] ?? 0)
              ? local['referralCount']
              : cloud['referral_count'],
    };
  }

  Future<void> onQuizComplete(
      {required int score,
      required int xpEarned,
      required int coinsEarned}) async {
    if (_currentUser == null) return;
    await _db.collection('users').doc(_currentUser!.uid).update({
      'total_score': FieldValue.increment(score),
      'total_attempts': FieldValue.increment(1),
      'xp': FieldValue.increment(xpEarned),
      'coins': FieldValue.increment(coinsEarned),
    });
  }

  Future<void> onStreakUpdate(int newStreak) async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'current_streak': newStreak});
  }

  Future<void> onDailyRewardClaim() async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'last_daily_reward': FieldValue.serverTimestamp()});
  }

  Future<void> onAchievementUnlock(String achievementId) async {
    if (_currentUser == null) return;
    await _db.collection('users').doc(_currentUser!.uid).update({
      'unlocked_achievements': FieldValue.arrayUnion([achievementId])
    });
  }

  Future<void> onLevelUp(int newLevel) async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'level': newLevel});
  }

  Future<void> addCoins(int amount) async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'coins': FieldValue.increment(amount)});
  }

  Future<void> useCoins(int amount) async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'coins': FieldValue.increment(-amount)});
  }

  Future<void> useLife() async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'lives': FieldValue.increment(-1)});
  }

  Future<void> addLife() async {
    if (_currentUser == null) return;
    await _db
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'lives': FieldValue.increment(1)});
  }
}
