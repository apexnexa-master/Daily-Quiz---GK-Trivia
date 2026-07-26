// lib/core/services/quiz/quiz_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../data/models/firestore_models.dart';
import '../../../data/local_quiz_data.dart';
import '../../constants/app_constants.dart';
import '../question_tracking_service.dart';
import 'quiz_timing_manager.dart';
import 'practice_quiz_service.dart';

class QuizGenerator {
  QuizGenerator._();
  static final QuizGenerator instance = QuizGenerator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init() async {}

  Future<QuizModel?> prepareDailyQuiz(String examMode) async {
    QuizTimingManager.instance.ensureTimingFresh();
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final cacheKey = 'daily_quiz_${today}_$examMode';

    // Step 1: Check Hive cache
    final box = await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
    final cachedJson = box.get(cacheKey);
    if (cachedJson != null) {
      try {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        return _deserializeQuizFromMap(map);
      } catch (_) {
        // Cache corrupted - proceed to network/generation
      }
    }

    // Step 2: Check internet connection
    final online = await _isOnline();

    if (online) {
      // Step 3: Fetch today's official quiz from Firestore
      final officialQuiz = await _fetchOfficialQuizFromFirestore(examMode, today);
      if (officialQuiz != null) {
        // Randomize option order for each question
        final randomizedQuestions = officialQuiz.questions.map((q) => q.shuffleOptions()).toList();
        final finalQuiz = officialQuiz.copyWithQuestions(randomizedQuestions);
        
        // Cache it locally with type "official"
        final quizMap = _serializeQuizToMap(finalQuiz, type: 'official');
        await box.put(cacheKey, jsonEncode(quizMap));
        return finalQuiz;
      }
    }

    // Step 4: Generate local daily quiz if offline or official quiz does not exist
    final generatedQuiz = await _generateLocalDailyQuiz(examMode, today);
    if (generatedQuiz != null) {
      // Cache it locally with type "generated"
      final quizMap = _serializeQuizToMap(generatedQuiz, type: 'generated');
      await box.put(cacheKey, jsonEncode(quizMap));
      return generatedQuiz;
    }

    return null;
  }

  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('clients3.google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<QuizModel?> _fetchOfficialQuizFromFirestore(String examMode, String date) async {
    try {
      final doc = await _db.collection('quizzes').doc('${date}_$examMode').get().timeout(const Duration(seconds: 6));
      if (!doc.exists) return null;

      final questionsSnapshot = await _db
          .collection('quizzes')
          .doc('${date}_$examMode')
          .collection('questions')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 6));

      if (questionsSnapshot.docs.isEmpty) return null;

      final questions = questionsSnapshot.docs
          .map((d) => QuestionModel.fromFirestore(d))
          .toList();

