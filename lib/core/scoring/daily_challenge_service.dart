import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'scoring_config.dart';
import 'scoring_store.dart';

class DailyChallengeGame {
  final String gameId;
  final String challengeKey;
  final String label;
  final String introRoute;
  final String badge;
  final String emblemPath;

  const DailyChallengeGame({
    required this.gameId,
    required this.challengeKey,
    required this.label,
    required this.introRoute,
    required this.badge,
    required this.emblemPath,
  });
}

class ChallengeSubmission {
  final String challengeId;
  final bool countsAsOfficial;
  final bool newBestForChallenge;
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
  static const Duration _challengeUtcOffset = Duration(hours: 5, minutes: 30);
  static const String configCollection = 'daily_challenge_config';
  static const String defaultConfigId = 'default';

  static const List<DailyChallengeGame> dailyGames = [
    DailyChallengeGame(
      gameId: 'quiz',
      challengeKey: 'quiz',
      label: 'GK Quiz',
      introRoute: '/intro/gk-quiz',
      badge: 'QUIZ',
      emblemPath: 'assets/covers/gk_quiz_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'synapse',
      challengeKey: 'synapse',
      label: 'Synapse Recall',
      introRoute: '/intro/synapse-recall',
      badge: 'MEMORY',
      emblemPath: 'assets/covers/synapse_recall_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'stroop',
      challengeKey: 'stroop',
      label: 'Stroop Rush',
      introRoute: '/intro/stroop-rush',
      badge: 'STROOP',
      emblemPath: 'assets/covers/stroop_rush_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'math',
      challengeKey: 'math',
      label: 'Math Sprint',
      introRoute: '/intro/math-sprint',
      badge: 'MATH',
      emblemPath: 'assets/covers/math_sprint_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'flowFree',
      challengeKey: 'flowFree',
      label: 'Flow Free',
      introRoute: '/intro/flow-free',
      badge: 'FLOW',
      emblemPath: 'assets/covers/flow_free_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'oneLine',
      challengeKey: 'oneLine',
      label: 'One Line',
      introRoute: '/intro/one-line',
      badge: 'LINE',
      emblemPath: 'assets/covers/one_line_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'arrowSilhouette',
      challengeKey: 'arrowSilhouette',
      label: 'Arrow Puzzle',
      introRoute: '/intro/arrow-silhouette',
      badge: 'ARROWS',
      emblemPath: 'assets/covers/arrow_maze_emblem.svg',
    ),
    DailyChallengeGame(
      gameId: 'dualDrive',
      challengeKey: 'dualDrive',
      label: 'Dual Drive',
      introRoute: '/intro/dual-drive',
      badge: 'DRIVE',
      emblemPath: 'assets/covers/workout_brain_emblem.svg',
    ),
  ];

  static const List<String> fallbackGameIds = [
    'arrowSilhouette',
    'math',
    'dualDrive',
  ];

  static final ValueNotifier<Map<String, List<String>>> scheduleNotifier =
      ValueNotifier(<String, List<String>>{});

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _configSubscription;

  static final Map<String, DailyChallengeGame> _gamesById = {
    for (final game in dailyGames) game.gameId: game,
  };

