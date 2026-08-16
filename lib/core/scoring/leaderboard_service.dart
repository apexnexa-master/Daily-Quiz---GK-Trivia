// lib/core/scoring/leaderboard_service.dart
// Competitive leaderboard metrics, kept strictly separate from Brain Score,
// XP and daily goal.
//
// Spec §19: the WEEKLY score is NOT the sum of everything played. It is the
// sum of the best 5 Daily Challenge scores during the week, so nobody wins by
// grinding easy games. Only official Daily Challenge submissions are recorded
// here (see DailyChallengeService) — practice and workout never count.
//
// All-time metrics (§21) avoid an "older account wins" problem: we track the
// best weekly score and best daily score, not a lifetime point total.

import '../services/local_stats_service.dart';
import 'scoring_config.dart';
import 'scoring_store.dart';

/// One official Daily Challenge result for a week, keyed by challenge id so a
/// repeated attempt never double-counts.
class ChallengeResult {
  final String challengeId;
  final String date; // 'yyyy-MM-dd'
  final int score; // normalized 0-1000

  const ChallengeResult({
    required this.challengeId,
    required this.date,
    required this.score,
  });

  Map<String, dynamic> toJson() =>
      {'challengeId': challengeId, 'date': date, 'score': score};

  factory ChallengeResult.fromJson(Map<String, dynamic> json) => ChallengeResult(
        challengeId: json['challengeId']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}

/// Aggregated leaderboard row (a player's weekly / all-time entry).
class AggregatedEntry {
  final String playerName;
  final int score;
  final int timeTaken;

  const AggregatedEntry({
    required this.playerName,
    required this.score,
    required this.timeTaken,
  });
}

/// How a player currently ranks among a set of scored entries.
class RankInfo {
  /// 1-based rank (competition ranking: ties share the best rank).
  final int rank;

  /// Total number of ranked players.
  final int totalPlayers;

  /// Points needed to reach the next better rank (0 when already #1).
  final int pointsToNext;

  const RankInfo({
    required this.rank,
    required this.totalPlayers,
    required this.pointsToNext,
  });
}

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const String _keyWeekly = ScoringStore.keyWeeklyResults;
  static const String _keyCompetition = ScoringStore.keyCompetitionStats;

