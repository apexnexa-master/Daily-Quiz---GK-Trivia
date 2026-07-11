// lib/data/models/gamification_models.dart
// Gamification models for XP, Levels, Achievements, Lives, Battle Mode

import 'package:equatable/equatable.dart';

class UserStatsModel extends Equatable {
  final int xp;
  final int level;
  final int coins;
  final int totalQuizzes;
  final int perfectScores;
  final int currentStreak;
  final int longestStreak;
  final int lives;
  final DateTime? lastDailyReward;
  final DateTime? lastAttemptDate;
  final String? referralCode;
  final int referralCount;

  const UserStatsModel({
    this.xp = 0,
    this.level = 1,
    this.coins = 100,
    this.totalQuizzes = 0,
    this.perfectScores = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lives = 3,
    this.lastDailyReward,
    this.lastAttemptDate,
    this.referralCode,
    this.referralCount = 0,
  });

  bool get canClaimDailyReward {
    if (lastDailyReward == null) return true;
    final now = DateTime.now();
    return now.difference(lastDailyReward!).inHours >= 24;
  }

  int get xpForNextLevel => UserStatsModel._xpForLevel(level + 1);
  double get levelProgress {
    final needed = xpForNextLevel;
    return needed > 0 ? (xp / needed).clamp(0.0, 1.0) : 0.0;
  }

  static int _xpForLevel(int lvl) {
    return (lvl * lvl * 50).toInt();
  }

  static int xpForLevel(int lvl) => _xpForLevel(lvl);

  UserStatsModel copyWith({
    int? xp,
    int? level,
    int? coins,
    int? totalQuizzes,
    int? perfectScores,
    int? currentStreak,
    int? longestStreak,
    int? lives,
    DateTime? lastDailyReward,
    DateTime? lastAttemptDate,
    String? referralCode,
    int? referralCount,
  }) {
    return UserStatsModel(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      coins: coins ?? this.coins,
      totalQuizzes: totalQuizzes ?? this.totalQuizzes,
      perfectScores: perfectScores ?? this.perfectScores,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lives: lives ?? this.lives,
      lastDailyReward: lastDailyReward ?? this.lastDailyReward,
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
    );
  }

  @override
  List<Object?> get props => [
        xp,
        level,
        coins,
        totalQuizzes,
        perfectScores,
        currentStreak,
        longestStreak,
        lives,
        lastDailyReward,
        lastAttemptDate,
        referralCode,
        referralCount,
      ];
}

class _DefaultDate implements DateTime {
  const _DefaultDate();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime(2000);
}

enum AchievementType {
  firstQuiz,
  streak7Days,
  streak30Days,
  perfectScore,
  quizMaster,
  speedDemon,
  earlyBird,
  socialButterfly,
  referralChampion,
  explorer,
  level10,
  level25,
  level50,
}

class AchievementModel extends Equatable {
  final AchievementType type;
  final String titleKey;
  final String descriptionKey;
  final String icon;
  final int xpReward;
  final int coinReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final String? progress;
  final int requiredCount;
  final int currentCount;

  const AchievementModel({
    required this.type,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.xpReward,
    required this.coinReward,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress,
    this.requiredCount = 1,
    this.currentCount = 0,
  });

  double get progressPercent =>
      requiredCount > 0 ? (currentCount / requiredCount).clamp(0.0, 1.0) : 0.0;

  AchievementModel copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentCount,
  }) {
    return AchievementModel(
      type: type,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      icon: icon,
      xpReward: xpReward,
      coinReward: coinReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress,
      requiredCount: requiredCount,
      currentCount: currentCount ?? this.currentCount,
    );
  }

  @override
  List<Object?> get props => [type, isUnlocked, currentCount];
}

enum PowerUpType {
  extraTime,
  fiftyFifty,
  skipQuestion,
  doubleXp,
}

