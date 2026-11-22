import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../scoring/scoring_store.dart';

class PendingLeaderboardSubmission {
  final String challengeId;
  final int score;
  final int timeTaken;
  final String submittedAt;

  const PendingLeaderboardSubmission({
    required this.challengeId,
    required this.score,
    required this.timeTaken,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'score': score,
        'timeTaken': timeTaken,
        'submittedAt': submittedAt,
      };

  factory PendingLeaderboardSubmission.fromJson(Map<String, dynamic> json) =>
      PendingLeaderboardSubmission(
        challengeId: json['challengeId']?.toString() ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        timeTaken: (json['timeTaken'] as num?)?.toInt() ?? 0,
        submittedAt: json['submittedAt']?.toString() ?? '',
      );
}

class DailyChallengeSubmissionService {
  DailyChallengeSubmissionService._();

  static final DailyChallengeSubmissionService instance =
      DailyChallengeSubmissionService._();

  static const String _pendingKey = 'pending_leaderboard_submissions';
  static const String _functionsRegion = 'asia-south1';

  final StreamController<bool> _signInPromptController =
      StreamController<bool>.broadcast();

  Stream<bool> get signInPromptStream => _signInPromptController.stream;

  Future<User?> _currentUser() async {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<String?> currentPlayerId() async => (await _currentUser())?.uid;

  Future<void> submit({
    required String challengeId,
    required int score,
    required int timeTaken,
  }) async {
    final user = await _currentUser();
    if (user == null || user.isAnonymous) {
      await queue(
        challengeId: challengeId,
        score: score,
        timeTaken: timeTaken,
      );
      _signInPromptController.add(true);
      return;
    }
    await _send(
      PendingLeaderboardSubmission(
        challengeId: challengeId,
        score: score,
        timeTaken: timeTaken,
        submittedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> queue({
    required String challengeId,
    required int score,
    required int timeTaken,
  }) async {
    final submissions = await pendingSubmissions();
    submissions[challengeId] = PendingLeaderboardSubmission(
      challengeId: challengeId,
      score: score,
      timeTaken: timeTaken,
      submittedAt: DateTime.now().toIso8601String(),
    );
    await _write(submissions);
  }

  Future<Map<String, PendingLeaderboardSubmission>> pendingSubmissions() async {
    final raw = ScoringStore.instance.readJson(_pendingKey);
    return raw.map(
      (key, value) => MapEntry(
        key,
        PendingLeaderboardSubmission.fromJson(
          value is Map<String, dynamic>
              ? value
              : Map<String, dynamic>.from(value as Map),
        ),
      ),
    );
  }

  Future<int> flushPending() async {
    final user = await _currentUser();
    if (user == null || user.isAnonymous) return 0;

    final submissions = await pendingSubmissions();
    if (submissions.isEmpty) return 0;

    var submitted = 0;
    for (final pending in submissions.values.toList()) {
      if (await _send(pending)) submitted++;
    }
    return submitted;
  }

  Future<bool> _send(PendingLeaderboardSubmission pending) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable('submitChallengeScore');
      await callable.call<Map<String, dynamic>>({
        'score': pending.score,
        'challengeId': pending.challengeId,
        'timeTaken': pending.timeTaken,
      });
      final submissions = await pendingSubmissions();
      submissions.remove(pending.challengeId);
      await _write(submissions);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _write(
    Map<String, PendingLeaderboardSubmission> submissions,
  ) async {
    await ScoringStore.instance.writeJson(
      _pendingKey,
      submissions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    );
  }

  Future<void> clearPending() => _write({});
}
