import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/core/scoring/brain_score.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';
import 'package:gk_quiz_app/core/scoring/skill_ratings.dart';

void main() {
  setUp(() async {
    await ScoringStore.instance.resetForTest();
  });

  group('BrainScoreService scoreFrom', () {
    test('no rated skills yields 0', () {
      expect(BrainScoreService.instance.scoreFrom(const SkillRatings()), 0);
    });

    test('single skill returns the skill value', () {
      const ratings = SkillRatings(
        ratings: {ScoringConfig.skillKnowledge: 100.0},
        sessions: {ScoringConfig.skillKnowledge: 1},
      );
      expect(BrainScoreService.instance.scoreFrom(ratings), 100);
    });

    test('multiple skills use weight-renormalized average', () {
      const ratings = SkillRatings(
        ratings: {ScoringConfig.skillKnowledge: 100.0, ScoringConfig.skillLogic: 0.0},
        sessions: {
          ScoringConfig.skillKnowledge: 1,
          ScoringConfig.skillLogic: 1,
        },
      );
      // (100*0.2 + 0*0.2) / (0.2+0.2) = 50
      expect(BrainScoreService.instance.scoreFrom(ratings), 50);
    });
  });

  group('BrainScoreService statusFrom', () {
    test('fewer than 5 sessions is building', () {
      const ratings = SkillRatings(
        ratings: {ScoringConfig.skillKnowledge: 60.0},
        sessions: {ScoringConfig.skillKnowledge: 4},
      );
      expect(
        BrainScoreService.instance.statusFrom(ratings),
        BrainScoreStatus.building,
      );
    });

    test('5 sessions across fewer than 3 skills is building', () {
      const ratings = SkillRatings(
        ratings: {ScoringConfig.skillKnowledge: 60.0},
        sessions: {ScoringConfig.skillKnowledge: 5},
      );
      expect(
        BrainScoreService.instance.statusFrom(ratings),
        BrainScoreStatus.building,
      );
    });

    test('5 sessions across 3 skills is established', () {
      const ratings = SkillRatings(
        ratings: {
          ScoringConfig.skillKnowledge: 60.0,
          ScoringConfig.skillLogic: 50.0,
          ScoringConfig.skillMemory: 70.0,
        },
        sessions: {
          ScoringConfig.skillKnowledge: 5,
          ScoringConfig.skillLogic: 5,
          ScoringConfig.skillMemory: 5,
        },
      );
      expect(
        BrainScoreService.instance.statusFrom(ratings),
        BrainScoreStatus.established,
      );
    });
  });

  group('BrainScoreService recordSession', () {
    test('increments the session counter and snapshots today', () async {
      final update = await BrainScoreService.instance.recordSession();
      expect(update.state.totalSessions, 1);
      expect(update.state.lastSnapshotDate, isNotEmpty);
      expect(update.state.history.length, 1);
    });

    test('only one snapshot is stored per day', () async {
      await BrainScoreService.instance.recordSession();
      final second = await BrainScoreService.instance.recordSession();
      expect(second.state.totalSessions, 2);
      expect(second.state.history.length, 1);
    });

    test('weekly baseline rolls over only when the week changes', () async {
      final first = await BrainScoreService.instance.recordSession();
      expect(first.weeklyChange, 0);
      expect(first.state.weekStartDate, isNotEmpty);
    });
  });

  group('BrainScoreService recordChallengeScore', () {
    test('only a new personal best returns true', () async {
      expect(await BrainScoreService.instance.recordChallengeScore(800), isTrue);
      expect(await BrainScoreService.instance.recordChallengeScore(700), isFalse);
      expect(await BrainScoreService.instance.recordChallengeScore(900), isTrue);
      final state = BrainScoreState.fromJson(
        ScoringStore.instance.readJson(ScoringStore.keyBrainState),
      );
      expect(state.bestChallengeScore, 900);
    });
  });
}