  // ── Week ids (local time) ──────────────────────────────────
  // Week starts on Monday and the id looks like '2026-W34'. Using the user's
  // local date keeps day/week boundaries correct per spec §25.
  static String weekIdFor(DateTime date) {
    // Move to Monday of the current ISO week.
    final daysSinceMonday = date.weekday - DateTime.monday;
    final monday = date.subtract(Duration(days: daysSinceMonday));
    // Week number: ISO 8601 approximation.
    final start = DateTime(monday.year);
    final dayOfYear = monday.difference(start).inDays + 1;
    final week = ((dayOfYear + start.weekday - 1) ~/ 7) + 1;
    return '${monday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String currentWeekId() => weekIdFor(DateTime.now());

  // ── Weekly results storage ─────────────────────────────────
  Map<String, List<ChallengeResult>> _readWeeks() {
    final map = ScoringStore.instance.readJson(_keyWeekly);
    final weeks = <String, List<ChallengeResult>>{};
    map.forEach((weekId, value) {
      if (value is List) {
        weeks[weekId] = value
            .whereType<Map>()
            .map((e) => ChallengeResult.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    });
    return weeks;
  }

  Future<void> _writeWeeks(Map<String, List<ChallengeResult>> weeks) async {
    final json = weeks.map((k, v) =>
        MapEntry(k, v.map((r) => r.toJson()).toList()));
    await ScoringStore.instance.writeJson(_keyWeekly, json);
  }

  /// Records an OFFICIAL daily challenge result for the week of [date].
  /// Idempotent per challenge: a challenge already recorded for the week is
  /// kept at its best score (a retry cannot inflate the weekly total).
  Future<void> recordChallengeResult({
    required String challengeId,
    required DateTime date,
    required int score,
  }) async {
    final clamped = score.clamp(0, ScoringConfig.dailyScoreMax);
    final weeks = _readWeeks();
    final weekId = weekIdFor(date);
    final results = List<ChallengeResult>.from(weeks[weekId] ?? const []);

    final existing = results.indexWhere((r) => r.challengeId == challengeId);
    if (existing != -1) {
      final current = results[existing];
      if (clamped > current.score) {
        results[existing] = ChallengeResult(
          challengeId: challengeId,
          date: date.toIso8601String().split('T').first,
          score: clamped,
        );
      }
    } else {
      results.add(ChallengeResult(
        challengeId: challengeId,
        date: date.toIso8601String().split('T').first,
        score: clamped,
      ));
    }

    weeks[weekId] = results;
    await _writeWeeks(weeks);

    await _updateAllTimeBest(weekId);
  }

  /// The scores recorded for [weekId] (best-5 not yet applied).
  Future<List<ChallengeResult>> resultsForWeek(String weekId) async {
    final weeks = _readWeeks();
    return List.unmodifiable(weeks[weekId] ?? const []);
  }

  /// Sum of the best [ScoringConfig.weeklyBestChallenges] challenge scores in
  /// the week. This is the weekly leaderboard metric (§19).
  Future<int> weeklyScore(String weekId) async {
    final results = await resultsForWeek(weekId);
    if (results.isEmpty) return 0;
    final sorted =
        results.map((r) => r.score).toList()..sort((a, b) => b.compareTo(a));
    final best = sorted.take(ScoringConfig.weeklyBestChallenges);
    return best.fold<int>(0, (sum, s) => sum + s);
  }

  /// This week's running weekly score.
  Future<int> currentWeeklyScore() => weeklyScore(currentWeekId());

  /// Number of official daily challenges this week so far.
  Future<int> currentWeekChallengeCount() async {
    final results = await resultsForWeek(currentWeekId());
    return results.length;
  }

  // ── All-time bests (§21) ───────────────────────────────────
  Future<Map<String, dynamic>> _readCompetition() =>
      Future.value(ScoringStore.instance.readJson(_keyCompetition));

  Future<void> _writeCompetition(Map<String, dynamic> data) =>
      ScoringStore.instance.writeJson(_keyCompetition, data);

  /// Recomputes (and stores) the best weekly score seen so far.
  Future<void> _updateAllTimeBest(String updatedWeekId) async {
    final weeks = _readWeeks();
    var best = 0;
    var bestWeek = '';
    for (final weekId in weeks.keys) {
      final score = await weeklyScore(weekId);
      if (score > best) {
        best = score;
        bestWeek = weekId;
      }
    }
    final data = await _readCompetition();
    final previous = (data['bestWeeklyScore'] as num?)?.toInt() ?? 0;
    if (best > previous) {
      data['bestWeeklyScore'] = best;
      data['bestWeeklyWeekId'] = bestWeek.isNotEmpty ? bestWeek : updatedWeekId;
      await _writeCompetition(data);
    }
  }

  /// Best weekly score ever achieved (sum of best-5 in a single week).
  Future<int> bestWeeklyScore() async {
    final data = await _readCompetition();
    return (data['bestWeeklyScore'] as num?)?.toInt() ?? 0;
  }

  /// Best normalized Daily Challenge score ever (single day).
  Future<int> bestDailyScore() async {
    final data = await _readCompetition();
    return (data['bestDailyScore'] as num?)?.toInt() ?? 0;
  }

  /// Updates the stored best daily score; returns true when it improved.
  Future<bool> updateBestDailyScore(int score) async {
    final data = await _readCompetition();
    final current = (data['bestDailyScore'] as num?)?.toInt() ?? 0;
    if (score <= current) return false;
    data['bestDailyScore'] = score;
    data['bestDailyDate'] = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    await _writeCompetition(data);
    return true;
  }

  /// Best rank ever seen in the weekly leaderboard (stored as we compute it).
  Future<void> updateBestWeeklyRank(int rank) async {
    if (rank <= 0) return;
    final data = await _readCompetition();
    final current = (data['bestWeeklyRank'] as num?)?.toInt() ?? 0;
    if (current == 0 || rank < current) {
      data['bestWeeklyRank'] = rank;
      data['bestWeeklyRankWeekId'] = currentWeekId();
      await _writeCompetition(data);
    }
  }

  Future<int> bestWeeklyRank() async {
    final data = await _readCompetition();
    return (data['bestWeeklyRank'] as num?)?.toInt() ?? 0;
  }

  // ── Rank math ──────────────────────────────────────────────
  /// Competition ranking: rank = 1 + count of strictly higher scores.
  static RankInfo rankOf(int userScore, List<int> allScores) {
    final nonEmpty = allScores.where((s) => s > 0).toList();
    final rank = 1 + nonEmpty.where((s) => s > userScore).length;
    int pointsToNext = 0;
    if (rank > 1) {
      final nextHigher = nonEmpty.where((s) => s > userScore).reduce(
            (a, b) => a < b ? a : b,
          );
      pointsToNext = nextHigher - userScore;
    }
    return RankInfo(
      rank: rank,
      totalPlayers: nonEmpty.length + (userScore > 0 ? 1 : 0),
      pointsToNext: pointsToNext < 0 ? 0 : pointsToNext,
    );
  }

  /// Aggregates raw daily entries into a weekly board: for each player only
  /// the best 5 daily scores within the week count (§19). Days outside the
  /// week window are ignored.
  static List<AggregatedEntry> aggregateWeekly(
    List<LeaderboardEntryLocal> raw, {
    DateTime? weekReference,
  }) {
    final ref = weekReference ?? DateTime.now();
    final windowStart = ref.subtract(const Duration(days: 6));

    final grouped = <String, List<LeaderboardEntryLocal>>{};
    for (final entry in raw) {
      final date = DateTime.tryParse(entry.date);
      if (date == null) continue;
      if (date.isBefore(windowStart) || date.isAfter(ref)) continue;
      grouped.putIfAbsent(entry.playerName, () => []).add(entry);
    }

    final aggregated = <AggregatedEntry>[];
    grouped.forEach((name, entries) {
      final best5 = (entries.toList()
            ..sort((a, b) => b.score.compareTo(a.score)))
          .take(ScoringConfig.weeklyBestChallenges);
      var totalScore = 0;
      var totalTime = 0;
      for (final e in best5) {
        totalScore += e.score;
        totalTime += e.timeTaken;
      }
      aggregated.add(AggregatedEntry(
        playerName: name,
        score: totalScore,
        timeTaken: totalTime,
      ));
    });

    aggregated.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.timeTaken.compareTo(b.timeTaken);
    });
    return aggregated;
  }

  /// Aggregates all daily entries into an all-time best-5 board. Lifetime
  /// accumulation is intentionally avoided (§21); using the same best-5 rule
  /// keeps easy-game grinding worthless across every tab.
  static List<AggregatedEntry> aggregateAllTime(
    List<LeaderboardEntryLocal> raw,
  ) {
    final grouped = <String, List<LeaderboardEntryLocal>>{};
    for (final entry in raw) {
      if (entry.score <= 0) continue;
      grouped.putIfAbsent(entry.playerName, () => []).add(entry);
    }

    final aggregated = <AggregatedEntry>[];
    grouped.forEach((name, entries) {
      final best5 = (entries.toList()
            ..sort((a, b) => b.score.compareTo(a.score)))
          .take(ScoringConfig.weeklyBestChallenges);
      var totalScore = 0;
      var totalTime = 0;
      for (final e in best5) {
        totalScore += e.score;
        totalTime += e.timeTaken;
      }
      aggregated.add(AggregatedEntry(
        playerName: name,
        score: totalScore,
        timeTaken: totalTime,
      ));
    });

    aggregated.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.timeTaken.compareTo(b.timeTaken);
    });
    return aggregated;
  }
}