class PowerUpModel extends Equatable {
  final PowerUpType type;
  final String nameKey;
  final String descriptionKey;
  final String icon;
  final int cost;
  final int quantity;

  const PowerUpModel({
    required this.type,
    required this.nameKey,
    required this.descriptionKey,
    required this.icon,
    required this.cost,
    this.quantity = 0,
  });

  PowerUpModel copyWith({int? quantity}) {
    return PowerUpModel(
      type: type,
      nameKey: nameKey,
      descriptionKey: descriptionKey,
      icon: icon,
      cost: cost,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [type, quantity];
}

class BattleSessionModel extends Equatable {
  final String sessionId;
  final String player1Id;
  final String player1Name;
  final String? player1PhotoUrl;
  final String? player2Id;
  final String? player2Name;
  final String? player2PhotoUrl;
  final String quizId;
  final int player1Score;
  final int player2Score;
  final int player1Time;
  final int player2Time;
  final String status; // 'waiting', 'in_progress', 'completed'
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winnerId;

  const BattleSessionModel({
    required this.sessionId,
    required this.player1Id,
    required this.player1Name,
    this.player1PhotoUrl,
    this.player2Id,
    this.player2Name,
    this.player2PhotoUrl,
    required this.quizId,
    this.player1Score = 0,
    this.player2Score = 0,
    this.player1Time = 0,
    this.player2Time = 0,
    this.status = 'waiting',
    required this.createdAt,
    this.completedAt,
    this.winnerId,
  });

  bool get isWaiting => status == 'waiting';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  BattleSessionModel copyWith({
    String? player2Id,
    String? player2Name,
    String? player2PhotoUrl,
    int? player1Score,
    int? player2Score,
    int? player1Time,
    int? player2Time,
    String? status,
    DateTime? completedAt,
    String? winnerId,
  }) {
    return BattleSessionModel(
      sessionId: sessionId,
      player1Id: player1Id,
      player1Name: player1Name,
      player1PhotoUrl: player1PhotoUrl,
      player2Id: player2Id ?? this.player2Id,
      player2Name: player2Name ?? this.player2Name,
      player2PhotoUrl: player2PhotoUrl ?? this.player2PhotoUrl,
      quizId: quizId,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      player1Time: player1Time ?? this.player1Time,
      player2Time: player2Time ?? this.player2Time,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      winnerId: winnerId ?? this.winnerId,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        player1Score,
        player2Score,
        status,
        winnerId,
      ];
}

class DailyChallengeModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String type; // 'score', 'streak', 'speed'
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final int coinReward;
  final DateTime expiresAt;
  final bool isCompleted;

  const DailyChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.xpReward,
    required this.coinReward,
    required this.expiresAt,
    this.isCompleted = false,
  });

  double get progressPercent =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  DailyChallengeModel copyWith({
    int? currentValue,
    bool? isCompleted,
  }) {
    return DailyChallengeModel(
      id: id,
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      xpReward: xpReward,
      coinReward: coinReward,
      expiresAt: expiresAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [id, currentValue, isCompleted];
}

class ReferralRewardModel extends Equatable {
  final String referralCode;
  final int referrerReward;
  final int refereeReward;
  final DateTime createdAt;

  const ReferralRewardModel({
    required this.referralCode,
    this.referrerReward = 100,
    this.refereeReward = 50,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [referralCode, referrerReward, refereeReward];
}

class QuizRewards {
  final int xpEarned;
  final int coinsEarned;
  final int streakBonus;
  final int speedBonus;
  final bool isPerfect;

  const QuizRewards({
    required this.xpEarned,
    required this.coinsEarned,
    this.streakBonus = 0,
    this.speedBonus = 0,
    this.isPerfect = false,
  });

  // Keep compatibility fields
  int get xp => xpEarned;
  int get coins => coinsEarned;
  bool get isSpeedBonus => speedBonus > 0;
  bool get isStreakBonus => streakBonus > 0;
}
