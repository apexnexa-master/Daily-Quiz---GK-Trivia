// lib/core/services/quiz/practice_quiz_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import '../../../data/models/firestore_models.dart';
import '../../../data/local_quiz_data.dart';

class PracticeQuizService {
  PracticeQuizService._();
  static final PracticeQuizService instance = PracticeQuizService._();

  static const String _questionsBoxName = 'practice_questions_db';
  static const String _statsBoxName = 'practice_stats_db';

  late Box<String> _questionsBox;
  late Box<String> _statsBox;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _questionsBox = await Hive.openBox<String>(_questionsBoxName);
    _statsBox = await Hive.openBox<String>(_statsBoxName);

    final resetDone = _statsBox.get('practice_quiz_v2_initialized') != null;
    if (!resetDone) {
      await _questionsBox.clear();
      await _statsBox.clear();
      await _statsBox.put('practice_quiz_v2_initialized', 'true');
    }

    if (_questionsBox.isEmpty) {
      // Load validated bundled offline questions from LocalQuizData
      await LocalQuizData.init();
      final generalQ = LocalQuizData.getAllQuestionsForMode('GENERAL');

      for (final q in generalQ) {
        await _questionsBox.put(q.id, jsonEncode(q.toFirestore()));
      }
    }
    _initialized = true;
  }

  /// Check connectivity silently
  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('clients3.google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Synchronization logic
  Future<void> syncWithFirestore() async {
    try {
      await init();
      final online = await _isOnline();
      if (!online) {
        // Skip synchronization silently if offline
        return;
      }

      // Fetch practice questions from Firestore
      // Source 1: Check the dedicated practice/GENERAL document
      final practiceDoc = await _db.collection('practice').doc('GENERAL').get().timeout(const Duration(seconds: 6));
      if (practiceDoc.exists) {
        final questionsData = practiceDoc.data()?['questions'] as List?;
        if (questionsData != null && questionsData.isNotEmpty) {
          for (final qMap in questionsData) {
            final parsedMap = Map<String, dynamic>.from(qMap as Map);
            await _syncSingleQuestion(parsedMap);
          }
        }
      }

      // Source 2: Fetch general questions directly from the questions collection
      final questionsQuery = await _db
          .collectionGroup('questions')
          .where('exam_tags', arrayContains: 'GENERAL')
          .get()
          .timeout(const Duration(seconds: 8));

      for (final doc in questionsQuery.docs) {
        final parsedMap = doc.data();
        parsedMap['id'] = doc.id; // Assign ID
        await _syncSingleQuestion(parsedMap);
      }
    } catch (_) {
      // Continue silently if synchronization fails
    }
  }

  Future<void> _syncSingleQuestion(Map<String, dynamic> data) async {
    final id = data['id'] ?? data['questionId'] ?? '';
    if (id.toString().isEmpty) return;

    // Build standard model for validation
    Map<String, List<String>> parsedOptions = {};
    if (data['options'] is Map) {
      (data['options'] as Map).forEach((k, v) {
        if (v is List) {
          parsedOptions[k.toString()] = List<String>.from(v.map((e) => e.toString()));
        }
      });
    } else if (data['options'] is List) {
      parsedOptions['en'] = List<String>.from((data['options'] as List).map((e) => e.toString()));
    }

    final serverQuestion = QuestionModel(
      id: id.toString(),
      text: Map<String, String>.from(data['text'] ?? {}),
      options: parsedOptions,
      correctIndex: data['correct_index'] ?? data['correctIndex'] ?? 0,
      explanation: Map<String, String>.from(data['explanation'] ?? {}),
      category: data['category'] ?? 'General Knowledge',
      difficulty: data['difficulty'] ?? 'medium',
      examTags: List<String>.from(data['exam_tags'] ?? data['examTags'] ?? ['GENERAL']),
      order: data['order'] ?? 0,
    );

    // Strict Validation: Ensure translations are complete and valid
    final textEn = serverQuestion.text['en']?.trim() ?? '';
    final textHi = serverQuestion.text['hi']?.trim() ?? '';
    final textBn = serverQuestion.text['bn']?.trim() ?? '';
    final optEn = serverQuestion.options['en'];
    final optHi = serverQuestion.options['hi'];
    final optBn = serverQuestion.options['bn'];

    if (textEn.isEmpty ||
        textHi.isEmpty ||
        textBn.isEmpty ||
        optEn == null || optEn.length != 4 || optEn.any((e) => e.trim().isEmpty) ||
        optHi == null || optHi.length != 4 || optHi.any((e) => e.trim().isEmpty) ||
        optBn == null || optBn.length != 4 || optBn.any((e) => e.trim().isEmpty)) {
      // Discard invalid question to prevent UI issues
      return;
    }

    final existingJson = _questionsBox.get(serverQuestion.id);
    if (existingJson == null) {
      // New question: Save it
      await _questionsBox.put(serverQuestion.id, jsonEncode(serverQuestion.toFirestore()));
    } else {
      // Check if server version is newer or updated
      final existingMap = jsonDecode(existingJson) as Map<String, dynamic>;
      final serverUpdated = data['updated_at'] ?? data['updatedAt'];
      final localUpdated = existingMap['updated_at'] ?? existingMap['updatedAt'];

      bool shouldUpdate = false;
      if (serverUpdated != null && localUpdated != null) {
        try {
          final serverTime = (serverUpdated as Timestamp).toDate();
          final localTime = DateTime.parse(localUpdated.toString());
          if (serverTime.isAfter(localTime)) shouldUpdate = true;
        } catch (_) {
          shouldUpdate = true; // Fallback to update on parse error
        }
      } else {
        // If no timestamp is provided, overwrite to keep it fresh with Firestore
        shouldUpdate = true;
      }

      if (shouldUpdate) {
        await _questionsBox.put(serverQuestion.id, jsonEncode(serverQuestion.toFirestore()));
      }
    }
  }

  /// Get tracking statistics for a question
  Map<String, dynamic> getQuestionStats(String questionId) {
    final data = _statsBox.get(questionId);
    if (data == null) {
      return {
        'questionId': questionId,
        'timesShown': 0,
        'timesCorrect': 0,
        'timesWrong': 0,
        'lastShownAt': null,
        'lastAnsweredAt': null,
        'favorite': false,
        'bookmarked': false,
      };
    }
    return Map<String, dynamic>.from(jsonDecode(data));
  }

  /// Save tracking statistics for a question
  Future<void> saveQuestionStats(String questionId, Map<String, dynamic> stats) async {
    await _statsBox.put(questionId, jsonEncode(stats));
  }

  /// Update statistics after answering
  Future<void> recordAnswer({required String questionId, required bool isCorrect}) async {
    await init();
    final stats = getQuestionStats(questionId);
    final now = DateTime.now().toIso8601String();

    stats['timesShown'] = (stats['timesShown'] as int? ?? 0) + 1;
    if (isCorrect) {
      stats['timesCorrect'] = (stats['timesCorrect'] as int? ?? 0) + 1;
    } else {
      stats['timesWrong'] = (stats['timesWrong'] as int? ?? 0) + 1;
    }
    stats['lastShownAt'] = now;
    stats['lastAnsweredAt'] = now;

    await saveQuestionStats(questionId, stats);
  }

  /// Load and select practice questions intelligently based on weighted randomization
  Future<QuizModel> fetchPracticeQuiz({
    int questionCount = 10,
    String? difficulty,
  }) async {
    await init();

    // 1. Load all questions from local database
    final List<QuestionModel> pool = [];
    for (final key in _questionsBox.keys) {
      final jsonStr = _questionsBox.get(key);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        Map<String, List<String>> parsedOptions = {};
        if (map['options'] is Map) {
          (map['options'] as Map).forEach((k, v) {
            if (v is List) {
              parsedOptions[k.toString()] = List<String>.from(v.map((e) => e.toString()));
            }
          });
        } else if (map['options'] is List) {
          parsedOptions['en'] = List<String>.from((map['options'] as List).map((e) => e.toString()));
        }

        final q = QuestionModel(
          id: map['id'] ?? key,
          text: Map<String, String>.from(map['text'] ?? {}),
          options: parsedOptions,
          correctIndex: map['correct_index'] ?? map['correctIndex'] ?? 0,
          explanation: Map<String, String>.from(map['explanation'] ?? {}),
          category: map['category'] ?? 'General Knowledge',
          difficulty: map['difficulty'] ?? 'medium',
          examTags: List<String>.from(map['exam_tags'] ?? map['examTags'] ?? ['GENERAL']),
          order: map['order'] ?? 0,
        );
        
        // Filter by GENERAL mode and difficulty if supplied
        if (q.examTags.contains('GENERAL')) {
          if (difficulty == null ||
              difficulty.toLowerCase() == 'all' ||
              q.difficulty.toLowerCase() == difficulty.toLowerCase()) {
            pool.add(q);
          }
        }
      }
    }

    // Fallback if difficulty filter yields no questions
    if (pool.isEmpty) {
      for (final key in _questionsBox.keys) {
        final jsonStr = _questionsBox.get(key);
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final q = QuestionModel(
            id: map['id'] ?? key,
            text: Map<String, String>.from(map['text'] ?? {}),
            options: (map['options'] as Map).map(
              (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
            ),
            correctIndex: map['correct_index'] ?? map['correctIndex'] ?? 0,
            explanation: Map<String, String>.from(map['explanation'] ?? {}),
            category: map['category'] ?? 'General Knowledge',
            difficulty: map['difficulty'] ?? 'medium',
            examTags: List<String>.from(map['exam_tags'] ?? map['examTags'] ?? ['GENERAL']),
            order: map['order'] ?? 0,
          );
          if (q.examTags.contains('GENERAL')) {
            pool.add(q);
          }
        }
      }
    }

    if (pool.isEmpty) {
      // Ultimate fallback: create from LocalQuizData
      final localQuiz = LocalQuizData.getPracticeQuiz('GENERAL', questionCount, difficulty: difficulty);
      if (localQuiz != null) return localQuiz;
      throw Exception('No questions available in the local database.');
    }

    // 2. Select questions intelligently using weighted randomization
    final List<QuestionModel> selectedQuestions = [];
    final List<QuestionModel> candidatePool = List.from(pool);

    final today = DateTime.now();

    while (selectedQuestions.length < questionCount && candidatePool.isNotEmpty) {
      // Calculate weights for all candidates
      final List<double> weights = [];
      double totalWeight = 0.0;

      for (final q in candidatePool) {
        final stats = getQuestionStats(q.id);
        final int timesShown = stats['timesShown'] ?? 0;
        final int timesWrong = stats['timesWrong'] ?? 0;
        final String? lastShownStr = stats['lastShownAt'];

        double weight = 30.0; // Default: Seen multiple times weight = 30

        if (timesShown == 0) {
          weight = 100.0; // Never attempted
        } else if (lastShownStr != null) {
          try {
            final lastShown = DateTime.parse(lastShownStr);
            if (lastShown.year == today.year &&
                lastShown.month == today.month &&
                lastShown.day == today.day) {
              weight = 0.0; // Seen today: Weight = 0
            } else if (timesWrong > 0) {
              weight = 80.0; // Wrong previously
            } else if (timesShown == 1) {
              weight = 60.0; // Seen once
            }
          } catch (_) {
            weight = 30.0;
          }
        } else if (timesWrong > 0) {
          weight = 80.0;
        } else if (timesShown == 1) {
          weight = 60.0;
        }

        weights.add(weight);
        totalWeight += weight;
      }

      // If all candidate weights are 0 (e.g. all seen today), reset all weights to 1.0 to allow choice
      if (totalWeight <= 0.0) {
        for (int i = 0; i < weights.length; i++) {
          weights[i] = 1.0;
        }
        totalWeight = weights.length.toDouble();
      }

      // Select a candidate using weighted random selection
      double randomVal = _random.nextDouble() * totalWeight;
      double runningSum = 0.0;
      int selectedIdx = 0;

      for (int i = 0; i < candidatePool.length; i++) {
        runningSum += weights[i];
        if (randomVal <= runningSum) {
          selectedIdx = i;
          break;
        }
      }

      final q = candidatePool[selectedIdx];
      selectedQuestions.add(q);
      candidatePool.removeAt(selectedIdx); // Prevent repetition within session
    }

    // Shuffle options for selected questions to keep it fresh
    final questionsWithShuffledOptions = selectedQuestions.map((q) => q.shuffleOptions()).toList();

    final now = DateTime.now();
    return QuizModel(
      quizId: 'practice_GENERAL_${now.millisecondsSinceEpoch}',
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      examMode: 'GENERAL',
      status: 'active',
      questionCount: questionsWithShuffledOptions.length,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 1)),
      totalAttempts: 0,
      questions: questionsWithShuffledOptions,
    );
  }
}
