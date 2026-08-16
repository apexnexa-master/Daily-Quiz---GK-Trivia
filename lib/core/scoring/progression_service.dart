// lib/core/scoring/progression_service.dart
// Orchestrator for one game session.
//
// GAME → RAW RESULT → PERFORMANCE SCORE (0-100) → SKILL RATING UPDATE →
// BRAIN SCORE UPDATE → XP / GOAL / STREAK → (daily challenge only)
// CHALLENGE SCORE (0-1000) → LEADERBOARD
//
// Each responsibility lives in its own service; this class wires them together
// once so scoring logic is never duplicated across game screens. It never
// throws: bookkeeping failures degrade silently instead of breaking a game.

import '../services/analytics_service.dart';
import '../services/daily_progress_service.dart';
import '../services/local_stats_service.dart';
import 'activity_service.dart';
import 'brain_score.dart';
import 'daily_challenge_service.dart';
import 'game_performance.dart';
import 'leaderboard_service.dart';
import 'scoring_config.dart';
import 'scoring_store.dart';
import 'skill_ratings.dart';
import 'xp_service.dart';

export 'xp_service.dart';

/// Everything the engine needs to score one completed game session.
class SessionRecord {
  /// Canonical game id used for the skill mapping ('quiz','arrow',...).
  final String gameId;

  /// Where the session happened; drives the XP base value.
  final SessionMode mode;

  /// GameType key for the daily goal ('quiz','arrow','stroop',...).
  final String gameType;

  /// BrainPillar key for the legacy daily-goal / pillar display.
  final String primaryPillar;

  /// Raw game data used by the game-specific performance calculator.
  final GamePerformanceInput performance;

  /// True for the official daily challenge (leaderboard + challenge score).
  final bool isDailyChallenge;

  /// Deterministic challenge id (e.g. 'DC-20260816-gk').
  final String? challengeId;

  /// Display name used when submitting to the leaderboard.
  final String? playerName;

  /// Session duration in seconds (leaderboard time tie-break).
  final int durationSeconds;

  const SessionRecord({
    required this.gameId,
    required this.mode,
    required this.gameType,
    required this.primaryPillar,
    required this.performance,
    this.isDailyChallenge = false,
    this.challengeId,
    this.playerName,
    this.durationSeconds = 0,
  });
}

/// Full result of a session, surfaced to the UI (result screen, workout).
class SessionOutcome {
  final int performanceScore;
  final SkillRatings ratings;
  final Map<String, double> skillDeltas;
  final BrainScoreUpdate brain;
  final XpAward xp;
  final int dailyGoalProgress;
  final int dailyGoalTotal;
  final bool dailyGoalComplete;
  final int streak;
  final int challengeScore;
  final bool newChallengeBest;

  const SessionOutcome({
    required this.performanceScore,
    required this.ratings,
    required this.skillDeltas,
    required this.brain,
    required this.xp,
    required this.dailyGoalProgress,
    required this.dailyGoalTotal,
    required this.dailyGoalComplete,
    required this.streak,
    required this.challengeScore,
    required this.newChallengeBest,
  });

  /// Safe default for flows where a session must never break the game.
  static const SessionOutcome empty = SessionOutcome(
    performanceScore: 0,
    ratings: SkillRatings(),
    skillDeltas: {},
    brain: BrainScoreUpdate(
      state: BrainScoreState(),
      ratings: SkillRatings(),
      score: 0,
      status: BrainScoreStatus.building,
      weeklyChange: 0,
    ),
    xp: XpAward(requested: 0, granted: 0),
    dailyGoalProgress: 0,
    dailyGoalTotal: 0,
    dailyGoalComplete: false,
    streak: 0,
    challengeScore: 0,
    newChallengeBest: false,
  );
}

class ProgressionService {
  ProgressionService._();
  static final ProgressionService instance = ProgressionService._();

  Future<void> init() => ScoringStore.instance.init();

