// lib/core/services/gamification_service.dart
import 'dart:math';
import '../../data/models/gamification_models.dart';
import 'gamification/user_stats_service.dart';
import 'gamification/streak_service.dart';
import 'gamification/referral_service.dart';
import 'gamification/power_up_service.dart';
import 'gamification/achievements_service.dart';

class GamificationService {
  static final GamificationService instance = GamificationService._();
  GamificationService._();

  final _userStatsService = UserStatsService.instance;
  final _streakService = StreakService.instance;
  final _referralService = ReferralService.instance;
  final _powerUpService = PowerUpService.instance;
  final _achievementsService = AchievementsService.instance;

  Future<void> init() async {
    await Future.wait([
      _userStatsService.init(),
      _streakService.init(),
      _referralService.init(),
      _powerUpService.init(),
      _achievementsService.init(),
    ]);
  }

  // ── User Stats Delegated ─────────────────────────────────────
  Future<UserStatsModel> getUserStats() => _userStatsService.getUserStats();
  Future<void> saveUserStats(UserStatsModel stats) => _userStatsService.saveUserStats(stats);
  Future<UserStatsModel> addXP(int xp) => _userStatsService.addXP(xp);
  Future<UserStatsModel> addCoins(int coins) => _userStatsService.addCoins(coins);
  Future<UserStatsModel> spendCoins(int amount) => _userStatsService.spendCoins(amount);
  Future<UserStatsModel> addLife() => _userStatsService.addLife();
  Future<UserStatsModel> useLife() => _userStatsService.useLife();

  // ── Streak Delegated ─────────────────────────────────────────
  Future<UserStatsModel> updateStreak() => _streakService.updateStreak();
  Future<bool> claimDailyReward() => _streakService.claimDailyReward();

  // ── Referral Delegated ───────────────────────────────────────
  String getReferralCode() => _referralService.generateReferralCode();
  Future<bool> applyReferralCode(String code) => _referralService.applyReferralCode(code);

  // ── Powerups Delegated ───────────────────────────────────────
  Map<PowerUpType, PowerUpModel> getPowerUps() => _powerUpService.getPowerUps();
  Future<void> addPowerUp(PowerUpType type) => _powerUpService.addPowerUp(type);
  Future<bool> usePowerUp(PowerUpType type) => _powerUpService.usePowerUp(type);

  // ── Achievements Delegated ───────────────────────────────────
  List<AchievementModel> getAllAchievements() => _achievementsService.getAllAchievements();
  Future<AchievementModel?> unlockAchievement(AchievementType type) => _achievementsService.unlockAchievement(type);
  Future<void> updateAchievementProgress(AchievementType type, int count) =>
      _achievementsService.updateAchievementProgress(type, count);

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
    await updateAchievementProgress(AchievementType.quizMaster, newStats.totalQuizzes);
    if (newStats.currentStreak >= 7) {
      await updateAchievementProgress(AchievementType.streak7Days, newStats.currentStreak);
    }
    if (newStats.currentStreak >= 30) {
      await updateAchievementProgress(AchievementType.streak30Days, newStats.currentStreak);
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
      xpEarned: baseXP + bonusXP,
      coinsEarned: baseCoins + bonusCoins,
      isPerfect: score == totalQuestions,
      speedBonus: timeTaken < 60 ? 10 : 0, // speed bonus value
      streakBonus: stats.currentStreak > 0 ? 15 : 0, // streak bonus value
    );
  }
}
