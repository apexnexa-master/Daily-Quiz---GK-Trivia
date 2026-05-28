// lib/core/services/question_tracking_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class QuestionTrackingService {
  QuestionTrackingService._();
  static final QuestionTrackingService instance = QuestionTrackingService._();

  static const String _boxName = 'question_tracking';
  static const String _keyAnsweredQuestions = 'answered_questions';
  static const String _keyPerModeStats = 'mode_stats';
  static const String _keyAchievements = 'achievements';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Map<String, List<String>> getAnsweredQuestions() {
    final data = _box.get(_keyAnsweredQuestions);
    if (data == null) return {};
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, List<String>.from(v)));
    } catch (_) {
      return {};
    }
  }

  Future<void> markQuestionsAnswered(
      String mode, List<String> questionIds) async {
    final answered = getAnsweredQuestions();
    final modeQuestions = answered[mode] ?? [];
    for (final id in questionIds) {
      if (!modeQuestions.contains(id)) {
        modeQuestions.add(id);
      }
    }
    answered[mode] = modeQuestions;
    await _box.put(_keyAnsweredQuestions, jsonEncode(answered));
  }

  Future<void> resetAnsweredQuestions(String mode) async {
    final answered = getAnsweredQuestions();
    answered[mode] = [];
    await _box.put(_keyAnsweredQuestions, jsonEncode(answered));
  }

  List<String> getUnansweredQuestions(
      String mode, List<String> allQuestionIds) {
    final answered = getAnsweredQuestions();
    final modeQuestions = answered[mode] ?? [];
    return allQuestionIds.where((id) => !modeQuestions.contains(id)).toList();
  }

  bool hasUnansweredQuestions(String mode, List<String> allQuestionIds) {
    return getUnansweredQuestions(mode, allQuestionIds).isNotEmpty;
  }

  Future<ModeStats> getModeStats(String mode) async {
    final data = _box.get('${_keyPerModeStats}_$mode');
    if (data == null) {
      return ModeStats(
        mode: mode,
        quizzesPlayed: 0,
        totalCorrect: 0,
        totalQuestions: 0,
        bestScore: 0,
        averageScore: 0,
        totalTimeSpentSeconds: 0,
      );
    }
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return ModeStats.fromJson(map);
    } catch (_) {
      return ModeStats(
          mode: mode,
          quizzesPlayed: 0,
          totalCorrect: 0,
          totalQuestions: 0,
          bestScore: 0,
          averageScore: 0,
          totalTimeSpentSeconds: 0);
    }
  }

  Future<void> updateModeStats(
      String mode, int score, int total, int timeTaken) async {
    final stats = await getModeStats(mode);
    stats.quizzesPlayed++;
    stats.totalCorrect += score;
    stats.totalQuestions += total;
    stats.totalTimeSpentSeconds += timeTaken;
    if (score > stats.bestScore) {
      stats.bestScore = score;
    }
    stats.averageScore =
        (stats.totalCorrect / stats.totalQuestions * 100).round();
    await _box.put('${_keyPerModeStats}_$mode', jsonEncode(stats.toJson()));
  }

  Future<Map<String, ModeStats>> getAllModeStats() async {
    final modes = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];
    final statsMap = <String, ModeStats>{};
    for (final mode in modes) {
      statsMap[mode] = await getModeStats(mode);
    }
    return statsMap;
  }

  Future<List<Achievement>> getAchievements() async {
    final data = _box.get(_keyAchievements);
    if (data == null) return _defaultAchievements;
    try {
      final list = jsonDecode(data) as List;
      return list
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultAchievements;
    }
  }

  Future<void> checkAndUnlockAchievements({
    required int totalQuizzes,
    required int currentStreak,
    required int bestScore,
    required Map<String, int> modeScores,
  }) async {
    final achievements = await getAchievements();
    bool updated = false;

    for (final achievement in achievements) {
      if (achievement.isUnlocked) continue;

      bool shouldUnlock = false;
      switch (achievement.id) {
        case 'first_quiz':
          shouldUnlock = totalQuizzes >= 1;
          break;
        case 'quiz_10':
          shouldUnlock = totalQuizzes >= 10;
          break;
        case 'quiz_50':
          shouldUnlock = totalQuizzes >= 50;
          break;
        case 'quiz_100':
          shouldUnlock = totalQuizzes >= 100;
          break;
        case 'streak_3':
          shouldUnlock = currentStreak >= 3;
          break;
        case 'streak_7':
          shouldUnlock = currentStreak >= 7;
          break;
        case 'streak_30':
          shouldUnlock = currentStreak >= 30;
          break;
        case 'perfect_score':
          shouldUnlock = bestScore >= 100;
          break;
        case 'all_modes':
          shouldUnlock = modeScores.keys.length >= 5;
          break;
        case 'general_master':
          shouldUnlock = (modeScores['GENERAL'] ?? 0) >= 80;
          break;
        case 'wbpsc_aspirant':
          shouldUnlock = (modeScores['WBPSC'] ?? 0) >= 70;
          break;
      }

      if (shouldUnlock) {
        achievement.isUnlocked = true;
        achievement.unlockedAt = DateTime.now();
        updated = true;
      }
    }

    if (updated) {
      await _box.put(_keyAchievements,
          jsonEncode(achievements.map((a) => a.toJson()).toList()));
    }
  }

  static final List<Achievement> _defaultAchievements = [
    Achievement(
        id: 'first_quiz',
        title: 'First Steps',
        description: 'Complete your first quiz',
        icon: '🎯',
        isUnlocked: false),
    Achievement(
        id: 'quiz_10',
        title: 'Getting Started',
        description: 'Complete 10 quizzes',
        icon: '📚',
        isUnlocked: false),
    Achievement(
        id: 'quiz_50',
        title: 'Quiz Enthusiast',
        description: 'Complete 50 quizzes',
        icon: '🏅',
        isUnlocked: false),
    Achievement(
        id: 'quiz_100',
        title: 'Quiz Master',
        description: 'Complete 100 quizzes',
        icon: '👑',
        isUnlocked: false),
    Achievement(
        id: 'streak_3',
        title: 'On Fire',
        description: 'Maintain a 3-day streak',
        icon: '🔥',
        isUnlocked: false),
    Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        icon: '⚡',
        isUnlocked: false),
    Achievement(
        id: 'streak_30',
        title: 'Monthly Champion',
        description: 'Maintain a 30-day streak',
        icon: '🌟',
        isUnlocked: false),
    Achievement(
        id: 'perfect_score',
        title: 'Perfectionist',
        description: 'Score 100% on any quiz',
        icon: '💯',
        isUnlocked: false),
    Achievement(
        id: 'all_modes',
        title: 'Versatile Learner',
        description: 'Attempt all exam modes',
        icon: '🎓',
        isUnlocked: false),
    Achievement(
        id: 'general_master',
        title: 'GK Expert',
        description: 'Score 80%+ in General Knowledge',
        icon: '🧠',
        isUnlocked: false),
    Achievement(
        id: 'wbpsc_aspirant',
        title: 'WBPSC Aspirant',
        description: 'Score 70%+ in WBPSC mode',
        icon: '🏛️',
        isUnlocked: false),
  ];
}

