import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gk_quiz_app/core/scoring/leaderboard_service.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';
import 'package:gk_quiz_app/core/services/local_stats_service.dart';

String _day(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoringStore.instance.resetForTest();
  });

  group('LeaderboardService.weekIdFor', () {
    test('Monday and Sunday of the same week share a week id', () {
      final monday = DateTime(2026, 8, 10); // Monday
      final sunday = DateTime(2026, 8, 16); // Sunday
      expect(LeaderboardService.weekIdFor(monday),
          LeaderboardService.weekIdFor(sunday));
    });

    test('week ids are deterministic', () {
      expect(LeaderboardService.weekIdFor(DateTime(2026, 8, 12)),
          LeaderboardService.weekIdFor(DateTime(2026, 8, 12)));
    });
  });

  group('LeaderboardService.recordChallengeResult', () {
    test('records a result for the current week', () async {
      await LeaderboardService.instance.recordChallengeResult(
        challengeId: 'DC-20260816-gk',
        date: DateTime.now(),
        score: 840,
      );
      expect(await LeaderboardService.instance.currentWeekChallengeCount(), 1);
      expect(await LeaderboardService.instance.currentWeeklyScore(), 840);
    });

    test('idempotent per challenge — retry keeps the best score', () async {
      await LeaderboardService.instance.recordChallengeResult(
        challengeId: 'DC-20260816-gk',
        date: DateTime.now(),
        score: 800,
      );
      await LeaderboardService.instance.recordChallengeResult(
        challengeId: 'DC-20260816-gk',
        date: DateTime.now(),
        score: 300,
      );
      expect(await LeaderboardService.instance.currentWeeklyScore(), 800);
    });

    test('weekly score is the sum of the best 5 challenges', () async {
      final week = LeaderboardService.currentWeekId();
      for (var i = 0; i < 7; i++) {
        await LeaderboardService.instance.recordChallengeResult(
          challengeId: 'DC-2026081${i}-gk',
          date: DateTime.now(),
          score: 100 * (i + 1), // 100..700
        );
      }
      final scores = await LeaderboardService.instance.resultsForWeek(week);
      expect(scores.length, 7);
      // best 5 = 700+600+500+400+300 = 2500
      expect(await LeaderboardService.instance.weeklyScore(week), 2500);
    });

    test('clamps out-of-range scores', () async {
      await LeaderboardService.instance.recordChallengeResult(
        challengeId: 'DC-20260816-gk',
        date: DateTime.now(),
        score: 999999,
      );
      expect(await LeaderboardService.instance.currentWeeklyScore(),
          ScoringConfig.dailyScoreMax);
    });
  });

  group('LeaderboardService all-time bests', () {
    test('updateBestDailyScore keeps the highest', () async {
      expect(await LeaderboardService.instance.updateBestDailyScore(700), isTrue);
      expect(await LeaderboardService.instance.updateBestDailyScore(500), isFalse);
      expect(await LeaderboardService.instance.bestDailyScore(), 700);
    });

    test('updateBestWeeklyRank keeps the lowest (best) rank', () async {
      await LeaderboardService.instance.updateBestWeeklyRank(5);
      await LeaderboardService.instance.updateBestWeeklyRank(12);
      await LeaderboardService.instance.updateBestWeeklyRank(2);
      expect(await LeaderboardService.instance.bestWeeklyRank(), 2);
    });

    test('bestWeeklyScore tracks the best week seen', () async {
      await LeaderboardService.instance.recordChallengeResult(
        challengeId: 'DC-20260816-gk',
        date: DateTime.now(),
        score: 900,
      );
      expect(await LeaderboardService.instance.bestWeeklyScore(), 900);
    });
  });

  group('LeaderboardService.rankOf', () {
    test('rank 1 with no higher scores, zero points to next', () {
      final rank = LeaderboardService.rankOf(500, [400, 300, 500]);
      expect(rank.rank, 1);
      expect(rank.pointsToNext, 0);
    });

    test('competition ranking counts strictly higher scores only', () {
      // Scores 700,700,500,400 → ranks 1,1,3,4 (competition ranking).
      final rank = LeaderboardService.rankOf(500, [700, 700, 500, 400]);
      expect(rank.rank, 3);
      expect(rank.pointsToNext, 200);
    });

    test('ties share the same rank', () {
      final rank = LeaderboardService.rankOf(600, [600, 600, 700]);
      expect(rank.rank, 2);
    });
  });

  group('LeaderboardService aggregation', () {
    test('aggregateWeekly sums only the best 5 in the window', () {
      final raw = [
        LeaderboardEntryLocal(
            playerName: 'A', score: 900, timeTaken: 10, date: _day(0)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 800, timeTaken: 20, date: _day(1)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 700, timeTaken: 30, date: _day(2)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 600, timeTaken: 40, date: _day(3)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 500, timeTaken: 50, date: _day(4)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 400, timeTaken: 60, date: _day(5)),
        LeaderboardEntryLocal(
            playerName: 'A', score: 300, timeTaken: 70, date: _day(6)),
        // Outside the 7-day window — must be ignored.
        LeaderboardEntryLocal(
            playerName: 'A', score: 950, timeTaken: 5, date: _day(10)),
      ];
      final agg = LeaderboardService.aggregateWeekly(raw);
      expect(agg, hasLength(1));
      // best 5 of 300..900 = 900+800+700+600+500 = 3500
      expect(agg.first.score, 3500);
      expect(agg.first.timeTaken, 150);
    });

    test('aggregateWeekly handles players with fewer than 5 days', () {
      final raw = [
        LeaderboardEntryLocal(
            playerName: 'B', score: 700, timeTaken: 10, date: _day(0)),
        LeaderboardEntryLocal(
            playerName: 'B', score: 200, timeTaken: 20, date: _day(1)),
      ];
      final agg = LeaderboardService.aggregateWeekly(raw);
      expect(agg.first.score, 900);
    });

    test('aggregateAllTime uses the same best-5 rule', () {
      final raw = [
        for (var i = 0; i < 8; i++)
          LeaderboardEntryLocal(
              playerName: 'C', score: 100 * (i + 1), timeTaken: i, date: _day(i)),
      ];
      final agg = LeaderboardService.aggregateAllTime(raw);
      // best 5 = 800+700+600+500+400 = 3000
      expect(agg.first.score, 3000);
    });
  });
}