  /// Scores one game session end-to-end. Safe: never throws.
  Future<SessionOutcome> recordSession(SessionRecord record) async {
    final perf = GamePerformanceService.calculate(record.performance);

    // 0. Official daily-challenge claim (idempotency): only the FIRST
    //    submission of a challenge is official and feeds XP, the leaderboard
    //    and the weekly score. Retries keep the performance score + personal
    //    best for display but never double-reward (§18 / §33).
    var challengeScore = 0;
    var countsAsOfficial = false;
    if (record.isDailyChallenge && perf > 0) {
      challengeScore =
          (perf / 100 * ScoringConfig.dailyScoreMax).round().clamp(0, 1000);
      final challengeId =
          record.challengeId ?? DailyChallengeService.todaysChallengeId(record.gameId);
      try {
        final submission =
            await DailyChallengeService.instance.submitOfficialScore(
          challengeId: challengeId,
          score: challengeScore,
        );
        countsAsOfficial = submission.countsAsOfficial;
      } catch (_) {
        // Invalid/unparseable score — treat as non-official so nothing leaks
        // into the leaderboard.
      }
    }

    // 1. Daily goal, streak and legacy pillar history (also keeps the Home
    //    screen and existing profile data working).
    var before = const DailyProgress();
    var progress = const DailyProgress();
    try {
      before = await DailyProgressService.instance.getProgress();
      progress = await DailyProgressService.instance.recordGameCompletion(
        pillar: record.primaryPillar,
        scorePct: perf,
        gameType: record.gameType,
      );
    } catch (_) {
      progress = before;
    }

    // 2. Skill ratings (gradual EWMA) and Brain Score.
    var ratings = const SkillRatings();
    var deltas = <String, double>{};
    var brain = const BrainScoreUpdate(
      state: BrainScoreState(),
      ratings: SkillRatings(),
      score: 0,
      status: BrainScoreStatus.building,
      weeklyChange: 0,
    );
    try {
      final skillResult =
          await SkillRatingService.instance.applyGamePerformance(
        record.gameId,
        perf,
      );
      ratings = skillResult.ratings;
      deltas = skillResult.deltas;
      brain = await BrainScoreService.instance.recordSession();
    } catch (_) {}

    // 3. XP (a workout's component games award nothing here; the whole
    //    workout is rewarded once by [awardWorkout]). A repeated daily
    //    challenge attempt awards nothing either.
    var xp = const XpAward(requested: 0, granted: 0);
    final shouldAwardModeXp = record.mode == SessionMode.dailyChallenge
        ? countsAsOfficial
        : record.mode != SessionMode.workoutGame;
    if (shouldAwardModeXp) {
      try {
        xp = await XPService.instance.award(record.mode);
      } catch (_) {}
    }

    // 4. Daily goal completion bonus.
    if (progress.isDailyGoalComplete && !before.isDailyGoalComplete) {
      try {
        await XPService.instance.awardDailyGoal();
      } catch (_) {}
    }

    // 5. Official daily challenge only → personal best + weekly/all-time
    //    competition + normalized leaderboard submission.
    var newBest = false;
    if (countsAsOfficial) {
      try {
        newBest =
            await BrainScoreService.instance.recordChallengeScore(challengeScore);
      } catch (_) {}
      try {
        await LeaderboardService.instance.recordChallengeResult(
          challengeId: record.challengeId ??
              DailyChallengeService.todaysChallengeId(record.gameId),
          date: DateTime.now(),
          score: challengeScore,
        );
        await LeaderboardService.instance.updateBestDailyScore(challengeScore);
      } catch (_) {}
      if (record.playerName != null && record.playerName!.isNotEmpty) {
        try {
          await LocalStatsService.instance.addScoreToLeaderboard(
            record.playerName!,
            challengeScore,
            record.durationSeconds,
            record.challengeId ?? 'daily_challenge',
          );
        } catch (_) {}
      }
    }

    // 6. Activity counters (never used for scoring; profile display only).
    try {
      if (record.isDailyChallenge && countsAsOfficial) {
        await ActivityService.instance
            .recordDailyChallenge(trainingSeconds: record.durationSeconds);
      } else if (record.mode != SessionMode.workoutGame &&
          !record.isDailyChallenge) {
        await ActivityService.instance
            .recordGame(trainingSeconds: record.durationSeconds);
      }
    } catch (_) {}

    // 7. Analytics (safe, fire-and-forget).
    try {
      await AnalyticsService.instance.logSessionScored(
        gameId: record.gameId,
        mode: record.mode.name,
        performanceScore: perf,
        challengeScore: challengeScore,
        durationSeconds: record.durationSeconds,
      );
    } catch (_) {}

    return SessionOutcome(
      performanceScore: perf,
      ratings: ratings,
      skillDeltas: deltas,
      brain: brain,
      xp: xp,
      dailyGoalProgress: progress.dailyGamesCompleted,
      dailyGoalTotal: progress.dailyGoal,
      dailyGoalComplete: progress.isDailyGoalComplete,
      streak: progress.currentStreak,
      challengeScore: challengeScore,
      newChallengeBest: newBest,
    );
  }

  /// Rewards a finished workout once (component games are not XP-awarded
  /// individually). Returns the granted XP for display.
  Future<XpAward> awardWorkout({
    required int overallScore,
    required int completedCount,
    required int plannedCount,
    int trainingSeconds = 0,
  }) async {
    try {
      final award = await XPService.instance.awardWorkout(
        overallScore: overallScore,
        completedCount: completedCount,
        plannedCount: plannedCount,
      );
      try {
        await ActivityService.instance
            .recordWorkout(trainingSeconds: trainingSeconds);
      } catch (_) {}
      try {
        await AnalyticsService.instance.logWorkoutCompleted(
          overallScore: overallScore,
          completedCount: completedCount,
          plannedCount: plannedCount,
          xpGranted: award.granted,
        );
      } catch (_) {}
      return award;
    } catch (_) {
      return const XpAward(requested: 0, granted: 0);
    }
  }
}
