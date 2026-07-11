// lib/core/services/gamification_service.dart
// Gamification service for XP, Levels, Achievements, Streaks, Referral, and Rewards

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/gamification_models.dart';
import '../../data/models/firestore_models.dart';
import '../constants/app_constants.dart';

class GamificationService {
  static final GamificationService instance = GamificationService._();
  GamificationService._();

  late Box _statsBox;
  late Box _achievementsBox;
  late Box _powerUpsBox;

  Future<void> init() async {
    _statsBox = await Hive.openBox('gamification_stats');
    _achievementsBox = await Hive.openBox('achievements');
    _powerUpsBox = await Hive.openBox('power_ups');
  }

  // ── User Stats ───────────────────────────────────────────────
  Future<UserStatsModel> getUserStats() async {
    final data = _statsBox.get('user_stats');
    if (data != null) {
      return _userStatsFromJson(jsonDecode(data));
    }
    return UserStatsModel(
      referralCode: _generateReferralCode(),
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
    return updated;
  }

  Future<UserStatsModel> addCoins(int coins) async {
    final stats = await getUserStats();
    final updated = stats.copyWith(coins: stats.coins + coins);
    await saveUserStats(updated);
    return updated;
  }

  Future<UserStatsModel> spendCoins(int amount) async {
    final stats = await getUserStats();
    if (stats.coins < amount) {
      throw Exception('Not enough coins');
    }
    final updated = stats.copyWith(coins: stats.coins - amount);
    await saveUserStats(updated);
    return updated;
  }

  Future<UserStatsModel> addLife() async {
    final stats = await getUserStats();
    final updated = stats.copyWith(lives: (stats.lives + 1).clamp(0, 5));
    await saveUserStats(updated);
    return updated;
  }

  Future<UserStatsModel> useLife() async {
    final stats = await getUserStats();
    if (stats.lives <= 0) {
      throw Exception('No lives left');
    }
    final updated = stats.copyWith(lives: stats.lives - 1);
    await saveUserStats(updated);
    return updated;
  }

  // ── Streak System ────────────────────────────────────────────
  Future<UserStatsModel> updateStreak() async {
    final stats = await getUserStats();
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    int newStreak = stats.currentStreak;
    int newLongest = stats.longestStreak;

    if (stats.lastAttemptDate == null) {
      newStreak = 1;
    } else {
      final lastAttempt = stats.lastAttemptDate!;
      final lastDate = DateTime(lastAttempt.year, lastAttempt.month, lastAttempt.day);
      final diff = todayDate.difference(lastDate).inDays;

      if (diff == 1) {
        newStreak++;
      } else if (diff > 1) {
        newStreak = 1;
      }
    }

    if (newStreak > newLongest) {
      newLongest = newStreak;
    }

    final updated = stats.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastAttemptDate: now,
    );
    await saveUserStats(updated);
    return updated;
  }

  Future<bool> claimDailyReward() async {
    final stats = await getUserStats();
    if (!stats.canClaimDailyReward) {
      return false;
    }

    final streakBonus = (stats.currentStreak ~/ 7) * 10;
    final baseReward = 10 + streakBonus;

    final updated = stats.copyWith(
      coins: stats.coins + baseReward,
      xp: stats.xp + 15,
      lastDailyReward: DateTime.now(),
    );
    await saveUserStats(updated);
    return true;
  }

