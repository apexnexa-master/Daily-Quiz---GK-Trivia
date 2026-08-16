import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';
import 'package:gk_quiz_app/core/scoring/skill_ratings.dart';

void main() {
  setUp(() async {
    await ScoringStore.instance.resetForTest();
  });

  group('ScoringConfig', () {
    test('every game skill weight set sums to 1.0', () {
      ScoringConfig.validateGameSkillWeights();
      for (final entry in ScoringConfig.gameSkillWeights.entries) {
        final sum = entry.value.values.fold(0.0, (a, b) => a + b);
        expect(sum, closeTo(1.0, 0.001),
            reason: 'game "${entry.key}" weights must sum to 1.0');
      }
    });

    test('every configured game has a skill mapping', () {
      for (final game in const ['quiz', 'arrow', 'stroop', 'synapse', 'math', 'battle']) {
        expect(ScoringConfig.gameSkillWeights[game], isNotNull);
      }
    });
  });

  group('SkillRatingService', () {
    test('first quiz session moves knowledge by expected EWMA delta', () async {
      final result = await SkillRatingService.instance.applyGamePerformance(
        'quiz',
        80,
      );
      // 80 * 0.30 (new-user rate) * 0.70 (knowledge weight) = 16.8
      expect(result.deltas[ScoringConfig.skillKnowledge], closeTo(16.8, 0.001));
      // 80 * 0.30 * 0.30 (focus weight) = 7.2
      expect(result.deltas[ScoringConfig.skillFocus], closeTo(7.2, 0.001));
      expect(result.ratings.sessionCount(ScoringConfig.skillKnowledge), 1);
    });

    test('second session builds on the previous rating', () async {
      await SkillRatingService.instance.applyGamePerformance('quiz', 80);
      final result =
          await SkillRatingService.instance.applyGamePerformance('quiz', 50);
      // 16.8 + (50 - 16.8) * 0.30 * 0.70 = 23.772
      expect(
        result.ratings.rating(ScoringConfig.skillKnowledge),
        closeTo(23.772, 0.001),
      );
    });

    test('learning rate drops after the new-user threshold', () async {
      // First five sessions run at the new-user rate.
      for (var i = 0; i < 5; i++) {
        await SkillRatingService.instance.applyGamePerformance('quiz', 100);
      }
      final sixth =
          await SkillRatingService.instance.applyGamePerformance('quiz', 100);
      final deltaAfterNewUser = sixth.deltas[ScoringConfig.skillKnowledge]!;

      // A hypothetical new-user update on the same base would move more.
      final base = sixth.ratings.rating(ScoringConfig.skillKnowledge) - deltaAfterNewUser;
      final newUserDelta = (100 - base) * 0.30 * 0.70;
      expect(deltaAfterNewUser, lessThan(newUserDelta));
      // Normal rate: (100 - base) * 0.15 * 0.70
      final normalDelta = (100 - base) * 0.15 * 0.70;
      expect(deltaAfterNewUser, closeTo(normalDelta, 0.001));
    });

    test('unknown game throws a StateError', () {
      expect(
        () => SkillRatingService.instance.applyGamePerformance('nope', 80),
        throwsStateError,
      );
    });

    test('ratings persist through the store', () async {
      await SkillRatingService.instance.applyGamePerformance('quiz', 90);
      final reloaded = await SkillRatingService.instance.getRatings();
      expect(reloaded.sessionCount(ScoringConfig.skillKnowledge), 1);
      expect(reloaded.rating(ScoringConfig.skillKnowledge), closeTo(18.9, 0.001));
    });
  });
}
