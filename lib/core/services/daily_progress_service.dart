// lib/core/services/daily_progress_service.dart
// Tracks per-user daily goal, day streak, and brain score pillars.
// Backed by local Hive storage and synced to Firestore for logged-in users.

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'gamification_service.dart';

/// Brain score pillars (equal weight, rolling average of last [DailyProgress.pillarHistorySize] games).
class BrainPillar {
  static const String knowledge = 'knowledge';
  static const String logic = 'logic';
  static const String speed = 'speed';
  static const String memory = 'memory';
  static const String reaction = 'reaction';

  static const List<String> all = [knowledge, logic, speed, memory, reaction];
}

/// Game type keys used for the daily goal ("1 daily challenge + 2 different games").
/// Only distinct game types count toward the goal.
class GameType {
  static const String challenge = 'challenge'; // today's GK daily quiz
  static const String quiz = 'quiz'; // practice / other knowledge quizzes
  static const String arrow = 'arrow';
  static const String stroop = 'stroop';
  static const String synapse = 'synapse';
  static const String math = 'math';
  static const String battle = 'battle';
  static const String flowFree = 'flowFree';
  static const String oneLine = 'oneLine';
}

class DailyProgress {
  static const int dailyGoalDefault = 3;
  static const int pillarHistorySize = 10;

  final String? dailyGoalDate; // 'yyyy-MM-dd'
  final bool dailyChallengeDone; // today's daily challenge completed
  final List<String> dailyGamesPlayed; // distinct game types played today
  final int dailyGoal;
  final int currentStreak;
  final int longestStreak;
  final String? lastPlayedDate; // 'yyyy-MM-dd'
  final Map<String, List<int>> pillarScores;

  const DailyProgress({
    this.dailyGoalDate,
    this.dailyChallengeDone = false,
    this.dailyGamesPlayed = const [],
    this.dailyGoal = dailyGoalDefault,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPlayedDate,
    this.pillarScores = const {},
  });

  /// Daily goal = 1 daily challenge + 2 different games (capped at the goal).
  int get dailyGamesCompleted {
    final games = (dailyChallengeDone ? 1 : 0) + dailyGamesPlayed.length;
    return games < dailyGoal ? games : dailyGoal;
  }

  bool get isDailyGoalComplete => dailyGamesCompleted >= dailyGoal;

  /// Brain Score = average of every pillar that has at least one recorded game.
  /// Once the user has played all 5 pillars this equals
  /// (Knowledge + Logic + Speed + Memory + Reaction) / 5.
  int get brainScore {
    final pillarValues = pillarScores.values
        .where((scores) => scores.isNotEmpty)
        .map((scores) => _average(scores))
        .toList();
    if (pillarValues.isEmpty) return 0;
    return (pillarValues.reduce((a, b) => a + b) / pillarValues.length).round();
  }

  /// Average score for a single pillar (0 when no games recorded yet).
  int pillarScore(String pillar) {
    final scores = pillarScores[pillar];
    if (scores == null || scores.isEmpty) return 0;
    return _average(scores);
  }