  // ── Referral System ───────────────────────────────────────────
  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final uuid = const Uuid();
    final random = uuid.v4().replaceAll('-', '').toUpperCase();
    return 'GKQ${random.substring(0, 6)}';
  }

  String getReferralCode() {
    final stats = _statsBox.get('user_stats');
    if (stats != null) {
      final decoded = jsonDecode(stats);
      return decoded['referralCode'] ?? _generateReferralCode();
    }
    return _generateReferralCode();
  }

  Future<bool> applyReferralCode(String code) async {
    if (code.isEmpty || code.length < 4) return false;

    // In production, validate against Firestore
    // For now, just simulate successful referral
    final stats = await getUserStats();
    final updated = stats.copyWith(
      referralCount: stats.referralCount + 1,
      coins: stats.coins + 50,
      xp: stats.xp + 100,
    );
    await saveUserStats(updated);
    return true;
  }

  // ── Achievements ───────────────────────────────────────────────
  static const Map<AchievementType, AchievementModel> _achievementDefinitions =
      {
    AchievementType.firstQuiz: AchievementModel(
      type: AchievementType.firstQuiz,
      titleKey: 'First Quiz',
      descriptionKey: 'Complete your first quiz',
      icon: '🎯',
      xpReward: 50,
      coinReward: 25,
      requiredCount: 1,
    ),
    AchievementType.streak7Days: AchievementModel(
      type: AchievementType.streak7Days,
      titleKey: '7 Day Streak',
      descriptionKey: 'Complete quizzes for 7 consecutive days',
      icon: '🔥',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 7,
    ),
    AchievementType.streak30Days: AchievementModel(
      type: AchievementType.streak30Days,
      titleKey: '30 Day Streak',
      descriptionKey: 'Complete quizzes for 30 consecutive days',
      icon: '⚡',
      xpReward: 500,
      coinReward: 250,
      requiredCount: 30,
    ),
    AchievementType.perfectScore: AchievementModel(
      type: AchievementType.perfectScore,
      titleKey: 'Perfect Score',
      descriptionKey: 'Get 100% on any quiz',
      icon: '💯',
      xpReward: 150,
      coinReward: 75,
      requiredCount: 1,
    ),
    AchievementType.quizMaster: AchievementModel(
      type: AchievementType.quizMaster,
      titleKey: 'Quiz Master',
      descriptionKey: 'Complete 50 quizzes',
      icon: '🏆',
      xpReward: 300,
      coinReward: 150,
      requiredCount: 50,
    ),
    AchievementType.speedDemon: AchievementModel(
      type: AchievementType.speedDemon,
      titleKey: 'Speed Demon',
      descriptionKey: 'Complete a quiz in under 60 seconds',
      icon: '⏱️',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 1,
    ),
    AchievementType.earlyBird: AchievementModel(
      type: AchievementType.earlyBird,
      titleKey: 'Early Bird',
      descriptionKey: 'Take a quiz before 8 AM',
      icon: '🌅',
      xpReward: 75,
      coinReward: 35,
      requiredCount: 1,
    ),
    AchievementType.socialButterfly: AchievementModel(
      type: AchievementType.socialButterfly,
      titleKey: 'Social Butterfly',
      descriptionKey: 'Share your score 5 times',
      icon: '🦋',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 5,
    ),
    AchievementType.referralChampion: AchievementModel(
      type: AchievementType.referralChampion,
      titleKey: 'Referral Champion',
      descriptionKey: 'Refer 5 friends',
      icon: '👥',
      xpReward: 250,
      coinReward: 125,
      requiredCount: 5,
    ),
    AchievementType.explorer: AchievementModel(
      type: AchievementType.explorer,
      titleKey: 'Explorer',
      descriptionKey: 'Try all exam modes',
      icon: '🧭',
      xpReward: 150,
      coinReward: 75,
      requiredCount: 5,
    ),
    AchievementType.level10: AchievementModel(
      type: AchievementType.level10,
      titleKey: 'Rising Star',
      descriptionKey: 'Reach Level 10',
      icon: '⭐',
      xpReward: 200,
      coinReward: 100,
      requiredCount: 10,
    ),
    AchievementType.level25: AchievementModel(
      type: AchievementType.level25,
      titleKey: 'Quiz Pro',
      descriptionKey: 'Reach Level 25',
      icon: '🌟',
      xpReward: 500,
      coinReward: 250,
      requiredCount: 25,
    ),
    AchievementType.level50: AchievementModel(
      type: AchievementType.level50,
      titleKey: 'Quiz Legend',
      descriptionKey: 'Reach Level 50',
      icon: '👑',
      xpReward: 1000,
      coinReward: 500,
      requiredCount: 50,
    ),
  };

  List<AchievementModel> getAllAchievements() {
    final unlocked = _achievementsBox.get('unlocked', defaultValue: <String>[]);
    final progress =
        _achievementsBox.get('progress', defaultValue: <String, int>{});

    return _achievementDefinitions.values.map((def) {
      final isUnlocked = unlocked.contains(def.type.name);
      final current = progress[def.type.name] ?? 0;

      return def.copyWith(
        isUnlocked: isUnlocked,
        currentCount: current,
        unlockedAt: isUnlocked ? DateTime.now() : null,
      );
    }).toList();
  }

  Future<AchievementModel?> unlockAchievement(AchievementType type) async {
    final unlocked = _achievementsBox.get('unlocked', defaultValue: <String>[]);
    if (unlocked.contains(type.name)) return null;

    final def = _achievementDefinitions[type];
    if (def == null) return null;

    unlocked.add(type.name);
    await _achievementsBox.put('unlocked', unlocked);

    // Award rewards
    await addXP(def.xpReward);
    await addCoins(def.coinReward);

    return def.copyWith(isUnlocked: true, unlockedAt: DateTime.now());
  }

  Future<void> updateAchievementProgress(
      AchievementType type, int count) async {
    final progress =
        _achievementsBox.get('progress', defaultValue: <String, int>{});
    progress[type.name] = count;
    await _achievementsBox.put('progress', progress);

    // Check if should unlock
    final def = _achievementDefinitions[type];
    if (def != null && count >= def.requiredCount) {
      await unlockAchievement(type);
    }
  }

  // ── Power-ups ─────────────────────────────────────────────────
  Map<PowerUpType, PowerUpModel> getPowerUps() {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});

    return {
      PowerUpType.extraTime: PowerUpModel(
        type: PowerUpType.extraTime,
        nameKey: 'Extra Time',
        descriptionKey: '+15 seconds for current question',
        icon: '⏰',
        cost: 20,
        quantity: saved['extraTime'] ?? 0,
      ),
      PowerUpType.fiftyFifty: PowerUpModel(
        type: PowerUpType.fiftyFifty,
        nameKey: '50-50',
        descriptionKey: 'Remove 2 wrong answers',
        icon: '🎯',
        cost: 30,
        quantity: saved['fiftyFifty'] ?? 0,
      ),
      PowerUpType.skipQuestion: PowerUpModel(
        type: PowerUpType.skipQuestion,
        nameKey: 'Skip',
        descriptionKey: 'Skip current question',
        icon: '⏭️',
        cost: 15,
        quantity: saved['skipQuestion'] ?? 0,
      ),
      PowerUpType.doubleXp: PowerUpModel(
        type: PowerUpType.doubleXp,
        nameKey: '2X XP',
        descriptionKey: 'Double XP for this quiz',
        icon: '✨',
        cost: 50,
        quantity: saved['doubleXp'] ?? 0,
      ),
    };
  }

  Future<void> addPowerUp(PowerUpType type) async {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});
    final key = type.name.replaceAll('PowerUpType.', '');
    final keyMap = {
      PowerUpType.extraTime: 'extraTime',
      PowerUpType.fiftyFifty: 'fiftyFifty',
      PowerUpType.skipQuestion: 'skipQuestion',
      PowerUpType.doubleXp: 'doubleXp',
    };

    final safeKey = keyMap[type] ?? key;
    saved[safeKey] = (saved[safeKey] ?? 0) + 1;
    await _powerUpsBox.put('power_ups', saved);
  }

  Future<bool> usePowerUp(PowerUpType type) async {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});
    final keyMap = {
      PowerUpType.extraTime: 'extraTime',
      PowerUpType.fiftyFifty: 'fiftyFifty',
      PowerUpType.skipQuestion: 'skipQuestion',
      PowerUpType.doubleXp: 'doubleXp',
    };

    final key = keyMap[type] ?? type.name;
    if ((saved[key] ?? 0) <= 0) return false;

    saved[key] = (saved[key] ?? 1) - 1;
    await _powerUpsBox.put('power_ups', saved);
    return true;
  }

  // ── Quiz Completion Rewards ──────────────────────────────────
  Future<QuizRewards> calculateQuizRewards({
    required int score,
    required int totalQuestions,
    required int timeTaken,
  }) async {
    final stats = await updateStreak();

    int baseXP = score * 10;
    int baseCoins = score * 5;
    int bonusXP = 0;
    int bonusCoins = 0;

    // Perfect score bonus
    if (score == totalQuestions) {
      bonusXP += 50;
      bonusCoins += 25;
      await unlockAchievement(AchievementType.perfectScore);
    }

    // Speed bonus
    if (timeTaken < 60) {
      bonusXP += 25;
      await unlockAchievement(AchievementType.speedDemon);
    }

    // Early bird bonus
    final hour = DateTime.now().hour;
    if (hour < 8) {
      bonusXP += 20;
      bonusCoins += 10;
      await unlockAchievement(AchievementType.earlyBird);
    }

    // Streak bonus
    if (stats.currentStreak > 0) {
      bonusXP += stats.currentStreak * 2;
    }

    // Update stats
    final newStats = stats.copyWith(
      totalQuizzes: stats.totalQuizzes + 1,
      xp: stats.xp + baseXP + bonusXP,
      coins: stats.coins + baseCoins + bonusCoins,
    );
    await saveUserStats(newStats);

    // Check achievements
    await updateAchievementProgress(
        AchievementType.quizMaster, newStats.totalQuizzes);
    if (newStats.currentStreak >= 7) {
      await updateAchievementProgress(
          AchievementType.streak7Days, newStats.currentStreak);
    }
    if (newStats.currentStreak >= 30) {
      await updateAchievementProgress(
          AchievementType.streak30Days, newStats.currentStreak);
    }

    // Check level achievements
    if (newStats.level >= 10) {
      await unlockAchievement(AchievementType.level10);
    }
    if (newStats.level >= 25) {
      await unlockAchievement(AchievementType.level25);
    }
    if (newStats.level >= 50) {
      await unlockAchievement(AchievementType.level50);
    }

    return QuizRewards(
      xp: baseXP + bonusXP,
      coins: baseCoins + bonusCoins,
      isPerfect: score == totalQuestions,
      isSpeedBonus: timeTaken < 60,
      isStreakBonus: stats.currentStreak > 0,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
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

class QuizRewards {
  final int xp;
  final int coins;
  final bool isPerfect;
  final bool isSpeedBonus;
  final bool isStreakBonus;

  const QuizRewards({
    required this.xp,
    required this.coins,
    this.isPerfect = false,
    this.isSpeedBonus = false,
    this.isStreakBonus = false,
  });
}
