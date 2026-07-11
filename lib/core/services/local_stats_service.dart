// lib/core/services/local_stats_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'gamification_service.dart';
import '../../data/models/firestore_models.dart';

class LocalStatsService {
  LocalStatsService._();
  static final LocalStatsService instance = LocalStatsService._();

  static const String _boxName = 'local_stats';
  static const String _keyStreak = 'streak_data';
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
    if (data == null) {
      // Return demo leaderboard data
      return _getDemoLeaderboard();
    }
    try {
      final list = jsonDecode(data) as List;
      return list
          .map((e) => LeaderboardEntryLocal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _getDemoLeaderboard();
    }
  }

  Future<void> addScoreToLeaderboard(
      String playerName, int score, int timeTaken) async {
    final leaderboard = await getLocalLeaderboard();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if player already has entry today
    final existingIndex = leaderboard
        .indexWhere((e) => e.playerName == playerName && e.date == today);

    if (existingIndex != -1) {
      // Update if new score is better
      if (score > leaderboard[existingIndex].score) {
        leaderboard[existingIndex] = LeaderboardEntryLocal(
          playerName: playerName,
          score: score,
          timeTaken: timeTaken,
          date: today,
        );
      }
    } else {
      // Add new entry
      leaderboard.add(LeaderboardEntryLocal(
        playerName: playerName,
        score: score,
        timeTaken: timeTaken,
        date: today,
      ));
    }

    // Sort by score (descending), then by time (ascending)
    leaderboard.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.timeTaken.compareTo(b.timeTaken);
    });

    // Keep only top 50
    final trimmed = leaderboard.take(50).toList();
    await _box.put(
        _keyLeaderboard, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  List<LeaderboardEntryLocal> _getDemoLeaderboard() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return [
      LeaderboardEntryLocal(
          playerName: 'Rahim Sk', score: 10, timeTaken: 180, date: today),
      LeaderboardEntryLocal(
          playerName: 'Priya M', score: 9, timeTaken: 200, date: today),
      LeaderboardEntryLocal(
          playerName: 'Amit K', score: 9, timeTaken: 240, date: today),
      LeaderboardEntryLocal(
          playerName: 'Sneha D', score: 8, timeTaken: 210, date: today),
      LeaderboardEntryLocal(
          playerName: 'Ravi T', score: 8, timeTaken: 250, date: today),
      LeaderboardEntryLocal(
          playerName: 'Anita S', score: 7, timeTaken: 190, date: today),
      LeaderboardEntryLocal(
          playerName: 'Vikram R', score: 7, timeTaken: 220, date: today),
      LeaderboardEntryLocal(
          playerName: 'Meena K', score: 6, timeTaken: 200, date: today),
    ];
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
  final String playerName;
  final int score;
  final int timeTaken;
  final String date;

  LeaderboardEntryLocal({
    required this.playerName,
    required this.score,
    required this.timeTaken,
    required this.date,
  });

  factory LeaderboardEntryLocal.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryLocal(
      playerName: json['playerName'] ?? 'Unknown',
      score: json['score'] ?? 0,
      timeTaken: json['timeTaken'] ?? 0,
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'score': score,
        'timeTaken': timeTaken,
        'date': date,
      };
}
