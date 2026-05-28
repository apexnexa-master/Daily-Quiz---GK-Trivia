// lib/data/models/firestore_models.dart
//
// FIRESTORE SCHEMA
// ─────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════
// USER MODEL (with Gamification)
// Collection: /users/{uid}
// ══════════════════════════════════════════════════════════════
class UserModel extends Equatable {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String language;
  final bool isPro;
  final bool isAnonymous;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime lastSeen;
  final int totalScore;
  final int totalAttempts;
  final String examMode;
  final int xp;
  final int level;
  final int coins;
  final int currentStreak;
  final int longestStreak;
  final int lives;
  final String? referralCode;
  final int referralCount;
  final List<String> unlockedAchievements;
  final DateTime? lastDailyReward;

  const UserModel({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.language = 'bn',
    this.isPro = false,
    this.isAnonymous = false,
    this.fcmToken,
    required this.createdAt,
    required this.lastSeen,
    this.totalScore = 0,
    this.totalAttempts = 0,
    this.examMode = 'GENERAL',
    this.xp = 0,
    this.level = 1,
    this.coins = 100,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lives = 3,
    this.referralCode,
    this.referralCount = 0,
    this.unlockedAchievements = const [],
    this.lastDailyReward,
  });

  bool get canClaimDailyReward {
    if (lastDailyReward == null) return true;
    return DateTime.now().difference(lastDailyReward!).inHours >= 24;
  }

