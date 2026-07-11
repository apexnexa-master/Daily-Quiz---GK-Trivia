// lib/core/services/gamification/user_stats_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/gamification_models.dart';
import '../cloud_sync_service.dart';

class UserStatsService {
  UserStatsService._();
  static final UserStatsService instance = UserStatsService._();

  late Box _statsBox;

  Future<void> init() async {
    _statsBox = await Hive.openBox('gamification_stats');
  }

  Future<UserStatsModel> getUserStats() async {
    final data = _statsBox.get('user_stats');
    if (data != null) {
      return _userStatsFromJson(jsonDecode(data));
    }
    return UserStatsModel(
      referralCode: _generateReferralCodeInitial(),
    );
  }

  Future<void> saveUserStats(UserStatsModel stats) async {
    await _statsBox.put('user_stats', jsonEncode(_userStatsToJson(stats)));
  }

  Future<UserStatsModel> addXP(int xp) async {
    final stats = await getUserStats();
    int newXP = stats.xp + xp;
    int newLevel = stats.level;

    while (newXP >= UserStatsModel.xpForLevel(newLevel + 1)) {
      newLevel++;
    }

    final updated = stats.copyWith(xp: newXP, level: newLevel);
    await saveUserStats(updated);
    
    // Cloud sync!
    await CloudSyncService.instance.onLevelUp(newLevel);
    return updated;
  }

  Future<UserStatsModel> addCoins(int coins) async {
    final stats = await getUserStats();
    final updated = stats.copyWith(coins: stats.coins + coins);
    await saveUserStats(updated);
    
    await CloudSyncService.instance.addCoins(coins);
    return updated;
  }

  Future<UserStatsModel> spendCoins(int amount) async {
    final stats = await getUserStats();
    if (stats.coins < amount) {
      throw Exception('Not enough coins');
    }
    final updated = stats.copyWith(coins: stats.coins - amount);
    await saveUserStats(updated);
    
    await CloudSyncService.instance.useCoins(amount);
    return updated;
  }

  Future<UserStatsModel> addLife() async {
    final stats = await getUserStats();
    final updated = stats.copyWith(lives: (stats.lives + 1).clamp(0, 5));
    await saveUserStats(updated);
    
    await CloudSyncService.instance.addLife();
    return updated;
  }

  Future<UserStatsModel> useLife() async {
    final stats = await getUserStats();
    if (stats.lives <= 0) {
      throw Exception('No lives left');
    }
    final updated = stats.copyWith(lives: stats.lives - 1);
    await saveUserStats(updated);
    
    await CloudSyncService.instance.useLife();
    return updated;
  }

  String _generateReferralCodeInitial() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GKQ${now.substring(now.length - 6).toUpperCase()}';
  }

  Map<String, dynamic> _userStatsToJson(UserStatsModel stats) {
    return {
      'xp': stats.xp,
      'level': stats.level,
      'coins': stats.coins,
      'totalQuizzes': stats.totalQuizzes,
      'perfectScores': stats.perfectScores,
      'currentStreak': stats.currentStreak,
      'longestStreak': stats.longestStreak,
      'lives': stats.lives,
      'lastDailyReward': stats.lastDailyReward?.toIso8601String(),
      'lastAttemptDate': stats.lastAttemptDate?.toIso8601String(),
      'referralCode': stats.referralCode,
      'referralCount': stats.referralCount,
    };
  }

  UserStatsModel _userStatsFromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      coins: json['coins'] ?? 100,
      totalQuizzes: json['totalQuizzes'] ?? 0,
      perfectScores: json['perfectScores'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lives: json['lives'] ?? 3,
      lastDailyReward: json['lastDailyReward'] != null
          ? DateTime.tryParse(json['lastDailyReward'])
          : null,
      lastAttemptDate: json['lastAttemptDate'] != null
          ? DateTime.tryParse(json['lastAttemptDate'])
          : null,
      referralCode: json['referralCode'],
      referralCount: json['referralCount'] ?? 0,
    );
  }
}
