// lib/core/services/gamification/streak_service.dart
import 'user_stats_service.dart';
import '../../../data/models/gamification_models.dart';
import '../cloud_sync_service.dart';

class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  Future<void> init() async {}

  Future<UserStatsModel> updateStreak() async {
    final statsService = UserStatsService.instance;
    final stats = await statsService.getUserStats();
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
    await statsService.saveUserStats(updated);
    
    // Cloud sync!
    await CloudSyncService.instance.onStreakUpdate(newStreak);
    return updated;
  }

  Future<bool> claimDailyReward() async {
    final statsService = UserStatsService.instance;
    final stats = await statsService.getUserStats();
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
    await statsService.saveUserStats(updated);
    
    // Cloud sync!
    await CloudSyncService.instance.onDailyRewardClaim();
    return true;
  }
}
