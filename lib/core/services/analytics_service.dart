// lib/core/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import '../utils/app_logger.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logEvent(
        name: 'screen_view_custom',
        parameters: {'screen_name': screenName},
      );
      AppLogger.info('Logged Screen View: $screenName', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log Screen View', error: e, name: 'ANALYTICS');
    }
  }

  Future<void> logQuizStarted(String quizId, String mode) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_started',
        parameters: {
          'quiz_id': quizId,
          'exam_mode': mode,
        },
      );
      AppLogger.info('Logged Quiz Started: $quizId ($mode)', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log Quiz Started', error: e, name: 'ANALYTICS');
    }
  }

  Future<void> logQuizCompleted({
    required String quizId,
    required String mode,
    required int score,
    required int totalQuestions,
    required int timeTaken,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_completed',
        parameters: {
          'quiz_id': quizId,
          'exam_mode': mode,
          'score': score,
          'total_questions': totalQuestions,
          'time_taken_seconds': timeTaken,
        },
      );
      AppLogger.info('Logged Quiz Completed: $quizId (Score: $score/$totalQuestions)', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log Quiz Completed', error: e, name: 'ANALYTICS');
    }
  }

  Future<void> logAchievementUnlocked(String id) async {
    try {
      await _analytics.logEvent(
        name: 'achievement_unlocked',
        parameters: {'achievement_id': id},
      );
      AppLogger.info('Logged Achievement Unlocked: $id', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log Achievement Unlocked', error: e, name: 'ANALYTICS');
    }
  }

  Future<void> logPowerUpUsed(String powerUpType) async {
    try {
      await _analytics.logEvent(
        name: 'powerup_used',
        parameters: {'powerup_type': powerUpType},
      );
      AppLogger.info('Logged PowerUp Used: $powerUpType', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log PowerUp Used', error: e, name: 'ANALYTICS');
    }
  }

  Future<void> logAdWatched(String adType) async {
    try {
      await _analytics.logEvent(
        name: 'ad_watched',
        parameters: {'ad_type': adType},
      );
      AppLogger.info('Logged Ad Watched: $adType', name: 'ANALYTICS');
    } catch (e) {
      AppLogger.error('Failed to log Ad Watched', error: e, name: 'ANALYTICS');
    }
  }

  /// Fired for every scored session so the scoring system can be audited
  /// (spec §40): average performance, mode mix, challenge participation and
  /// suspicious submissions can all be monitored from these events.
  Future<void> logSessionScored({
    required String gameId,
    required String mode,
    required int performanceScore,
    required int challengeScore,
    required int durationSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'session_scored',
        parameters: {
          'game_id': gameId,
          'mode': mode,
          'performance_score': performanceScore,
          'challenge_score': challengeScore,
          'session_duration': durationSeconds,
        },
      );
      AppLogger.info(
        'Logged Session Scored: $gameId perf=$performanceScore '
        'challenge=$challengeScore',
        name: 'ANALYTICS',
      );
    } catch (e) {
      AppLogger.error('Failed to log Session Scored', error: e, name: 'ANALYTICS');
    }
  }

  /// Fired when a workout completes (spec §40 workout completion rate).
  Future<void> logWorkoutCompleted({
    required int overallScore,
    required int completedCount,
    required int plannedCount,
    required int xpGranted,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'workout_completed',
        parameters: {
          'overall_score': overallScore,
          'completed_count': completedCount,
          'planned_count': plannedCount,
          'xp_granted': xpGranted,
        },
      );
      AppLogger.info(
        'Logged Workout Completed: score=$overallScore '
        '($completedCount/$plannedCount)',
        name: 'ANALYTICS',
      );
    } catch (e) {
      AppLogger.error('Failed to log Workout Completed', error: e, name: 'ANALYTICS');
    }
  }
}