  static DateTime challengeDate([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(_challengeUtcOffset);

  static String dateKey([DateTime? now]) {
    final date = challengeDate(now);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String todayDateString([DateTime? now]) {
    final key = dateKey(now);
    return '${key.substring(0, 4)}-${key.substring(4, 6)}-${key.substring(6, 8)}';
  }

  static DailyChallengeGame? gameById(String gameId) => _gamesById[gameId];

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty || _configSubscription != null) return;
    _configSubscription = FirebaseFirestore.instance
        .collection(configCollection)
        .snapshots()
        .listen(
      (snapshot) {
        final next = <String, List<String>>{};
        for (final doc in snapshot.docs) {
          final raw = doc.data()['game_ids'];
          if (raw is! List) continue;
          final ids = raw
              .map((id) => id.toString())
              .where(_gamesById.containsKey)
              .toList();
          if (ids.isNotEmpty) next[doc.id] = ids;
        }
        scheduleNotifier.value = next;
      },
      onError: (_) {},
    );
  }

  Future<void> refresh() async {
    if (Firebase.apps.isEmpty) return;
    final snapshot =
        await FirebaseFirestore.instance.collection(configCollection).get();
    final next = <String, List<String>>{};
    for (final doc in snapshot.docs) {
      final raw = doc.data()['game_ids'];
      if (raw is! List) continue;
      final ids = raw
          .map((id) => id.toString())
          .where(_gamesById.containsKey)
          .toList();
      if (ids.isNotEmpty) next[doc.id] = ids;
    }
    scheduleNotifier.value = next;
  }

  Future<List<String>> loadSchedule(String documentId) async {
    final cached = scheduleNotifier.value[documentId];
    if (cached != null && cached.isNotEmpty) return List<String>.from(cached);
    if (Firebase.apps.isEmpty) return List<String>.from(fallbackGameIds);
    final doc = await FirebaseFirestore.instance
        .collection(configCollection)
        .doc(documentId)
        .get();
    final raw = doc.data()?['game_ids'];
    if (raw is! List) {
      if (documentId != defaultConfigId) {
        return loadSchedule(defaultConfigId);
      }
      return List<String>.from(fallbackGameIds);
    }
    final ids = raw
        .map((id) => id.toString())
        .where(_gamesById.containsKey)
        .toList();
    return ids.isEmpty ? List<String>.from(fallbackGameIds) : ids;
  }

  Future<void> saveSchedule(String documentId, List<String> gameIds) async {
    if (documentId.isEmpty) {
      throw ArgumentError.value(documentId, 'documentId', 'Cannot be empty');
    }
    final normalized = gameIds
        .where(_gamesById.containsKey)
        .toList(growable: false);
    if (normalized.isEmpty) {
      throw ArgumentError.value(gameIds, 'gameIds', 'Select at least one game');
    }
    await FirebaseFirestore.instance
        .collection(configCollection)
        .doc(documentId)
        .set({
      'game_ids': normalized,
      'updated_at': FieldValue.serverTimestamp(),
    });
    final next = Map<String, List<String>>.from(scheduleNotifier.value);
    next[documentId] = normalized;
    scheduleNotifier.value = next;
  }

  static List<String> configuredGameIds([DateTime? now]) {
    final configs = scheduleNotifier.value;
    final dateId = todayDateString(now);
    for (final id in <String>[dateId, defaultConfigId]) {
      final ids = configs[id];
      if (ids != null && ids.isNotEmpty) return List<String>.from(ids);
    }
    return List<String>.from(fallbackGameIds);
  }

  static List<DailyChallengeGame> gamesForDate([DateTime? now]) =>
      configuredGameIds(now)
          .map((id) => _gamesById[id])
          .whereType<DailyChallengeGame>()
          .toList(growable: false);

  static List<DailyChallengeGame> gamesForToday() => gamesForDate();

  static DailyChallengeGame gameForDate([DateTime? now]) => gamesForDate(now).first;

  static DailyChallengeGame gameForToday() => gameForDate();

  static bool isScheduledGame(String gameId, [DateTime? now]) =>
      configuredGameIds(now).contains(gameId);

  static bool isTodaysGame(String gameId) => isScheduledGame(gameId);

  static double scoreMultiplierFor(String gameId) =>
      ScoringConfig.dailyGameScoreMultiplier[gameId] ?? 1.0;

  static String challengeIdFor(DateTime date, String gameKey) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'DC-$y$m$d-$gameKey';
  }

  static String challengeIdForGame(String gameId, [DateTime? now]) =>
      challengeIdFor(challengeDate(now), gameId);

  static String todaysChallengeId([String? gameKey]) => challengeIdForGame(
        gameKey ?? gameForToday().gameId,
      );

  static String scheduledChallengeId([DateTime? now, String? gameId]) =>
      challengeIdForGame(gameId ?? gameForDate(now).gameId, now);

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

  Future<bool> isCompleted(String challengeId) async {
    final completed = await _completedSet();
    return completed.contains(challengeId);
  }

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

  Future<int> totalCompleted() async {
    final completed = await _completedSet();
    return completed.length;
  }

  Future<int> bestFor(String challengeId) async {
    final raw = ScoringStore.instance.get('challenge_best_$challengeId');
    return int.tryParse(raw ?? '') ?? 0;
  }
}
