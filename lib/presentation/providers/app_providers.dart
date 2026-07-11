// lib/presentation/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/quiz_service.dart';
import '../../core/services/local_stats_service.dart';
import '../../core/services/question_tracking_service.dart';
import '../../core/services/gamification_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/question_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/firestore_models.dart';
import '../../data/models/gamification_models.dart';

// ── Service Providers ─────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final quizServiceProvider = Provider<QuizService>((ref) => QuizService());
final localStatsProvider =
    Provider<LocalStatsService>((ref) => LocalStatsService.instance);
final questionTrackingProvider = Provider<QuestionTrackingService>(
    (ref) => QuestionTrackingService.instance);
final gamificationServiceProvider =
    Provider<GamificationService>((ref) => GamificationService.instance);
final cloudSyncServiceProvider =
    Provider<CloudSyncService>((ref) => CloudSyncService.instance);
final questionServiceProvider =
    Provider<QuestionService>((ref) => QuestionService.instance);

// ── Auth State ────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  } catch (_) {
    return null;
  }
});

// Cloud-synced user stats provider
final cloudUserStatsProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  // Sync local stats to cloud after login
  try {
    await ref.read(cloudSyncServiceProvider).syncStatsToCloud();
  } catch (_) {}

  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  } catch (_) {
    return null;
  }
});

// ── Language State ────────────────────────────────────────────
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(AppConstants.defaultLanguage) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(AppConstants.prefLanguage) ??
        AppConstants.defaultLanguage;
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLanguage, lang);
  }
}

