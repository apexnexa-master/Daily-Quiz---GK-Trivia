// lib/core/services/local_stats_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'gamification_service.dart';

class LocalStatsService {
  LocalStatsService._();
  static final LocalStatsService instance = LocalStatsService._();

  static const String _boxName = 'local_stats';
  static const String _keyLeaderboard = 'leaderboard_data';
  static const String _keyPersonalBest = 'personal_best';
  static const String _keyTotalQuizzes = 'total_quizzes';
  static const String _keyTotalScore = 'total_score';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  // ── Streak Management ────────────────────────────────────────
  Future<LocalStreakData> getStreak() async {
    final stats = await GamificationService.instance.getUserStats();
    return LocalStreakData(
      currentStreak: stats.currentStreak,
      longestStreak: stats.longestStreak,
      lastPlayedDate: stats.lastAttemptDate?.toIso8601String(),
    );
  }

  Future<void> updateStreakOnQuizComplete() async {
    await GamificationService.instance.updateStreak();
  }

  // ── Personal Best ──────────────────────────────────────────
  Future<PersonalBestData> getPersonalBest() async {
    final data = _box.get(_keyPersonalBest);
    if (data == null) {
      return PersonalBestData(bestScore: 0, totalQuestions: 0, percentage: 0);
    }
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return PersonalBestData.fromJson(map);
    } catch (_) {
      return PersonalBestData(bestScore: 0, totalQuestions: 0, percentage: 0);
    }
  }

  Future<bool> updatePersonalBestIfNeeded(int score, int totalQuestions) async {
    if (totalQuestions <= 0) return false;

    final current = await getPersonalBest();
    final newPercentage = (score / totalQuestions * 100).round();

    bool shouldUpdate = false;
    if (current.totalQuestions == 0) {
      shouldUpdate = true;
    } else if (current.totalQuestions == totalQuestions) {
      shouldUpdate = score > current.bestScore;
    } else {
      shouldUpdate = newPercentage > current.percentage;
    }

    if (shouldUpdate) {
      final newBest = PersonalBestData(
        bestScore: score,
        totalQuestions: totalQuestions,
        percentage: newPercentage,
      );
      await _box.put(_keyPersonalBest, jsonEncode(newBest.toJson()));
      return true;
    }
    return false;
  }

  // ── Total Stats ────────────────────────────────────────────
  Future<int> getTotalQuizzes() async {
    final data = _box.get(_keyTotalQuizzes);
    return int.tryParse(data ?? '0') ?? 0;
  }

  Future<void> incrementTotalQuizzes() async {
    final current = await getTotalQuizzes();
    await _box.put(_keyTotalQuizzes, (current + 1).toString());
  }

  Future<int> getTotalScore() async {
    final data = _box.get(_keyTotalScore);
    return int.tryParse(data ?? '0') ?? 0;
  }

  Future<void> addToTotalScore(int score) async {
    final current = await getTotalScore();
    await _box.put(_keyTotalScore, (current + score).toString());
  }

  // ── Leaderboard (Local Mock Data) ──────────────────────────
  Future<List<LeaderboardEntryLocal>> getLocalLeaderboard() async {
    final data = _box.get(_keyLeaderboard);
    if (data == null) return const [];

    try {
      final list = jsonDecode(data) as List;
      return list
          .map((e) => LeaderboardEntryLocal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addScoreToLeaderboard(
    String playerName,
    int score,
    int timeTaken,
    String challengeId, {
    String playerId = '',
  }) async {
    final leaderboard = await getLocalLeaderboard();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    bool samePlayer(LeaderboardEntryLocal entry) {
      if (playerId.isNotEmpty && entry.playerId.isNotEmpty) {
        return entry.playerId == playerId;
      }
      return entry.playerName == playerName;
    }

    final existingIndex = leaderboard.indexWhere(
      (e) => samePlayer(e) && e.date == today,
    );

    if (existingIndex != -1) {
      final entry = leaderboard[existingIndex];
      if (!entry.completedChallenges.contains(challengeId)) {
        final updatedChallenges =
            List<String>.from(entry.completedChallenges)..add(challengeId);
        leaderboard[existingIndex] = LeaderboardEntryLocal(
          playerId: entry.playerId.isNotEmpty ? entry.playerId : playerId,
          playerName: playerName,
          score: entry.score + score,
          timeTaken: entry.timeTaken + timeTaken,
          date: today,
          completedChallenges: updatedChallenges,
        );
      }
    } else {
      leaderboard.add(LeaderboardEntryLocal(
        playerId: playerId,
        playerName: playerName,
        score: score,
        timeTaken: timeTaken,
        date: today,
        completedChallenges: [challengeId],
      ));
    }

    leaderboard.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.timeTaken.compareTo(b.timeTaken);
    });

    final trimmed = leaderboard.take(50).toList();
    await _box.put(
      _keyLeaderboard,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

}

// ── Data Models ────────────────────────────────────────────────
class LocalStreakData {
  final int currentStreak;
  final int longestStreak;
  final String? lastPlayedDate;

  LocalStreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastPlayedDate,
  });

  factory LocalStreakData.fromJson(Map<String, dynamic> json) {
    return LocalStreakData(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastPlayedDate: json['lastPlayedDate'],
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastPlayedDate': lastPlayedDate,
      };
}

class PersonalBestData {
  final int bestScore;
  final int totalQuestions;
  final int percentage;

  PersonalBestData({
    required this.bestScore,
    required this.totalQuestions,
    required this.percentage,
  });

  factory PersonalBestData.fromJson(Map<String, dynamic> json) {
    return PersonalBestData(
      bestScore: json['bestScore'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      percentage: json['percentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'bestScore': bestScore,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
      };
}

class LeaderboardEntryLocal {
  final String playerId;
  final String playerName;
  final int score;
  final int timeTaken;
  final String date;
  final List<String> completedChallenges;

  LeaderboardEntryLocal({
    required this.playerName,
    required this.score,
    required this.timeTaken,
    required this.date,
    this.playerId = '',
    this.completedChallenges = const [],
  });

  factory LeaderboardEntryLocal.fromJson(Map<String, dynamic> json) {
    final rawList = json['completedChallenges'] as List?;
    return LeaderboardEntryLocal(
      playerId: json['playerId']?.toString() ?? json['uid']?.toString() ?? '',
      playerName: json['playerName'] ?? 'Unknown',
      score: json['score'] ?? 0,
      timeTaken: json['timeTaken'] ?? 0,
      date: json['date'] ?? '',
      completedChallenges: rawList != null ? List<String>.from(rawList) : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'score': score,
        'timeTaken': timeTaken,
        'date': date,
        'completedChallenges': completedChallenges,
      };
}
