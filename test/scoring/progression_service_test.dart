import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gk_quiz_app/core/services/daily_progress_service.dart';
import 'package:gk_quiz_app/core/scoring/activity_service.dart';
import 'package:gk_quiz_app/core/scoring/brain_score.dart';
import 'package:gk_quiz_app/core/scoring/daily_challenge_service.dart';
import 'package:gk_quiz_app/core/scoring/game_performance.dart';
import 'package:gk_quiz_app/core/scoring/leaderboard_service.dart';
import 'package:gk_quiz_app/core/scoring/progression_service.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoringStore.instance.resetForTest();
    DailyChallengeService.scheduleNotifier.value = {
      '2026-11-18': ['quiz'],
      '2026-11-19': ['quiz'],
      'default': ['quiz'],
    };
  });

  group('ProgressionService.recordSession', () {
    test('practice session returns performance, deltas, brain and XP', () async {
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.practice,
          gameType: 'quiz',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(
            correct: 9,
            total: 10,
            timeTakenSeconds: 60,
            avgDifficulty: 70,
          ),
        ),
      );

      expect(outcome.performanceScore, 84);
      expect(outcome.skillDeltas[ScoringConfig.skillKnowledge],
          closeTo(17.64, 0.001));
      expect(outcome.ratings.sessionCount(ScoringConfig.skillKnowledge), 1);
      expect(outcome.xp.granted, ScoringConfig.practiceXp);
      expect(outcome.brain.status, BrainScoreStatus.building);
      expect(outcome.challengeScore, 0);
    });

    test('workout component games never award XP', () async {
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'stroop',
          mode: SessionMode.workoutGame,
          gameType: 'stroop',
          primaryPillar: BrainPillar.reaction,
          performance: StroopPerformanceInput(
            correct: 20,
            totalAttempts: 20,
            avgReactionMs: 250,
            difficulty: 3,
          ),
        ),
      );
      expect(outcome.xp.granted, 0);
      expect(outcome.performanceScore, greaterThan(0));
    });

    test('daily challenge computes normalized 0-1000 challenge score', () async {
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.dailyChallenge,
          gameType: 'challenge',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(
            correct: 9,
            total: 10,
            timeTakenSeconds: 60,
            avgDifficulty: 70,
          ),
          isDailyChallenge: true,
          challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
          playerName: 'Test Player',
          durationSeconds: 60,
        ),
      );

      expect(outcome.challengeScore, 840); // 84 / 100 * 1000
      expect(outcome.newChallengeBest, isTrue);
      final state = BrainScoreState.fromJson(
        ScoringStore.instance.readJson(ScoringStore.keyBrainState),
      );
      expect(state.bestChallengeScore, 840);
    });

    test('a lower repeat challenge does not replace the personal best', () async {
      await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.dailyChallenge,
          gameType: 'challenge',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(correct: 10, total: 10),
          isDailyChallenge: true,
          challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
          playerName: 'Test Player',
        ),
      );
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.dailyChallenge,
          gameType: 'challenge',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(correct: 1, total: 10),
          isDailyChallenge: true,
          challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
          playerName: 'Test Player',
        ),
      );
      expect(outcome.challengeScore, lessThan(1000));
      expect(outcome.newChallengeBest, isFalse);
    });

    test('only the official daily challenge submission awards XP', () async {
      final record = SessionRecord(
        gameId: 'quiz',
        mode: SessionMode.dailyChallenge,
        gameType: 'challenge',
        primaryPillar: BrainPillar.knowledge,
        performance: QuizPerformanceInput(correct: 8, total: 10),
        isDailyChallenge: true,
        challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
        playerName: 'Test Player',
      );

      final first = await ProgressionService.instance.recordSession(record);
      expect(first.xp.granted, ScoringConfig.dailyChallengeXp);

      final retry = await ProgressionService.instance.recordSession(record);
      expect(retry.xp.granted, 0, reason: 'retry must not re-award XP');
      expect(retry.challengeScore, greaterThan(0),
          reason: 'score is still computed for display');
    });

    test('the weekly score only counts official submissions', () async {
      final record = SessionRecord(
        gameId: 'quiz',
        mode: SessionMode.dailyChallenge,
        gameType: 'challenge',
        primaryPillar: BrainPillar.knowledge,
        performance: QuizPerformanceInput(correct: 9, total: 10),
        isDailyChallenge: true,
        challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
        playerName: 'Test Player',
        durationSeconds: 60,
      );

      final first = await ProgressionService.instance.recordSession(record);
      final officialScore = first.challengeScore;
      expect(officialScore, greaterThan(0));
      // The weekly total must match the single official score, not double it.
      expect(await LeaderboardService.instance.currentWeeklyScore(), officialScore);
      expect(await LeaderboardService.instance.currentWeekChallengeCount(), 1);

      await ProgressionService.instance.recordSession(record);
      expect(await LeaderboardService.instance.currentWeeklyScore(), officialScore,
          reason: 'retries must not inflate the weekly score');
      expect(await LeaderboardService.instance.currentWeekChallengeCount(), 1);
    });

    test('activity counters are updated for official attempts only', () async {
      final record = SessionRecord(
        gameId: 'quiz',
        mode: SessionMode.dailyChallenge,
        gameType: 'challenge',
        primaryPillar: BrainPillar.knowledge,
        performance: QuizPerformanceInput(correct: 9, total: 10),
        isDailyChallenge: true,
        challengeId: 'gk_challenge',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
        playerName: 'Test Player',
        durationSeconds: 60,
      );

      await ProgressionService.instance.recordSession(record);
      var activity = await ActivityService.instance.current();
      expect(activity.dailyChallengesCompleted, 1);
      expect(activity.gamesPlayed, 1);
      expect(activity.trainingSeconds, 60);

      await ProgressionService.instance.recordSession(record);
      activity = await ActivityService.instance.current();
      expect(activity.dailyChallengesCompleted, 1,
          reason: 'a retry must not count as another challenge');
      expect(activity.gamesPlayed, 1);
    });

    test('a practice session records a game but never a challenge', () async {
      await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.practice,
          gameType: 'quiz',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(correct: 5, total: 10),
          durationSeconds: 30,
        ),
      );
      final activity = await ActivityService.instance.current();
      expect(activity.gamesPlayed, 1);
      expect(activity.dailyChallengesCompleted, 0);
    });

    test('a game not scheduled today cannot claim a daily challenge', () async {
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'stroop',
          mode: SessionMode.dailyChallenge,
          gameType: 'stroop',
          primaryPillar: BrainPillar.reaction,
          performance: StroopPerformanceInput(
            correct: 20,
            totalAttempts: 20,
            avgReactionMs: 250,
            difficulty: 3,
          ),
          isDailyChallenge: true,
          challengeId: DailyChallengeService.todaysChallengeId(),
          playerName: 'Test Player',
          challengeDate: DateTime.utc(2026, 11, 18, 12),
        ),
      );

      expect(outcome.performanceScore, greaterThan(0));
      expect(outcome.challengeScore, 0);
      expect(outcome.xp.granted, 0);
      expect(await LeaderboardService.instance.currentWeekChallengeCount(), 0);
    });

    test('multiple scheduled games can each score on the same date', () async {
      DailyChallengeService.scheduleNotifier.value = {
        '2026-11-18': ['quiz', 'math'],
      };
      final challengeDate = DateTime.utc(2026, 11, 18, 12);

      final quizOutcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'quiz',
          mode: SessionMode.dailyChallenge,
          gameType: 'challenge',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(correct: 8, total: 10),
          isDailyChallenge: true,
          challengeDate: challengeDate,
        ),
      );
      final mathOutcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'math',
          mode: SessionMode.dailyChallenge,
          gameType: 'challenge',
          primaryPillar: BrainPillar.logic,
          performance: MathPerformanceInput(
            correct: 10,
            totalAttempts: 10,
            maxLevel: 5,
            avgTimePerAnswerSeconds: 2,
          ),
          isDailyChallenge: true,
          challengeDate: challengeDate,
        ),
      );

      expect(quizOutcome.challengeScore, greaterThan(0));
      expect(mathOutcome.challengeScore, greaterThan(0));
      expect(await LeaderboardService.instance.currentWeekChallengeCount(), 2);
    });

    test('dual drive challenge score uses its game multiplier', () async {
      DailyChallengeService.scheduleNotifier.value = {
        '2026-11-18': ['dualDrive'],
      };
      final input = DualDrivePerformanceInput(
        coins: 10,
        timeSeconds: 10,
        missedCoin: false,
      );
      final perf = GamePerformanceService.calculate(input);
      final raw = (perf /
              100 *
              ScoringConfig.dailyScoreMax *
              ScoringConfig.dailyGameScoreMultiplier['dualDrive']!)
          .round();

      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'dualDrive',
          mode: SessionMode.dailyChallenge,
          gameType: GameType.dualDrive,
          primaryPillar: BrainPillar.reaction,
          performance: input,
          isDailyChallenge: true,
          challengeDate: DateTime.utc(2026, 11, 18, 12),
          durationSeconds: 10,
        ),
      );

      expect(outcome.challengeScore, raw.clamp(0, ScoringConfig.dailyScoreMax));
    });

    test('unknown game never throws and degrades gracefully', () async {
      final outcome = await ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'not-a-game',
          mode: SessionMode.practice,
          gameType: 'quiz',
          primaryPillar: BrainPillar.knowledge,
          performance: QuizPerformanceInput(correct: 5, total: 10),
        ),
      );
      expect(outcome.performanceScore, greaterThan(0));
      expect(outcome.skillDeltas, isEmpty);
    });
  });

  group('ProgressionService.awardWorkout', () {
    test('perfect workout grants base + performance + bonus', () async {
      final award = await ProgressionService.instance.awardWorkout(
        overallScore: 100,
        completedCount: 3,
        plannedCount: 3,
      );
      expect(
        award.granted,
        ScoringConfig.workoutXp +
            (100 * ScoringConfig.workoutPerformanceXpMultiplier).round() +
            ScoringConfig.perfectBonusXp,
      );
    });
  });
}
