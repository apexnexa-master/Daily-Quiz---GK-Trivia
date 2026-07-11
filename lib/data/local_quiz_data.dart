// lib/data/local_quiz_data.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'models/firestore_models.dart';

class LocalQuizData {
  LocalQuizData._();

  static const int _questionsPerQuiz = 10;

  static final List<QuestionModel> _allQuestions = [];
  static final Map<String, List<QuestionModel>> _questionsByMode = {
    'GENERAL': [],
    'WBPSC': [],
    'SSC': [],
    'UPSC': [],
    'BANK': [],
  };

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    if (_initialized) return;

    final categories = [
      'geography', 'science', 'history', 'sports', 'economy', 'current_affairs',
      'west_bengal_history', 'west_bengal', 'west_bengal_polity', 'west_bengal_culture',
      'west_bengal_geography', 'west_bengal_economy', 'english', 'mathematics',
      'general_awareness', 'reasoning', 'general_science', 'polity', 'environment',
      'science_and_technology', 'banking_awareness'
    ];

    _allQuestions.clear();
    for (final key in _questionsByMode.keys) {
      _questionsByMode[key]!.clear();
    }

    for (final category in categories) {
      try {
        final jsonStr = await rootBundle.loadString('assets/questions/$category.json');
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        for (final item in jsonList) {
          final q = QuestionModel(
            id: item['id'] ?? '',
            text: Map<String, String>.from(item['text'] ?? {}),
            options: (item['options'] as Map).map(
              (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
            ),
            correctIndex: item['correctIndex'] ?? 0,
            explanation: Map<String, String>.from(item['explanation'] ?? {}),
            category: item['category'] ?? 'General Knowledge',
            difficulty: item['difficulty'] ?? 'medium',
            examTags: List<String>.from(item['examTags'] ?? []),
            order: item['order'] ?? 0,
          );
          _allQuestions.add(q);

          for (final tag in q.examTags) {
            if (_questionsByMode.containsKey(tag)) {
              _questionsByMode[tag]!.add(q);
            }
          }
        }
      } catch (e) {
        // Fallback or ignore missing category
      }
    }

    _initialized = true;
  }

  static int get questionCountPerMode => _questionsByMode['GENERAL']?.length ?? 0;

  static List<String> getQuestionIds(String examMode) {
    final questions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];
    return questions.map((q) => q.id).toList();
  }

  static QuizModel? getQuizForMode(
    String examMode, {
    List<String>? excludeIds,
    String? difficulty,
    bool shuffleOptions = true,
  }) {
    var allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];

    if (allQuestions.isEmpty) return null;

    if (excludeIds != null && excludeIds.isNotEmpty) {
      allQuestions = allQuestions.where((q) => !excludeIds.contains(q.id)).toList();
    }

    if (difficulty != null) {
      allQuestions = allQuestions.where((q) => q.difficulty == difficulty).toList();
    }

    if (allQuestions.isEmpty) {
      allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];
    }

    final shuffledQuestions = List<QuestionModel>.from(allQuestions)..shuffle(Random());

    final selectedQuestions = shuffledQuestions.length > _questionsPerQuiz
        ? shuffledQuestions.sublist(0, _questionsPerQuiz)
        : shuffledQuestions;

    final questionsWithShuffledOptions = shuffleOptions
        ? selectedQuestions.map((q) => q.shuffleOptions()).toList()
        : selectedQuestions;

    final now = DateTime.now();
    return QuizModel(
      quizId: 'local_${examMode}_${now.millisecondsSinceEpoch}',
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      examMode: examMode,
      status: 'active',
      questionCount: questionsWithShuffledOptions.length,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 1)),
      totalAttempts: 0,
      questions: questionsWithShuffledOptions,
    );
  }

  static QuizModel? getPracticeQuiz(String examMode, int questionCount, {String? difficulty}) {
    var allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];

    if (allQuestions.isEmpty) return null;

    if (difficulty != null && difficulty.toLowerCase() != 'all') {
      allQuestions = allQuestions.where((q) => q.difficulty.toLowerCase() == difficulty.toLowerCase()).toList();
    }

    if (allQuestions.isEmpty) {
      allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];
    }

    final shuffledQuestions = List<QuestionModel>.from(allQuestions)..shuffle(Random());

    final selectedQuestions = shuffledQuestions.length > questionCount
        ? shuffledQuestions.sublist(0, questionCount)
        : shuffledQuestions;

    final questionsWithShuffledOptions = selectedQuestions.map((q) => q.shuffleOptions()).toList();

    final now = DateTime.now();
    return QuizModel(
      quizId: 'practice_${examMode}_${now.millisecondsSinceEpoch}',
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      examMode: examMode,
      status: 'active',
      questionCount: questionsWithShuffledOptions.length,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 1)),
      totalAttempts: 0,
      questions: questionsWithShuffledOptions,
    );
  }

  static List<QuestionModel> getAllQuestionsForMode(String examMode) {
    final allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];
    return List<QuestionModel>.from(allQuestions)..shuffle(Random());
  }
}
