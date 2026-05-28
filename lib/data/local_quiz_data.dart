// lib/data/local_quiz_data.dart
// Provides bundled offline quizzes so the app works even without Firestore data.
// These cover GENERAL, WBPSC, SSC, UPSC, BANK exam modes.
// Contains 20+ questions per mode for variety.

import 'dart:math';
import 'models/firestore_models.dart';

class LocalQuizData {
  LocalQuizData._();

  static const int _questionsPerQuiz = 10;

  static int get questionCountPerMode => _generalQuestions.length;

  static List<String> getQuestionIds(String examMode) {
    final questions =
        _questionsByMode[examMode] ?? _questionsByMode['GENERAL']!;
    return questions.map((q) => q.id).toList();
  }

  static QuizModel? getQuizForMode(
    String examMode, {
    List<String>? excludeIds,
    String? difficulty,
    bool shuffleOptions = true,
  }) {
    var allQuestions =
        _questionsByMode[examMode] ?? _questionsByMode['GENERAL']!;

    if (allQuestions.isEmpty) return null;

    if (excludeIds != null && excludeIds.isNotEmpty) {
      allQuestions =
          allQuestions.where((q) => !excludeIds.contains(q.id)).toList();
    }

    if (difficulty != null) {
      allQuestions =
          allQuestions.where((q) => q.difficulty == difficulty).toList();
    }

    if (allQuestions.isEmpty) {
      allQuestions = _questionsByMode[examMode] ?? _questionsByMode['GENERAL']!;
    }

    final shuffledQuestions = List<QuestionModel>.from(allQuestions)
      ..shuffle(Random());

    final selectedQuestions = shuffledQuestions.length > _questionsPerQuiz
        ? shuffledQuestions.sublist(0, _questionsPerQuiz)
        : shuffledQuestions;

    final questionsWithShuffledOptions = shuffleOptions
        ? selectedQuestions.map((q) => q.shuffleOptions()).toList()
        : selectedQuestions;

    final now = DateTime.now();
    return QuizModel(
      quizId: 'local_${examMode}_${now.millisecondsSinceEpoch}',
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      examMode: examMode,
      status: 'active',
      questionCount: questionsWithShuffledOptions.length,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 1)),
      totalAttempts: 0,
      questions: questionsWithShuffledOptions,
    );
  }

  static QuizModel? getPracticeQuiz(String examMode, int questionCount) {
    var allQuestions =
        _questionsByMode[examMode] ?? _questionsByMode['GENERAL']!;

    if (allQuestions.isEmpty) return null;

    final shuffledQuestions = List<QuestionModel>.from(allQuestions)
      ..shuffle(Random());

    final selectedQuestions = shuffledQuestions.length > questionCount
        ? shuffledQuestions.sublist(0, questionCount)
        : shuffledQuestions;

    final questionsWithShuffledOptions =
        selectedQuestions.map((q) => q.shuffleOptions()).toList();

    final now = DateTime.now();
    return QuizModel(
      quizId: 'practice_${examMode}_${now.millisecondsSinceEpoch}',
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
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
    final allQuestions =
        _questionsByMode[examMode] ?? _questionsByMode['GENERAL']!;
    return List<QuestionModel>.from(allQuestions)..shuffle(Random());
  }

  static const Map<String, List<QuestionModel>> _questionsByMode = {
    'GENERAL': _generalQuestions,
    'WBPSC': _wbpscQuestions,
    'SSC': _sscQuestions,
    'UPSC': _upscQuestions,
    'BANK': _bankQuestions,
  };

  // ── GENERAL ───────────────────────────────────────────────
  static const List<QuestionModel> _generalQuestions = [
    QuestionModel(
      id: 'g01',
      order: 0,
      correctIndex: 1,
      category: 'Geography',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the capital of India?',
        'hi': 'भारत की राजधानी क्या है?',
        'bn': 'ভারতের রাজধানী কোনটি?',
      },
      options: {
        'en': ['Mumbai', 'New Delhi', 'Kolkata', 'Chennai'],
        'hi': ['मुम्बई', 'नई दिल्ली', 'कोलकाता', 'चेन्नई'],
        'bn': ['মুম্বাই', 'নতুন দিল্লি', 'কলকাতা', 'চেন্নাই'],
      },
      explanation: {
        'en':
            'New Delhi has been the capital of India since 1911 when the British shifted it from Calcutta.',
        'hi': 'नई दिल्ली 1911 से भारत की राजधानी है।',
        'bn': 'নতুন দিল্লি ১৯১১ সাল থেকে ভারতের রাজধানী।',
      },
    ),
    QuestionModel(
      id: 'g02',
      order: 1,
      correctIndex: 2,
      category: 'Science',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which planet is closest to the Sun?',
        'hi': 'सूर्य के सबसे नजदीक कौन-सा ग्रह है?',
        'bn': 'সূর্যের সবচেয়ে কাছের গ্রহ কোনটি?',
      },
      options: {
        'en': ['Venus', 'Earth', 'Mercury', 'Mars'],
        'hi': ['शुक्र', 'पृथ्वी', 'बुध', 'मंगल'],
        'bn': ['শুক্র', 'পৃথিবী', 'বুধ', 'মঙ্গল'],
      },
      explanation: {
        'en':
            'Mercury is the closest planet to the Sun, orbiting at about 57.9 million km.',
        'hi': 'बुध सूर्य का सबसे निकटतम ग्रह है।',
        'bn': 'বুধ সূর্যের সবচেয়ে কাছের গ্রহ।',
      },
    ),
    QuestionModel(
      id: 'g03',
      order: 2,
      correctIndex: 0,
      category: 'History',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'In which year did India gain independence?',
        'hi': 'भारत को किस वर्ष स्वतंत्रता मिली?',
        'bn': 'ভারত কোন বছর স্বাধীনতা লাভ করে?',
      },
      options: {
        'en': ['1947', '1950', '1942', '1945'],
        'hi': ['1947', '1950', '1942', '1945'],
        'bn': ['১৯৪৭', '১৯৫০', '১৯৪২', '১৯৪৫'],
      },
      explanation: {
        'en': 'India gained independence from British rule on 15 August 1947.',
        'hi': 'भारत को 15 अगस्त 1947 को ब्रिटिश शासन से स्वतंत्रता मिली।',
        'bn': 'ভারত ১৫ আগস্ট ১৯৪৭ সালে ব্রিটিশ শাসন থেকে মুক্তি পায়।',
      },
    ),
    QuestionModel(
      id: 'g04',
      order: 3,
      correctIndex: 3,
      category: 'Sports',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'How many players are there in a cricket team?',
        'hi': 'क्रिकेट टीम में कितने खिलाड़ी होते हैं?',
        'bn': 'একটি ক্রিকেট দলে কতজন খেলোয়াড় থাকে?',
      },
      options: {
        'en': ['9', '10', '12', '11'],
        'hi': ['9', '10', '12', '11'],
        'bn': ['৯', '১০', '১২', '১১'],
      },
      explanation: {
        'en': 'A cricket team consists of 11 players.',
        'hi': 'क्रिकेट टीम में 11 खिलाड़ी होते हैं।',
        'bn': 'একটি ক্রিকেট দলে ১১ জন খেলোয়াড় থাকে।',
      },
    ),
    QuestionModel(
      id: 'g05',
      order: 4,
      correctIndex: 1,
      category: 'Science',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the chemical symbol for Gold?',
        'hi': 'सोने का रासायनिक प्रतीक क्या है?',
        'bn': 'সোনার রাসায়নিক প্রতীক কী?',
      },
      options: {
        'en': ['Go', 'Au', 'Ag', 'Gd'],
        'hi': ['Go', 'Au', 'Ag', 'Gd'],
        'bn': ['Go', 'Au', 'Ag', 'Gd'],
      },
      explanation: {
        'en': 'Au comes from the Latin word "Aurum" meaning Gold.',
        'hi': 'Au लैटिन शब्द "Aurum" से आया है जिसका अर्थ सोना है।',
        'bn': 'Au লাতিন শব্দ "Aurum" থেকে এসেছে যার অর্থ সোনা।',
      },
    ),
    QuestionModel(
      id: 'g06',
      order: 5,
      correctIndex: 2,
      category: 'Geography',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which is the largest state in India by area?',
        'hi': 'क्षेत्रफल की दृष्टि से भारत का सबसे बड़ा राज्य कौन सा है?',
        'bn': 'আয়তনে ভারতের সবচেয়ে বড় রাজ্য কোনটি?',
      },
      options: {
        'en': ['Uttar Pradesh', 'Maharashtra', 'Rajasthan', 'Madhya Pradesh'],
        'hi': ['उत्तर प्रदेश', 'महाराष्ट्र', 'राजस्थान', 'मध्य प्रदेश'],
        'bn': ['উত্তর প্রদেশ', 'মহারাষ্ট্র', 'রাজস্থান', 'মধ্যপ্রদেশ'],
      },
      explanation: {
        'en':
            'Rajasthan is the largest state in India with an area of 342,239 sq km.',
        'hi':
            'राजस्थान 342,239 वर्ग किमी क्षेत्रफल के साथ भारत का सबसे बड़ा राज्य है।',
        'bn':
            'রাজস্থান ৩,৪২,২৩৯ বর্গ কিমি আয়তন নিয়ে ভারতের সবচেয়ে বড় রাজ্য।',
      },
    ),
    QuestionModel(
      id: 'g07',
      order: 6,
      correctIndex: 0,
      category: 'History',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Who wrote the Indian National Anthem?',
        'hi': 'भारतीय राष्ट्रगान किसने लिखा?',
        'bn': 'ভারতীয় জাতীয় সংগীত কে লিখেছেন?',
      },
      options: {
        'en': [
          'Rabindranath Tagore',
          'Bankim Chandra',
          'Sarojini Naidu',
          'Mahatma Gandhi'
        ],
        'hi': [
          'रवींद्रनाथ टैगोर',
          'बंकिम चंद्र',
          'सरोजिनी नायडू',
          'महात्मा गांधी'
        ],
        'bn': [
          'রবীন্দ্রনাথ ঠাকুর',
          'বঙ্কিমচন্দ্র',
          'সরোজিনী নাইডু',
          'মহাত্মা গান্ধী'
        ],
      },
      explanation: {
        'en':
            'Jana Gana Mana was written by Rabindranath Tagore and adopted as India\'s national anthem in 1950.',
        'hi': 'जन गण मन रवींद्रनाथ टैगोर द्वारा लिखा गया था।',
        'bn':
            'জন গণ মন রবীন্দ্রনাথ ঠাকুর লিখেছিলেন এবং ১৯৫০ সালে জাতীয় সংগীত হিসেবে গৃহীত হয়।',
      },
    ),
    QuestionModel(
      id: 'g08',
      order: 7,
      correctIndex: 3,
      category: 'Science',
      difficulty: 'hard',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the speed of light in vacuum?',
        'hi': 'निर्वात में प्रकाश की गति क्या है?',
        'bn': 'শূন্যমাধ্যমে আলোর গতি কত?',
      },
      options: {
        'en': [
          '2.8 × 10⁸ m/s',
          '3.5 × 10⁸ m/s',
          '2.5 × 10⁸ m/s',
          '3 × 10⁸ m/s'
        ],
        'hi': [
          '2.8 × 10⁸ m/s',
          '3.5 × 10⁸ m/s',
          '2.5 × 10⁸ m/s',
          '3 × 10⁸ m/s'
        ],
        'bn': [
          '2.8 × 10⁸ m/s',
          '3.5 × 10⁸ m/s',
          '2.5 × 10⁸ m/s',
          '3 × 10⁸ m/s'
        ],
      },
      explanation: {
        'en':
            'The speed of light in vacuum is approximately 3 × 10⁸ m/s (299,792,458 m/s).',
        'hi': 'निर्वात में प्रकाश की गति लगभग 3 × 10⁸ m/s है।',
        'bn': 'শূন্যমাধ্যমে আলোর গতি প্রায় 3 × 10⁸ m/s।',
      },
    ),
    QuestionModel(
      id: 'g09',
      order: 8,
      correctIndex: 1,
      category: 'Economy',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'What does GDP stand for?',
        'hi': 'GDP का पूर्ण रूप क्या है?',
        'bn': 'GDP-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'General Domestic Product',
          'Gross Domestic Product',
          'Gross Development Product',
          'General Development Progress'
        ],
        'hi': [
          'जनरल डोमेस्टिक प्रोडक्ट',
          'ग्रॉस डोमेस्टिक प्रोडक्ट',
          'ग्रॉस डेवलपमेंट प्रोडक्ट',
          'जनरल डेवलपमेंट प्रोग्रेस'
        ],
        'bn': [
          'জেনারেল ডোমেস্টিক প্রোডাক্ট',
          'গ্রস ডোমেস্টিক প্রোডাক্ট',
          'গ্রস ডেভেলপমেন্ট প্রোডাক্ট',
          'জেনারেল ডেভেলপমেন্ট প্রোগ্রেস'
        ],
      },
      explanation: {
        'en':
            'GDP stands for Gross Domestic Product — the total monetary value of goods and services produced in a country.',
        'hi': 'GDP का मतलब है ग्रॉस डोमेस्टिक प्रोडक्ट।',
        'bn':
            'GDP মানে গ্রস ডোমেস্টিক প্রোডাক্ট — একটি দেশে উৎপাদিত পণ্য ও সেবার মোট মূল্য।',
      },
    ),
    QuestionModel(
      id: 'g10',
      order: 9,
      correctIndex: 2,
      category: 'Current Affairs',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which city is known as the "City of Joy"?',
        'hi': '"আনন্দের শহর" के नाम से कौन-सा शहर जाना जाता है?',
        'bn': '"আনন্দের শহর" হিসেবে কোন শহর পরিচিত?',
      },
      options: {
        'en': ['Mumbai', 'Delhi', 'Kolkata', 'Pune'],
        'hi': ['मुम्बई', 'दिल्ली', 'कोलकाता', 'पुणे'],
        'bn': ['মুম্বাই', 'দিল্লি', 'কলকাতা', 'পুনে'],
      },
      explanation: {
        'en':
            'Kolkata is known as the "City of Joy", a phrase popularized by Dominique Lapierre\'s novel of the same name.',
        'hi': 'कोलकाता को "आनंद का शहर" कहा जाता है।',
        'bn':
            'কলকাতাকে "আনন্দের শহর" বলা হয়, ডোমিনিক লাপিয়েরের উপন্যাসের নামে।',
      },
    ),
    QuestionModel(
      id: 'g11',
      order: 10,
      correctIndex: 1,
      category: 'Science',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the chemical symbol for Sodium?',
        'hi': 'सोडियम का रासायनिक प्रतीक क्या है?',
        'bn': 'সোডিয়ামের রাসায়নিক প্রতীক কী?',
      },
      options: {
        'en': ['So', 'Na', 'Sd', 'Sm'],
        'hi': ['So', 'Na', 'Sd', 'Sm'],
        'bn': ['So', 'Na', 'Sd', 'Sm'],
      },
      explanation: {
        'en': 'Na comes from the Latin word "Natrium" meaning Sodium.',
        'hi': 'Na लैटिन शब्द "Natrium" से आया है।',
        'bn': 'Na লাতিন শব্দ "Natrium" থেকে এসেছে।',
      },
    ),
    QuestionModel(
      id: 'g12',
      order: 11,
      correctIndex: 0,
      category: 'Geography',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which is the longest river in the world?',
        'hi': 'विश्व की सबसे लंबी नदी कौन सी है?',
        'bn': 'বিশ্বের দীর্ঘতম নদী কোনটি?',
      },
      options: {
        'en': ['Nile', 'Amazon', 'Yangtze', 'Mississippi'],
        'hi': ['नील', 'अमेज़न', 'यांग्त्ज़े', 'मिसिसिपी'],
        'bn': ['নীল', 'আমাজন', 'ইয়াংৎসে', 'মিসিসিপি'],
      },
      explanation: {
        'en':
            'The Nile River is approximately 6,650 km long, making it the longest river in the world.',
        'hi': 'नील नदी विश्व की सबसे लंबी नदी है।',
        'bn': 'নীল নদী বিশ্বের দীর্ঘতম নদী।',
      },
    ),
    QuestionModel(
      id: 'g13',
      order: 12,
      correctIndex: 3,
      category: 'History',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Who was the first Prime Minister of India?',
        'hi': 'भारत के प्रथम प्रधानमंत्री कौन थे?',
        'bn': 'ভারতের প্রথম প্রধানমন্ত্রী কে ছিলেন?',
      },
      options: {
        'en': [
          'Mahatma Gandhi',
          'Jawaharlal Nehru',
          'Sardar Patel',
          'Rajendra Prasad'
        ],
        'hi': [
          'महात्मा गांधी',
          'जवाहरलाल नेहरू',
          'सरदार पटेल',
          'राजेंद्र प्रसाद'
        ],
        'bn': [
          'মহাত্মা গান্ধী',
          'জওহরলাল নেহরু',
          'সর্দার প্যাটেল',
          'রাজেন্দ্র প্রসাদ'
        ],
      },
      explanation: {
        'en':
            'Jawaharlal Nehru was the first Prime Minister of India, serving from 1947 to 1964.',
        'hi': 'जवाहरलाल नेहरू भारत के पहले प्रधानमंत्री थे।',
        'bn': 'জওহরলাল নেহরু ভারতের প্রথম প্রধানমন্ত্রী ছিলেন।',
      },
    ),
    QuestionModel(
      id: 'g14',
      order: 13,
      correctIndex: 2,
      category: 'Geography',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which planet is known as the Red Planet?',
        'hi': 'कौन-सा ग्रह लाल ग्रह के नाम से जाना जाता है?',
        'bn': 'কোন গ্রহটি লাল গ্রহ নামে পরিচিত?',
      },
      options: {
        'en': ['Venus', 'Jupiter', 'Mars', 'Saturn'],
        'hi': ['शुक्र', 'बृहस्पति', 'मंगल', 'शनि'],
        'bn': ['শুক্র', 'বৃহস্পতি', 'মঙ্গল', 'শনি'],
      },
      explanation: {
        'en':
            'Mars is called the Red Planet because of its reddish appearance due to iron oxide on its surface.',
        'hi': 'मंगल को लाल ग्रह इसके लाल रंग के कारण कहा जाता है।',
        'bn': 'মঙ্গলকে তার লাল রঙের কারণে লাল গ্রহ বলা হয়।',
      },
    ),
    QuestionModel(
      id: 'g15',
      order: 14,
      correctIndex: 1,
      category: 'Science',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the SI unit of force?',
        'hi': 'बल की SI इकाई क्या है?',
        'bn': 'বলের SI একক কী?',
      },
      options: {
        'en': ['Joule', 'Newton', 'Watt', 'Pascal'],
        'hi': ['जूल', 'न्यूटन', 'वाट', 'पास्कल'],
        'bn': ['জুল', 'নিউটন', 'ওয়াট', 'প্যাসকেল'],
      },
      explanation: {
        'en':
            'The SI unit of force is Newton (N), named after Sir Isaac Newton.',
        'hi': 'बल की SI इकाई न्यूटन है।',
        'bn': 'বলের SI একক নিউটন।',
      },
    ),
    QuestionModel(
      id: 'g16',
      order: 15,
      correctIndex: 0,
      category: 'Sports',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which country won the first Cricket World Cup?',
        'hi': 'किस देश ने पहला क्रिकेट विश्व कप जीता?',
        'bn': 'কোন দেশ প্রথম ক্রিকেট বিশ্বকাপ জিতেছিল?',
      },
      options: {
        'en': ['England', 'Australia', 'West Indies', 'India'],
        'hi': ['इंग्लैंड', 'ऑस्ट्रेलिया', 'वेस्ट इंडीज', 'भारत'],
        'bn': ['ইংল্যান্ড', 'অস্ট্রেলিয়া', 'ওয়েস্ট ইন্ডিজ', 'ভারত'],
      },
      explanation: {
        'en':
            'England won the first Cricket World Cup in 1975, defeating West Indies in the final.',
        'hi': 'इंग्लैंड ने 1975 में पहला क्रिकेट विश्व कप जीता।',
        'bn': '১৯৭৫ সালে ইংল্যান্ড প্রথম ক্রিকেট বিশ্বকাপ জিতেছিল।',
      },
    ),
    QuestionModel(
      id: 'g17',
      order: 16,
      correctIndex: 3,
      category: 'Geography',
      difficulty: 'hard',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the deepest ocean trench in the world?',
        'hi': 'विश्व की सबसे गहरी समुद्री खाई कौन सी है?',
        'bn': 'বিশ্বের গভীরতম মহাসাগরীয় খাত কোনটি?',
      },
      options: {
        'en': [
          'Philippine Trench',
          'Tonga Trench',
          'Kuril Trench',
          'Mariana Trench'
        ],
        'hi': [
          'फिलिपीन ट्रेंच',
          'टोंगा ट्रेंच',
          'कुरिल ट्रेंच',
          'मारियाना ट्रेंच'
        ],
        'bn': [
          'ফিলিপাইন ট্রেঞ্চ',
          'টোঙ্গা ট্রেঞ্চ',
          'কুরিল ট্রেঞ্চ',
          'মারিয়ানা ট্রেঞ্চ'
        ],
      },
      explanation: {
        'en':
            'The Mariana Trench is the deepest ocean trench, reaching about 11,000 meters at its deepest point.',
        'hi': 'মারিয়ানা ট্রেঞ্চ বিশ্বের গভীরতম মহাসাগরীয় খাত।',
        'bn': 'মারিয়ানা ট্রেঞ্চ বিশ্বের গভীরতম মহাসাগরীয় খাত।',
      },
    ),
    QuestionModel(
      id: 'g18',
      order: 17,
      correctIndex: 1,
      category: 'Science',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the largest organ in the human body?',
        'hi': 'मानव शरीर का सबसे बड़ा अंग कौन सा है?',
        'bn': 'মানবদেহের বৃহত্তম অঙ্গ কোনটি?',
      },
      options: {
        'en': ['Heart', 'Skin', 'Liver', 'Brain'],
        'hi': ['हृदय', 'त्वचा', 'यकृत', 'मस्तिष्क'],
        'bn': ['হৃদয়', 'ত্বক', 'যকৃত', 'মস্তিষ্ক'],
      },
      explanation: {
        'en':
            'The skin is the largest organ in the human body, covering about 20 square feet in adults.',
        'hi': 'त्वचा मानव शरीर का सबसे बड़ा अंग है।',
        'bn': 'ত্বক মানবদেহের বৃহত্তম অঙ্গ।',
      },
    ),
    QuestionModel(
      id: 'g19',
      order: 18,
      correctIndex: 2,
      category: 'History',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'In which year did the Quit India Movement start?',
        'hi': 'भारत छोड़ो आंदोलन किस वर्ष शुरू हुआ?',
        'bn': 'ভারত ছাড়ো আন্দোলন কোন বছর শুরু হয়েছিল?',
      },
      options: {
        'en': ['1940', '1942', '1944', '1946'],
        'hi': ['1940', '1942', '1944', '1946'],
        'bn': ['১৯৪০', '১৯৪২', '১৯৪৪', '১৯৪৬'],
      },
      explanation: {
        'en':
            'The Quit India Movement was launched on August 8, 1942, by Mahatma Gandhi.',
        'hi': 'भारत छोड़ो आंदोलन 8 अगस्त 1942 को शुरू हुआ।',
        'bn': 'ভারত ছাড়ো আন্দোলন ৮ আগস্ট ১৯৪২ সালে শুরু হয়েছিল।',
      },
    ),
    QuestionModel(
      id: 'g20',
      order: 19,
      correctIndex: 0,
      category: 'Science',
      difficulty: 'easy',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the boiling point of water in Celsius?',
        'hi': 'सेल्सियस में पानी का क्वथनांक क्या है?',
        'bn': 'সেলসিয়াসে পানির স্ফুটনাঙ্ক কত?',
      },
      options: {
        'en': ['100°C', '90°C', '110°C', '80°C'],
        'hi': ['100°C', '90°C', '110°C', '80°C'],
        'bn': ['১০০°C', '৯০°C', '১১০°C', '৮০°C'],
      },
      explanation: {
        'en': 'Water boils at 100°C (212°F) at standard atmospheric pressure.',
        'hi': 'पानी मानक वायुदाब पर 100°C पर उबलता है।',
        'bn': 'পানি মানক বায়ুমণ্ডলীয় চাপে ১০০°C-এ ফোটে।',
      },
    ),
    QuestionModel(
      id: 'g21',
      order: 20,
      correctIndex: 3,
      category: 'Geography',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which country has the largest population in the world?',
        'hi': 'विश्व में किस देश की सबसे अधिक आबादी है?',
        'bn': 'বিশ্বে কোন দেশের জনসংখ্যা সবচেয়ে বেশি?',
      },
      options: {
        'en': ['USA', 'Indonesia', 'Pakistan', 'India'],
        'hi': ['USA', 'इंडोनेशिया', 'पाकिस्तान', 'भारत'],
        'bn': ['USA', 'ইন্দোনেশিয়া', 'পাকিস্তান', 'ভারত'],
      },
      explanation: {
        'en':
            'India has surpassed China to become the most populous country in the world.',
        'hi': 'भारत दुनिया का सबसे अधिक आबादी वाला देश बन गया है।',
        'bn': 'ভারত বিশ্বের সবচেয়ে জনবহুল দেশ হয়েছে।',
      },
    ),
    QuestionModel(
      id: 'g22',
      order: 21,
      correctIndex: 1,
      category: 'Economy',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Who is known as the Father of the Indian Nation?',
        'hi': 'भारतीय राष्ट्र के जनक किसे कहा जाता है?',
        'bn': 'ভারতীয় জাতির জনক কাকে বলা হয়?',
      },
      options: {
        'en': [
          'Jawaharlal Nehru',
          'Mahatma Gandhi',
          'Sardar Patel',
          'Subhas Chandra Bose'
        ],
        'hi': [
          'जवाहरलाल नेहरू',
          'महात्मा गांधी',
          'सरदार पटेल',
          'सुभास चंद्र बोस'
        ],
        'bn': [
          'জওহরলাল নেহরু',
          'মহাত্মা গান্ধী',
          'সর্দার প্যাটেল',
          'সুভাষ চন্দ্র বোস'
        ],
      },
      explanation: {
        'en':
            'Mahatma Gandhi is known as the Father of the Nation for his role in India\'s independence.',
        'hi': 'महात्मा गांधी को राष्ट्रपिता कहा जाता है।',
        'bn': 'মহাত্মা গান্ধীকে জাতির জনক বলা হয়।',
      },
    ),
    QuestionModel(
      id: 'g23',
      order: 22,
      correctIndex: 0,
      category: 'Science',
      difficulty: 'hard',
      examTags: ['GENERAL'],
      text: {
        'en': 'What is the chemical formula of table salt?',
        'hi': 'टेबल साल्ट का रासायनिक सूत्र क्या है?',
        'bn': 'টেবিল সল্টের রাসায়নিক সূত্র কী?',
      },
      options: {
        'en': ['NaCl', 'KCl', 'CaCl2', 'MgCl2'],
        'hi': ['NaCl', 'KCl', 'CaCl2', 'MgCl2'],
        'bn': ['NaCl', 'KCl', 'CaCl2', 'MgCl2'],
      },
      explanation: {
        'en':
            'Table salt is sodium chloride (NaCl), composed of sodium and chlorine atoms.',
        'hi': 'टेबल साल्ट सोडियम क्लोराइड (NaCl) है।',
        'bn': 'টেবিল সল্ট সোডিয়াম ক্লোরাইড (NaCl)।',
      },
    ),
    QuestionModel(
      id: 'g24',
      order: 23,
      correctIndex: 2,
      category: 'Sports',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'Which Indian city hosts the Indian Premier League (IPL)?',
        'hi': 'इंडियन प्रीमियर लीग (IPL) किस भारतीय शहर में आयोजित होती है?',
        'bn': 'আইপিএল কোন ভারতীয় শহরে অনুষ্ঠিত হয়?',
      },
      options: {
        'en': [
          'Only Mumbai',
          'Only Delhi',
          'Multiple cities',
          'Only Bangalore'
        ],
        'hi': ['केवल मुंबई', 'केवल दिल्ली', 'कई शहर', 'केवल बेंगलुरु'],
        'bn': ['শুধু মুম্বাই', 'শুধু দিল্লি', 'একাধিক শহর', 'শুধু ব্যাঙ্গালোর'],
      },
      explanation: {
        'en': 'IPL matches are hosted across multiple Indian cities each year.',
        'hi': 'IPL मैच हर साल भारत के कई शहरों में खेले जाते हैं।',
        'bn': 'আইপিএল ম্যাচ প্রতি বছর একাধিক ভারতীয় শহরে অনুষ্ঠিত হয়।',
      },
    ),
    QuestionModel(
      id: 'g25',
      order: 24,
      correctIndex: 1,
      category: 'Current Affairs',
      difficulty: 'medium',
      examTags: ['GENERAL'],
      text: {
        'en': 'What does UNESCO stand for?',
        'hi': 'UNESCO का पूर्ण रूप क्या है?',
        'bn': 'UNESCO-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'United Nations Educational, Scientific and Cultural Organization',
          'United Nations Economic, Social and Cultural Organization',
          'Universal National Education, Science and Culture Organization',
          'United Nations Education, Science and Culture Organization'
        ],
        'hi': [
          'संयुक्त राष्ट्र शैक्षिक, वैज्ञानिक और सांस्कृतिक संगठन',
          'संयुक्त राष्ट्र आर्थिक, सामाजिक और सांस्कृतिक संगठन',
          'विश्वव्यापी राष्ट्रीय शिक्षा, विज्ञान और संस्कृति संगठन',
          'संयुक्त राष्ट्र शिक्षा, विज्ञान और संस्कृति संगठन'
        ],
        'bn': [
          'জাতিসংঘ শিক্ষা, বৈজ্ঞানিক ও সাংস্কৃতিক সংস্থা',
          'জাতিসংঘ অর্থনৈতিক, সামাজিক ও সাংস্কৃতিক সংস্থা',
          'সর্বজনীন জাতীয় শিক্ষা, বিজ্ঞান ও সংস্কৃতি সংস্থা',
          'জাতিসংঘ শিক্ষা, বিজ্ঞান ও সংস্কৃতি সংস্থা'
        ],
      },
      explanation: {
        'en':
            'UNESCO stands for United Nations Educational, Scientific and Cultural Organization.',
        'hi':
            'UNESCO का मतलब है संयुक्त राष्ट्र शैक्षिक, वैज्ञानिक और सांस्कृतिक संगठन।',
        'bn': 'UNESCO মানে জাতিসংঘ শিক্ষা, বৈজ্ঞানিক ও সাংস্কৃতিক সংস্থা।',
      },
    ),
  ];

  // ── WBPSC ─────────────────────────────────────────────────
  static const List<QuestionModel> _wbpscQuestions = [
    QuestionModel(
      id: 'wb01',
      order: 0,
      correctIndex: 0,
      category: 'West Bengal History',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'When was West Bengal state formed?',
        'hi': 'पश्चिम बंगाल राज्य कब बना?',
        'bn': 'পশ্চিমবঙ্গ রাজ্য কবে গঠিত হয়েছিল?',
      },
      options: {
        'en': ['1947', '1950', '1956', '1960'],
        'hi': ['1947', '1950', '1956', '1960'],
        'bn': ['১৯৪৭', '১৯৫০', '১৯৫৬', '১৯৬০'],
      },
      explanation: {
        'en':
            'West Bengal was formed in 1947 after the partition of India and Bengal.',
        'hi': 'पश्चिम बंगाल 1947 में भारत और बंगाल के विभाजन के बाद बना।',
        'bn': 'পশ্চিমবঙ্গ ১৯৪৭ সালে ভারত বিভাজনের পর গঠিত হয়।',
      },
    ),
    QuestionModel(
      id: 'wb02',
      order: 1,
      correctIndex: 2,
      category: 'West Bengal',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'What is the capital of West Bengal?',
        'hi': 'पश्चिम बंगाल की राजधानी क्या है?',
        'bn': 'পশ্চিমবঙ্গের রাজধানী কোনটি?',
      },
      options: {
        'en': ['Siliguri', 'Howrah', 'Kolkata', 'Asansol'],
        'hi': ['सिलीगुड़ी', 'हावड़ा', 'कोलकाता', 'आसनसोल'],
        'bn': ['শিলিগুড়ি', 'হাওড়া', 'কলকাতা', 'আসানসোল'],
      },
      explanation: {
        'en': 'Kolkata (formerly Calcutta) is the capital of West Bengal.',
        'hi': 'कोलकाता पश्चिम बंगाल की राजधानी है।',
        'bn': 'কলকাতা পশ্চিমবঙ্গের রাজধানী।',
      },
    ),
    QuestionModel(
      id: 'wb03',
      order: 2,
      correctIndex: 1,
      category: 'West Bengal Polity',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'How many districts are there in West Bengal?',
        'hi': 'पश्चिम बंगाल में कितने जिले हैं?',
        'bn': 'পশ্চিমবঙ্গে কতটি জেলা আছে?',
      },
      options: {
        'en': ['20', '23', '30', '18'],
        'hi': ['20', '23', '30', '18'],
        'bn': ['২০', '২৩', '৩০', '১৮'],
      },
      explanation: {
        'en': 'West Bengal currently has 23 districts.',
        'hi': 'पश्चिम बंगाल में वर्तमान में 23 जिले हैं।',
        'bn': 'পশ্চিমবঙ্গে বর্তমানে ২৩টি জেলা রয়েছে।',
      },
    ),
    QuestionModel(
      id: 'wb04',
      order: 3,
      correctIndex: 3,
      category: 'West Bengal Culture',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which festival is most famous in West Bengal?',
        'hi': 'पश्चिम बंगाल में कौन-सा त्यौहार सबसे प्रसिद्ध है?',
        'bn': 'পশ্চিমবঙ্গে সবচেয়ে বিখ্যাত উৎসব কোনটি?',
      },
      options: {
        'en': ['Holi', 'Diwali', 'Eid', 'Durga Puja'],
        'hi': ['होली', 'दिवाली', 'ईद', 'दुर्गा पूजा'],
        'bn': ['হোলি', 'দীপাবলি', 'ঈদ', 'দুর্গাপূজা'],
      },
      explanation: {
        'en': 'Durga Puja is the most significant festival in West Bengal.',
        'hi': 'दुर्गा पूजा पश्चिम बंगाल का सबसे महत्वपूर्ण त्यौहार है।',
        'bn': 'দুর্গাপূজা পশ্চিমবঙ্গের সবচেয়ে গুরুত্বপূর্ণ উৎসব।',
      },
    ),
    QuestionModel(
      id: 'wb05',
      order: 4,
      correctIndex: 0,
      category: 'West Bengal Geography',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which river flows through Kolkata?',
        'hi': 'कोलकाता से होकर कौन-सी नदी बहती है?',
        'bn': 'কলকাতার মধ্য দিয়ে কোন নদী বয়ে যায়?',
      },
      options: {
        'en': ['Hooghly', 'Ganges', 'Damodar', 'Rupnarayan'],
        'hi': ['हुगली', 'गंगा', 'दामोदर', 'रूपनारायण'],
        'bn': ['হুগলি', 'গঙ্গা', 'দামোদর', 'রূপনারায়ণ'],
      },
      explanation: {
        'en':
            'The Hooghly River (a distributary of the Ganges) flows through Kolkata.',
        'hi': 'हुगली नदी (गंगा की एक शाखा) कोलकाता से होकर बहती है।',
        'bn': 'হুগলি নদী (গঙ্গার একটি শাখা) কলকাতার মধ্য দিয়ে বয়ে যায়।',
      },
    ),
    QuestionModel(
      id: 'wb06',
      order: 5,
      correctIndex: 2,
      category: 'West Bengal History',
      difficulty: 'hard',
      examTags: ['WBPSC'],
      text: {
        'en': 'Who founded the Brahmo Samaj in 1828?',
        'hi': 'ब्रह्म समाज की स्थापना 1828 में किसने की?',
        'bn': '১৮২৮ সালে ব্রাহ্মসমাজ কে প্রতিষ্ঠা করেন?',
      },
      options: {
        'en': [
          'Swami Vivekananda',
          'Ishwar Chandra Vidyasagar',
          'Raja Ram Mohan Roy',
          'Rabindranath Tagore'
        ],
        'hi': [
          'स्वामी विवेकानंद',
          'ईश्वर चंद्र विद्यासागर',
          'राजा राम मोहन रॉय',
          'रवींद्रनाथ टैगोर'
        ],
        'bn': [
          'স্বামী বিবেকানন্দ',
          'ঈশ্বরচন্দ্র বিদ্যাসাগর',
          'রাজা রামমোহন রায়',
          'রবীন্দ্রনাথ ঠাকুর'
        ],
      },
      explanation: {
        'en':
            'Raja Ram Mohan Roy founded the Brahmo Samaj in 1828 to reform Hindu society.',
        'hi': 'राजा राम मोहन रॉय ने 1828 में ब्रह्म समाज की स्थापना की।',
        'bn': 'রাজা রামমোহন রায় ১৮২৮ সালে ব্রাহ্মসমাজ প্রতিষ্ঠা করেন।',
      },
    ),
    QuestionModel(
      id: 'wb07',
      order: 6,
      correctIndex: 1,
      category: 'West Bengal Economy',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which port is the largest in West Bengal?',
        'hi': 'पश्चिम बंगाल का सबसे बड़ा बंदरगाह कौन सा है?',
        'bn': 'পশ্চিমবঙ্গের বৃহত্তম বন্দর কোনটি?',
      },
      options: {
        'en': ['Diamond Harbour', 'Kolkata Port', 'Haldia Port', 'Sandheads'],
        'hi': [
          'डायमंड हार्बर',
          'कोलकाता बंदरगाह',
          'हल्दिया बंदरगाह',
          'सैंडहेड्स'
        ],
        'bn': [
          'ডায়মন্ড হারবার',
          'কলকাতা বন্দর',
          'হলদিয়া বন্দর',
          'স্যান্ডহেডস'
        ],
      },
      explanation: {
        'en':
            'Kolkata Port (Syama Prasad Mookerjee Port) is the oldest major port in India and the largest in West Bengal.',
        'hi': 'कोलकाता बंदरगाह भारत का सबसे पुराना प्रमुख बंदरगाह है।',
        'bn':
            'কলকাতা বন্দর ভারতের প্রাচীনতম প্রধান বন্দর এবং পশ্চিমবঙ্গের বৃহত্তম।',
      },
    ),
    QuestionModel(
      id: 'wb08',
      order: 7,
      correctIndex: 0,
      category: 'West Bengal',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'What is the state animal of West Bengal?',
        'hi': 'पश्चिम बंगाल का राज्य पशु क्या है?',
        'bn': 'পশ্চিমবঙ্গের রাজ্য প্রাণী কী?',
      },
      options: {
        'en': ['Fishing Cat', 'Tiger', 'Elephant', 'Leopard'],
        'hi': ['फिशिंग कैट', 'बाघ', 'हाथी', 'तेंदुआ'],
        'bn': ['ফিশিং ক্যাট', 'বাঘ', 'হাতি', 'চিতাবাঘ'],
      },
      explanation: {
        'en':
            'The Fishing Cat (Prionailurus viverrinus) is the state animal of West Bengal.',
        'hi': 'फिशिंग कैट पश्चिम बंगाल का राज्य पशु है।',
        'bn': 'ফিশিং ক্যাট পশ্চিমবঙ্গের রাজ্য প্রাণী।',
      },
    ),
    QuestionModel(
      id: 'wb09',
      order: 8,
      correctIndex: 3,
      category: 'West Bengal Culture',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Rabindranath Tagore won the Nobel Prize in which year?',
        'hi': 'रवींद्रनाथ टैगोर को किस वर्ष नोबेल पुरस्कार मिला?',
        'bn': 'রবীন্দ্রনাথ ঠাকুর কোন বছর নোবেল পুরস্কার পান?',
      },
      options: {
        'en': ['1910', '1911', '1912', '1913'],
        'hi': ['1910', '1911', '1912', '1913'],
        'bn': ['১৯১০', '১৯১১', '১৯১২', '১৯১৩'],
      },
      explanation: {
        'en':
            'Rabindranath Tagore won the Nobel Prize in Literature in 1913 for Gitanjali.',
        'hi':
            'रवींद्रनाथ टैगोर को 1913 में गीतांजलि के लिए साहित्य का नोबेल पुरस्कार मिला।',
        'bn':
            'রবীন্দ্রনাথ ঠাকুর ১৯১৩ সালে গীতাঞ্জলির জন্য সাহিত্যে নোবেল পুরস্কার পান।',
      },
    ),
    QuestionModel(
      id: 'wb10',
      order: 9,
      correctIndex: 2,
      category: 'West Bengal',
      difficulty: 'hard',
      examTags: ['WBPSC'],
      text: {
        'en': 'Where is the Sundarbans located?',
        'hi': 'सुंदरबन कहाँ स्थित है?',
        'bn': 'সুন্দরবন কোথায় অবস্থিত?',
      },
      options: {
        'en': [
          'North Bengal',
          'Central Bengal',
          'South Bengal delta region',
          'East Bengal border'
        ],
        'hi': [
          'उत्तर बंगाल',
          'मध्य बंगाल',
          'दक्षिण बंगाल डेल्टा क्षेत्र',
          'पूर्व बंगाल सीमा'
        ],
        'bn': [
          'উত্তরবঙ্গ',
          'মধ্যবঙ্গ',
          'দক্ষিণবঙ্গের ব-দ্বীপ অঞ্চল',
          'পূর্ববঙ্গ সীমান্ত'
        ],
      },
      explanation: {
        'en':
            'Sundarbans is located in the southern delta region of West Bengal and is the largest mangrove forest in the world.',
        'hi': 'सुंदरबन पश्चिम बंगाल के दक्षिणी डेल्टा क्षेत्र में स्थित है।',
        'bn':
            'সুন্দরবন পশ্চিমবঙ্গের দক্ষিণ ব-দ্বীপ অঞ্চলে অবস্থিত এবং বিশ্বের বৃহত্তম ম্যানগ্রোভ বন।',
      },
    ),
    QuestionModel(
      id: 'wb11',
      order: 10,
      correctIndex: 1,
      category: 'West Bengal Geography',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'What is the state flower of West Bengal?',
        'hi': 'पश्चिम बंगाल का राज्य फूल क्या है?',
        'bn': 'পশ্চিমবঙ্গের রাজ্য ফুল কী?',
      },
      options: {
        'en': ['Rose', 'Glory Lily', 'Marigold', 'Lotus'],
        'hi': ['गुलाब', 'ग्लोरी लिली', 'गेंदा', 'कमल'],
        'bn': ['গোলাপ', 'গ্লোরি লিলি', 'গাঁদা ফুল', 'পদ্ম'],
      },
      explanation: {
        'en':
            'The Glory Lily (Gloriosa superba) is the state flower of West Bengal.',
        'hi': 'ग्लोरी लिली पश्चिम बंगाल का राज्य फूल है।',
        'bn': 'গ্লোরি লিলি পশ্চিমবঙ্গের রাজ্য ফুল।',
      },
    ),
    QuestionModel(
      id: 'wb12',
      order: 11,
      correctIndex: 0,
      category: 'West Bengal Culture',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'What is the state bird of West Bengal?',
        'hi': 'पश्चिम बंगाल का राज्य पक्षी क्या है?',
        'bn': 'পশ্চিমবঙ্গের রাজ্য পাখি কী?',
      },
      options: {
        'en': ['White-throated Kingfisher', 'Peacock', 'Parrot', 'Pigeon'],
        'hi': ['सफेद गला मछली पकड़ने वाला', 'मोर', 'तोता', 'कबूतर'],
        'bn': ['সাদা-গলা মাছরাঙা', 'ময়ূর', 'টিয়া', 'কবুতর'],
      },
      explanation: {
        'en':
            'The White-throated Kingfisher (Halcyon smyrnensis) is the state bird of West Bengal.',
        'hi': 'सफेद गला किंगफिशर पश्चिम बंगाल का राज्य पक्षी है।',
        'bn': 'সাদা-গলা মাছরাঙা পশ্চিমবঙ্গের রাজ্য পাখি।',
      },
    ),
    QuestionModel(
      id: 'wb13',
      order: 12,
      correctIndex: 3,
      category: 'West Bengal History',
      difficulty: 'hard',
      examTags: ['WBPSC'],
      text: {
        'en': 'Who was the first Governor of West Bengal?',
        'hi': 'पश्चिम बंगाल के पहले राज्यपाल कौन थे?',
        'bn': 'পশ্চিমবঙ্গের প্রথম রাজ্যপাল কে ছিলেন?',
      },
      options: {
        'en': [
          'Prafulla Chandra Ghosh',
          'Bidhan Chandra Roy',
          'Ramsingh',
          'Chakravarti Rajagopalachari'
        ],
        'hi': [
          'প্রফুল্ল চন্দ্র ঘোষ',
          'বিধান চন্দ্র রায়',
          'রামসিংহ',
          'চক্রবর্তী রাজগোপালাচারি'
        ],
        'bn': [
          'প্রফুল্ল চন্দ্র ঘোষ',
          'বিধান চন্দ্র রায়',
          'রামসিংহ',
          'চক্রবর্তী রাজগোপালাচারি'
        ],
      },
      explanation: {
        'en':
            'Chakravarti Rajagopalachari was the first Governor of West Bengal after independence.',
        'hi':
            'চক্রবর্তী রাজগোপালাচারি স্বাধীনতার পর পশ্চিমবঙ্গের প্রথম রাজ্যপাল ছিলেন।',
        'bn':
            'চক্রবর্তী রাজগোপালাচারি স্বাধীনতার পর পশ্চিমবঙ্গের প্রথম রাজ্যপাল ছিলেন।',
      },
    ),
    QuestionModel(
      id: 'wb14',
      order: 13,
      correctIndex: 2,
      category: 'West Bengal Culture',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which famous folk dance originated from West Bengal?',
        'hi': 'पश्चिम बंगाल से कौन सा प्रसिद्ध लोक नृत्य उत्पन्न हुआ?',
        'bn': 'পশ্চিমবঙ্গ থেকে কোন বিখ্যাত লোকনৃত্যের উৎপত্তি?',
      },
      options: {
        'en': ['Bihu', 'Bhootham', 'Jatra', 'Baul'],
        'hi': ['বিহু', 'ভূতাম', 'জাট্রা', 'বাউল'],
        'bn': ['বিহু', 'ভূতাম', 'জাট্রা', 'বাউল'],
      },
      explanation: {
        'en':
            'Jatra is a popular folk theatre form that originated in West Bengal.',
        'hi': 'জাট্রা পশ্চিমবঙ্গের একটি জনপ্রিয় লোকনাট্য রূপ।',
        'bn': 'জাট্রা পশ্চিমবঙ্গের একটি জনপ্রিয় লোকনাট্য রূপ।',
      },
    ),
    QuestionModel(
      id: 'wb15',
      order: 14,
      correctIndex: 0,
      category: 'West Bengal Geography',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which river is known as the "Suffering River" of West Bengal?',
        'hi': 'किस नदी को पश्चिम बंगाल की "दुखद नदी" कहा जाता है?',
        'bn': 'কোন নদীকে পশ্চিমবঙ্গের "দুঃখময় নদী" বলা হয়?',
      },
      options: {
        'en': ['Damodar', 'Rupnarayan', 'Ajoy', 'Kangsabati'],
        'hi': ['দামোদর', 'রূপনারায়ণ', 'অজয়', 'কাঁচাই'],
        'bn': ['দামোদর', 'রূপনারায়ণ', 'অজয়', 'কাংসাবতী'],
      },
      explanation: {
        'en':
            'Damodar River is known as the "Sorrow of Bengal" due to frequent floods.',
        'hi': 'দামোদর নদীকে "বঙ্গের শোক" বলা হয় ঘন ঘন বন্যার কারণে।',
        'bn': 'দামোদর নদীকে "বঙ্গের শোক" বলা হয় ঘন ঘন বন্যার কারণে।',
      },
    ),
    QuestionModel(
      id: 'wb16',
      order: 15,
      correctIndex: 1,
      category: 'West Bengal History',
      difficulty: 'hard',
      examTags: ['WBPSC'],
      text: {
        'en': 'In which year was the Battle of Plassey fought?',
        'hi': 'प्लासी का युद्ध किस वर्ष लड़ा गया था?',
        'bn': 'পলাশীর যুদ্ধ কোন বছর হয়েছিল?',
      },
      options: {
        'en': ['1755', '1757', '1759', '1761'],
        'hi': ['১৭৫৫', '১৭৫৭', '১৭৫৯', '১৭৬১'],
        'bn': ['১৭৫৫', '১৭৫৭', '১৭৫৯', '১৭৬১'],
      },
      explanation: {
        'en': 'The Battle of Plassey was fought on June 23, 1757.',
        'hi': 'পলাশীর যুদ্ধ ২৩ জুন, ১৭৫৭ সালে হয়েছিল।',
        'bn': 'পলাশীর যুদ্ধ ২৩ জুন, ১৭৫৭ সালে হয়েছিল।',
      },
    ),
    QuestionModel(
      id: 'wb17',
      order: 16,
      correctIndex: 3,
      category: 'West Bengal Culture',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'What is the state language of West Bengal?',
        'hi': 'पश्चिम बंगाल की राज्य भाषा क्या है?',
        'bn': 'পশ্চিমবঙ্গের রাজ্য ভাষা কী?',
      },
      options: {
        'en': ['Hindi', 'English', 'Nepali', 'Bengali'],
        'hi': ['হিন্দি', 'ইংরেজি', 'নেপালি', 'বাংলা'],
        'bn': ['হিন্দি', 'ইংরেজি', 'নেপালি', 'বাংলা'],
      },
      explanation: {
        'en': 'Bengali is the official language of West Bengal.',
        'hi': 'বাংলা পশ্চিমবঙ্গের সরকারি ভাষা।',
        'bn': 'বাংলা পশ্চিমবঙ্গের সরকারি ভাষা।',
      },
    ),
    QuestionModel(
      id: 'wb18',
      order: 17,
      correctIndex: 0,
      category: 'West Bengal Economy',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which is the major crop grown in West Bengal?',
        'hi': 'पश्चिम बंगाल में कौन सी प्रमुख फसल उगाई जाती है?',
        'bn': 'পশ্চিমবঙ্গে কোন প্রধান ফসল চাষ করা হয়?',
      },
      options: {
        'en': ['Rice', 'Wheat', 'Sugarcane', 'Cotton'],
        'hi': ['চাল', 'গম', 'আখ', 'তুলা'],
        'bn': ['চাল', 'গম', 'আখ', 'তুলা'],
      },
      explanation: {
        'en':
            'Rice is the major crop grown in West Bengal, which is one of the largest rice-producing states in India.',
        'hi':
            'চাল পশ্চিমবঙ্গের প্রধান ফসল, যা ভারতের সবচেয়ে বড় চাল উৎপাদক রাজ্যগুলির একটি।',
        'bn':
            'চাল পশ্চিমবঙ্গের প্রধান ফসল, যা ভারতের সবচেয়ে বড় চাল উৎপাদক রাজ্যগুলির একটি।',
      },
    ),
    QuestionModel(
      id: 'wb19',
      order: 18,
      correctIndex: 2,
      category: 'West Bengal Polity',
      difficulty: 'medium',
      examTags: ['WBPSC'],
      text: {
        'en': 'How many legislative assembly seats are there in West Bengal?',
        'hi': 'पश्चिम बंगाल में कितनी विधानसभा सीटें हैं?',
        'bn': 'পশ্চিমবঙ্গে কতটি বিধানসভা আসন আছে?',
      },
      options: {
        'en': ['294', '295', '296', '297'],
        'hi': ['২৯৪', '২৯৫', '২৯৬', '২৯৭'],
        'bn': ['২৯৪', '২৯৫', '২৯৬', '২৯৭'],
      },
      explanation: {
        'en': 'West Bengal Legislative Assembly has 294 seats.',
        'hi': 'পশ্চিমবঙ্গ বিধানসভায় ২৯৪টি আসন আছে।',
        'bn': 'পশ্চিমবঙ্গ বিধানসভায় ২৯৪টি আসন আছে।',
      },
    ),
    QuestionModel(
      id: 'wb20',
      order: 19,
      correctIndex: 1,
      category: 'West Bengal Geography',
      difficulty: 'easy',
      examTags: ['WBPSC'],
      text: {
        'en': 'Which is the highest peak in West Bengal?',
        'hi': 'पश्चिम बंगाल की सबसे ऊँची चोटी कौन सी है?',
        'bn': 'পশ্চিমবঙ্গের সর্বোচ্চ শৃঙ্গ কোনটি?',
      },
      options: {
        'en': ['Sandakphu', 'Fulong', 'Tonglu', 'Kangchenjunga'],
        'hi': ['সন্দকফু', 'ফুলং', 'টংলু', 'কাংচেনজঙ্ঘা'],
        'bn': ['সন্দকফু', 'ফুলং', 'টংলু', 'কাংচেনজঙ্ঘা'],
      },
      explanation: {
        'en': 'Sandakphu (3,636 m) is the highest peak in West Bengal.',
        'hi': 'সন্দকফু (৩,৬৩৬ মি) পশ্চিমবঙ্গের সর্বোচ্চ শৃঙ্গ।',
        'bn': 'সন্দকফু (৩,৬৩৬ মি) পশ্চিমবঙ্গের সর্বোচ্চ শৃঙ্গ।',
      },
    ),
  ];

  // ── SSC ───────────────────────────────────────────────────
  static const List<QuestionModel> _sscQuestions = [
    QuestionModel(
      id: 'ssc01',
      order: 0,
      correctIndex: 1,
      category: 'English',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Choose the correct synonym for "Eloquent":',
        'hi': '"Eloquent" का सही पर्यायवाची चुनें:',
        'bn': '"Eloquent" শব্দের সঠিক সমার্থক বেছে নিন:',
      },
      options: {
        'en': ['Silent', 'Articulate', 'Confused', 'Rude'],
        'hi': ['मौन', 'वाक्पटु', 'भ्रमित', 'असभ्य'],
        'bn': ['নীরব', 'বাকপটু', 'বিভ্রান্ত', 'অভদ্র'],
      },
      explanation: {
        'en':
            'Eloquent means fluent and persuasive in speaking, so "Articulate" is the correct synonym.',
        'hi':
            'Eloquent का मतलब है वाक्पटु, इसलिए "Articulate" सही पर्यायवाची है।',
        'bn': 'Eloquent অর্থ বাকপটু, তাই "Articulate" সঠিক সমার্থক।',
      },
    ),
    QuestionModel(
      id: 'ssc02',
      order: 1,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'What is 15% of 200?',
        'hi': '200 का 15% क्या है?',
        'bn': '200 এর 15% কত?',
      },
      options: {
        'en': ['25', '20', '35', '30'],
        'hi': ['25', '20', '35', '30'],
        'bn': ['২৫', '২০', '৩৫', '৩০'],
      },
      explanation: {
        'en': '15% of 200 = (15/100) × 200 = 30.',
        'hi': '200 का 15% = (15/100) × 200 = 30।',
        'bn': '200 এর 15% = (15/100) × 200 = 30।',
      },
    ),
    QuestionModel(
      id: 'ssc03',
      order: 2,
      correctIndex: 0,
      category: 'General Awareness',
      difficulty: 'easy',
      examTags: ['SSC'],
      text: {
        'en': 'Who is the head of state in India?',
        'hi': 'भारत में राज्य का प्रमुख कौन है?',
        'bn': 'ভারতে রাষ্ট্রের প্রধান কে?',
      },
      options: {
        'en': ['President', 'Prime Minister', 'Chief Justice', 'Speaker'],
        'hi': ['राष्ट्रपति', 'प्रधानमंत्री', 'मुख्य न्यायाधीश', 'अध्यक्ष'],
        'bn': ['রাষ্ট্রপতি', 'প্রধানমন্ত্রী', 'প্রধান বিচারপতি', 'স্পিকার'],
      },
      explanation: {
        'en': 'The President of India is the constitutional head of state.',
        'hi': 'भारत का राष्ट्रपति राज्य का संवैधानिक प्रमुख है।',
        'bn': 'ভারতের রাষ্ট্রপতি হলেন সাংবিধানিক রাষ্ট্রপ্রধান।',
      },
    ),
    QuestionModel(
      id: 'ssc04',
      order: 3,
      correctIndex: 2,
      category: 'Reasoning',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en':
            'In a certain code, "APPLE" is written as "BQQMF". How is "MANGO" written?',
        'hi':
            'एक निश्चित कोड में "APPLE" को "BQQMF" लिखा जाता है। "MANGO" कैसे लिखा जाएगा?',
        'bn':
            'একটি নির্দিষ্ট কোডে "APPLE" কে "BQQMF" লেখা হয়। "MANGO" কীভাবে লেখা হবে?',
      },
      options: {
        'en': ['NBNHP', 'NZMHP', 'NBOHP', 'NZMGP'],
        'hi': ['NBNHP', 'NZMHP', 'NBOHP', 'NZMGP'],
        'bn': ['NBNHP', 'NZMHP', 'NBOHP', 'NZMGP'],
      },
      explanation: {
        'en': 'Each letter is shifted +1. M→N, A→B, N→O, G→H, O→P → NBOHP.',
        'hi': 'हर अक्षर +1 होता है। M→N, A→B, N→O, G→H, O→P → NBOHP।',
        'bn': 'প্রতিটি অক্ষর +1 শিফট হয়। M→N, A→B, N→O, G→H, O→P → NBOHP।',
      },
    ),
    QuestionModel(
      id: 'ssc05',
      order: 4,
      correctIndex: 1,
      category: 'Mathematics',
      difficulty: 'hard',
      examTags: ['SSC'],
      text: {
        'en': 'A train travels 360 km in 4 hours. What is its speed in m/s?',
        'hi':
            'एक ट्रेन 4 घंटे में 360 किमी तय करती है। m/s में उसकी गति क्या है?',
        'bn': 'একটি ট্রেন ৪ ঘণ্টায় ৩৬০ কিমি যায়। m/s-এ এর গতি কত?',
      },
      options: {
        'en': ['20 m/s', '25 m/s', '30 m/s', '22.5 m/s'],
        'hi': ['20 m/s', '25 m/s', '30 m/s', '22.5 m/s'],
        'bn': ['20 m/s', '25 m/s', '30 m/s', '22.5 m/s'],
      },
      explanation: {
        'en': 'Speed = 360/4 = 90 km/h = 90 × (1000/3600) = 25 m/s.',
        'hi': 'गति = 360/4 = 90 km/h = 90 × (1000/3600) = 25 m/s।',
        'bn': 'গতি = 360/4 = 90 km/h = 90 × (1000/3600) = 25 m/s।',
      },
    ),
    QuestionModel(
      id: 'ssc06',
      order: 5,
      correctIndex: 0,
      category: 'General Science',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Which gas is used in fire extinguishers?',
        'hi': 'अग्निशामक यंत्रों में कौन-सी गैस का उपयोग किया जाता है?',
        'bn': 'অগ্নি নির্বাপক যন্ত্রে কোন গ্যাস ব্যবহার হয়?',
      },
      options: {
        'en': ['Carbon Dioxide', 'Oxygen', 'Nitrogen', 'Helium'],
        'hi': ['कार्बन डाइऑक्साइड', 'ऑक्सीजन', 'नाइट्रोजन', 'हीलियम'],
        'bn': ['কার্বন ডাই-অক্সাইড', 'অক্সিজেন', 'নাইট্রোজেন', 'হিলিয়াম'],
      },
      explanation: {
        'en':
            'Carbon Dioxide (CO₂) is widely used in fire extinguishers as it displaces oxygen.',
        'hi':
            'CO₂ अग्निशामक में उपयोग होती है क्योंकि यह ऑक्सीजन को हटा देती है।',
        'bn': 'CO₂ অগ্নি নির্বাপকে ব্যবহৃত হয় কারণ এটি অক্সিজেন সরিয়ে দেয়।',
      },
    ),
    QuestionModel(
      id: 'ssc07',
      order: 6,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'What is the LCM of 12 and 18?',
        'hi': '12 और 18 का LCM क्या है?',
        'bn': '12 এবং 18 এর LCM কত?',
      },
      options: {
        'en': ['24', '48', '72', '36'],
        'hi': ['24', '48', '72', '36'],
        'bn': ['২৪', '৪৮', '৭২', '৩৬'],
      },
      explanation: {
        'en': 'LCM of 12 and 18: 12 = 2² × 3, 18 = 2 × 3². LCM = 2² × 3² = 36.',
        'hi': '12 = 2² × 3, 18 = 2 × 3²। LCM = 2² × 3² = 36।',
        'bn': '12 = 2² × 3, 18 = 2 × 3²। LCM = 2² × 3² = 36।',
      },
    ),
    QuestionModel(
      id: 'ssc08',
      order: 7,
      correctIndex: 1,
      category: 'History',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'When was the Indian Constitution adopted?',
        'hi': 'भारतीय संविधान कब अपनाया गया?',
        'bn': 'ভারতীয় সংবিধান কবে গৃহীত হয়েছিল?',
      },
      options: {
        'en': ['15 Aug 1947', '26 Nov 1949', '26 Jan 1950', '30 Jan 1948'],
        'hi': [
          '15 अगस्त 1947',
          '26 नवंबर 1949',
          '26 जनवरी 1950',
          '30 जनवरी 1948'
        ],
        'bn': [
          '১৫ আগস্ট ১৯৪৭',
          '২৬ নভেম্বর ১৯৪৯',
          '২৬ জানুয়ারি ১৯৫০',
          '৩০ জানুয়ারি ১৯৪৮'
        ],
      },
      explanation: {
        'en':
            'The Indian Constitution was adopted on 26 November 1949 and came into effect on 26 January 1950.',
        'hi': 'भारतीय संविधान 26 नवंबर 1949 को अपनाया गया था।',
        'bn': 'ভারতীয় সংবিধান ২৬ নভেম্বর ১৯৪৯ সালে গৃহীত হয়।',
      },
    ),
    QuestionModel(
      id: 'ssc09',
      order: 8,
      correctIndex: 2,
      category: 'English',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Choose the correct antonym for "Benevolent":',
        'hi': '"Benevolent" का सही विलोम चुनें:',
        'bn': '"Benevolent" শব্দের সঠিক বিপরীতার্থক বেছে নিন:',
      },
      options: {
        'en': ['Kind', 'Generous', 'Malevolent', 'Gracious'],
        'hi': ['दयालु', 'उदार', 'दुर्भावनापूर्ण', 'कृपालु'],
        'bn': ['দয়ালু', 'উদার', 'বিদ্বেষপরায়ণ', 'সদয়'],
      },
      explanation: {
        'en':
            'Benevolent means kind and generous; its antonym is Malevolent (wishing harm).',
        'hi': 'Benevolent का विलोम Malevolent है।',
        'bn': 'Benevolent এর বিপরীত হল Malevolent।',
      },
    ),
    QuestionModel(
      id: 'ssc10',
      order: 9,
      correctIndex: 0,
      category: 'General Awareness',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Which is the longest river in India?',
        'hi': 'भारत की सबसे लंबी नदी कौन सी है?',
        'bn': 'ভারতের দীর্ঘতম নদী কোনটি?',
      },
      options: {
        'en': ['Ganga', 'Yamuna', 'Godavari', 'Indus'],
        'hi': ['गंगा', 'यमुना', 'गोदावरी', 'सिंधु'],
        'bn': ['গঙ্গা', 'যমুনা', 'গোদাবরী', 'সিন্ধু'],
      },
      explanation: {
        'en':
            'The Ganga (2,525 km) is the longest river that flows entirely within India.',
        'hi': 'गंगा (2,525 किमी) भारत की सबसे लंबी नदी है।',
        'bn': 'গঙ্গা (২,৫২৫ কিমি) ভারতের মধ্য দিয়ে প্রবাহিত দীর্ঘতম নদী।',
      },
    ),
    QuestionModel(
      id: 'ssc11',
      order: 10,
      correctIndex: 2,
      category: 'English',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Choose the correct synonym for "Abundant":',
        'hi': '"Abundant" का सही पर्यायवाची चुनें:',
        'bn': '"Abundant" শব্দের সঠিক সমার্থক বেছে নিন:',
      },
      options: {
        'en': ['Scarce', 'Limited', 'Plentiful', 'Rare'],
        'hi': ['दुर्लभ', 'सीमित', 'प्रचुर', 'दुर्लभ'],
        'bn': ['দুর্লভ', 'সীমিত', 'প্রচুর', 'দুর্লভ'],
      },
      explanation: {
        'en': 'Abundant means existing in large quantities; plentiful.',
        'hi': 'Abundant का मतलब है प्रचुर मात्रा में।',
        'bn': 'Abundant অর্থ প্রচুর পরিমাণে বিদ্যমান।',
      },
    ),
    QuestionModel(
      id: 'ssc12',
      order: 11,
      correctIndex: 1,
      category: 'Reasoning',
      difficulty: 'easy',
      examTags: ['SSC'],
      text: {
        'en': 'Find the next number: 2, 6, 12, 20, 30, ?',
        'hi': 'अगला नंबर ज्ञात करें: 2, 6, 12, 20, 30, ?',
        'bn': 'পরবর্তী সংখ্যা বের করুন: 2, 6, 12, 20, 30, ?',
      },
      options: {
        'en': ['40', '42', '44', '38'],
        'hi': ['40', '42', '44', '38'],
        'bn': ['40', '42', '44', '38'],
      },
      explanation: {
        'en': 'Pattern: n² + n. So 6² + 6 = 42.',
        'hi': 'প্যাটার্ন হল n² + n। তাই 6² + 6 = 42।',
        'bn': 'প্যাটার্ন হল n² + n। তাই 6² + 6 = 42।',
      },
    ),
    QuestionModel(
      id: 'ssc13',
      order: 12,
      correctIndex: 0,
      category: 'Mathematics',
      difficulty: 'hard',
      examTags: ['SSC'],
      text: {
        'en':
            'If the ratio of boys to girls is 3:2 and there are 30 boys, how many girls are there?',
        'hi':
            'यदि लड़कों और लड़कियों का अनुपात 3:2 है और 30 लड़के हैं, तो कितनी लड़कियाँ हैं?',
        'bn':
            'যদি ছেলে ও মেয়েদের অনুপাত 3:2 এবং 30 জন ছেলে থাকে, তাহলে কতজন মেয়ে আছে?',
      },
      options: {
        'en': ['20', '15', '25', '18'],
        'hi': ['20', '15', '25', '18'],
        'bn': ['20', '15', '25', '18'],
      },
      explanation: {
        'en': '3/2 = 30/x, so x = 30 × 2/3 = 20 girls.',
        'hi': '3/2 = 30/x, তাই x = 30 × 2/3 = 20 মেয়ে।',
        'bn': '3/2 = 30/x, তাই x = 30 × 2/3 = 20 মেয়ে।',
      },
    ),
    QuestionModel(
      id: 'ssc14',
      order: 13,
      correctIndex: 3,
      category: 'History',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Who was known as the "Iron Man of India"?',
        'hi': 'किसे "भारत का लौह पुरुष" कहा जाता था?',
        'bn': 'কাকে "ভারতের লৌহ পুরুষ" বলা হত?',
      },
      options: {
        'en': [
          'Mahatma Gandhi',
          'Jawaharlal Nehru',
          'Bhagat Singh',
          'Sardar Patel'
        ],
        'hi': ['মহাত্মা গান্ধী', 'জওহরলাল নেহরু', 'ভগত সিং', 'সর্দার প্যাটেল'],
        'bn': ['মহাত্মা গান্ধী', 'জওহরলাল নেহরু', 'ভগত সিং', 'সর্দার প্যাটেল'],
      },
      explanation: {
        'en':
            'Sardar Vallabhbhai Patel was known as the Iron Man of India for his role in integration of princely states.',
        'hi':
            'সর্দার বল্লভভাই প্যাটেলকে ভারতের লৌহ পুরুষ বলা হত রাজ্য সংহতকরণে তাঁর ভূমিকার জন্য।',
        'bn':
            'সর্দার বল্লভভাই প্যাটেলকে ভারতের লৌহ পুরুষ বলা হত রাজ্য সংহতকরণে তাঁর ভূমিকার জন্য।',
      },
    ),
    QuestionModel(
      id: 'ssc15',
      order: 14,
      correctIndex: 1,
      category: 'General Science',
      difficulty: 'easy',
      examTags: ['SSC'],
      text: {
        'en': 'What is the unit of electrical resistance?',
        'hi': 'विद्युत प्रतिरोध की इकाई क्या है?',
        'bn': 'বৈদ্যুতিক প্রতিরোধের একক কী?',
      },
      options: {
        'en': ['Volt', 'Ohm', 'Ampere', 'Watt'],
        'hi': ['ভোল্ট', 'ওহম', 'অ্যাম্পিয়ার', 'ওয়াট'],
        'bn': ['ভোল্ট', 'ওহম', 'অ্যাম্পিয়ার', 'ওয়াট'],
      },
      explanation: {
        'en':
            'The SI unit of electrical resistance is Ohm (Ω), named after Georg Ohm.',
        'hi': 'বৈদ্যুতিক প্রতিরোধের SI একক ওহম (Ω)।',
        'bn': 'বৈদ্যুতিক প্রতিরোধের SI একক ওহম (Ω)।',
      },
    ),
    QuestionModel(
      id: 'ssc16',
      order: 15,
      correctIndex: 2,
      category: 'English',
      difficulty: 'hard',
      examTags: ['SSC'],
      text: {
        'en': 'Which word is incorrectly spelled?',
        'hi': 'कौन सा शब्द गलत वर्तनी में है?',
        'bn': 'কোন শব্দটি ভুল বানানে আছে?',
      },
      options: {
        'en': ['Necessary', 'Occasion', 'Accomodate', 'Restaurant'],
        'hi': ['Necessary', 'Occasion', 'Accomodate', 'Restaurant'],
        'bn': ['Necessary', 'Occasion', 'Accomodate', 'Restaurant'],
      },
      explanation: {
        'en':
            '"Accomodate" is misspelled. The correct spelling is "Accommodate".',
        'hi': '"Accomodate" ভুল বানান। সঠিক বানান "Accommodate"।',
        'bn': '"Accomodate" ভুল বানান। সঠিক বানান "Accommodate"।',
      },
    ),
    QuestionModel(
      id: 'ssc17',
      order: 16,
      correctIndex: 0,
      category: 'Reasoning',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'If BROTHER is coded as 1234567, how is MOTHER coded?',
        'hi':
            'यदि BROTHER को 1234567 के रूप में कोडित किया जाता है, तो MOTHER को कैसे कोडित किया जाएगा?',
        'bn':
            'যদি BROTHER-কে 1234567 হিসাবে কোড করা হয়, তাহলে MOTHER কীভাবে কোড করা হবে?',
      },
      options: {
        'en': ['145267', '145276', '154267', '145627'],
        'hi': ['145267', '145276', '154267', '145627'],
        'bn': ['145267', '145276', '154267', '145627'],
      },
      explanation: {
        'en':
            'B=1, R=2, O=3, T=4, H=5, E=6, R=7. MOTHER = M=?, O=3, T=4, H=5, E=6, R=7. M is not in BROTHER so it gets the next number 1.',
        'hi':
            'B=1, R=2, O=3, T=4, H=5, E=6, R=7। MOTHER = M=?, O=3, T=4, H=5, E=6, R=7। M BROTHER-এ নেই তাই এটি পরবর্তী সংখ্যা 1 পায়।',
        'bn':
            'B=1, R=2, O=3, T=4, H=5, E=6, R=7। MOTHER = M=?, O=3, T=4, H=5, E=6, R=7। M BROTHER-এ নেই তাই এটি পরবর্তী সংখ্যা 1 পায়।',
      },
    ),
    QuestionModel(
      id: 'ssc18',
      order: 17,
      correctIndex: 3,
      category: 'General Awareness',
      difficulty: 'easy',
      examTags: ['SSC'],
      text: {
        'en': 'Which is the national bird of India?',
        'hi': 'भारत का राष्ट्रीय पक्षी कौन सा है?',
        'bn': 'ভারতের জাতীয় পাখি কোনটি?',
      },
      options: {
        'en': ['Pigeon', 'Parrot', 'Peacock', 'Crow'],
        'hi': ['কবুতর', 'টিয়া', 'ময়ূর', 'কাক'],
        'bn': ['কবুতর', 'টিয়া', 'ময়ূর', 'কাক'],
      },
      explanation: {
        'en': 'The Indian Peafowl (Peacock) is the national bird of India.',
        'hi': 'ভারতীয় ময়ূর ভারতের জাতীয় পাখি।',
        'bn': 'ভারতীয় ময়ূর ভারতের জাতীয় পাখি।',
      },
    ),
    QuestionModel(
      id: 'ssc19',
      order: 18,
      correctIndex: 1,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en':
            'The average of 5 consecutive numbers is 15. What is the largest number?',
        'hi': '5 क्रमिक संख्याओं का औसत 15 है। सबसे बड़ी संख्या क्या है?',
        'bn': '5টি ক্রমাগত সংখ্যার গড় 15। বৃহত্তম সংখ্যা কত?',
      },
      options: {
        'en': ['17', '16', '15', '18'],
        'hi': ['17', '16', '15', '18'],
        'bn': ['17', '16', '15', '18'],
      },
      explanation: {
        'en': 'Numbers are 13, 14, 15, 16, 17. Largest = 17.',
        'hi': 'সংখ্যাগুলি হল 13, 14, 15, 16, 17। বৃহত্তম = 17।',
        'bn': 'সংখ্যাগুলি হল 13, 14, 15, 16, 17। বৃহত্তম = 17।',
      },
    ),
    QuestionModel(
      id: 'ssc20',
      order: 19,
      correctIndex: 0,
      category: 'History',
      difficulty: 'medium',
      examTags: ['SSC'],
      text: {
        'en': 'Who founded the Maurya Empire?',
        'hi': 'मौर्य साम्राज्य की स्थापना किसने की?',
        'bn': 'মৌর্য সাম্রাজ্যের প্রতিষ্ঠা কে করেছিলেন?',
      },
      options: {
        'en': ['Chandragupta Maurya', 'Ashoka', 'Bindusara', 'Brihadratha'],
        'hi': ['চন্দ্রগুপ্ত মৌর্য', 'অশোক', 'বিন্দুসার', 'বৃহদ্রথ'],
        'bn': ['চন্দ্রগুপ্ত মৌর্য', 'অশোক', 'বিন্দুসার', 'বৃহদ্রথ'],
      },
      explanation: {
        'en': 'Chandragupta Maurya founded the Maurya Empire around 321 BCE.',
        'hi':
            'চন্দ্রগুপ্ত মৌর্য প্রায় 321 খ্রিস্টপূর্বাব্দে মৌর্য সাম্রাজ্য প্রতিষ্ঠা করেছিলেন।',
        'bn':
            'চন্দ্রগুপ্ত মৌর্য প্রায় 321 খ্রিস্টপূর্বাব্দে মৌর্য সাম্রাজ্য প্রতিষ্ঠা করেছিলেন।',
      },
    ),
  ];

  // ── UPSC ──────────────────────────────────────────────────
  static const List<QuestionModel> _upscQuestions = [
    QuestionModel(
      id: 'up01',
      order: 0,
      correctIndex: 2,
      category: 'Polity',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'How many Fundamental Rights are guaranteed by the Indian Constitution?',
        'hi': 'भारतीय संविधान द्वारा कितने मौलिक अधिकार गारंटी दिए गए हैं?',
        'bn': 'ভারতীয় সংবিধান কতটি মৌলিক অধিকারের নিশ্চয়তা দেয়?',
      },
      options: {
        'en': ['5', '7', '6', '8'],
        'hi': ['5', '7', '6', '8'],
        'bn': ['৫', '৭', '৬', '৮'],
      },
      explanation: {
        'en':
            'The Indian Constitution guarantees 6 Fundamental Rights under Articles 12-35.',
        'hi':
            'भारतीय संविधान अनुच्छेद 12-35 के तहत 6 मौलिक अधिकारों की गारंटी देता है।',
        'bn':
            'ভারতীয় সংবিধান ১২-৩৫ অনুচ্ছেদের অধীনে ৬টি মৌলিক অধিকারের নিশ্চয়তা দেয়।',
      },
    ),
    QuestionModel(
      id: 'up02',
      order: 1,
      correctIndex: 1,
      category: 'Economy',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'Which Five-Year Plan gave priority to agriculture and allied sectors?',
        'hi':
            'किस पंचवर्षीय योजना ने कृषि और संबद्ध क्षेत्रों को प्राथमिकता दी?',
        'bn':
            'কোন পঞ্চবার্ষিক পরিকল্পনায় কৃষি ও সংশ্লিষ্ট ক্ষেত্রকে অগ্রাধিকার দেওয়া হয়েছিল?',
      },
      options: {
        'en': ['First', 'Second', 'Third', 'Fourth'],
        'hi': ['पहली', 'दूसरी', 'तीसरी', 'चौथी'],
        'bn': ['প্রথম', 'দ্বিতীয়', 'তৃতীয়', 'চতুর্থ'],
      },
      explanation: {
        'en':
            'The Second Five-Year Plan (1956-61) followed the Mahalanobis model and prioritised heavy industry, but the FIRST plan (1951-56) focused on agriculture.',
        'hi': 'पहली पंचवर्षीय योजना (1951-56) कृषि पर केंद्रित थी।',
        'bn':
            'প্রথম পঞ্চবার্ষিক পরিকল্পনা (১৯৫১-৫৬) কৃষি খাতকে অগ্রাধিকার দিয়েছিল।',
      },
    ),
    QuestionModel(
      id: 'up03',
      order: 2,
      correctIndex: 3,
      category: 'Geography',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'Which is the highest peak in India?',
        'hi': 'भारत की सबसे ऊँची चोटी कौन-सी है?',
        'bn': 'ভারতের সর্বোচ্চ শৃঙ্গ কোনটি?',
      },
      options: {
        'en': ['Mount Everest', 'Nanda Devi', 'Kanchenjunga', 'K2'],
        'hi': ['माउंट एवरेस्ट', 'नंदा देवी', 'कंचनजंगा', 'K2'],
        'bn': ['মাউন্ট এভারেস্ট', 'নন্দাদেবী', 'কাঞ্চনজঙ্ঘা', 'K2'],
      },
      explanation: {
        'en':
            'Kanchenjunga (8,586 m) is the highest peak within Indian territory.',
        'hi': 'कंचनजंगा (8,586 मीटर) भारतीय क्षेत्र की सबसे ऊँची चोटी है।',
        'bn': 'কাঞ্চনজঙ্ঘা (৮,৫৮৬ মি.) ভারতীয় ভূখণ্ডের সর্বোচ্চ শৃঙ্গ।',
      },
    ),
    QuestionModel(
      id: 'up04',
      order: 3,
      correctIndex: 0,
      category: 'Environment',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en': 'What is the primary cause of the greenhouse effect?',
        'hi': 'ग्रीनहाउस प्रभाव का प्राथमिक कारण क्या है?',
        'bn': 'গ্রিনহাউস প্রভাবের প্রাথমিক কারণ কী?',
      },
      options: {
        'en': [
          'Increased CO₂ in atmosphere',
          'Ozone depletion',
          'Deforestation',
          'Ocean acidification'
        ],
        'hi': [
          'वायुमंडल में CO₂ की वृद्धि',
          'ओजोन रिक्तीकरण',
          'वनों की कटाई',
          'महासागर अम्लीकरण'
        ],
        'bn': [
          'বায়ুমণ্ডলে CO₂ বৃদ্ধি',
          'ওজোন ক্ষয়',
          'বন উজাড়',
          'সমুদ্র অম্লীকরণ'
        ],
      },
      explanation: {
        'en':
            'Increased concentrations of CO₂ and other greenhouse gases trap heat in the atmosphere.',
        'hi':
            'CO₂ और अन्य ग्रीनहाउस गैसों की बढ़ती सांद्रता वायुमंडल में गर्मी को रोकती है।',
        'bn':
            'CO₂ ও অন্যান্য গ্রিনহাউস গ্যাসের বর্ধিত ঘনত্ব বায়ুমণ্ডলে তাপ আটকে রাখে।',
      },
    ),
    QuestionModel(
      id: 'up05',
      order: 4,
      correctIndex: 2,
      category: 'History',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'The Battle of Plassey was fought in which year?',
        'hi': 'प्लासी का युद्ध किस वर्ष लड़ा गया था?',
        'bn': 'পলাশীর যুদ্ধ কোন বছর হয়েছিল?',
      },
      options: {
        'en': ['1764', '1761', '1757', '1775'],
        'hi': ['1764', '1761', '1757', '1775'],
        'bn': ['১৭৬৪', '১৭৬১', '১৭৫৭', '১৭৭৫'],
      },
      explanation: {
        'en':
            'The Battle of Plassey was fought on 23 June 1757, establishing British dominance in India.',
        'hi': 'प्लासी का युद्ध 23 जून 1757 को लड़ा गया था।',
        'bn': 'পলাশীর যুদ্ধ ২৩ জুন ১৭৫৭ সালে হয়েছিল।',
      },
    ),
    QuestionModel(
      id: 'up06',
      order: 5,
      correctIndex: 1,
      category: 'Polity',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'Which Article of the Indian Constitution deals with the Right to Equality?',
        'hi':
            'भारतीय संविधान का कौन-सा अनुच्छेद समानता के अधिकार से संबंधित है?',
        'bn': 'ভারতীয় সংবিধানের কোন অনুচ্ছেদ সমতার অধিকার নিয়ে আলোচনা করে?',
      },
      options: {
        'en': ['Article 12', 'Article 14', 'Article 19', 'Article 21'],
        'hi': ['अनुच्छेद 12', 'अनुच्छेद 14', 'अनुच्छेद 19', 'अनुच्छेद 21'],
        'bn': ['অনুচ্ছেদ ১২', 'অনুচ্ছেদ ১৪', 'অনুচ্ছেদ ১৯', 'অনুচ্ছেদ ২১'],
      },
      explanation: {
        'en':
            'Article 14 guarantees equality before the law and equal protection of laws.',
        'hi':
            'अनुच्छेद 14 कानून के समक्ष समानता और कानूनों की समान सुरक्षा की गारंटी देता है।',
        'bn':
            'অনুচ্ছেদ ১৪ আইনের সামনে সাম্য ও আইনের সমান সংরক্ষণের নিশ্চয়তা দেয়।',
      },
    ),
    QuestionModel(
      id: 'up07',
      order: 6,
      correctIndex: 0,
      category: 'Economy',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en':
            'Which institution is known as the "Lender of Last Resort" in India?',
        'hi': 'भारत में "अंतिम उपाय का ऋणदाता" किस संस्था को कहा जाता है?',
        'bn': 'ভারতে "শেষ ঋণদাতা" কোন সংস্থাকে বলা হয়?',
      },
      options: {
        'en': ['Reserve Bank of India', 'SBI', 'NABARD', 'SEBI'],
        'hi': ['भारतीय रिजर्व बैंक', 'SBI', 'नाबार्ड', 'सेबी'],
        'bn': ['ভারতীয় রিজার্ভ ব্যাংক', 'SBI', 'নাবার্ড', 'সেবি'],
      },
      explanation: {
        'en':
            'The Reserve Bank of India (RBI) acts as the lender of last resort to commercial banks.',
        'hi': 'RBI वाणिज्यिक बैंकों के लिए अंतिम उपाय का ऋणदाता है।',
        'bn': 'RBI বাণিজ্যিক ব্যাংকগুলির জন্য শেষ ঋণদাতা হিসেবে কাজ করে।',
      },
    ),
    QuestionModel(
      id: 'up08',
      order: 7,
      correctIndex: 3,
      category: 'Science & Technology',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en': 'Which Indian spacecraft successfully orbited Mars?',
        'hi': 'किस भारतीय अंतरिक्ष यान ने सफलतापूर्वक मंगल की परिक्रमा की?',
        'bn':
            'কোন ভারতীয় মহাকাশযান সফলভাবে মঙ্গল গ্রহের কক্ষপথে প্রবেশ করেছে?',
      },
      options: {
        'en': ['Chandrayaan-1', 'Aryabhata', 'Astrosat', 'Mangalyaan'],
        'hi': ['चंद्रयान-1', 'आर्यभट्ट', 'एस्ट्रोसैट', 'मंगलयान'],
        'bn': ['চন্দ্রযান-১', 'আর্যভট্ট', 'অ্যাস্ট্রোস্যাট', 'মঙ্গলযান'],
      },
      explanation: {
        'en':
            'Mangalyaan (Mars Orbiter Mission) successfully entered Mars orbit on 24 September 2014.',
        'hi':
            'मंगलयान ने 24 सितंबर 2014 को सफलतापूर्वक मंगल की कक्षा में प्रवेश किया।',
        'bn':
            'মঙ্গলযান ২৪ সেপ্টেম্বর ২০১৪ সালে সফলভাবে মঙ্গলের কক্ষপথে প্রবেশ করে।',
      },
    ),
    QuestionModel(
      id: 'up09',
      order: 8,
      correctIndex: 1,
      category: 'History',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'Who started the "Drain of Wealth" theory regarding British India?',
        'hi': '"धन की निकासी" सिद्धांत किसने शुरू किया?',
        'bn': '"সম্পদ নিষ্কাশন" তত্ত্ব কে শুরু করেছিলেন?',
      },
      options: {
        'en': [
          'Bal Gangadhar Tilak',
          'Dadabhai Naoroji',
          'Gopal Krishna Gokhale',
          'Bipin Chandra Pal'
        ],
        'hi': [
          'बाल गंगाधर तिलक',
          'दादाभाई नौरोजी',
          'गोपाल कृष्ण गोखले',
          'बिपिन चंद्र पाल'
        ],
        'bn': [
          'বাল গঙ্গাধর তিলক',
          'দাদাভাই নওরোজি',
          'গোপাল কৃষ্ণ গোখলে',
          'বিপিন চন্দ্র পাল'
        ],
      },
      explanation: {
        'en':
            'Dadabhai Naoroji first articulated the "Drain of Wealth" theory in his book "Poverty and Un-British Rule in India".',
        'hi':
            'दादाभाई नौरोजी ने "धन की निकासी" सिद्धांत को पहली बार व्यक्त किया।',
        'bn': 'দাদাভাই নওরোজি প্রথম "সম্পদ নিষ্কাশন" তত্ত্ব উপস্থাপন করেন।',
      },
    ),
    QuestionModel(
      id: 'up10',
      order: 9,
      correctIndex: 0,
      category: 'Geography',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en': 'The Tropic of Cancer passes through how many Indian states?',
        'hi': 'কর্কটক্রান্তি রেখা কতটি ভারতীয় রাজ্যের মধ্য দিয়ে যায়?',
        'bn': 'কর্কটক্রান্তি রেখা কতটি ভারতীয় রাজ্যের মধ্য দিয়ে যায়?',
      },
      options: {
        'en': ['8', '7', '9', '6'],
        'hi': ['৮', '৭', '৯', '৬'],
        'bn': ['৮', '৭', '৯', '৬'],
      },
      explanation: {
        'en':
            'The Tropic of Cancer passes through 8 Indian states: Gujarat, Rajasthan, MP, Chhattisgarh, Jharkhand, West Bengal, Tripura, and Mizoram.',
        'hi': 'কর্কটক্রান্তি রেখা ৮টি ভারতীয় রাজ্যের মধ্য দিয়ে যায়।',
        'bn': 'কর্কটক্রান্তি রেখা ৮টি ভারতীয় রাজ্যের মধ্য দিয়ে যায়।',
      },
    ),
    QuestionModel(
      id: 'up11',
      order: 10,
      correctIndex: 2,
      category: 'Polity',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'Which article of the Indian Constitution abolishes untouchability?',
        'hi': 'भारतीय संविधान का कौन सा अनुच्छेद अस्पृश्यता को समाप्त करता है?',
        'bn': 'ভারতীয় সংবিধানের কোন অনুচ্ছেদ অস্পৃশ্যতা বিলুপ্ত করে?',
      },
      options: {
        'en': ['Article 15', 'Article 16', 'Article 17', 'Article 18'],
        'hi': ['অনুচ্ছেদ ১৫', 'অনুচ্ছেদ ১৬', 'অনুচ্ছেদ ১৭', 'অনুচ্ছেদ ১৮'],
        'bn': ['অনুচ্ছেদ ১৫', 'অনুচ্ছেদ ১৬', 'অনুচ্ছেদ ১৭', 'অনুচ্ছেদ ১৮'],
      },
      explanation: {
        'en': 'Article 17 of the Indian Constitution abolishes untouchability.',
        'hi': 'ভারতীয় সংবিধানের ১৭ অনুচ্ছেদ অস্পৃশ্যতা বিলুপ্ত করে।',
        'bn': 'ভারতীয় সংবিধানের ১৭ অনুচ্ছেদ অস্পৃশ্যতা বিলুপ্ত করে।',
      },
    ),
    QuestionModel(
      id: 'up12',
      order: 11,
      correctIndex: 1,
      category: 'Geography',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'Which is the largest delta in the world?',
        'hi': 'বিশ্বের বৃহত্তম ব-দ্বীপ কোনটি?',
        'bn': 'বিশ্বের বৃহত্তম ব-দ্বীপ কোনটি?',
      },
      options: {
        'en': [
          'Nile Delta',
          'Ganges-Brahmaputra Delta',
          'Mississippi Delta',
          'Amazon Delta'
        ],
        'hi': [
          'নীল ব-দ্বীপ',
          'গঙ্গা-ব্রহ্মপুত্র ব-দ্বীপ',
          'মিসিসিপি ব-দ্বীপ',
          'আমাজন ব-দ্বীপ'
        ],
        'bn': [
          'নীল ব-দ্বীপ',
          'গঙ্গা-ব্রহ্মপুত্র ব-দ্বীপ',
          'মিসিসিপি ব-দ্বীপ',
          'আমাজন ব-দ্বীপ'
        ],
      },
      explanation: {
        'en':
            'The Ganges-Brahmaputra Delta (Sunderbans) is the largest delta in the world.',
        'hi': 'গঙ্গা-ব্রহ্মপুত্র ব-দ্বীপ (সুন্দরবন) বিশ্বের বৃহত্তম ব-দ্বীপ।',
        'bn': 'গঙ্গা-ব্রহ্মপুত্র ব-দ্বীপ (সুন্দরবন) বিশ্বের বৃহত্তম ব-দ্বীপ।',
      },
    ),
    QuestionModel(
      id: 'up13',
      order: 12,
      correctIndex: 0,
      category: 'Economy',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'Which committee recommended the establishment of the RBI?',
        'hi': 'किस समिति ने RBI की स्थापना की सिफारिश की?',
        'bn': 'কোন কমিটি RBI প্রতিষ্ঠার সুপারিশ করেছিল?',
      },
      options: {
        'en': [
          'Hilton Young Commission',
          'Royal Commission',
          'JPC',
          'Narsimham Committee'
        ],
        'hi': ['হিল্টন ইয়ং কমিশন', 'রাজকীয় কমিশন', 'JPC', 'নর্সিংহাম কমিটি'],
        'bn': ['হিল্টন ইয়ং কমিশন', 'রাজকীয় কমিশন', 'JPC', 'নর্সিংহাম কমিটি'],
      },
      explanation: {
        'en':
            'The Hilton Young Commission (1936) recommended the establishment of RBI.',
        'hi': 'হিল্টন ইয়ং কমিশন (1936) RBI প্রতিষ্ঠার সুপারিশ করেছিল।',
        'bn': 'হিল্টন ইয়ং কমিশন (1936) RBI প্রতিষ্ঠার সুপারিশ করেছিল।',
      },
    ),
    QuestionModel(
      id: 'up14',
      order: 13,
      correctIndex: 3,
      category: 'Environment',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en': 'Which is the first Ramsar site in India?',
        'hi': 'ভারতের প্রথম রামসার স্থান কোনটি?',
        'bn': 'ভারতের প্রথম রামসার স্থান কোনটি?',
      },
      options: {
        'en': [
          'Dal Lake',
          'Sambhar Lake',
          'Chilika Lake',
          'Keoladeo National Park'
        ],
        'hi': [
          'দাল হ্রদ',
          'সম্ভার হ্রদ',
          'চিলিকা হ্রদ',
          'কেওলাদেও জাতীয় উদ্যান'
        ],
        'bn': [
          'দাল হ্রদ',
          'সম্ভার হ্রদ',
          'চিলিকা হ্রদ',
          'কেওলাদেও জাতীয় উদ্যান'
        ],
      },
      explanation: {
        'en':
            'Keoladeo National Park (Bharatpur) was the first Ramsar site in India (1981).',
        'hi':
            'কেওলাদেও জাতীয় উদ্যান (ভরতপুর) ছিল ভারতের প্রথম রামসার স্থান (1981)।',
        'bn':
            'কেওলাদেও জাতীয় উদ্যান (ভরতপুর) ছিল ভারতের প্রথম রামসার স্থান (1981)।',
      },
    ),
    QuestionModel(
      id: 'up15',
      order: 14,
      correctIndex: 1,
      category: 'History',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'Who wrote the "Discovery of India"?',
        'hi': '"ভারতের আবিষ্কার" কে লিখেছিলেন?',
        'bn': '"ভারতের আবিষ্কার" কে লিখেছিলেন?',
      },
      options: {
        'en': [
          'Mahatma Gandhi',
          'Jawaharlal Nehru',
          'Subhas Chandra Bose',
          'Amartya Sen'
        ],
        'hi': [
          'মহাত্মা গান্ধী',
          'জওহরলাল নেহরু',
          'সুভাষ চন্দ্র বোস',
          'অমর্ত্য সেন'
        ],
        'bn': [
          'মহাত্মা গান্ধী',
          'জওহরলাল নেহরু',
          'সুভাষ চন্দ্র বোস',
          'অমর্ত্য সেন'
        ],
      },
      explanation: {
        'en':
            'Jawaharlal Nehru wrote "Discovery of India" during his imprisonment in 1944.',
        'hi':
            'জওহরলাল নেহরু 1944 সালে কারাবন্দী অবস্থায় "ভারতের আবিষ্কার" লিখেছিলেন।',
        'bn':
            'জওহরলাল নেহরু 1944 সালে কারাবন্দী অবস্থায় "ভারতের আবিষ্কার" লিখেছিলেন।',
      },
    ),
    QuestionModel(
      id: 'up16',
      order: 15,
      correctIndex: 2,
      category: 'Polity',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'How many members are nominated by the President to the Rajya Sabha?',
        'hi': 'রাষ্ট্রপতি দ্বারা রাজ্যসভায় কতজন সদস্য মনোনীত হন?',
        'bn': 'রাষ্ট্রপতি দ্বারা রাজ্যসভায় কতজন সদস্য মনোনীত হন?',
      },
      options: {
        'en': ['10', '12', '14', '16'],
        'hi': ['10', '12', '14', '16'],
        'bn': ['10', '12', '14', '16'],
      },
      explanation: {
        'en': 'The President nominates 12 members to the Rajya Sabha.',
        'hi': 'রাষ্ট্রপতি রাজ্যসভায় 12 জন সদস্য মনোনীত করেন।',
        'bn': 'রাষ্ট্রপতি রাজ্যসভায় 12 জন সদস্য মনোনীত করেন।',
      },
    ),
    QuestionModel(
      id: 'up17',
      order: 16,
      correctIndex: 0,
      category: 'Science & Technology',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'Which Indian satellite was the first to be placed in geo-stationary orbit?',
        'hi': 'কোন ভারতীয় উপগ্রহ প্রথম জিও-স্টেশনারি কক্ষপথে স্থাপিত হয়েছিল?',
        'bn': 'কোন ভারতীয় উপগ্রহ প্রথম জিও-স্টেশনারি কক্ষপথে স্থাপিত হয়েছিল?',
      },
      options: {
        'en': ['APPLE', 'INSAT-1A', 'Rohini', 'Aryabhata'],
        'hi': ['APPLE', 'INSAT-1A', 'রোহিনি', 'আর্যভট্ট'],
        'bn': ['APPLE', 'INSAT-1A', 'রোহিনি', 'আর্যভট্ট'],
      },
      explanation: {
        'en':
            'APPLE (Ariane Passenger Payload Experiment) was India\'s first experimental communication satellite.',
        'hi': 'APPLE ছিল ভারতের প্রথম পরীক্ষামূলক যোগাযোগ উপগ্রহ।',
        'bn': 'APPLE ছিল ভারতের প্রথম পরীক্ষামূলক যোগাযোগ উপগ্রহ।',
      },
    ),
    QuestionModel(
      id: 'up18',
      order: 17,
      correctIndex: 1,
      category: 'Geography',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en': 'Which state has the longest coastline in India?',
        'hi': 'ভারতে কোন রাজ্যের উপকূলরেখা সবচেয়ে দীর্ঘ?',
        'bn': 'ভারতে কোন রাজ্যের উপকূলরেখা সবচেয়ে দীর্ঘ?',
      },
      options: {
        'en': ['Tamil Nadu', 'Gujarat', 'Maharashtra', 'Andhra Pradesh'],
        'hi': ['তামিলনাড়ু', 'গুজরাট', 'মহারাষ্ট্র', 'অন্ধ্রপ্রদেশ'],
        'bn': ['তামিলনাড়ু', 'গুজরাট', 'মহারাষ্ট্র', 'অন্ধ্রপ্রদেশ'],
      },
      explanation: {
        'en': 'Gujarat has the longest coastline in India at about 1,600 km.',
        'hi': 'গুজরাটের উপকূলরেখা প্রায় 1,600 কিমি যা ভারতে সবচেয়ে দীর্ঘ।',
        'bn': 'গুজরাটের উপকূলরেখা প্রায় 1,600 কিমি যা ভারতে সবচেয়ে দীর্ঘ।',
      },
    ),
    QuestionModel(
      id: 'up19',
      order: 18,
      correctIndex: 3,
      category: 'Polity',
      difficulty: 'hard',
      examTags: ['UPSC'],
      text: {
        'en':
            'The power of the Supreme Court to review any act of the government is called:',
        'hi':
            'সরকারের যেকোনো আইন পর্যালোচনা করার সুপ্রিম কোর্টের ক্ষমতাকে কী বলা হয়?',
        'bn':
            'সরকারের যেকোনো আইন পর্যালোচনা করার সুপ্রিম কোর্টের ক্ষমতাকে কী বলা হয়?',
      },
      options: {
        'en': [
          'Original Jurisdiction',
          'Appellate Jurisdiction',
          'Judicial Review',
          'Public Interest Litigation'
        ],
        'hi': [
          'মূল এখতিয়ার',
          'আপীল এখতিয়ার',
          'বিচারব্যবস্থা পর্যালোচনা',
          'জনস্বার্থ মামলা'
        ],
        'bn': [
          'মূল এখতিয়ার',
          'আপীল এখতিয়ার',
          'বিচারব্যবস্থা পর্যালোচনা',
          'জনস্বার্থ মামলা'
        ],
      },
      explanation: {
        'en':
            'Judicial Review is the power of the Supreme Court to examine laws and government actions.',
        'hi':
            'বিচারব্যবস্থা পর্যালোচনা হল সুপ্রিম কোর্টের আইন ও সরকারি কার্যক্রম পরীক্ষা করার ক্ষমতা।',
        'bn':
            'বিচারব্যবস্থা পর্যালোচনা হল সুপ্রিম কোর্টের আইন ও সরকারি কার্যক্রম পরীক্ষা করার ক্ষমতা।',
      },
    ),
    QuestionModel(
      id: 'up20',
      order: 19,
      correctIndex: 0,
      category: 'Environment',
      difficulty: 'medium',
      examTags: ['UPSC'],
      text: {
        'en': 'Which is the first biosphere reserve in India?',
        'hi': 'ভারতের প্রথম বায়োস্ফিয়ার রিজার্ভ কোনটি?',
        'bn': 'ভারতের প্রথম বায়োস্ফিয়ার রিজার্ভ কোনটি?',
      },
      options: {
        'en': [
          'Nilgiri Biosphere Reserve',
          'Sundarbans Biosphere Reserve',
          'Nanda Devi',
          'Great Himalayan National Park'
        ],
        'hi': [
          'নীলগিরি বায়োস্ফিয়ার রিজার্ভ',
          'সুন্দরবন বায়োস্ফিয়ার রিজার্ভ',
          'নন্দা দেবী',
          'গ্রেট হিমালয় জাতীয় উদ্যান'
        ],
        'bn': [
          'নীলগিরি বায়োস্ফিয়ার রিজার্ভ',
          'সুন্দরবন বায়োস্ফিয়ার রিজার্ভ',
          'নন্দা দেবী',
          'গ্রেট হিমালয় জাতীয় উদ্যান'
        ],
      },
      explanation: {
        'en':
            'Nilgiri Biosphere Reserve (1986) was the first biosphere reserve in India.',
        'hi':
            'নীলগিরি বায়োস্ফিয়ার রিজার্ভ (1986) ছিল ভারতের প্রথম বায়োস্ফিয়ার রিজার্ভ।',
        'bn':
            'নীলগিরি বায়োস্ফিয়ার রিজার্ভ (1986) ছিল ভারতের প্রথম বায়োস্ফিয়ার রিজার্ভ।',
      },
    ),
  ];

  // ── BANK ──────────────────────────────────────────────────
  static const List<QuestionModel> _bankQuestions = [
    QuestionModel(
      id: 'bk01',
      order: 0,
      correctIndex: 2,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'What does NEFT stand for?',
        'hi': 'NEFT का पूर्ण रूप क्या है?',
        'bn': 'NEFT-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'National Electronic Fund Transaction',
          'National Easy Fund Transfer',
          'National Electronic Funds Transfer',
          'Net Electronic Funds Transfer'
        ],
        'hi': [
          'नेशनल इलेक्ट्रॉनिक फंड ट्रांजैक्शन',
          'नेशनल ईजी फंड ट्रांसफर',
          'नेशनल इलेक्ट्रॉनिक फंड्स ट्रांसफर',
          'नेट इलेक्ट्रॉनिक फंड्स ट्रांसफर'
        ],
        'bn': [
          'ন্যাশনাল ইলেক্ট্রনিক ফান্ড ট্র্যানজ্যাকশন',
          'ন্যাশনাল ইজি ফান্ড ট্রান্সফার',
          'ন্যাশনাল ইলেক্ট্রনিক ফান্ডস ট্রান্সফার',
          'নেট ইলেক্ট্রনিক ফান্ডস ট্রান্সফার'
        ],
      },
      explanation: {
        'en':
            'NEFT stands for National Electronic Funds Transfer — a payment system for transferring funds between bank accounts.',
        'hi': 'NEFT का मतलब है National Electronic Funds Transfer।',
        'bn':
            'NEFT মানে National Electronic Funds Transfer — ব্যাংক অ্যাকাউন্টের মধ্যে তহবিল স্থানান্তরের একটি পদ্ধতি।',
      },
    ),
    QuestionModel(
      id: 'bk02',
      order: 1,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'easy',
      examTags: ['BANK'],
      text: {
        'en': 'What is the full form of RBI?',
        'hi': 'RBI का पूर्ण रूप क्या है?',
        'bn': 'RBI-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'Reserve Bank of India',
          'Regional Bank of India',
          'Rural Bank of India',
          'Republic Bank of India'
        ],
        'hi': [
          'रिजर्व बैंक ऑफ इंडिया',
          'रीजनल बैंक ऑफ इंडिया',
          'रूरल बैंक ऑफ इंडिया',
          'रिपब्लिक बैंक ऑफ इंडिया'
        ],
        'bn': [
          'রিজার্ভ ব্যাংক অফ ইন্ডিয়া',
          'রিজিওনাল ব্যাংক অফ ইন্ডিয়া',
          'রুরাল ব্যাংক অফ ইন্ডিয়া',
          'রিপাবলিক ব্যাংক অফ ইন্ডিয়া'
        ],
      },
      explanation: {
        'en': 'RBI stands for Reserve Bank of India, established in 1935.',
        'hi': 'RBI का अर्थ है Reserve Bank of India, 1935 में स्थापित।',
        'bn': 'RBI মানে Reserve Bank of India, ১৯৩৫ সালে প্রতিষ্ঠিত।',
      },
    ),
    QuestionModel(
      id: 'bk03',
      order: 2,
      correctIndex: 1,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'Which is the largest public sector bank in India?',
        'hi': 'भारत में सबसे बड़ा सार्वजनिक क्षेत्र का बैंक कौन सा है?',
        'bn': 'ভারতের বৃহত্তম সরকারি ব্যাংক কোনটি?',
      },
      options: {
        'en': [
          'Punjab National Bank',
          'State Bank of India',
          'Bank of Baroda',
          'Canara Bank'
        ],
        'hi': [
          'पंजाब नेशनल बैंक',
          'भारतीय स्टेट बैंक',
          'बैंक ऑफ बड़ौदा',
          'कैनरा बैंक'
        ],
        'bn': [
          'পাঞ্জাব ন্যাশনাল ব্যাংক',
          'স্টেট ব্যাংক অফ ইন্ডিয়া',
          'ব্যাংক অফ বরোদা',
          'কানারা ব্যাংক'
        ],
      },
      explanation: {
        'en':
            'State Bank of India (SBI) is the largest public sector bank in India.',
        'hi': 'SBI भारत का सबसे बड़ा सार्वजनिक क्षेत्र का बैंक है।',
        'bn': 'SBI ভারতের বৃহত্তম সরকারি ব্যাংক।',
      },
    ),
    QuestionModel(
      id: 'bk04',
      order: 3,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en':
            'If Principal = ₹5000, Rate = 10%, Time = 2 years, what is Simple Interest?',
        'hi':
            'यदि मूलधन = ₹5000, दर = 10%, समय = 2 साल, तो साधारण ब्याज क्या है?',
        'bn': 'যদি আসল = ৫০০০ টাকা, হার = ১০%, সময় = ২ বছর হয়, সরল সুদ কত?',
      },
      options: {
        'en': ['₹500', '₹750', '₹1500', '₹1000'],
        'hi': ['₹500', '₹750', '₹1500', '₹1000'],
        'bn': ['৫০০ টাকা', '৭৫০ টাকা', '১৫০০ টাকা', '১০০০ টাকা'],
      },
      explanation: {
        'en': 'SI = (P × R × T) / 100 = (5000 × 10 × 2) / 100 = ₹1000.',
        'hi': 'SI = (5000 × 10 × 2) / 100 = ₹1000।',
        'bn': 'সরল সুদ = (5000 × 10 × 2) / 100 = ১০০০ টাকা।',
      },
    ),
    QuestionModel(
      id: 'bk05',
      order: 4,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'easy',
      examTags: ['BANK'],
      text: {
        'en':
            'What is the minimum balance generally required for a savings account in public banks?',
        'hi':
            'सार्वजनिक बैंकों में बचत खाते के लिए सामान्यतः न्यूनतम शेष राशि क्या आवश्यक है?',
        'bn':
            'সরকারি ব্যাংকে সেভিংস অ্যাকাউন্টে সাধারণত কত ন্যূনতম ব্যালেন্স রাখতে হয়?',
      },
      options: {
        'en': ['₹0 (Zero Balance Jan Dhan)', '₹500', '₹1000', '₹2000'],
        'hi': ['₹0 (जन धन)', '₹500', '₹1000', '₹2000'],
        'bn': ['০ টাকা (জন ধন)', '৫০০ টাকা', '১০০০ টাকা', '২০০০ টাকা'],
      },
      explanation: {
        'en':
            'Under PMJDY (Jan Dhan Yojana), zero-balance savings accounts are available.',
        'hi': 'PMJDY (जन धन योजना) के तहत शून्य-शेष बचत खाता उपलब्ध है।',
        'bn':
            'PMJDY (জন ধন যোজনা) এর অধীনে শূন্য ব্যালেন্সের সেভিংস অ্যাকাউন্ট পাওয়া যায়।',
      },
    ),
    QuestionModel(
      id: 'bk06',
      order: 5,
      correctIndex: 2,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'KYC stands for?',
        'hi': 'KYC का पूर्ण रूप क्या है?',
        'bn': 'KYC-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'Keep Your Customer',
          'Know Your Client',
          'Know Your Customer',
          'Keep Your Client'
        ],
        'hi': [
          'Keep Your Customer',
          'Know Your Client',
          'Know Your Customer',
          'Keep Your Client'
        ],
        'bn': [
          'Keep Your Customer',
          'Know Your Client',
          'Know Your Customer',
          'Keep Your Client'
        ],
      },
      explanation: {
        'en':
            'KYC stands for Know Your Customer — a process used by banks to verify their clients\' identities.',
        'hi': 'KYC का मतलब है Know Your Customer।',
        'bn':
            'KYC মানে Know Your Customer — ব্যাংক তাদের গ্রাহকের পরিচয় যাচাই করতে এই প্রক্রিয়া ব্যবহার করে।',
      },
    ),
    QuestionModel(
      id: 'bk07',
      order: 6,
      correctIndex: 1,
      category: 'Mathematics',
      difficulty: 'hard',
      examTags: ['BANK'],
      text: {
        'en':
            'A sum doubles in 8 years at simple interest. What is the rate of interest?',
        'hi':
            'एक राशि साधारण ब्याज पर 8 वर्षों में दोगुनी हो जाती है। ब्याज दर क्या है?',
        'bn': 'একটি টাকা সরল সুদে ৮ বছরে দ্বিগুণ হয়। সুদের হার কত?',
      },
      options: {
        'en': ['10%', '12.5%', '15%', '8%'],
        'hi': ['10%', '12.5%', '15%', '8%'],
        'bn': ['১০%', '১২.৫%', '১৫%', '৮%'],
      },
      explanation: {
        'en':
            'If P doubles in T years: Rate = 100/T = 100/8 = 12.5% per annum.',
        'hi': 'Rate = 100/T = 100/8 = 12.5% प्रति वर्ष।',
        'bn': 'হার = 100/T = 100/8 = 12.5% প্রতি বছর।',
      },
    ),
    QuestionModel(
      id: 'bk08',
      order: 7,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'What is the full form of ATM?',
        'hi': 'ATM का पूर्ण रूप क्या है?',
        'bn': 'ATM-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'Automated Teller Machine',
          'Automated Transaction Machine',
          'Automatic Transfer Machine',
          'Authorised Teller Machine'
        ],
        'hi': [
          'ऑटोमेटेड टेलर मशीन',
          'ऑटोमेटेड ट्रांजैक्शन मशीन',
          'ऑटोमैटिक ट्रांसफर मशीन',
          'ऑथराइज्ड टेलर मशीन'
        ],
        'bn': [
          'অটোমেটেড টেলার মেশিন',
          'অটোমেটেড ট্র্যানজ্যাকশন মেশিন',
          'অটোমেটিক ট্রান্সফার মেশিন',
          'অথোরাইজড টেলার মেশিন'
        ],
      },
      explanation: {
        'en': 'ATM stands for Automated Teller Machine.',
        'hi': 'ATM का मतलब है Automated Teller Machine।',
        'bn': 'ATM মানে Automated Teller Machine।',
      },
    ),
    QuestionModel(
      id: 'bk09',
      order: 8,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en':
            'If a number is increased by 20%, then decreased by 20%, the net change is:',
        'hi':
            'यदि किसी संख्या को 20% बढ़ाया जाए, फिर 20% घटाया जाए, तो शुद्ध परिवर्तन क्या होगा?',
        'bn':
            'কোনো সংখ্যা ২০% বাড়ানো হলে এবং তারপর ২০% কমানো হলে নেট পরিবর্তন:',
      },
      options: {
        'en': ['No change', '+4%', '+2%', '-4%'],
        'hi': ['कोई परिवर्तन नहीं', '+4%', '+2%', '-4%'],
        'bn': ['কোনো পরিবর্তন নেই', '+৪%', '+২%', '-৪%'],
      },
      explanation: {
        'en':
            'Net % change = -(r²/100) = -(400/100) = -4%. The number decreases by 4%.',
        'hi': 'Net % = -(r²/100) = -4%।',
        'bn': 'নেট % = -(r²/100) = -4%। সংখ্যাটি ৪% কমে।',
      },
    ),
    QuestionModel(
      id: 'bk10',
      order: 9,
      correctIndex: 1,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'IMPS allows money transfer:',
        'hi': 'IMPS পैसे ট্রांসফর করने की अनुमति देता है:',
        'bn': 'IMPS-এর মাধ্যমে অর্থ স্থানান্তর সম্ভব:',
      },
      options: {
        'en': [
          'Only on weekdays',
          '24×7 including holidays',
          'Only business hours',
          'Only weekends'
        ],
        'hi': [
          'केवल कार्यदिवस पर',
          '24×7 छुट्टियों सहित',
          'केवल कार्य समय में',
          'केवल सप्ताहांत'
        ],
        'bn': [
          'শুধু কার্যদিবসে',
          '২৪×৭ ছুটির দিনসহ',
          'শুধু কর্মঘণ্টায়',
          'শুধু সাপ্তাহিক ছুটিতে'
        ],
      },
      explanation: {
        'en':
            'IMPS (Immediate Payment Service) is available 24×7, 365 days including bank holidays.',
        'hi': 'IMPS 24×7, 365 दिन उपलब्ध है, बैंक छुट्टियों सहित।',
        'bn': 'IMPS ব্যাংকের ছুটির দিনসহ ২৪×৭, ৩৬৫ দিন উপলব্ধ।',
      },
    ),
    QuestionModel(
      id: 'bk11',
      order: 10,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'easy',
      examTags: ['BANK'],
      text: {
        'en': 'What does RTGS stand for?',
        'hi': 'RTGS का पूर्ण रूप क्या है?',
        'bn': 'RTGS-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'Real Time Gross Settlement',
          'Regional Transfer Gross Settlement',
          'Rapid Transfer Global System',
          'Real Time Global Settlement'
        ],
        'hi': [
          'Real Time Gross Settlement',
          'Regional Transfer Gross Settlement',
          'Rapid Transfer Global System',
          'Real Time Global Settlement'
        ],
        'bn': [
          'Real Time Gross Settlement',
          'Regional Transfer Gross Settlement',
          'Rapid Transfer Global System',
          'Real Time Global Settlement'
        ],
      },
      explanation: {
        'en':
            'RTGS stands for Real Time Gross Settlement, used for high-value transactions.',
        'hi':
            'RTGS মানে Real Time Gross Settlement, উচ্চ মূল্যের লেনদেনের জন্য ব্যবহৃত হয়।',
        'bn':
            'RTGS মানে Real Time Gross Settlement, উচ্চ মূল্যের লেনদেনের জন্য ব্যবহৃত হয়।',
      },
    ),
    QuestionModel(
      id: 'bk12',
      order: 11,
      correctIndex: 2,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en':
            'A shopkeeper sells an article at 20% profit. If he buys it for ₹500 and sells it for ₹700, what is his actual profit?',
        'hi':
            'একজন দোকানদার 20% লাভে একটি নিবন্ধ বিক্রি করেন। যদি তিনি এটি ₹500-এ কিনে ₹700-এ বিক্রি করেন, তাহলে তার প্রকৃত লাভ কত?',
        'bn':
            'একজন দোকানদার 20% লাভে একটি নিবন্ধ বিক্রি করেন। যদি তিনি এটি ₹500-এ কিনে ₹700-এ বিক্রি করেন, তাহলে তার প্রকৃত লাভ কত?',
      },
      options: {
        'en': ['20%', '30%', '40%', '25%'],
        'hi': ['20%', '30%', '40%', '25%'],
        'bn': ['20%', '30%', '40%', '25%'],
      },
      explanation: {
        'en': 'Actual profit % = (200/500) × 100 = 40%.',
        'hi': 'প্রকৃত লাভ % = (200/500) × 100 = 40%।',
        'bn': 'প্রকৃত লাভ % = (200/500) × 100 = 40%।',
      },
    ),
    QuestionModel(
      id: 'bk13',
      order: 12,
      correctIndex: 1,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'What is the current Repo Rate in India?',
        'hi': 'ভারতে বর্তমান রেপো রেট কত?',
        'bn': 'ভারতে বর্তমান রেপো রেট কত?',
      },
      options: {
        'en': ['5.50%', '6.50%', '7.00%', '6.00%'],
        'hi': ['5.50%', '6.50%', '7.00%', '6.00%'],
        'bn': ['5.50%', '6.50%', '7.00%', '6.00%'],
      },
      explanation: {
        'en': 'The Repo Rate is the rate at which RBI lends money to banks.',
        'hi': 'রেপো রেট হল সেই হার যেখানে RBI ব্যাংকগুলিকে টাকা ধার দেয়।',
        'bn': 'রেপো রেট হল সেই হার যেখানে RBI ব্যাংকগুলিকে টাকা ধার দেয়।',
      },
    ),
    QuestionModel(
      id: 'bk14',
      order: 13,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'Which organization issues currency notes in India?',
        'hi': 'ভারতে কোন সংস্থা মুদ্রা নোট জারি করে?',
        'bn': 'ভারতে কোন সংস্থা মুদ্রা নোট জারি করে?',
      },
      options: {
        'en': [
          'Reserve Bank of India',
          'State Bank of India',
          'Government of India',
          'Finance Ministry'
        ],
        'hi': [
          'ভারতীয় রিজার্ভ ব্যাংক',
          'স্টেট ব্যাংক অফ ইন্ডিয়া',
          'ভারত সরকার',
          'অর্থ মন্ত্রণালয়'
        ],
        'bn': [
          'ভারতীয় রিজার্ভ ব্যাংক',
          'স্টেট ব্যাংক অফ ইন্ডিয়া',
          'ভারত সরকার',
          'অর্থ মন্ত্রণালয়'
        ],
      },
      explanation: {
        'en': 'The Reserve Bank of India (RBI) issues currency notes in India.',
        'hi': 'ভারতীয় রিজার্ভ ব্যাংক (RBI) ভারতে মুদ্রা নোট জারি করে।',
        'bn': 'ভারতীয় রিজার্ভ ব্যাংক (RBI) ভারতে মুদ্রা নোট জারি করে।',
      },
    ),
    QuestionModel(
      id: 'bk15',
      order: 14,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'hard',
      examTags: ['BANK'],
      text: {
        'en':
            'The compound interest on ₹10,000 for 2 years at 10% per annum is:',
        'hi': 'বার্ষিক 10% হারে 2 বছরের জন্য ₹10,000-এর জটিল সুদ কত?',
        'bn': 'বার্ষিক 10% হারে 2 বছরের জন্য ₹10,000-এর জটিল সুদ কত?',
      },
      options: {
        'en': ['₹2,000', '₹2,100', '₹2,150', '₹2,100'],
        'hi': ['₹2,000', '₹2,100', '₹2,150', '₹2,100'],
        'bn': ['₹2,000', '₹2,100', '₹2,150', '₹2,100'],
      },
      explanation: {
        'en': 'CI = P(1 + r/100)^n - P = 10000(1.1)^2 - 10000 = ₹2,100.',
        'hi': 'CI = P(1 + r/100)^n - P = 10000(1.1)^2 - 10000 = ₹2,100।',
        'bn': 'CI = P(1 + r/100)^n - P = 10000(1.1)^2 - 10000 = ₹2,100।',
      },
    ),
    QuestionModel(
      id: 'bk16',
      order: 15,
      correctIndex: 1,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'What is the full form of NPCI?',
        'hi': 'NPCI-এর পূর্ণ রূপ কী?',
        'bn': 'NPCI-এর পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'National Payment Corporation of India',
          'National Payments Corporation of India',
          'New Payment Corporation of India',
          'National Payment Council of India'
        ],
        'hi': [
          'National Payment Corporation of India',
          'National Payments Corporation of India',
          'New Payment Corporation of India',
          'National Payment Council of India'
        ],
        'bn': [
          'National Payment Corporation of India',
          'National Payments Corporation of India',
          'New Payment Corporation of India',
          'National Payment Council of India'
        ],
      },
      explanation: {
        'en': 'NPCI stands for National Payments Corporation of India.',
        'hi': 'NPCI মানে National Payments Corporation of India।',
        'bn': 'NPCI মানে National Payments Corporation of India।',
      },
    ),
    QuestionModel(
      id: 'bk17',
      order: 16,
      correctIndex: 2,
      category: 'Banking Awareness',
      difficulty: 'easy',
      examTags: ['BANK'],
      text: {
        'en': 'UPI stands for:',
        'hi': 'UPI-এর অর্থ কী?',
        'bn': 'UPI-এর অর্থ কী?',
      },
      options: {
        'en': [
          'Universal Payment Interface',
          'Unified Payments Interface',
          'United Payment Interface',
          'Unique Payment Integration'
        ],
        'hi': [
          'Universal Payment Interface',
          'Unified Payments Interface',
          'United Payment Interface',
          'Unique Payment Integration'
        ],
        'bn': [
          'Universal Payment Interface',
          'Unified Payments Interface',
          'United Payment Interface',
          'Unique Payment Integration'
        ],
      },
      explanation: {
        'en':
            'UPI stands for Unified Payments Interface, a real-time payment system.',
        'hi':
            'UPI মানে Unified Payments Interface, একটি রিয়েল-টাইম পেমেন্ট সিস্টেম।',
        'bn':
            'UPI মানে Unified Payments Interface, একটি রিয়েল-টাইম পেমেন্ট সিস্টেম।',
      },
    ),
    QuestionModel(
      id: 'bk18',
      order: 17,
      correctIndex: 0,
      category: 'Banking Awareness',
      difficulty: 'hard',
      examTags: ['BANK'],
      text: {
        'en': 'Which is the largest Public Sector Bank in India after merger?',
        'hi': 'একত্রীকরণের পর ভারতের বৃহত্তম পাবলিক সেক্টর ব্যাংক কোনটি?',
        'bn': 'একত্রীকরণের পর ভারতের বৃহত্তম পাবলিক সেক্টর ব্যাংক কোনটি?',
      },
      options: {
        'en': [
          'State Bank of India',
          'Punjab National Bank',
          'Canara Bank',
          'Bank of Baroda'
        ],
        'hi': [
          'State Bank of India',
          'Punjab National Bank',
          'Canara Bank',
          'Bank of Baroda'
        ],
        'bn': [
          'State Bank of India',
          'Punjab National Bank',
          'Canara Bank',
          'Bank of Baroda'
        ],
      },
      explanation: {
        'en':
            'State Bank of India (SBI) remains the largest public sector bank in India.',
        'hi': 'State Bank of India (SBI) ভারতের বৃহত্তম পাবলিক সেক্টর ব্যাংক।',
        'bn': 'State Bank of India (SBI) ভারতের বৃহত্তম পাবলিক সেক্টর ব্যাংক।',
      },
    ),
    QuestionModel(
      id: 'bk19',
      order: 18,
      correctIndex: 3,
      category: 'Mathematics',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en':
            'A man buys an item for ₹800 and sells it at a loss of 15%. The selling price is:',
        'hi':
            'একজন মানুষ ₹800-এ একটি জিনিস কেনেন এবং 15% ক্ষতিতে বিক্রি করেন। বিক্রয় মূল্য কত?',
        'bn':
            'একজন মানুষ ₹800-এ একটি জিনিস কেনেন এবং 15% ক্ষতিতে বিক্রি করেন। বিক্রয় মূল্য কত?',
      },
      options: {
        'en': ['₹700', '₹720', '₹680', '₹680'],
        'hi': ['₹700', '₹720', '₹680', '₹680'],
        'bn': ['₹700', '₹720', '₹680', '₹680'],
      },
      explanation: {
        'en': 'SP = 800 × (100 - 15)/100 = 800 × 0.85 = ₹680.',
        'hi': 'SP = 800 × (100 - 15)/100 = 800 × 0.85 = ₹680।',
        'bn': 'SP = 800 × (100 - 15)/100 = 800 × 0.85 = ₹680।',
      },
    ),
    QuestionModel(
      id: 'bk20',
      order: 19,
      correctIndex: 1,
      category: 'Banking Awareness',
      difficulty: 'medium',
      examTags: ['BANK'],
      text: {
        'en': 'What is the full form of BSR code?',
        'hi': 'BSR কোডের পূর্ণ রূপ কী?',
        'bn': 'BSR কোডের পূর্ণ রূপ কী?',
      },
      options: {
        'en': [
          'Bank Service Routing Code',
          'Basic Statistical Return Code',
          'Bank Sort Routing Code',
          'Branch Standard Routing Code'
        ],
        'hi': [
          'Bank Service Routing Code',
          'Basic Statistical Return Code',
          'Bank Sort Routing Code',
          'Branch Standard Routing Code'
        ],
        'bn': [
          'Bank Service Routing Code',
          'Basic Statistical Return Code',
          'Bank Sort Routing Code',
          'Branch Standard Routing Code'
        ],
      },
      explanation: {
        'en':
            'BSR stands for Basic Statistical Return, used for tax deduction purposes.',
        'hi': 'BSR মানে Basic Statistical Return, কর কর্তনের জন্য ব্যবহৃত হয়।',
        'bn': 'BSR মানে Basic Statistical Return, কর কর্তনের জন্য ব্যবহৃত হয়।',
      },
    ),
  ];
}
