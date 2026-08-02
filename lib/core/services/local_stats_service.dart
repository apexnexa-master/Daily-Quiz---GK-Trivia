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
      return _getDemoLeaderboard();
    }
    try {
      final list = jsonDecode(data) as List;
      final parsed = list
          .map((e) => LeaderboardEntryLocal.fromJson(e as Map<String, dynamic>))
          .toList();
      // Check if Vikram R is recorded with 9 points today (our new dataset signature). If not, force a database reset!
      final hasNewSeeding = parsed.any((e) => e.playerName == 'Vikram R' && e.score == 9);
      if (!hasNewSeeding) {
        final newDemo = _getDemoLeaderboard();
        await _box.put(_keyLeaderboard, jsonEncode(newDemo.map((e) => e.toJson()).toList()));
        return newDemo;
      }
      return parsed;
    } catch (_) {
      return _getDemoLeaderboard();
    }
  }

  Future<void> addScoreToLeaderboard(
      String playerName, int score, int timeTaken, String challengeId) async {
    final leaderboard = await getLocalLeaderboard();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if player already has entry today
    final existingIndex = leaderboard
        .indexWhere((e) => e.playerName == playerName && e.date == today);

    if (existingIndex != -1) {
      final entry = leaderboard[existingIndex];
      // Only add to score if this challenge hasn't been completed yet today
      if (!entry.completedChallenges.contains(challengeId)) {
        final updatedChallenges = List<String>.from(entry.completedChallenges)..add(challengeId);
        leaderboard[existingIndex] = LeaderboardEntryLocal(
          playerName: playerName,
          score: entry.score + score,
          timeTaken: entry.timeTaken + timeTaken,
          date: today,
          completedChallenges: updatedChallenges,
        );
      }
    } else {
      // Add new entry
      leaderboard.add(LeaderboardEntryLocal(
        playerName: playerName,
        score: score,
        timeTaken: timeTaken,
        date: today,
        completedChallenges: [challengeId],
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
    final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    final twoDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 2)));
    final threeDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 3)));
    final fourDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 4)));
    final fiveDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 5)));
    final sixDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 6)));
    final nineDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 9)));
    final twelveDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 12)));

    return [
      // Today entries (small scores, Vikram R 1st, Amit K 3rd, Rahim Sk 4th)
      LeaderboardEntryLocal(playerName: 'Vikram R', score: 220, timeTaken: 150, date: today, completedChallenges: ['gk_challenge', 'arrow_puzzle']),
      LeaderboardEntryLocal(playerName: 'Priya M', score: 190, timeTaken: 170, date: today, completedChallenges: ['gk_challenge', 'arrow_puzzle']),
      LeaderboardEntryLocal(playerName: 'Amit K', score: 160, timeTaken: 180, date: today, completedChallenges: ['gk_challenge', 'arrow_puzzle']),
      LeaderboardEntryLocal(playerName: 'Rahim Sk', score: 130, timeTaken: 190, date: today, completedChallenges: ['gk_challenge', 'arrow_puzzle']),
      LeaderboardEntryLocal(playerName: 'Sneha D', score: 100, timeTaken: 200, date: today, completedChallenges: ['gk_challenge']),

      // Yesterday/This Week entries (To sum up to > 10 distinct people with little big numbers)
      LeaderboardEntryLocal(playerName: 'Vikram R', score: 210, timeTaken: 160, date: yesterday),
      LeaderboardEntryLocal(playerName: 'Priya M', score: 190, timeTaken: 180, date: yesterday),
      LeaderboardEntryLocal(playerName: 'Amit K', score: 175, timeTaken: 210, date: threeDaysAgo),
      LeaderboardEntryLocal(playerName: 'Rahim Sk', score: 160, timeTaken: 220, date: threeDaysAgo),
      LeaderboardEntryLocal(playerName: 'Sneha D', score: 140, timeTaken: 230, date: fourDaysAgo),
      LeaderboardEntryLocal(playerName: 'Anita S', score: 120, timeTaken: 240, date: yesterday),
      LeaderboardEntryLocal(playerName: 'Ravi T', score: 105, timeTaken: 250, date: twoDaysAgo),
      LeaderboardEntryLocal(playerName: 'Meena K', score: 90, timeTaken: 200, date: threeDaysAgo),
      LeaderboardEntryLocal(playerName: 'Vikram S', score: 75, timeTaken: 210, date: fourDaysAgo),
      LeaderboardEntryLocal(playerName: 'Kabir J', score: 60, timeTaken: 220, date: fiveDaysAgo),
      LeaderboardEntryLocal(playerName: 'Neha G', score: 45, timeTaken: 230, date: sixDaysAgo),
      LeaderboardEntryLocal(playerName: 'Rohan B', score: 30, timeTaken: 240, date: sixDaysAgo),

      // Older entries (All Time only - to push Vikram R's all-time score > 500)
      LeaderboardEntryLocal(playerName: 'Vikram R', score: 300, timeTaken: 140, date: nineDaysAgo),
      LeaderboardEntryLocal(playerName: 'Priya M', score: 250, timeTaken: 160, date: nineDaysAgo),
      LeaderboardEntryLocal(playerName: 'Amit K', score: 200, timeTaken: 190, date: twelveDaysAgo),
      LeaderboardEntryLocal(playerName: 'Rahim Sk', score: 180, timeTaken: 200, date: twelveDaysAgo),
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
  final List<String> completedChallenges;

  LeaderboardEntryLocal({
    required this.playerName,
    required this.score,
    required this.timeTaken,
    required this.date,
    this.completedChallenges = const [],
  });

  factory LeaderboardEntryLocal.fromJson(Map<String, dynamic> json) {
    final rawList = json['completedChallenges'] as List?;
    return LeaderboardEntryLocal(
      playerName: json['playerName'] ?? 'Unknown',
      score: json['score'] ?? 0,
      timeTaken: json['timeTaken'] ?? 0,
      date: json['date'] ?? '',
      completedChallenges: rawList != null ? List<String>.from(rawList) : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'score': score,
        'timeTaken': timeTaken,
        'date': date,
        'completedChallenges': completedChallenges,
      };
}