      final data = doc.data()!;
      final now = DateTime.now();
      return QuizModel(
        quizId: data['quiz_id'] ?? '${date}_$examMode',
        date: data['date'] ?? date,
        examMode: data['exam_mode'] ?? examMode,
        status: data['status'] ?? 'active',
        questionCount: questions.length,
        createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? now,
        expiresAt: (data['expires_at'] as Timestamp?)?.toDate() ?? now.add(const Duration(days: 1)),
        totalAttempts: data['total_attempts'] ?? 0,
        questions: questions,
      );
    } catch (_) {
      return null;
    }
  }

  Future<QuizModel?> _generateLocalDailyQuiz(String examMode, String date) async {
    try {
      final practiceBox = await Hive.openBox<String>('practice_questions_db');
      List<QuestionModel> candidates = [];

      if (practiceBox.isNotEmpty) {
        candidates = practiceBox.values.map((str) {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return _questionModelFromMap(map);
        }).toList();
      }

      if (candidates.isEmpty) {
        candidates = LocalQuizData.getAllQuestionsForMode(examMode);
      }

      if (candidates.isEmpty) {
        candidates = _getLocalFallbackQuestions(examMode);
      }

      if (candidates.isEmpty) return null;

      // Filter candidates to match generalized GENERAL mode questions
      candidates = candidates.where((q) => q.examTags.contains(examMode) || q.examTags.contains('GENERAL')).toList();
      if (candidates.isEmpty) return null;

      // Get recently seen Daily Quiz question IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recent_daily_quiz_question_ids') ?? [];

      // Get user's answered questions history
      final tracking = QuestionTrackingService.instance;
      final answeredIds = tracking.getAnsweredQuestions()[examMode] ?? [];

      // Greedy Selector to pick exactly 10 questions
      final selectedQuestions = <QuestionModel>[];
      final selectedCategories = <String, int>{};
      final selectedDifficulties = <String, int>{};

      final remainingCandidates = List<QuestionModel>.from(candidates);

      for (int slot = 0; slot < 10; slot++) {
        if (remainingCandidates.isEmpty) break;

        QuestionModel? bestCandidate;
        double bestCost = double.infinity;

        for (final q in remainingCandidates) {
          double cost = 0.0;

          // Avoid recently used Daily Quiz questions (recency penalty)
          if (recentIds.contains(q.id)) {
            final index = recentIds.indexOf(q.id);
            final recencyScore = (index + 1) / recentIds.length;
            cost += 5000.0 * recencyScore;
          }

          // Prefer unused questions
          if (answeredIds.contains(q.id)) {
            cost += 500.0;
          }

          // Prefer questions answered incorrectly in practice mode
          final stats = PracticeQuizService.instance.getQuestionStats(q.id);
          final timesWrong = stats['timesWrong'] as int? ?? 0;
          if (timesWrong > 0) {
            cost -= (timesWrong * 30.0).clamp(0.0, 300.0);
          }

          // Balance categories
          final catCount = selectedCategories[q.category] ?? 0;
          cost += catCount * 250.0;

          // Balance difficulties
          final diffCount = selectedDifficulties[q.difficulty] ?? 0;
          cost += diffCount * 200.0;

          if (cost < bestCost) {
            bestCost = cost;
            bestCandidate = q;
          }
        }

        if (bestCandidate != null) {
          selectedQuestions.add(bestCandidate);
          selectedCategories[bestCandidate.category] = (selectedCategories[bestCandidate.category] ?? 0) + 1;
          selectedDifficulties[bestCandidate.difficulty] = (selectedDifficulties[bestCandidate.difficulty] ?? 0) + 1;
          remainingCandidates.remove(bestCandidate);
        }
      }

      if (selectedQuestions.isEmpty) return null;

      // Randomize options for each question
      final randomizedQuestions = selectedQuestions.map((q) => q.shuffleOptions()).toList();

      // Update order index
      final orderedQuestions = <QuestionModel>[];
      for (int i = 0; i < randomizedQuestions.length; i++) {
        final q = randomizedQuestions[i];
        orderedQuestions.add(QuestionModel(
          id: q.id,
          text: q.text,
          options: q.options,
          correctIndex: q.correctIndex,
          explanation: q.explanation,
          category: q.category,
          difficulty: q.difficulty,
          examTags: q.examTags,
          order: i,
        ));
      }

      // Add selected IDs to recent history
      final newRecentIds = List<String>.from(recentIds);
      for (final q in orderedQuestions) {
        newRecentIds.remove(q.id);
        newRecentIds.add(q.id);
      }
      if (newRecentIds.length > 300) {
        newRecentIds.removeRange(0, newRecentIds.length - 300);
      }
      await prefs.setStringList('recent_daily_quiz_question_ids', newRecentIds);

      final now = DateTime.now();
      return QuizModel(
        quizId: '${date}_$examMode',
        date: date,
        examMode: examMode,
        status: 'active',
        questionCount: orderedQuestions.length,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 1)),
        totalAttempts: 0,
        questions: orderedQuestions,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _serializeQuizToMap(QuizModel quiz, {required String type}) {
    return {
      'quiz_id': quiz.quizId,
      'date': quiz.date,
      'exam_mode': quiz.examMode,
      'status': quiz.status,
      'question_count': quiz.questionCount,
      'created_at': quiz.createdAt.toIso8601String(),
      'expires_at': quiz.expiresAt.toIso8601String(),
      'total_attempts': quiz.totalAttempts,
      'type': type,
      'questions': quiz.questions.map((q) {
        final map = q.toFirestore();
        map['id'] = q.id;
        return map;
      }).toList(),
    };
  }

  QuizModel _deserializeQuizFromMap(Map<String, dynamic> map) {
    final questionsList = map['questions'] as List;
    final questions = questionsList.asMap().entries.map((entry) {
      final idx = entry.key;
      final qMap = Map<String, dynamic>.from(entry.value as Map);
      final id = qMap['id'] ?? 'q_$idx';
      
      Map<String, List<String>> parsedOptions = {};
      if (qMap['options'] is Map) {
        (qMap['options'] as Map).forEach((k, v) {
          if (v is List) {
            parsedOptions[k.toString()] = List<String>.from(v.map((e) => e.toString()));
          }
        });
      }

      return QuestionModel(
        id: id,
        text: Map<String, String>.from(qMap['text'] ?? {}),
        options: parsedOptions,
        correctIndex: qMap['correct_index'] ?? 0,
        explanation: Map<String, String>.from(qMap['explanation'] ?? {}),
        category: qMap['category'] ?? 'General',
        difficulty: qMap['difficulty'] ?? 'medium',
        examTags: List<String>.from(qMap['exam_tags'] ?? []),
        order: qMap['order'] ?? idx,
      );
    }).toList();

    return QuizModel(
      quizId: map['quiz_id'] ?? '',
      date: map['date'] ?? '',
      examMode: map['exam_mode'] ?? 'GENERAL',
      status: map['status'] ?? 'active',
      questionCount: map['question_count'] ?? questions.length,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(map['expires_at'] ?? DateTime.now().add(const Duration(days: 1)).toIso8601String()),
      totalAttempts: map['total_attempts'] ?? 0,
      questions: questions,
    );
  }

  QuestionModel _questionModelFromMap(Map<String, dynamic> map) {
    Map<String, List<String>> parsedOptions = {};
    if (map['options'] is Map) {
      (map['options'] as Map).forEach((k, v) {
        if (v is List) {
          parsedOptions[k.toString()] = List<String>.from(v.map((e) => e.toString()));
        }
      });
    }

    return QuestionModel(
      id: map['id'] ?? '',
      text: Map<String, String>.from(map['text'] ?? {}),
      options: parsedOptions,
      correctIndex: map['correct_index'] ?? 0,
      explanation: Map<String, String>.from(map['explanation'] ?? {}),
      category: map['category'] ?? 'General',
      difficulty: map['difficulty'] ?? 'medium',
      examTags: List<String>.from(map['exam_tags'] ?? []),
      order: map['order'] ?? 0,
    );
  }

  List<QuestionModel> _getLocalFallbackQuestions(String examMode) {
    try {
      final localQuestions = LocalQuizData.getAllQuestionsForMode(examMode);
      if (localQuestions.isNotEmpty) {
        return localQuestions;
      }
    } catch (_) {}

    return [
      QuestionModel(
        id: 'fallback_1',
        text: {
          'en': 'What is the capital of India?',
          'hi': 'भारत की राजधानी क्या है?',
          'bn': 'ভারতের রাজধানী কী?'
        },
        options: {
          'en': ['Mumbai', 'New Delhi', 'Kolkata', 'Chennai'],
          'hi': ['मुंबई', 'नई दिल्ली', 'कोलकाता', 'चेन्नई'],
          'bn': ['মুম্বাই', 'নয়া দিল্লি', 'কোলকাতা', 'চেন্নাই']
        },
        correctIndex: 1,
        explanation: {
          'en': 'New Delhi is the capital of India.',
          'hi': 'नई दिल्ली भारत की राजधानी है।',
          'bn': 'নয়া দিল্লি ভারতের রাজধানী।'
        },
        category: 'Geography',
        difficulty: 'easy',
        examTags: [examMode],
        order: 0,
      ),
      QuestionModel(
        id: 'fallback_2',
        text: {
          'en': 'Who wrote the Indian National Anthem?',
          'hi': 'भारतीय राष्ट्रगान किसने लिखा?',
          'bn': 'ভারতের জাতীয় সংগীত কে লিখেছিল?'
        },
        options: {
          'en': [
            'Rabindranath Tagore',
            'Bankim Chandra',
            'Mahatma Gandhi',
            'Jawaharlal Nehru'
          ],
          'hi': [
            'रबींद्रनाथ टैगोर',
            'बंकिम चंद्र',
            'महात्मा गांधी',
            'जवाहरलाल नेहरू'
          ],
          'bn': [
            'রবীন্দ্রনাথ ঠাকুর',
            'বঙ্কিম চন্দ্র',
            'মহাত্মা গান্ধী',
            'জওহরলাল নেহরু'
          ]
        },
        correctIndex: 0,
        explanation: {
          'en': 'Rabindranath Tagore wrote Jana Gana Mana.',
          'hi': 'रबींद्रनाथ टैगोर ने जन गण मन लिखा।',
          'bn': 'রবীন্দ্রনাথ ঠাকুর জন গণ মন লিখেছিল।'
        },
        category: 'History',
        difficulty: 'medium',
        examTags: [examMode],
        order: 1,
      ),
      QuestionModel(
        id: 'fallback_3',
        text: {
          'en': 'What is the chemical symbol for Gold?',
          'hi': 'सोने का रासायनिक प्रतीक क्या है?',
          'bn': 'সোনার রাসায়নিক প্রতীক কী?'
        },
        options: {
          'en': ['Au', 'Ag', 'Fe', 'Cu'],
          'hi': ['Au', 'Ag', 'Fe', 'Cu'],
          'bn': ['Au', 'Ag', 'Fe', 'Cu']
        },
        correctIndex: 0,
        explanation: {
          'en': 'Au comes from Latin word Aurum.',
          'hi': 'Au लैटिन शब्द Aurum से आता है।',
          'bn': 'Au ল্যাটিন শব্দ Aurum থেকে এসেছে।'
        },
        category: 'Science',
        difficulty: 'easy',
        examTags: [examMode],
        order: 2,
      ),
      QuestionModel(
        id: 'fallback_4',
        text: {
          'en': 'Which planet is known as the Red Planet?',
          'hi': 'कौन सा ग्रह लाल ग्रह के रूप में जाना जाता है?',
          'bn': 'কোন গ্রহকে লাল গ্রহ বলা হয়?'
        },
        options: {
          'en': ['Venus', 'Mars', 'Jupiter', 'Saturn'],
          'hi': ['शुक्र', 'मंगल', 'बृहस्पति', 'शनि'],
          'bn': ['শুক্র', 'মঙ্গল', 'বৃহস্পতি', 'শনি']
        },
        correctIndex: 1,
        explanation: {
          'en': 'Mars appears red due to iron oxide.',
          'hi': 'मंगल लोहे ऑक्साइड के कारण लाल दिखाई देता है।',
          'bn': 'মঙ্গল আয়রন অক্সাইডের কারণে লাল দেখায়।'
        },
        category: 'Science',
        difficulty: 'easy',
        examTags: [examMode],
        order: 3,
      ),
      QuestionModel(
        id: 'fallback_5',
        text: {
          'en': 'What is the largest mammal?',
          'hi': 'सबसे बड़ा स्तनधारी क्या है?',
          'bn': 'বৃহত্তম স্তন্যপায়ী কী?'
        },
        options: {
          'en': ['Elephant', 'Blue Whale', 'Giraffe', 'Hippopotamus'],
          'hi': ['हाथी', 'नीली व्हेल', 'जिराफ', 'दरियाई घोड़ा'],
          'bn': ['হাতি', 'নীল তিমি', 'জিরাফ', 'জলহস্তী']
        },
        correctIndex: 1,
        explanation: {
          'en': 'Blue Whale is the largest mammal.',
          'hi': 'नीली व्हेल सबसे बड़ा स्तनधारी है।',
          'bn': 'নীল তিমি বৃহত্তম স্তন্যপায়ী।'
        },
        category: 'Science',
        difficulty: 'easy',
        examTags: [examMode],
        order: 4,
      ),
      QuestionModel(
        id: 'fallback_6',
        text: {
          'en': 'How many states are in India?',
          'hi': 'भारत में कितने राज्य हैं?',
          'bn': 'ভারতে কতগুলি রাজ্য আছে?'
        },
        options: {
          'en': ['26', '28', '29', '30'],
          'hi': ['26', '28', '29', '30'],
          'bn': ['২৬', '২৮', '২৯', '৩০']
        },
        correctIndex: 2,
        explanation: {
          'en': 'India has 28 states and 8 Union Territories.',
          'hi': 'भारत में 28 राज्य और 8 केंद्र शासित प्रदेश हैं।',
          'bn': 'ভারতে ২৮টি রাজ্য এবং ৮টি কেন্দ্রশাসিত অঞ্চল আছে।'
        },
        category: 'Geography',
        difficulty: 'medium',
        examTags: [examMode],
        order: 5,
      ),
      QuestionModel(
        id: 'fallback_7',
        text: {
          'en': 'Who invented the telephone?',
          'hi': 'टेलीफोन का आविष्कार किसने किया?',
          'bn': 'টেলিফোন আবিষ্কার কে করেছিল?'
        },
        options: {
          'en': [
            'Thomas Edison',
            'Alexander Graham Bell',
            'Nikola Tesla',
            'Guglielmo Marconi'
          ],
          'hi': [
            'थॉमस एडिसन',
            'एलेक्जेंडर ग्राहम बेल',
            'निकोला टेस्ला',
            'गुग्लिल्मो मार्कोनी'
          ],
          'bn': [
            'টমাস এডিসন',
            'আলেকজান্ডার গ্রাহাম বেল',
            'নিকোলা টেসলা',
            'গুগলিয়েমো মারকোনি'
          ]
        },
        correctIndex: 1,
        explanation: {
          'en': 'Alexander Graham Bell invented the telephone in 1876.',
          'hi': 'एलेक्जेंडर ग्राहम बेल ने 1876 में टेलीफोन का आविष्कार किया।',
          'bn': 'আলেকজান্ডার গ্রাহাম বেল ১৮৭৬ সালে টেলিফোন আবিষ্কার করেছিলেন।'
        },
        category: 'History',
        difficulty: 'easy',
        examTags: [examMode],
        order: 6,
      ),
      QuestionModel(
        id: 'fallback_8',
        text: {
          'en': 'What is the currency of Japan?',
          'hi': 'जापान की मुद्रा क्या है?',
          'bn': 'জাপানের মুদ্রা কী?'
        },
        options: {
          'en': ['Yuan', 'Won', 'Yen', 'Ringgit'],
          'hi': ['युआन', 'वोन', 'येन', 'रिंगित'],
          'bn': ['ইউয়ান', 'ওন', 'ইয়েন', 'রিংগিত']
        },
        correctIndex: 2,
        explanation: {
          'en': 'Yen is the currency of Japan.',
          'hi': 'येन जापान की मुद्रा है।',
          'bn': 'ইয়েন জাপানের মুদ্রা।'
        },
        category: 'Geography',
        difficulty: 'easy',
        examTags: [examMode],
        order: 7,
      ),
      QuestionModel(
        id: 'fallback_9',
        text: {
          'en': 'Which is the fastest land animal?',
          'hi': 'सबसे तेज़ जमीनी जानवर कौन सा है?',
          'bn': 'সবচেয়ে দ্রুততম স্থলজীব কোনটি?'
        },
        options: {
          'en': ['Lion', 'Cheetah', 'Leopard', 'Horse'],
          'hi': ['शेर', 'चीता', 'तेंदुआ', 'घोड़ा'],
          'bn': ['সিংহ', 'চিতা', 'বাঘ', 'ঘোড়া']
        },
        correctIndex: 1,
        explanation: {
          'en': 'Cheetah is the fastest land animal.',
          'hi': 'चीता सबसे तेज़ जमीनी जानवर है।',
          'bn': 'চিতা সবচেয়ে দ্রুততম স্থলজীব।'
        },
        category: 'Science',
        difficulty: 'easy',
        examTags: [examMode],
        order: 8,
      ),
      QuestionModel(
        id: 'fallback_10',
        text: {
          'en': 'How many days are in a leap year?',
          'hi': 'लीप वर्ष में कितने दिन होते हैं?',
          'bn': 'একটি অধিবর্ষে কতদিন থাকে?'
        },
        options: {
          'en': ['365', '366', '364', '367'],
          'hi': ['365', '366', '364', '367'],
          'bn': ['৩৬৫', '৩৬৬', '৩৬৪', '৩৬৭']
        },
        correctIndex: 1,
        explanation: {
          'en': 'A leap year has 366 days.',
          'hi': 'लीप वर्ष में 366 दिन होते हैं।',
          'bn': 'একটি অধিবর্ষে ৩৬৬ দিন থাকে।'
        },
        category: 'General',
        difficulty: 'easy',
        examTags: [examMode],
        order: 9,
      ),
    ];
  }
}
