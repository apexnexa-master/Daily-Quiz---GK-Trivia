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
    'UPSC': [],
    'BANK': [],
  };

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    if (_initialized) return;

    _allQuestions.clear();
    for (final key in _questionsByMode.keys) {
      _questionsByMode[key]!.clear();
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/questions/general_practice.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      for (final item in jsonList) {
        final q = QuestionModel(
          id: item['id'] ?? '',
          text: Map<String, String>.from(item['text'] ?? {}),
          options: (item['options'] as Map).map(
            (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
          ),
          correctIndex: item['correctIndex'] ?? item['correct_index'] ?? 0,
          explanation: Map<String, String>.from(item['explanation'] ?? {}),
          category: item['category'] ?? 'General Knowledge',
          difficulty: item['difficulty'] ?? 'medium',
          examTags: List<String>.from(item['examTags'] ?? item['exam_tags'] ?? []),
          order: item['order'] ?? 0,
        );

        // Strict Validation: Ensure translations are complete and valid
        final textEn = q.text['en']?.trim() ?? '';
        final textHi = q.text['hi']?.trim() ?? '';
        final textBn = q.text['bn']?.trim() ?? '';
        final optEn = q.options['en'];
        final optHi = q.options['hi'];
        final optBn = q.options['bn'];

        if (textEn.isNotEmpty &&
            textHi.isNotEmpty &&
            textBn.isNotEmpty &&
            optEn != null && optEn.length == 4 && !optEn.any((e) => e.trim().isEmpty) &&
            optHi != null && optHi.length == 4 && !optHi.any((e) => e.trim().isEmpty) &&
            optBn != null && optBn.length == 4 && !optBn.any((e) => e.trim().isEmpty)) {
          
          _allQuestions.add(q);
          for (final tag in q.examTags) {
            if (_questionsByMode.containsKey(tag)) {
              _questionsByMode[tag]!.add(q);
            }
          }
        }
      }
    } catch (e) {
      // Ignore or log error
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

  static QuizModel? getPracticeQuiz(String examMode, int questionCount, {String? difficulty, String? category}) {
    var allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL'] ?? [];

    if (allQuestions.isEmpty) return null;

    if (difficulty != null && difficulty.toLowerCase() != 'all') {
      allQuestions = allQuestions.where((q) => q.difficulty.toLowerCase() == difficulty.toLowerCase()).toList();
    }

    if (category != null && category.toLowerCase() != 'all') {
      allQuestions = allQuestions.where((q) => q.category.toLowerCase() == category.toLowerCase()).toList();
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
