import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gk_quiz_app/core/scoring/daily_challenge_service.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoringStore.instance.resetForTest();
    DailyChallengeService.scheduleNotifier.value = <String, List<String>>{};
  });

  group('DailyChallengeService.challengeIdFor', () {
    test('is deterministic and zero-padded', () {
      expect(DailyChallengeService.challengeIdFor(
          DateTime(2026, 8, 16), 'gk'), 'DC-20260816-gk');
      expect(DailyChallengeService.challengeIdFor(
          DateTime(2026, 1, 5), 'quiz'), 'DC-20260105-quiz');
      expect(DailyChallengeService.challengeIdFor(DateTime(2026, 8, 16), 'gk'),
          DailyChallengeService.challengeIdFor(DateTime(2026, 8, 16), 'gk'));
    });
  });

  group('DailyChallengeService schedule', () {
    test('uses every configured game for the date', () {
      DailyChallengeService.scheduleNotifier.value = {
        '2026-11-18': ['math', 'dualDrive', 'quiz'],
      };
      final games = DailyChallengeService.gamesForDate(
        DateTime.utc(2026, 11, 18, 12),
      );

      expect(games.map((game) => game.gameId),
          ['math', 'dualDrive', 'quiz']);
      expect(DailyChallengeService.isScheduledGame(
        'dualDrive',
        DateTime.utc(2026, 11, 18, 12),
      ), isTrue);
    });

    test('falls back when no date or default config is cached', () {
      final ids = DailyChallengeService.configuredGameIds(
        DateTime.utc(2026, 11, 18, 12),
      );
      expect(ids, DailyChallengeService.fallbackGameIds);
    });

    test('uses default config for dates without an override', () {
      DailyChallengeService.scheduleNotifier.value = {
        'default': ['oneLine'],
      };
      final id = DailyChallengeService.scheduledChallengeId(
        DateTime.utc(2026, 11, 18, 12),
      );
      expect(id, 'DC-20261118-oneLine');
    });

    test('scheduled ids use IST date and the selected game', () {
      DailyChallengeService.scheduleNotifier.value = {
        '2026-11-19': ['stroop'],
      };
      final id = DailyChallengeService.scheduledChallengeId(
        DateTime.utc(2026, 11, 18, 20),
      );
      expect(id, 'DC-20261119-stroop');
    });
  });

  group('DailyChallengeService.submitOfficialScore', () {
    test('first submission is official', () async {
      final sub = await DailyChallengeService.instance.submitOfficialScore(
        challengeId: 'DC-20260816-gk',
        score: 840,
      );
      expect(sub.countsAsOfficial, isTrue);
      expect(sub.newBestForChallenge, isTrue);
      expect(sub.challengeScore, 840);
    });

    test('a duplicate submission is not official (idempotent)', () async {
      await DailyChallengeService.instance.submitOfficialScore(
        challengeId: 'DC-20260816-gk',
        score: 840,
      );
      final retry = await DailyChallengeService.instance.submitOfficialScore(
        challengeId: 'DC-20260816-gk',
        score: 900,
      );
      expect(retry.countsAsOfficial, isFalse);
      expect(retry.newBestForChallenge, isTrue, reason: 'personal best can improve');
      expect(await DailyChallengeService.instance.isCompleted('DC-20260816-gk'),
          isTrue);
    });

    test('an out-of-range score is rejected', () async {
      expect(
        () => DailyChallengeService.instance.submitOfficialScore(
          challengeId: 'DC-20260816-gk',
          score: ScoringConfig.dailyScoreMax + 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => DailyChallengeService.instance.submitOfficialScore(
          challengeId: 'DC-20260816-gk',
          score: -1,
        ),
        throwsArgumentError,
      );
    });

    test('totalCompleted counts distinct challenges only', () async {
      await DailyChallengeService.instance
          .submitOfficialScore(challengeId: 'DC-20260816-gk', score: 800);
      await DailyChallengeService.instance
          .submitOfficialScore(challengeId: 'DC-20260816-gk', score: 900);
      await DailyChallengeService.instance
          .submitOfficialScore(challengeId: 'DC-20260816-gk', score: 950);
      expect(await DailyChallengeService.instance.totalCompleted(), 1);
    });

    test('official attempts stay persisted across instances', () async {
      await DailyChallengeService.instance
          .submitOfficialScore(challengeId: 'DC-20260816-gk', score: 700);
      final again = await DailyChallengeService.instance.submitOfficialScore(
        challengeId: 'DC-20260816-gk',
        score: 700,
      );
      expect(again.countsAsOfficial, isFalse);
    });
  });
}
