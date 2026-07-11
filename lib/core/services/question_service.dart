// lib/core/services/question_service.dart
// Store and fetch questions from Firebase Firestore with local fallback

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/firestore_models.dart';
import '../../data/local_quiz_data.dart';

class QuestionService {
  static final QuestionService instance = QuestionService._();
  QuestionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch questions from Firestore for a specific exam mode and date
  Future<List<QuestionModel>> fetchQuestions({
    required String examMode,
    required String date,
  }) async {
    try {
      // Try to fetch from Firestore first
      final quizDoc =
          await _db.collection('quizzes').doc('${date}_$examMode').get();

      if (quizDoc.exists) {
        final questionsSnapshot = await _db
            .collection('quizzes')
            .doc('${date}_$examMode')
            .collection('questions')
            .orderBy('order')
            .get();

        if (questionsSnapshot.docs.isNotEmpty) {
          return questionsSnapshot.docs
              .map((doc) => QuestionModel.fromFirestore(doc))
              .toList();
        }
      }

      // Fallback to local questions if Firestore has no questions
      return _getLocalQuestions(examMode);
    } catch (e) {
      // On any error, fall back to local
      return _getLocalQuestions(examMode);
    }
  }

  List<QuestionModel> _getLocalQuestions(String examMode) {
    return LocalQuizData.getAllQuestionsForMode(examMode);
  }

  // Fetch practice questions (random) with optional difficulty
  // Avoids showing questions user has recently seen
  Future<List<QuestionModel>> fetchPracticeQuestions({
    required String examMode,
    int count = 10,
    String? difficulty,
    List<String>? excludeQuestionIds,
  }) async {
    try {
      // Try to fetch from Firestore first
      final practiceDoc = await _db.collection('practice').doc(examMode).get();

      List<QuestionModel> availableQuestions = [];

      if (practiceDoc.exists) {
        final questionsData = practiceDoc.data()?['questions'] as List?;
        if (questionsData != null && questionsData.isNotEmpty) {
          availableQuestions = questionsData
              .map((e) => _questionModelFromMap(e as Map<String, dynamic>))
              .toList();
        }
      }

      // Fallback to local if no questions in Firestore
      if (availableQuestions.isEmpty) {
        availableQuestions = LocalQuizData.getAllQuestionsForMode(examMode);
      }

      if (availableQuestions.isEmpty) {
        return [];
      }

      // Filter by difficulty if specified
      if (difficulty != null) {
        final filtered = availableQuestions
            .where((q) => q.difficulty == difficulty)
            .toList();
        if (filtered.isNotEmpty) {
          availableQuestions = filtered;
        }
      }

      // Exclude recently seen questions
      if (excludeQuestionIds != null && excludeQuestionIds.isNotEmpty) {
        availableQuestions = availableQuestions
            .where((q) => !excludeQuestionIds.contains(q.id))
            .toList();
      }

      // Shuffle and return requested count
      availableQuestions.shuffle();
      return availableQuestions.take(count).toList();
    } catch (e) {
      // Fallback to local data on error
      var questions = LocalQuizData.getAllQuestionsForMode(examMode);

      if (difficulty != null) {
        questions = questions.where((q) => q.difficulty == difficulty).toList();
      }

      if (excludeQuestionIds != null && excludeQuestionIds.isNotEmpty) {
        questions =
            questions.where((q) => !excludeQuestionIds.contains(q.id)).toList();
      }

      questions.shuffle();
      return questions.take(count).toList();
    }
  }

  QuestionModel _questionModelFromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] ?? '',
      text: Map<String, String>.from(map['text'] ?? {}),
      options: (map['options'] as Map?)
              ?.map((k, v) => MapEntry(k, List<String>.from(v ?? []))) ??
          {},
      correctIndex: map['correct_index'] ?? 0,
      explanation: Map<String, String>.from(map['explanation'] ?? {}),
      category: map['category'] ?? 'General',
      difficulty: map['difficulty'] ?? 'medium',
      examTags: List<String>.from(map['exam_tags'] ?? []),
      order: map['order'] ?? 0,
    );
  }

  // Get total question count in Firestore for a mode
  Future<int> getQuestionCount(String examMode) async {
    try {
      final snapshot = await _db
          .collectionGroup('questions')
          .where('exam_tags', arrayContains: examMode)
          .get();
      return snapshot.size;
    } catch (e) {
      return LocalQuizData.getAllQuestionsForMode(examMode).length;
    }
  }

  // Admin: Upload questions to Firestore (for daily quiz)
  Future<void> uploadQuestions({
    required String examMode,
    required List<QuestionModel> questions,
    required String date,
  }) async {
    final quizRef = _db.collection('quizzes').doc('${date}_$examMode');

    await quizRef.set({
      'quiz_id': '${date}_$examMode',
      'date': date,
      'exam_mode': examMode,
      'status': 'active',
      'question_count': questions.length,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': DateTime.now().add(const Duration(days: 1)),
    });

    final batch = _db.batch();
    for (final question in questions) {
      final qRef = quizRef.collection('questions').doc(question.id);
      batch.set(qRef, question.toFirestore());
    }
    await batch.commit();
  }

  // Admin: Upload practice questions to Firestore
  Future<void> uploadPracticeQuestions({
    required String examMode,
    required List<QuestionModel> questions,
  }) async {
    final practiceRef = _db.collection('practice').doc(examMode);

    final doc = await practiceRef.get();
    final existingList = doc.exists
        ? (doc.data()?['questions'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];

    for (final q in questions) {
      existingList.add(q.toFirestore());
    }

    await practiceRef.set({
      'exam_mode': examMode,
      'questions': existingList,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Get available exam modes from Firestore
  Future<List<String>> getAvailableExamModes() async {
    try {
      final snapshot = await _db.collection('quizzes').get();
      final modes = <String>{};
      for (final doc in snapshot.docs) {
        final mode = doc.data()['exam_mode'] as String?;
        if (mode != null) modes.add(mode);
      }
      if (modes.isEmpty) return ['GENERAL', 'UPSC', 'BANK'];
      return modes.toList();
    } catch (e) {
      return ['GENERAL', 'UPSC', 'BANK'];
    }
  }
}
