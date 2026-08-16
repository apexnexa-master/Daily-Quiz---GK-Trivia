// lib/core/scoring/daily_challenge_service.dart
// Daily Challenge: the single controlled competitive environment.
//
// Every user must face the same challenge for the same date, so challenge ids
// are deterministic (`DC-YYYYMMDD-<gameKey>`) instead of random. Only ONE
// official attempt per challenge counts: the first completed submission is the
// official one and feeds the leaderboard / weekly score; retries are practice
// and never re-award XP or re-submit competitive scores. This also makes the
// whole flow idempotent (see spec §13 / §18 / §33).

import 'scoring_config.dart';
import 'scoring_store.dart';

/// Result of claiming a Daily Challenge submission.
class ChallengeSubmission {
  /// The deterministic challenge id this submission belonged to.
  final String challengeId;

  /// Whether this was the first (official) submission of the challenge. Only
  /// official submissions affect XP, the leaderboard and the weekly score.
  final bool countsAsOfficial;

  /// Whether it was a new personal best for this challenge.
  final bool newBestForChallenge;

  /// Normalized challenge score (0-1000).
  final int challengeScore;

  const ChallengeSubmission({
    required this.challengeId,
    required this.countsAsOfficial,
    required this.newBestForChallenge,
    required this.challengeScore,
  });
}

class DailyChallengeService {
  DailyChallengeService._();
  static final DailyChallengeService instance = DailyChallengeService._();

  static const String _keyCompleted = ScoringStore.keyCompletedChallenges;

  /// Deterministic challenge id: `DC-20260816-gk`. The same date + game key
  /// always yields the same id so all users share the same challenge.
  static String challengeIdFor(DateTime date, String gameKey) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'DC-$y$m$d-$gameKey';
  }

  /// Todays deterministic challenge id for [gameKey].
  static String todaysChallengeId(String gameKey) =>
      challengeIdFor(DateTime.now(), gameKey);

  Future<Set<String>> _completedSet() async {
    final map = ScoringStore.instance.readJson(_keyCompleted);
    final list = map['challenges'];
    if (list is List) return list.map((e) => e.toString()).toSet();
    return {};
  }

  Future<void> _saveCompleted(Set<String> completed) async {
    await ScoringStore.instance.writeJson(
      _keyCompleted,
      {'challenges': completed.toList()..sort()},
    );
  }

  /// Whether this challenge has already been officially completed.
  Future<bool> isCompleted(String challengeId) async {
    final completed = await _completedSet();
    return completed.contains(challengeId);
  }

  /// Claims a submission for the challenge.
  ///
  /// [score] must be a normalized challenge score in `0..dailyScoreMax`
  /// (0-1000). Invalid scores are rejected with an [ArgumentError] instead of
  /// being persisted — the client can never write `999999` into the board.
  ///
  /// Returns whether this submission counts as the official attempt. Only the
  /// first submission for a challenge returns `countsAsOfficial == true`.
  Future<ChallengeSubmission> submitOfficialScore({
    required String challengeId,
    required int score,
  }) async {
    if (score < 0 || score > ScoringConfig.dailyScoreMax) {
      throw ArgumentError.value(
        score,
        'score',
        'Challenge score must be within 0..${ScoringConfig.dailyScoreMax}',
      );
    }
    if (challengeId.isEmpty) {
      throw ArgumentError.value(challengeId, 'challengeId', 'Cannot be empty');
    }

    final completed = await _completedSet();
    final countsAsOfficial = !completed.contains(challengeId);

    if (countsAsOfficial) {
      completed.add(challengeId);
      await _saveCompleted(completed);
    }

    // Personal best per challenge is tracked for every attempt (a retry that
    // beats the first attempt still improves the profile's "Best Daily Score",
    // it just never touches the leaderboard).
    final bestRaw = ScoringStore.instance.get('challenge_best_$challengeId');
    final prevBest = int.tryParse(bestRaw ?? '') ?? 0;
    final newBestForChallenge = score > prevBest;
    if (newBestForChallenge) {
      await ScoringStore.instance.put(
        'challenge_best_$challengeId',
        score.toString(),
      );
    }

    return ChallengeSubmission(
      challengeId: challengeId,
      countsAsOfficial: countsAsOfficial,
      newBestForChallenge: newBestForChallenge,
      challengeScore: score,
    );
  }

  /// Number of distinct daily challenges officially completed so far.
  Future<int> totalCompleted() async {
    final completed = await _completedSet();
    return completed.length;
  }

  /// Best official score ever recorded for a challenge (0 when none).
  Future<int> bestFor(String challengeId) async {
    final raw = ScoringStore.instance.get('challenge_best_$challengeId');
    return int.tryParse(raw ?? '') ?? 0;
  }
}