class ModeStats {
  final String mode;
  int quizzesPlayed;
  int totalCorrect;
  int totalQuestions;
  int bestScore;
  int averageScore;
  int totalTimeSpentSeconds;

  ModeStats({
    required this.mode,
    required this.quizzesPlayed,
    required this.totalCorrect,
    required this.totalQuestions,
    required this.bestScore,
    required this.averageScore,
    required this.totalTimeSpentSeconds,
  });

  factory ModeStats.fromJson(Map<String, dynamic> json) {
    return ModeStats(
      mode: json['mode'] ?? '',
      quizzesPlayed: json['quizzesPlayed'] ?? 0,
      totalCorrect: json['totalCorrect'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      bestScore: json['bestScore'] ?? 0,
      averageScore: json['averageScore'] ?? 0,
      totalTimeSpentSeconds: json['totalTimeSpentSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'quizzesPlayed': quizzesPlayed,
        'totalCorrect': totalCorrect,
        'totalQuestions': totalQuestions,
        'bestScore': bestScore,
        'averageScore': averageScore,
        'totalTimeSpentSeconds': totalTimeSpentSeconds,
      };

  String get formattedTime {
    final hours = totalTimeSpentSeconds ~/ 3600;
    final minutes = (totalTimeSpentSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  bool isUnlocked;
  DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🏆',
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };
}
