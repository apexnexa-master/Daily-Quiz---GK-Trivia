// lib/core/services/quiz_scheduler_service.dart
import '../../data/models/firestore_models.dart';
import 'quiz/quiz_timing_manager.dart';
import 'quiz/quiz_generator.dart';

class QuizSchedulerService {
  static final QuizSchedulerService instance = QuizSchedulerService._();
  QuizSchedulerService._();

  final _timingManager = QuizTimingManager.instance;
  final _quizGenerator = QuizGenerator.instance;

  Future<void> refreshTiming() => _timingManager.refreshTiming();
  
  int get quizStartHour => _timingManager.quizStartHour;
  int get quizStartMinute => _timingManager.quizStartMinute;
  int get quizEndHour => _timingManager.quizEndHour;
  int get quizEndMinute => _timingManager.quizEndMinute;

  bool isQuizActive() => _timingManager.isQuizActive();
  bool canShowAnswers() => _timingManager.canShowAnswers();
  Future<bool> isNewQuizAvailable() => _timingManager.isNewQuizAvailable();
  Duration getTimeUntilNextQuiz() => _timingManager.getTimeUntilNextQuiz();
  String getCountdownString() => _timingManager.getCountdownString();

  Future<QuizModel?> prepareDailyQuiz(String examMode) =>
      _quizGenerator.prepareDailyQuiz(examMode);
}