  static int _average(List<int> scores) {
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  DailyProgress copyWith({
    String? dailyGoalDate,
    bool? dailyChallengeDone,
    List<String>? dailyGamesPlayed,
    int? dailyGoal,
    int? currentStreak,
    int? longestStreak,
    String? lastPlayedDate,
    Map<String, List<int>>? pillarScores,
  }) {
    return DailyProgress(
      dailyGoalDate: dailyGoalDate ?? this.dailyGoalDate,
      dailyChallengeDone: dailyChallengeDone ?? this.dailyChallengeDone,
      dailyGamesPlayed: dailyGamesPlayed ?? this.dailyGamesPlayed,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
      pillarScores: pillarScores ?? this.pillarScores,
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyGoalDate': dailyGoalDate,
        'dailyChallengeDone': dailyChallengeDone,
        'dailyGamesPlayed': dailyGamesPlayed,
        'dailyGoal': dailyGoal,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastPlayedDate': lastPlayedDate,
        'pillarScores': pillarScores.map((key, value) => MapEntry(key, value)),
      };

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    final rawPillars = json['pillarScores'];
    final pillarScores = <String, List<int>>{};
    if (rawPillars is Map) {
      rawPillars.forEach((key, value) {
        if (value is List) {
          pillarScores[key.toString()] =
              value.map((e) => (e is num) ? e.round() : 0).toList();
        }
      });
    }
    return DailyProgress(
      dailyGoalDate: json['dailyGoalDate'] as String?,
      dailyChallengeDone: json['dailyChallengeDone'] as bool? ?? false,
      dailyGamesPlayed: (json['dailyGamesPlayed'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? dailyGoalDefault,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastPlayedDate: json['lastPlayedDate'] as String?,
      pillarScores: pillarScores,
    );
  }

  factory DailyProgress.fromFirestore(Map<String, dynamic> data) {
    final rawPillars = data['pillar_scores'];
    final pillarScores = <String, List<int>>{};
    if (rawPillars is Map) {
      rawPillars.forEach((key, value) {
        if (value is List) {
          pillarScores[key.toString()] =
              value.map((e) => (e is num) ? e.round() : 0).toList();
        }
      });
    }
    return DailyProgress(
      dailyGoalDate: data['daily_goal_date'] as String?,
      dailyChallengeDone: data['daily_challenge_done'] as bool? ?? false,
      dailyGamesPlayed: (data['daily_games_played'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dailyGoal: (data['daily_goal'] as num?)?.toInt() ?? dailyGoalDefault,
      currentStreak: (data['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longest_streak'] as num?)?.toInt() ?? 0,
      lastPlayedDate: data['last_played_date'] as String?,
      pillarScores: pillarScores,
    );
  }
}

class DailyProgressService {
  DailyProgressService._();
  static final DailyProgressService instance = DailyProgressService._();

  static const String _boxName = 'daily_progress';
  static const String _key = 'progress';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<DailyProgress> getProgress() async {
    final data = _box.get(_key);
    if (data == null) return const DailyProgress();
    try {
      return DailyProgress.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return const DailyProgress();
    }
  }

  Future<void> resetDailyGoalIfNeeded(DailyProgress progress) async {
    if (progress.dailyGoalDate != _today) {
      final updated = progress.copyWith(
        dailyGoalDate: _today,
        dailyChallengeDone: false,
        dailyGamesPlayed: const [],
      );
      await _save(updated);
    }
  }

  /// Records a completed meaningful game session.
  ///
  /// [pillar] is the brain-score pillar this session belongs to,
  /// [scorePct] is the session performance as a 0-100 percentage and
  /// [gameType] is the game key used for the daily goal.
  ///
  /// Rules:
  ///  - Daily goal = 1 daily challenge + 2 different games (a game type only
  ///    counts once per day), resets every day.
  ///  - Streak only advances once per day (a day is active when >= 1 game is played).
  Future<DailyProgress> recordGameCompletion({
    required String pillar,
    required int scorePct,
    required String gameType,
  }) async {
    final progress = await getProgress();
    final today = _today;

    final isNewDay = progress.dailyGoalDate != today;
    var challengeDone = isNewDay ? false : progress.dailyChallengeDone;
    final gamesPlayed =
        isNewDay ? <String>[] : List<String>.from(progress.dailyGamesPlayed);

    if (gameType == GameType.challenge) {
      challengeDone = true;
    } else if (!gamesPlayed.contains(gameType)) {
      gamesPlayed.add(gameType);
    }

    var currentStreak = progress.currentStreak;
    var longestStreak = progress.longestStreak;
    if (progress.lastPlayedDate != today) {
      final lastDate = DateTime.tryParse(progress.lastPlayedDate ?? '');
      if (lastDate == null) {
        currentStreak = 1;
      } else {
        final todayDate = DateTime.now();
        final todayOnly =
            DateTime(todayDate.year, todayDate.month, todayDate.day);
        final lastOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = todayOnly.difference(lastOnly).inDays;
        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    final pillarScores = Map<String, List<int>>.from(progress.pillarScores);
    final scores = List<int>.from(pillarScores[pillar] ?? []);
    scores.add(scorePct.clamp(0, 100).toInt());
    if (scores.length > DailyProgress.pillarHistorySize) {
      scores.removeRange(0, scores.length - DailyProgress.pillarHistorySize);
    }
    pillarScores[pillar] = scores;

    final updated = progress.copyWith(
      dailyGoalDate: today,
      dailyChallengeDone: challengeDone,
      dailyGamesPlayed: gamesPlayed,
      dailyGoal: DailyProgress.dailyGoalDefault,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastPlayedDate: today,
      pillarScores: pillarScores,
    );
    await _save(updated);

    // Keep the legacy gamification streak in sync so existing
    // streak cards, achievements and result screens stay correct.
    try {
      await GamificationService.instance.updateStreak();
    } catch (_) {}

    return updated;
  }

  Future<void> _save(DailyProgress progress) async {
    await _box.put(_key, jsonEncode(progress.toJson()));
    await _syncToCloud(progress);
  }

  Future<void> _syncToCloud(DailyProgress progress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'daily_goal_date': progress.dailyGoalDate,
        'daily_challenge_done': progress.dailyChallengeDone,
        'daily_games_played': progress.dailyGamesPlayed,
        'daily_games_completed': progress.dailyGamesCompleted,
        'daily_goal': progress.dailyGoal,
        'current_streak': progress.currentStreak,
        'longest_streak': progress.longestStreak,
        'last_played_date': progress.lastPlayedDate,
        'pillar_scores': progress.pillarScores.map((k, v) => MapEntry(k, v)),
        'brain_score': progress.brainScore,
        'last_sync': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
