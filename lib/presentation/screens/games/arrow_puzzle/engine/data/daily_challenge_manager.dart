import 'economy_config.dart';
import 'campaign_data.dart';
import 'progress_manager.dart';

String dateToKey(DateTime date) {
  final u = date.toUtc();
  return '${u.year}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}';
}

int dailyLevelIdFromKey(String key) {
  final seed = int.tryParse(key) ?? 0;
  return (seed % 30) + 1;
}

bool isConsecutiveDay(String prevKey, String nextKey) {
  if (prevKey.isEmpty) return true;
  final prev = int.tryParse(prevKey) ?? 0;
  final next = int.tryParse(nextKey) ?? 0;
  return next == prev + 1;
}

int calculateCoinsForDaily(bool perfectClear, bool usedHint) {
  final coins = EconomyConfig.dailyChallengeCoins;
  if (perfectClear && !usedHint) {
    return coins + EconomyConfig.dailyChallengePerfectBonus;
  }
  return coins;
}

class DailyChallengeManager {
  final CampaignCatalog catalog;

  DailyChallengeManager({required this.catalog});

  String get todayKey => dateToKey(DateTime.now());

  int getTodayLevelId() => dailyLevelIdFromKey(todayKey);

  LevelDef? getTodayLevel(CampaignCatalog catalog) {
    return catalog.getLevel(getTodayLevelId());
  }

  bool isCompleted(ProgressManager progress) {
    return progress.isDailyCompleted(todayKey);
  }

  DailyProgress? getTodayResult(ProgressManager progress) {
    return progress.getDailyResult(todayKey);
  }

  int calculateStreak(ProgressManager progress) {
    int streak = 0;
    final now = DateTime.now().toUtc();
    for (int i = 0; i < 365; i++) {
      final checkKey = dateToKey(now.subtract(Duration(days: i)));
      if (progress.isDailyCompleted(checkKey)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  List<DateTime> getMissedDays(ProgressManager progress, {int maxDays = 14}) {
    final missed = <DateTime>[];
    final now = DateTime.now().toUtc();
    for (int i = 1; i <= maxDays; i++) {
      final day = now.subtract(Duration(days: i));
      final key = dateToKey(day);
      final result = progress.getDailyResult(key);
      if (result == null) {
        missed.add(day);
      }
    }
    return missed;
  }

  bool unlockMissedDay(ProgressManager progress, DateTime day) {
    final key = dateToKey(day);
    if (progress.isDailyCompleted(key)) return false;
    if (progress.walletBalance < EconomyConfig.dailyChallengeUnlockCost) {
      return false;
    }
    progress.spendCoins(EconomyConfig.dailyChallengeUnlockCost);
    progress.completeDailyChallenge(
      dateKey: key,
      stars: 0,
      movesUsed: 0,
      perfectClear: false,
      usedHint: false,
      coinsEarned: 0,
      unlockedViaCoin: true,
    );
    return true;
  }

  bool detectClockManipulation(ProgressManager progress) {
    final lastKey = progress.lastDailyDateKey;
    if (lastKey.isEmpty) return false;
    final now = DateTime.now().toUtc();
    final lastDate = DateTime(
      int.parse(lastKey.substring(0, 4)),
      int.parse(lastKey.substring(4, 6)),
      int.parse(lastKey.substring(6, 8)),
    );
    final diff = now.difference(lastDate);
    return diff.isNegative || diff > const Duration(days: 2);
  }

  int coinsForPerfectClear() {
    return EconomyConfig.dailyChallengeCoins + EconomyConfig.dailyChallengePerfectBonus;
  }

  int coinsForStandard() {
    return EconomyConfig.dailyChallengeCoins;
  }
}