// ── Sound Settings State ────────────────────────────────────────
class SoundSettingsNotifier extends StateNotifier<SoundSettings> {
  SoundSettingsNotifier() : super(const SoundSettings()) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = SoundSettings(
      soundEnabled: prefs.getBool('soundEnabled') ?? true,
      tapFeedback: prefs.getBool('tapFeedback') ?? true,
      correctAnswerSound: prefs.getBool('correctAnswerSound') ?? true,
      wrongAnswerSound: prefs.getBool('wrongAnswerSound') ?? true,
    );
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', enabled);
  }

  Future<void> setTapFeedback(bool enabled) async {
    state = state.copyWith(tapFeedback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tapFeedback', enabled);
  }

  Future<void> setCorrectSound(bool enabled) async {
    state = state.copyWith(correctAnswerSound: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('correctAnswerSound', enabled);
  }

  Future<void> setWrongSound(bool enabled) async {
    state = state.copyWith(wrongAnswerSound: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wrongAnswerSound', enabled);
  }
}

class SoundSettings {
  final bool soundEnabled;
  final bool tapFeedback;
  final bool correctAnswerSound;
  final bool wrongAnswerSound;

  const SoundSettings({
    this.soundEnabled = true,
    this.tapFeedback = true,
    this.correctAnswerSound = true,
    this.wrongAnswerSound = true,
  });

  SoundSettings copyWith({
    bool? soundEnabled,
    bool? tapFeedback,
    bool? correctAnswerSound,
    bool? wrongAnswerSound,
  }) {
    return SoundSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      tapFeedback: tapFeedback ?? this.tapFeedback,
      correctAnswerSound: correctAnswerSound ?? this.correctAnswerSound,
      wrongAnswerSound: wrongAnswerSound ?? this.wrongAnswerSound,
    );
  }
}

final soundSettingsProvider =
    StateNotifierProvider<SoundSettingsNotifier, SoundSettings>((ref) {
  return SoundSettingsNotifier();
});

// ── Today's Quiz State ────────────────────────────────────────
final examModeProvider = StateProvider<String>((ref) => 'GENERAL');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ── Bookmarks State ───────────────────────────────────────────
class BookmarksNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  BookmarksNotifier() : super([]) {
    _loadBookmarks();
  }

  void _loadBookmarks() {
    state = BookmarkService().getAllBookmarks();
  }

  Future<void> toggle(
      String questionId, Map<String, dynamic> questionData) async {
    await BookmarkService().toggleBookmark(questionId, questionData);
    _loadBookmarks();
  }

  bool isBookmarked(String questionId) {
    return BookmarkService().isBookmarked(questionId);
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<Map<String, dynamic>>>((ref) {
  return BookmarksNotifier();
});

final todayQuizProvider = FutureProvider.autoDispose<QuizModel?>((ref) async {
  ref.keepAlive();
  final examMode = ref.watch(examModeProvider);

  // First try to get quiz from QuizSchedulerService (checks Firestore)
  final scheduler = QuizSchedulerService.instance;
  final quiz = await scheduler.prepareDailyQuiz(examMode);

  if (quiz != null) {
    return quiz;
  }

  // Fallback to QuizService if scheduler fails
  return ref.watch(quizServiceProvider).fetchTodayQuiz(examMode: examMode);
});

// ── Quiz Session State ────────────────────────────────────────
class QuizSessionState {
  final QuizModel quiz;
  final int currentIndex;
  final List<int?> selectedAnswers;
  final int remainingSeconds;
  final bool isSubmitting;
  final AttemptResult? result;
  final int totalTimeTaken;

  const QuizSessionState({
    required this.quiz,
    this.currentIndex = 0,
    required this.selectedAnswers,
    this.remainingSeconds = AppConstants.questionTimerSeconds,
    this.isSubmitting = false,
    this.result,
    this.totalTimeTaken = 0,
  });

  bool get isComplete => currentIndex >= quiz.questions.length;
  double get progress => currentIndex / quiz.questions.length;

  QuizSessionState copyWith({
    int? currentIndex,
    List<int?>? selectedAnswers,
    int? remainingSeconds,
    bool? isSubmitting,
    AttemptResult? result,
    int? totalTimeTaken,
  }) =>
      QuizSessionState(
        quiz: quiz,
        currentIndex: currentIndex ?? this.currentIndex,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        result: result ?? this.result,
        totalTimeTaken: totalTimeTaken ?? this.totalTimeTaken,
      );
}

final quizSessionProvider =
    StateNotifierProvider<QuizSessionNotifier, QuizSessionState?>((ref) {
  return QuizSessionNotifier(
      ref.watch(quizServiceProvider), ref.watch(localStatsProvider));
});

class QuizSessionNotifier extends StateNotifier<QuizSessionState?> {
  final QuizService _quizService;
  final LocalStatsService _localStats;
  QuizSessionNotifier(this._quizService, this._localStats) : super(null);

  void startQuiz(QuizModel quiz) {
    state = QuizSessionState(
      quiz: quiz,
      selectedAnswers: List.filled(quiz.questions.length, null),
    );
  }

  void selectAnswer(int questionIndex, int answerIndex) {
    if (state == null) return;
    final answers = List<int?>.from(state!.selectedAnswers);
    answers[questionIndex] = answerIndex;
    state = state!.copyWith(selectedAnswers: answers);
  }

  void nextQuestion() {
    if (state == null) return;
    state = state!.copyWith(
      currentIndex: state!.currentIndex + 1,
      remainingSeconds: AppConstants.questionTimerSeconds,
    );
  }

  void setRemainingSeconds(int seconds) {
    if (state == null) return;
    state = state!.copyWith(remainingSeconds: seconds);
  }

  Future<void> submitQuiz(int totalTimeTaken) async {
    if (state == null) return;
    state = state!.copyWith(isSubmitting: true);

    final answers = state!.selectedAnswers.map((a) => a ?? -1).toList();

    // Always pass questions for local scoring fallback
    final questions = state!.quiz.questions;

    try {
      AttemptResult? result;

      // Try submission with questions for local scoring fallback
      result = await _quizService.submitAttempt(
        quizId: state!.quiz.quizId,
        answers: answers,
        timeTaken: totalTimeTaken,
        questions: questions,
      );

      // Update local stats
      await _localStats.updateStreakOnQuizComplete();
      await _localStats.incrementTotalQuizzes();

      final score = result.score;

      await _localStats.updatePersonalBestIfNeeded(
          score, state!.quiz.questionCount);
      await _localStats.addToTotalScore(score);

      // Add to local leaderboard
      final playerName = 'You';
      await _localStats.addScoreToLeaderboard(
          playerName, score, totalTimeTaken);

      state = state!.copyWith(isSubmitting: false, result: result, totalTimeTaken: totalTimeTaken);
    } catch (e) {
      state = state!.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  int _calculateScore() {
    if (state == null) return 0;
    int score = 0;
    for (int i = 0; i < state!.quiz.questions.length; i++) {
      if (i < state!.selectedAnswers.length &&
          state!.selectedAnswers[i] == state!.quiz.questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  void reset() => state = null;
}

// ── Local Streak State ────────────────────────────────────────
final localStreakProvider = FutureProvider<LocalStreakData>((ref) async {
  return ref.watch(localStatsProvider).getStreak();
});

// ── Local Leaderboard State ───────────────────────────────────
final localLeaderboardProvider =
    FutureProvider<List<LeaderboardEntryLocal>>((ref) async {
  return ref.watch(localStatsProvider).getLocalLeaderboard();
});

// ── Personal Best (Local) ─────────────────────────────────────
final localPersonalBestProvider = FutureProvider<PersonalBestData>((ref) async {
  return ref.watch(localStatsProvider).getPersonalBest();
});

// ── Total Stats ────────────────────────────────────────────────
final totalQuizzesProvider = FutureProvider<int>((ref) async {
  return ref.watch(localStatsProvider).getTotalQuizzes();
});

final totalScoreProvider = FutureProvider<int>((ref) async {
  return ref.watch(localStatsProvider).getTotalScore();
});

// ── Pro Status ────────────────────────────────────────────────
final isProProvider = FutureProvider<bool>((ref) async {
  final box = await ref.watch(_hiveBoxProvider.future);
  return box.get(AppConstants.hiveKeyIsPro) == 'true';
});

final _hiveBoxProvider = FutureProvider((ref) async {
  return Hive.openBox<String>(AppConstants.hiveBoxUser);
});

// ── Achievements ──────────────────────────────────────────────
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  return ref.watch(questionTrackingProvider).getAchievements();
});

// ── Per-Mode Stats ──────────────────────────────────────────
final modeStatsProvider = FutureProvider<Map<String, ModeStats>>((ref) async {
  return ref.watch(questionTrackingProvider).getAllModeStats();
});

final currentModeStatsProvider = FutureProvider<ModeStats>((ref) async {
  final mode = ref.watch(examModeProvider);
  return ref.watch(questionTrackingProvider).getModeStats(mode);
});

// ── Practice Mode ───────────────────────────────────────────
final practiceQuestionCountProvider = StateProvider<int>((ref) => 10);
final practiceDifficultyProvider = StateProvider<String?>((ref) => null);

// ── Gamification Stats ───────────────────────────────────────
final userStatsProvider = FutureProvider<UserStatsModel>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  return service.getUserStats();
});

// ── Gamification Actions ─────────────────────────────────────
class GamificationNotifier extends StateNotifier<AsyncValue<UserStatsModel>> {
  final GamificationService _service;

  GamificationNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _service.getUserStats();
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> claimDailyReward() async {
    state = const AsyncValue.loading();
    try {
      final claimed = await _service.claimDailyReward();
      await _loadStats();
      return claimed;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> addXP(int xp) async {
    try {
      final stats = await _service.addXP(xp);
      state = AsyncValue.data(stats);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> addCoins(int coins) async {
    try {
      final stats = await _service.addCoins(coins);
      state = AsyncValue.data(stats);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> useLife() async {
    try {
      final stats = await _service.useLife();
      state = AsyncValue.data(stats);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> addLife() async {
    try {
      final stats = await _service.addLife();
      state = AsyncValue.data(stats);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> refresh() async {
    await _loadStats();
  }
}

final gamificationNotifierProvider =
    StateNotifierProvider<GamificationNotifier, AsyncValue<UserStatsModel>>(
        (ref) {
  return GamificationNotifier(ref.watch(gamificationServiceProvider));
});

// ── Power-ups ─────────────────────────────────────────────────
final powerUpsProvider = Provider<Map<PowerUpType, PowerUpModel>>((ref) {
  return ref.watch(gamificationServiceProvider).getPowerUps();
});

// ── Achievements List ─────────────────────────────────────────
final gamificationAchievementsProvider =
    Provider<List<AchievementModel>>((ref) {
  return ref.watch(gamificationServiceProvider).getAllAchievements();
});

// ── Referral Code ─────────────────────────────────────────────
final referralCodeProvider = Provider<String>((ref) {
  return ref.watch(gamificationServiceProvider).getReferralCode();
});

// ── Quiz Rewards Calculator ───────────────────────────────────
final quizRewardsProvider =
    FutureProvider.family<QuizRewards, QuizRewardParams>((ref, params) async {
  final service = ref.watch(gamificationServiceProvider);
  return service.calculateQuizRewards(
    score: params.score,
    totalQuestions: params.totalQuestions,
    timeTaken: params.timeTaken,
  );
});

class QuizRewardParams {
  final int score;
  final int totalQuestions;
  final int timeTaken;

  QuizRewardParams({
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizRewardParams &&
          runtimeType == other.runtimeType &&
          score == other.score &&
          totalQuestions == other.totalQuestions &&
          timeTaken == other.timeTaken;

  @override
  int get hashCode => Object.hash(score, totalQuestions, timeTaken);
}

// ── Daily Challenges ──────────────────────────────────────────
final dailyChallengesProvider = Provider<List<DailyChallengeModel>>((ref) {
  final now = DateTime.now();
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

  return [
    DailyChallengeModel(
      id: 'daily_quiz',
      title: 'Daily Quiz',
      description: 'Complete 1 quiz today',
      type: 'score',
      targetValue: 1,
      xpReward: 20,
      coinReward: 10,
      expiresAt: endOfDay,
    ),
    DailyChallengeModel(
      id: 'streak_3',
      title: '3-Day Streak',
      description: 'Maintain a 3-day streak',
      type: 'streak',
      targetValue: 3,
      xpReward: 50,
      coinReward: 25,
      expiresAt: endOfDay,
    ),
    DailyChallengeModel(
      id: 'speed_run',
      title: 'Speed Run',
      description: 'Complete a quiz in under 90 seconds',
      type: 'speed',
      targetValue: 1,
      xpReward: 30,
      coinReward: 15,
      expiresAt: endOfDay,
    ),
  ];
});

// ── Battle Mode State ─────────────────────────────────────────
final battleSessionProvider = StateProvider<BattleSessionModel?>((ref) => null);

final isInBattleProvider = Provider<bool>((ref) {
  final session = ref.watch(battleSessionProvider);
  return session != null && session.isInProgress;
});
