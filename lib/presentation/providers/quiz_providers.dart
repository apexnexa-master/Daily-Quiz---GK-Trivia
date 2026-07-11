// lib/presentation/providers/quiz_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/quiz_service.dart';
import '../../core/services/question_service.dart';
import '../../core/services/local_stats_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/firestore_models.dart';

import '../../core/services/analytics_service.dart';

final quizServiceProvider = Provider<QuizService>((ref) => QuizService());
final questionServiceProvider = Provider<QuestionService>((ref) => QuestionService.instance);
final localStatsProvider = Provider<LocalStatsService>((ref) => LocalStatsService.instance);

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

  Future<void> toggle(String questionId, Map<String, dynamic> questionData) async {
    await BookmarkService().toggleBookmark(questionId, questionData);
    _loadBookmarks();
  }

  bool isBookmarked(String questionId) {
    return BookmarkService().isBookmarked(questionId);
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<Map<String, dynamic>>>((ref) {
  return BookmarksNotifier();
});

final todayQuizProvider = FutureProvider.autoDispose<QuizModel?>((ref) async {
  ref.keepAlive();
  final examMode = ref.watch(examModeProvider);

  final scheduler = QuizSchedulerService.instance;
  final quiz = await scheduler.prepareDailyQuiz(examMode);

  if (quiz != null) {
    return quiz;
  }

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

final quizSessionProvider = StateNotifierProvider<QuizSessionNotifier, QuizSessionState?>((ref) {
  return QuizSessionNotifier(ref.watch(quizServiceProvider), ref.watch(localStatsProvider));
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
    AnalyticsService.instance.logQuizStarted(quiz.quizId, quiz.examMode);
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
    final questions = state!.quiz.questions;

    try {
      final result = await _quizService.submitAttempt(
        quizId: state!.quiz.quizId,
        answers: answers,
        timeTaken: totalTimeTaken,
        questions: questions,
      );

      await _localStats.updateStreakOnQuizComplete();
      await _localStats.incrementTotalQuizzes();

      final score = result.score;
      await _localStats.updatePersonalBestIfNeeded(score, state!.quiz.questionCount);
      await _localStats.addToTotalScore(score);

      const playerName = 'You';
      await _localStats.addScoreToLeaderboard(playerName, score, totalTimeTaken);

      state = state!.copyWith(isSubmitting: false, result: result, totalTimeTaken: totalTimeTaken);
      
      AnalyticsService.instance.logQuizCompleted(
        quizId: state!.quiz.quizId,
        mode: state!.quiz.examMode,
        score: result.score,
        totalQuestions: state!.quiz.questionCount,
        timeTaken: totalTimeTaken,
      );
    } catch (e) {
      state = state!.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  void reset() => state = null;
}

// ── Practice Mode ───────────────────────────────────────────
final practiceQuestionCountProvider = StateProvider<int>((ref) => 10);
final practiceDifficultyProvider = StateProvider<String?>((ref) => null);
