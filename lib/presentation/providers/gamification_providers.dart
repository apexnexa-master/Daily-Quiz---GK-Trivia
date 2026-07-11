// lib/presentation/providers/gamification_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/gamification_service.dart';
import '../../data/models/gamification_models.dart';

final gamificationServiceProvider = Provider<GamificationService>((ref) => GamificationService.instance);

final userStatsProvider = FutureProvider<UserStatsModel>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  return service.getUserStats();
});

class GamificationNotifier extends StateNotifier<AsyncValue<UserStatsModel>> {
  final GamificationService _service;

  GamificationNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _service.getUserStats();
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> claimDailyReward() async {
    state = const AsyncValue.loading();
    try {
      final claimed = await _service.claimDailyReward();
      await _loadStats();
      return claimed;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> addXP(int xp) async {
    try {
      final stats = await _service.addXP(xp);
      state = AsyncValue.data(stats);
    } catch (_) {}
  }

  Future<void> addCoins(int coins) async {
    try {
      final stats = await _service.addCoins(coins);
      state = AsyncValue.data(stats);
    } catch (_) {}
  }

  Future<void> useLife() async {
    try {
      final stats = await _service.useLife();
      state = AsyncValue.data(stats);
    } catch (_) {}
  }

  Future<void> addLife() async {
    try {
      final stats = await _service.addLife();
      state = AsyncValue.data(stats);
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _loadStats();
  }
}

final gamificationNotifierProvider = StateNotifierProvider<GamificationNotifier, AsyncValue<UserStatsModel>>((ref) {
  return GamificationNotifier(ref.watch(gamificationServiceProvider));
});

final powerUpsProvider = Provider<Map<PowerUpType, PowerUpModel>>((ref) {
  return ref.watch(gamificationServiceProvider).getPowerUps();
});

final gamificationAchievementsProvider = Provider<List<AchievementModel>>((ref) {
  return ref.watch(gamificationServiceProvider).getAllAchievements();
});

final referralCodeProvider = Provider<String>((ref) {
  return ref.watch(gamificationServiceProvider).getReferralCode();
});

final quizRewardsProvider = FutureProvider.family<QuizRewards, QuizRewardParams>((ref, params) async {
  final service = ref.watch(gamificationServiceProvider);
  return service.calculateQuizRewards(
    score: params.score,
    totalQuestions: params.totalQuestions,
    timeTaken: params.timeTaken,
  );
});

class QuizRewardParams {
  final int score;
  final int totalQuestions;
  final int timeTaken;

  QuizRewardParams({
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizRewardParams &&
          runtimeType == other.runtimeType &&
          score == other.score &&
          totalQuestions == other.totalQuestions &&
          timeTaken == other.timeTaken;

  @override
  int get hashCode => Object.hash(score, totalQuestions, timeTaken);
}

final dailyChallengesProvider = Provider<List<DailyChallengeModel>>((ref) {
  final now = DateTime.now();
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

  return [
    DailyChallengeModel(
      id: 'daily_quiz',
      title: 'Daily Quiz',
      description: 'Complete 1 quiz today',
      type: 'score',
      targetValue: 1,
      xpReward: 20,
      coinReward: 10,
      expiresAt: endOfDay,
    ),
    DailyChallengeModel(
      id: 'streak_3',
      title: '3-Day Streak',
      description: 'Maintain a 3-day streak',
      type: 'streak',
      targetValue: 3,
      xpReward: 50,
      coinReward: 25,
      expiresAt: endOfDay,
    ),
    DailyChallengeModel(
      id: 'speed_run',
      title: 'Speed Run',
      description: 'Complete a quiz in under 90 seconds',
      type: 'speed',
      targetValue: 1,
      xpReward: 30,
      coinReward: 15,
      expiresAt: endOfDay,
    ),
  ];
});
