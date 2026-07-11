// lib/core/services/quiz/quiz_generator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/firestore_models.dart';
import '../../../data/local_quiz_data.dart';
import 'quiz_timing_manager.dart';

class QuizGenerator {
  QuizGenerator._();
  static final QuizGenerator instance = QuizGenerator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _lastQuizDateKey = 'last_quiz_date';

  Future<void> init() async {}

  Future<QuizModel?> prepareDailyQuiz(String examMode) async {
    QuizTimingManager.instance.ensureTimingFresh();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final existingQuiz = await _db
          .collection('quizzes')
          .doc('${today}_$examMode')
          .get()
          .timeout(const Duration(seconds: 8));
      if (existingQuiz.exists) {
        return await _fetchQuiz(examMode, today);
      }
    } catch (_) {}

    final localQuiz = await _createDailyQuizFromLocal(examMode, today);
    if (localQuiz != null) {
      return localQuiz;
    }

    try {
      final practiceQuiz = await _createDailyQuizFromPractice(examMode, today);
      if (practiceQuiz != null) {
        return practiceQuiz;
      }
    } catch (_) {}

    return null;
  }

  Future<QuizModel?> _createDailyQuizFromLocal(String examMode, String date) async {
    try {
      final availableQuestions = _getLocalFallbackQuestions(examMode);
      if (availableQuestions.isEmpty) return null;

      final excludedIds = await _getRecentlySeenQuestionIds(5);
      var filteredQuestions =
          availableQuestions.where((q) => !excludedIds.contains(q.id)).toList();

      if (filteredQuestions.length < 10) {
        filteredQuestions = availableQuestions;
      }

      filteredQuestions.shuffle();
      final selectedQuestions = filteredQuestions.take(10).toList();

      final orderedQuestions = <QuestionModel>[];
      for (int i = 0; i < selectedQuestions.length; i++) {
        orderedQuestions.add(QuestionModel(
          id: selectedQuestions[i].id,
          text: selectedQuestions[i].text,
          options: selectedQuestions[i].options,
          correctIndex: selectedQuestions[i].correctIndex,
          explanation: selectedQuestions[i].explanation,
          category: selectedQuestions[i].category,
          difficulty: selectedQuestions[i].difficulty,
          examTags: selectedQuestions[i].examTags,
          order: i,
        ));
      }

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

  Future<QuizModel?> _fetchQuiz(String examMode, String date) async {
    try {
      final quizDoc = await _db.collection('quizzes').doc('${date}_$examMode').get();
      if (!quizDoc.exists) return null;

      final questionsSnapshot = await _db
          .collection('quizzes')
          .doc('${date}_$examMode')
          .collection('questions')
          .orderBy('order')
          .get();

      if (questionsSnapshot.docs.isEmpty) return null;

      final questions = questionsSnapshot.docs
          .map((doc) => QuestionModel.fromFirestore(doc))
          .toList();

      final data = quizDoc.data()!;
      return QuizModel(
        quizId: data['quiz_id'] ?? '${date}_$examMode',
        date: data['date'] ?? date,
        examMode: data['exam_mode'] ?? examMode,
        status: data['status'] ?? 'active',
        questionCount: questions.length,
        createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiresAt: (data['expires_at'] as Timestamp?)?.toDate() ??
            DateTime.now().add(const Duration(days: 1)),
        totalAttempts: data['total_attempts'] ?? 0,
        questions: questions,
      );
    } catch (_) {
      return null;
    }
  }

  Future<QuizModel?> _createDailyQuizFromPractice(String examMode, String date) async {
    try {
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

      if (availableQuestions.isEmpty) {
        availableQuestions = _getLocalFallbackQuestions(examMode);
      }

      if (availableQuestions.isEmpty) return null;

      final excludedIds = await _getRecentlySeenQuestionIds(5);
      var filteredQuestions =
          availableQuestions.where((q) => !excludedIds.contains(q.id)).toList();

      if (filteredQuestions.length < 10) {
        filteredQuestions = availableQuestions;
      }

      filteredQuestions.shuffle();
      final selectedQuestions = filteredQuestions.take(10).toList();

      final orderedQuestions = <QuestionModel>[];
      for (int i = 0; i < selectedQuestions.length; i++) {
        orderedQuestions.add(QuestionModel(
          id: selectedQuestions[i].id,
          text: selectedQuestions[i].text,
          options: selectedQuestions[i].options,
          correctIndex: selectedQuestions[i].correctIndex,
          explanation: selectedQuestions[i].explanation,
          category: selectedQuestions[i].category,
          difficulty: selectedQuestions[i].difficulty,
          examTags: selectedQuestions[i].examTags,
          order: i,
        ));
      }

      await _saveDailyQuiz(examMode, date, orderedQuestions);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastQuizDateKey, date);

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

  Future<void> _saveDailyQuiz(String examMode, String date, List<QuestionModel> questions) async {
    final quizRef = _db.collection('quizzes').doc('${date}_$examMode');
    final now = DateTime.now();

    await quizRef.set({
      'quiz_id': '${date}_$examMode',
      'date': date,
      'exam_mode': examMode,
      'status': 'active',
      'question_count': questions.length,
      'created_at': Timestamp.fromDate(now),
      'expires_at': Timestamp.fromDate(now.add(const Duration(days: 1))),
      'total_attempts': 0,
    });

    final batch = _db.batch();
    for (final question in questions) {
      final qRef = quizRef.collection('questions').doc(question.id);
      batch.set(qRef, question.toFirestore());
    }
    await batch.commit();
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

  Future<Set<String>> _getRecentlySeenQuestionIds(int count) async {
    final seenIds = <String>{};
    try {
      final now = DateTime.now();
      for (int i = 0; i < count; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final quizDoc = await _db.collection('quizzes').doc('${dateStr}_GENERAL').get();
        if (quizDoc.exists) {
          final questionsSnapshot = await _db
              .collection('quizzes')
              .doc('${dateStr}_GENERAL')
              .collection('questions')
              .get();

          for (final doc in questionsSnapshot.docs) {
            seenIds.add(doc.id);
          }
        }
      }
    } catch (_) {}
    return seenIds;
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
