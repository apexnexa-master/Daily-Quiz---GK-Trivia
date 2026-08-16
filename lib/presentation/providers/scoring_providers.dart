// lib/presentation/providers/scoring_providers.dart
// Read-side providers that surface the progression engine to the UI (Home,
// Profile, Result, Leaderboard). All of them are safe to read anywhere — the
// engine never throws and falls back to in-memory storage in tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/scoring/activity_service.dart';
import '../../core/scoring/brain_score.dart';
import '../../core/scoring/daily_challenge_service.dart';
import '../../core/scoring/leaderboard_service.dart';
import '../../core/scoring/skill_ratings.dart';
import 'auth_providers.dart';
import 'leaderboard_providers.dart';

/// Everything the profile / home "Brain" section needs in one future.
class BrainStatsBundle {
  final BrainScoreUpdate brain;
  final SkillRatings ratings;
  final ActivityStats activity;
  final int weeklyScore;
  final int weeklyChallengeCount;
  final int bestWeeklyScore;
  final int bestDailyScore;
  final int bestWeeklyRank;
  final int totalChallenges;

  const BrainStatsBundle({
    required this.brain,
    required this.ratings,
    required this.activity,
    required this.weeklyScore,
    required this.weeklyChallengeCount,
    required this.bestWeeklyScore,
    required this.bestDailyScore,
    required this.bestWeeklyRank,
    required this.totalChallenges,
  });
}

final brainStatsProvider = FutureProvider<BrainStatsBundle>((ref) async {
  final brain = await BrainScoreService.instance.current();
  final activity = await ActivityService.instance.current();
  final weeklyScore = await LeaderboardService.instance.currentWeeklyScore();
  final weeklyChallengeCount =
      await LeaderboardService.instance.currentWeekChallengeCount();
  final bestWeeklyScore = await LeaderboardService.instance.bestWeeklyScore();
  final bestDailyScore = await LeaderboardService.instance.bestDailyScore();
  final bestWeeklyRank = await LeaderboardService.instance.bestWeeklyRank();
  final totalChallenges =
      await DailyChallengeService.instance.totalCompleted();
  return BrainStatsBundle(
    brain: brain,
    ratings: brain.ratings,
    activity: activity,
    weeklyScore: weeklyScore,
    weeklyChallengeCount: weeklyChallengeCount,
    bestWeeklyScore: bestWeeklyScore,
    bestDailyScore: bestDailyScore,
    bestWeeklyRank: bestWeeklyRank,
    totalChallenges: totalChallenges,
  );
});

/// The current user's weekly-leaderboard rank among the combined
/// local + remote board (spec §28). Persists the best rank ever seen.
final myWeeklyRankProvider = FutureProvider<RankInfo>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final myScore = await LeaderboardService.instance.currentWeeklyScore();

  final entries = await ref.watch(localLeaderboardProvider.future);
  final weekly = LeaderboardService.aggregateWeekly(entries);
  final scores = weekly.map((e) => e.score).toList();

  final playerName = user?.displayName;
  if (playerName != null && !weekly.any((e) => e.playerName == playerName)) {
    if (myScore > 0) scores.add(myScore);
  }

  final rank = LeaderboardService.rankOf(myScore, scores);
  if (rank.rank > 0) {
    await LeaderboardService.instance.updateBestWeeklyRank(rank.rank);
  }
  return rank;
});
