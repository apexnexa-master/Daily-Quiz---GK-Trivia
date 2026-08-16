import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gk_quiz_app/core/scoring/scoring_config.dart';
import 'package:gk_quiz_app/core/scoring/scoring_store.dart';
import 'package:gk_quiz_app/core/scoring/xp_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoringStore.instance.resetForTest();
    await XPService.instance.resetDaily();
  });

  group('XPService mode values', () {
    test('base XP per mode', () {
      expect(XPService.instance.xpForMode(SessionMode.practice),
          ScoringConfig.practiceXp);
      expect(XPService.instance.xpForMode(SessionMode.dailyChallenge),
          ScoringConfig.dailyChallengeXp);
      expect(XPService.instance.xpForMode(SessionMode.battle),
          ScoringConfig.battleXp);
      expect(XPService.instance.xpForMode(SessionMode.workoutGame), 0);
    });
  });

  group('XPService practice anti-farming', () {
    test('full XP for the first few practice sessions', () async {
      for (var i = 0; i < ScoringConfig.practiceFullXpCount; i++) {
        final award = await XPService.instance.award(SessionMode.practice);
        expect(award.granted, ScoringConfig.practiceXp);
      }
    });

    test('half XP next, then quarter XP', () async {
      for (var i = 0; i < ScoringConfig.practiceFullXpCount; i++) {
        final award = await XPService.instance.award(SessionMode.practice);
        expect(award.granted, ScoringConfig.practiceXp);
      }
      for (var i = 0; i < ScoringConfig.practiceHalfXpCount; i++) {
        final award = await XPService.instance.award(SessionMode.practice);
        expect(award.granted, (ScoringConfig.practiceXp / 2).round());
      }
      final diminished =
          await XPService.instance.award(SessionMode.practice);
      expect(diminished.granted,
          (ScoringConfig.practiceXp * ScoringConfig.practiceDiminishedMultiplier)
              .round());
    });
  });

  group('XPService daily cap', () {
    test('award stops once the daily cap is reached', () async {
      const times =
          ScoringConfig.dailyXpCap ~/ ScoringConfig.dailyChallengeXp;
      for (var i = 0; i < times; i++) {
        await XPService.instance.award(SessionMode.dailyChallenge);
      }
      final capped = await XPService.instance.award(SessionMode.dailyChallenge);
      expect(capped.granted, 0);
      expect(capped.capped, isTrue);
      expect(await XPService.instance.xpToday(), ScoringConfig.dailyXpCap);
      expect(await XPService.instance.remainingToday(), 0);
    });

    test('partial grant fills the remaining budget', () async {
      for (var i = 0; i < 5; i++) {
        await XPService.instance.award(SessionMode.dailyChallenge);
      }
      // 250 XP banked, a 50 XP award is fully granted...
      final ok = await XPService.instance.award(SessionMode.dailyChallenge);
      expect(ok.granted, 50);
      expect(ok.capped, isFalse);
      // ...and the next one only gets the remaining 0.
      final capped = await XPService.instance.award(SessionMode.dailyChallenge);
      expect(capped.granted, 0);
      expect(capped.capped, isTrue);
    });
  });

  group('XPService awardWorkout', () {
    test('base + performance component', () async {
      final award = await XPService.instance.awardWorkout(
        overallScore: 100,
        completedCount: 2,
        plannedCount: 3,
      );
      expect(award.granted,
          ScoringConfig.workoutXp + (100 * 0.2).round());
    });

    test('perfect session adds the perfect bonus', () async {
      final award = await XPService.instance.awardWorkout(
        overallScore: 100,
        completedCount: 3,
        plannedCount: 3,
      );
      expect(
        award.granted,
        ScoringConfig.workoutXp + (100 * 0.2).round() + ScoringConfig.perfectBonusXp,
      );
    });

    test('respects the daily cap', () async {
      // Bank 290 of 300, then a ~90 XP workout is capped at 10.
      for (var i = 0; i < 4; i++) {
        await XPService.instance.award(SessionMode.dailyChallenge);
      }
      await XPService.instance.award(SessionMode.dailyChallenge);
      // 250 now; add one more 50 → 300.
      await XPService.instance.award(SessionMode.dailyChallenge);
      final award = await XPService.instance.awardWorkout(
        overallScore: 100,
        completedCount: 2,
        plannedCount: 2,
      );
      expect(award.granted, 0);
      expect(award.capped, isTrue);
    });
  });
}
