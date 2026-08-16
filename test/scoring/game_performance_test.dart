import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/core/scoring/game_performance.dart';

void main() {
  group('QuizPerformanceInput', () {
    test('perfect run scores 100', () {
      final perf = GamePerformanceService.calculate(
        const QuizPerformanceInput(
          correct: 10,
          total: 10,
          timeTakenSeconds: 0,
          avgDifficulty: 100,
        ),
      );
      expect(perf, 100);
    });

    test('good run blends accuracy, difficulty and speed', () {
      final perf = GamePerformanceService.calculate(
        const QuizPerformanceInput(
          correct: 9,
          total: 10,
          timeTakenSeconds: 60,
          avgDifficulty: 70,
        ),
      );
      // 0.9*0.60 + 0.7*0.25 + 0.8*0.15 = 0.835 → 84
      expect(perf, 84);
    });

    test('zero total questions yields zero', () {
      expect(
        GamePerformanceService.calculate(
          const QuizPerformanceInput(correct: 5, total: 0),
        ),
        0,
      );
    });

    test('result is always clamped to 0-100', () {
      final perf = GamePerformanceService.calculate(
        const QuizPerformanceInput(
          correct: 10,
          total: 10,
          timeTakenSeconds: -5,
          avgDifficulty: 200,
        ),
      );
      expect(perf, 100);
    });
  });

  group('ArrowPerformanceInput', () {
    test('hard puzzle solved in time outranks easy puzzle solved instantly',
        () {
      final hard = GamePerformanceService.calculate(
        const ArrowPerformanceInput(
          level: 40,
          completed: true,
          timeSeconds: 8,
          movesUsed: 5,
          targetMoves: 5,
        ),
      );
      final easy = GamePerformanceService.calculate(
        const ArrowPerformanceInput(
          level: 5,
          completed: true,
          timeSeconds: 1,
          movesUsed: 5,
          targetMoves: 5,
        ),
      );
      expect(hard, greaterThan(easy));
    });

    test('failed level scores only the difficulty component', () {
      final failed = GamePerformanceService.calculate(
        const ArrowPerformanceInput(level: 50),
      );
      final completed = GamePerformanceService.calculate(
        const ArrowPerformanceInput(
          level: 50,
          completed: true,
          timeSeconds: 22,
          movesUsed: 10,
          targetMoves: 10,
        ),
      );
      expect(failed, greaterThan(0));
      expect(completed, greaterThan(failed));
    });

    test('hints reduce the quality component', () {
      final clean = GamePerformanceService.calculate(
        const ArrowPerformanceInput(
          level: 10,
          completed: true,
          timeSeconds: 22,
          movesUsed: 10,
          targetMoves: 10,
        ),
      );
      final hinted = GamePerformanceService.calculate(
        const ArrowPerformanceInput(
          level: 10,
          completed: true,
          timeSeconds: 22,
          movesUsed: 10,
          targetMoves: 10,
          hintsUsed: 5,
        ),
      );
      expect(clean, greaterThan(hinted));
    });
  });

  group('StroopPerformanceInput', () {
    test('fast reaction beats slow reaction at equal accuracy', () {
      final fast = GamePerformanceService.calculate(
        const StroopPerformanceInput(
          correct: 20,
          totalAttempts: 20,
          avgReactionMs: 250,
          difficulty: 3,
        ),
      );
      final slow = GamePerformanceService.calculate(
        const StroopPerformanceInput(
          correct: 20,
          totalAttempts: 20,
          avgReactionMs: 900,
          difficulty: 3,
        ),
      );
      expect(fast, greaterThan(slow));
    });

    test('zero attempts yields zero', () {
      expect(
        GamePerformanceService.calculate(
          const StroopPerformanceInput(correct: 0, totalAttempts: 0),
        ),
        0,
      );
    });
  });

  group('SynapsePerformanceInput', () {
    test('longer sequence with full accuracy scores 100', () {
      expect(
        GamePerformanceService.calculate(
          const SynapsePerformanceInput(
            maxSequenceLength: 9,
            correctRounds: 8,
            totalRounds: 8,
          ),
        ),
        100,
      );
    });

    test('zero rounds yields zero', () {
      expect(
        GamePerformanceService.calculate(
          const SynapsePerformanceInput(
            maxSequenceLength: 0,
            correctRounds: 0,
            totalRounds: 0,
          ),
        ),
        0,
      );
    });
  });

  group('MathPerformanceInput', () {
    test('fast answers beat slow answers at equal accuracy', () {
      final fast = GamePerformanceService.calculate(
        const MathPerformanceInput(
          correct: 30,
          totalAttempts: 30,
          maxLevel: 5,
          avgTimePerAnswerSeconds: 2,
        ),
      );
      final slow = GamePerformanceService.calculate(
        const MathPerformanceInput(
          correct: 30,
          totalAttempts: 30,
          maxLevel: 5,
          avgTimePerAnswerSeconds: 6,
        ),
      );
      expect(fast, greaterThan(slow));
    });

    test('zero attempts yields zero', () {
      expect(
        GamePerformanceService.calculate(
          const MathPerformanceInput(correct: 0, totalAttempts: 0),
        ),
        0,
      );
    });
  });

  group('BattlePerformanceInput', () {
    test('delegates to the quiz formula', () {
      final battle = GamePerformanceService.calculate(
        const BattlePerformanceInput(correct: 7, total: 10),
      );
      final quiz = GamePerformanceService.calculate(
        const QuizPerformanceInput(correct: 7, total: 10),
      );
      expect(battle, quiz);
    });
  });
}
