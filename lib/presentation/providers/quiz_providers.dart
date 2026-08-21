// lib/presentation/providers/quiz_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/quiz_service.dart';
import '../../core/services/question_service.dart';
import '../../core/services/local_stats_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/firestore_models.dart';

import '../../core/services/analytics_service.dart';
import 'auth_providers.dart';
import 'stats_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final quizServiceProvider = Provider<QuizService>((ref) => QuizService());
final questionServiceProvider = Provider<QuestionService>((ref) => QuestionService.instance);
final localStatsProvider = Provider<LocalStatsService>((ref) => LocalStatsService.instance);

final examModeProvider = StateProvider<String>((ref) => 'GENERAL');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final todayQuizProvider = FutureProvider.autoDispose<QuizModel?>((ref) async {
  ref.keepAlive();
  final examMode = ref.watch(examModeProvider);
  return QuizSchedulerService.instance.prepareDailyQuiz(examMode);
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
  return QuizSessionNotifier(ref);
});

class QuizSessionNotifier extends StateNotifier<QuizSessionState?> {
  final Ref _ref;
  QuizSessionNotifier(this._ref) : super(null);

  QuizService get _quizService => _ref.read(quizServiceProvider);
  LocalStatsService get _localStats => _ref.read(localStatsProvider);

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

      // Leaderboard handling moved out: the normalized challenge score is now
      // written (locally) by ProgressionService.recordSession in the results
      // screen, and (globally) there too — raw per-game points must never be
      // pushed to a shared leaderboard. Workout quizzes never reach that path.

      // Fetch overall stats to calculate and save overall accuracy to Firestore
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
        try {
          _ref.invalidate(modeStatsProvider);
          final statsMap = await _ref.read(modeStatsProvider.future);
          int totalCorrect = 0;
          int totalQuestions = 0;
          statsMap.forEach((_, stats) {
            totalCorrect += stats.totalCorrect;
            totalQuestions += stats.totalQuestions;
          });
          final double newAccuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'accuracy': newAccuracy,
          });
        } catch (_) {}
      }

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
