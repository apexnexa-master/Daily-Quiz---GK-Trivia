import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gk_quiz_app/core/scoring/activity_service.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoringStore.instance.resetForTest();
  });

  group('ActivityService', () {
    test('starts empty', () async {
      final stats = await ActivityService.instance.current();
      expect(stats.gamesPlayed, 0);
      expect(stats.workoutsCompleted, 0);
      expect(stats.dailyChallengesCompleted, 0);
      expect(stats.trainingSeconds, 0);
    });

    test('recordGame increments games and training time', () async {
      await ActivityService.instance.recordGame(trainingSeconds: 45);
      await ActivityService.instance.recordGame(trainingSeconds: 15);
      final stats = await ActivityService.instance.current();
      expect(stats.gamesPlayed, 2);
      expect(stats.trainingSeconds, 60);
    });

    test('recordDailyChallenge increments challenges and games', () async {
      await ActivityService.instance.recordDailyChallenge(trainingSeconds: 60);
      final stats = await ActivityService.instance.current();
      expect(stats.dailyChallengesCompleted, 1);
      expect(stats.gamesPlayed, 1);
      expect(stats.trainingSeconds, 60);
    });

    test('recordWorkout increments workouts only', () async {
      await ActivityService.instance.recordWorkout(trainingSeconds: 300);
      final stats = await ActivityService.instance.current();
      expect(stats.workoutsCompleted, 1);
      expect(stats.gamesPlayed, 0);
      expect(stats.trainingSeconds, 300);
    });

    test('counters persist across instances', () async {
      await ActivityService.instance.recordGame(trainingSeconds: 30);
      final stats = await ActivityService.instance.current();
      expect(stats.gamesPlayed, 1);
      expect(stats.trainingSeconds, 30);
    });
  });
}