  int get xpForNextLevel => (level + 1) * (level + 1) * 50;
  double get levelProgress =>
      xpForNextLevel > 0 ? (xp / xpForNextLevel).clamp(0.0, 1.0) : 0.0;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: d['display_name'] ?? 'Anonymous',
      email: d['email'],
      photoUrl: d['photo_url'],
      language: d['language'] ?? 'bn',
      isPro: d['is_pro'] ?? false,
      isAnonymous: d['is_anonymous'] ?? false,
      fcmToken: d['fcm_token'],
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (d['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalScore: d['total_score'] ?? 0,
      totalAttempts: d['total_attempts'] ?? 0,
      examMode: d['exam_mode'] ?? 'GENERAL',
      xp: d['xp'] ?? 0,
      level: d['level'] ?? 1,
      coins: d['coins'] ?? 100,
      currentStreak: d['current_streak'] ?? 0,
      longestStreak: d['longest_streak'] ?? 0,
      lives: d['lives'] ?? 3,
      referralCode: d['referral_code'],
      referralCount: d['referral_count'] ?? 0,
      unlockedAchievements: List<String>.from(d['unlocked_achievements'] ?? []),
      lastDailyReward: (d['last_daily_reward'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'display_name': displayName,
        'email': email,
        'photo_url': photoUrl,
        'language': language,
        'is_pro': isPro,
        'is_anonymous': isAnonymous,
        'fcm_token': fcmToken,
        'created_at': Timestamp.fromDate(createdAt),
        'last_seen': Timestamp.fromDate(lastSeen),
        'total_score': totalScore,
        'total_attempts': totalAttempts,
        'exam_mode': examMode,
        'xp': xp,
        'level': level,
        'coins': coins,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'lives': lives,
        'referral_code': referralCode,
        'referral_count': referralCount,
        'unlocked_achievements': unlockedAchievements,
        'last_daily_reward': lastDailyReward != null
            ? Timestamp.fromDate(lastDailyReward!)
            : null,
      };

  UserModel copyWith({
    String? language,
    bool? isPro,
    String? fcmToken,
    int? totalScore,
    int? totalAttempts,
    String? examMode,
    DateTime? lastSeen,
    int? xp,
    int? level,
    int? coins,
    int? currentStreak,
    int? longestStreak,
    int? lives,
    String? referralCode,
    int? referralCount,
    List<String>? unlockedAchievements,
    DateTime? lastDailyReward,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
        language: language ?? this.language,
        isPro: isPro ?? this.isPro,
        isAnonymous: isAnonymous,
        fcmToken: fcmToken ?? this.fcmToken,
        createdAt: createdAt,
        lastSeen: lastSeen ?? this.lastSeen,
        totalScore: totalScore ?? this.totalScore,
        totalAttempts: totalAttempts ?? this.totalAttempts,
        examMode: examMode ?? this.examMode,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        coins: coins ?? this.coins,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lives: lives ?? this.lives,
        referralCode: referralCode ?? this.referralCode,
        referralCount: referralCount ?? this.referralCount,
        unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
        lastDailyReward: lastDailyReward ?? this.lastDailyReward,
      );

  @override
  List<Object?> get props =>
      [uid, isPro, language, totalScore, xp, level, coins];
}

// ══════════════════════════════════════════════════════════════
// QUESTION MODEL  (i18n-first design)
// Subcollection: /quizzes/{quizId}/questions/{qId}
// ══════════════════════════════════════════════════════════════
//
// i18n design: All text stored in nested map keyed by locale.
// One document serves all 3 languages — no duplicate documents.
//
// Example JSON:
// {
//   "id": "q_001",
//   "text": {
//     "en": "Which state launched Orunodoi 2.0?",
//     "hi": "किस राज्य ने ओरुनोदोई 2.0 लॉन्च किया?",
//     "bn": "কোন রাজ্য 'অরুণোদই ২.০' চালু করেছে?"
//   },
//   "options": {
//     "en": ["Assam", "West Bengal", "Odisha", "Bihar"],
//     "hi": ["असम", "पश्चिम बंगाल", "ओडिशा", "बिहार"],
//     "bn": ["আসাম", "পশ্চিমবঙ্গ", "ওডিশা", "বিহার"]
//   },
//   "correct_index": 0,
//   "explanation": {
//     "en": "Assam's CM Himanta launched Orunodoi 2.0 providing ₹1,250/month to women.",
//     "hi": "असम के CM हिमंता ने महिलाओं को ₹1,250/माह देने के लिए ओरुनोदोई 2.0 लॉन्च किया।",
//     "bn": "আসামের মুখ্যমন্ত্রী হিমন্ত মহিলাদের ₹১,২৫০/মাস দেওয়ার জন্য অরুণোদই ২.০ চালু করেছেন।"
//   },
//   "category": "state_govt",
//   "difficulty": "medium",
//   "exam_tags": ["WBPSC", "SSC"],
//   "order": 1
// }
class QuestionModel extends Equatable {
  final String id;
  final Map<String, String> text; // locale → question text
  final Map<String, List<String>> options; // locale → [opt0, opt1, opt2, opt3]
  final int correctIndex;
  final Map<String, String> explanation;
  final String category;
  final String difficulty; // 'easy' | 'medium' | 'hard'
  final List<String> examTags;
  final int order;

  const QuestionModel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
    required this.difficulty,
    required this.examTags,
    required this.order,
  });

  // Convenience: get localised text
  String getText(String lang) => text[lang] ?? text['en'] ?? '';
  List<String> getOptions(String lang) => options[lang] ?? options['en'] ?? [];
  String getExplanation(String lang) =>
      explanation[lang] ?? explanation['en'] ?? '';

  QuestionModel shuffleOptions() {
    final newOptions = <String, List<String>>{};
    final newCorrectIndexMap = <String, int>{};

    for (final lang in options.keys) {
      final opts = List<String>.from(options[lang]!);
      final originalCorrect = opts[correctIndex];

      opts.shuffle();

      newOptions[lang] = opts;
      newCorrectIndexMap[lang] = opts.indexOf(originalCorrect);
    }

    return QuestionModel(
      id: id,
      text: text,
      options: newOptions,
      correctIndex: newCorrectIndexMap['en'] ?? correctIndex,
      explanation: explanation,
      category: category,
      difficulty: difficulty,
      examTags: examTags,
      order: order,
    );
  }

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      text: Map<String, String>.from(d['text'] ?? {}),
      options: (d['options'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      ),
      correctIndex: d['correct_index'] ?? 0,
      explanation: Map<String, String>.from(d['explanation'] ?? {}),
      category: d['category'] ?? 'general',
      difficulty: d['difficulty'] ?? 'medium',
      examTags: List<String>.from(d['exam_tags'] ?? []),
      order: d['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'text': text,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        'category': category,
        'difficulty': difficulty,
        'exam_tags': examTags,
        'order': order,
      };

  @override
  List<Object?> get props => [id, correctIndex];
}

// ══════════════════════════════════════════════════════════════
// QUIZ MODEL
// Collection: /quizzes/{quizId}   where quizId = 'YYYY-MM-DD_GENERAL'
// ══════════════════════════════════════════════════════════════
//
// Example JSON:
// {
//   "quiz_id": "2024-04-04_GENERAL",
//   "date": "2024-04-04",
//   "exam_mode": "GENERAL",
//   "status": "active",        // "draft" | "active" | "expired"
//   "question_count": 10,
//   "created_at": Timestamp,
//   "expires_at": Timestamp,   // next day 6:30 AM IST
//   "total_attempts": 1432
// }
// Questions are in SUBCOLLECTION: /quizzes/{quizId}/questions/
class QuizModel extends Equatable {
  final String quizId;
  final String date;
  final String examMode;
  final String status;
  final int questionCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int totalAttempts;
  final List<QuestionModel> questions; // loaded separately

  const QuizModel({
    required this.quizId,
    required this.date,
    required this.examMode,
    required this.status,
    required this.questionCount,
    required this.createdAt,
    required this.expiresAt,
    required this.totalAttempts,
    this.questions = const [],
  });

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';

  factory QuizModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuizModel(
      quizId: doc.id,
      date: d['date'] ?? '',
      examMode: d['exam_mode'] ?? 'GENERAL',
      status: d['status'] ?? 'draft',
      questionCount: d['question_count'] ?? 10,
      createdAt: (d['created_at'] as Timestamp).toDate(),
      expiresAt: (d['expires_at'] as Timestamp).toDate(),
      totalAttempts: d['total_attempts'] ?? 0,
    );
  }

  QuizModel copyWithQuestions(List<QuestionModel> qs) => QuizModel(
        quizId: quizId,
        date: date,
        examMode: examMode,
        status: status,
        questionCount: questionCount,
        createdAt: createdAt,
        expiresAt: expiresAt,
        totalAttempts: totalAttempts,
        questions: qs,
      );

  @override
  List<Object?> get props => [quizId, status];
}

// ══════════════════════════════════════════════════════════════
// ATTEMPT MODEL
// Subcollection: /users/{uid}/attempts/{attemptId}
// Also mirrored to /leaderboard/{date}_{uid} for ranking queries
// ══════════════════════════════════════════════════════════════
//
// Example JSON:
// {
//   "attempt_id": "uuid",
//   "uid": "abc123",
//   "quiz_id": "2024-04-04_GENERAL",
//   "quiz_date": "2024-04-04",
//   "exam_mode": "GENERAL",
//   "answers": [0, 2, 1, 3, 0, 1, 2, 0, 3, 1],
//   "score": 7,
//   "time_taken": 187,          // seconds total
//   "submitted_at": Timestamp,
//   "week_id": "2024-W14"
// }
class AttemptModel extends Equatable {
  final String attemptId;
  final String uid;
  final String quizId;
  final String quizDate;
  final String examMode;
  final List<int> answers;
  final int score;
  final int timeTaken; // seconds
  final DateTime submittedAt;
  final String weekId; // '2024-W14'

  const AttemptModel({
    required this.attemptId,
    required this.uid,
    required this.quizId,
    required this.quizDate,
    required this.examMode,
    required this.answers,
    required this.score,
    required this.timeTaken,
    required this.submittedAt,
    required this.weekId,
  });

  factory AttemptModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttemptModel(
      attemptId: doc.id,
      uid: d['uid'] ?? '',
      quizId: d['quiz_id'] ?? '',
      quizDate: d['quiz_date'] ?? '',
      examMode: d['exam_mode'] ?? 'GENERAL',
      answers: List<int>.from(d['answers'] ?? []),
      score: d['score'] ?? 0,
      timeTaken: d['time_taken'] ?? 0,
      submittedAt: (d['submitted_at'] as Timestamp).toDate(),
      weekId: d['week_id'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'quiz_id': quizId,
        'quiz_date': quizDate,
        'exam_mode': examMode,
        'answers': answers,
        'score': score,
        'time_taken': timeTaken,
        'submitted_at': Timestamp.fromDate(submittedAt),
        'week_id': weekId,
      };

  @override
  List<Object?> get props => [attemptId, score];
}

// ══════════════════════════════════════════════════════════════
// STREAK MODEL
// Subcollection: /users/{uid}/streak/current  (single doc)
// ══════════════════════════════════════════════════════════════
//
// Example JSON:
// {
//   "current_streak": 7,
//   "longest_streak": 12,
//   "last_attempt_date": "2024-04-03",
//   "updated_at": Timestamp
// }
class StreakModel extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final String lastAttemptDate; // 'YYYY-MM-DD'
  final DateTime updatedAt;

  const StreakModel({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastAttemptDate,
    required this.updatedAt,
  });

  factory StreakModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StreakModel(
      currentStreak: d['current_streak'] ?? 0,
      longestStreak: d['longest_streak'] ?? 0,
      lastAttemptDate: d['last_attempt_date'] ?? '',
      updatedAt: (d['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_attempt_date': lastAttemptDate,
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  @override
  List<Object?> get props => [currentStreak, longestStreak, lastAttemptDate];
}

// ══════════════════════════════════════════════════════════════
// LEADERBOARD ENTRY
// Collection: /leaderboard/{date}_{uid}
// ══════════════════════════════════════════════════════════════
//
// Example JSON:
// {
//   "uid": "abc123",
//   "display_name": "Rahim Uddin",
//   "photo_url": "...",
//   "score": 9,
//   "time_taken": 142,
//   "quiz_date": "2024-04-04",
//   "week_id": "2024-W14",
//   "rank": 1,
//   "exam_mode": "GENERAL"
// }
// INDEX: (quiz_date ASC, score DESC, time_taken ASC) for daily rank
// INDEX: (week_id ASC, score DESC, time_taken ASC) for weekly rank
class LeaderboardEntry extends Equatable {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int score;
  final int timeTaken;
  final String quizDate;
  final String weekId;
  final int rank;
  final String examMode;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.score,
    required this.timeTaken,
    required this.quizDate,
    required this.weekId,
    required this.rank,
    required this.examMode,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      uid: d['uid'] ?? '',
      displayName: d['display_name'] ?? '',
      photoUrl: d['photo_url'],
      score: d['score'] ?? 0,
      timeTaken: d['time_taken'] ?? 0,
      quizDate: d['quiz_date'] ?? '',
      weekId: d['week_id'] ?? '',
      rank: d['rank'] ?? 99,
      examMode: d['exam_mode'] ?? 'GENERAL',
    );
  }

  @override
  List<Object?> get props => [uid, quizDate, score];
}

// ══════════════════════════════════════════════════════════════
// CHALLENGE MODEL
// Collection: /challenges/{challengeId}
// ══════════════════════════════════════════════════════════════
//
// Example JSON:
// {
//   "challenge_id": "ch_uuid",
//   "quiz_id": "2024-04-04_GENERAL",
//   "created_by_uid": "abc123",
//   "created_by_name": "Rahim",
//   "challenger_score": 8,
//   "challenger_time": 145,
//   "deep_link": "https://gkquiz.yourapp.com/challenge/ch_uuid",
//   "created_at": Timestamp,
//   "expires_at": Timestamp,
//   "accepted_by": [],
//   "status": "open"   // "open" | "completed"
// }
class ChallengeModel extends Equatable {
  final String challengeId;
  final String quizId;
  final String createdByUid;
  final String createdByName;
  final int challengerScore;
  final int challengerTime;
  final String deepLink;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> acceptedBy;
  final String status;

  const ChallengeModel({
    required this.challengeId,
    required this.quizId,
    required this.createdByUid,
    required this.createdByName,
    required this.challengerScore,
    required this.challengerTime,
    required this.deepLink,
    required this.createdAt,
    required this.expiresAt,
    required this.acceptedBy,
    required this.status,
  });

  factory ChallengeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChallengeModel(
      challengeId: doc.id,
      quizId: d['quiz_id'] ?? '',
      createdByUid: d['created_by_uid'] ?? '',
      createdByName: d['created_by_name'] ?? '',
      challengerScore: d['challenger_score'] ?? 0,
      challengerTime: d['challenger_time'] ?? 0,
      deepLink: d['deep_link'] ?? '',
      createdAt: (d['created_at'] as Timestamp).toDate(),
      expiresAt: (d['expires_at'] as Timestamp).toDate(),
      acceptedBy: List<String>.from(d['accepted_by'] ?? []),
      status: d['status'] ?? 'open',
    );
  }

  @override
  List<Object?> get props => [challengeId, status];
}
