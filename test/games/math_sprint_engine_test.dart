// test/games/math_sprint_engine_test.dart
// Unit tests for the pure-Dart Math Sprint engine. The engine must never
// produce an invalid problem, must never crash on any input, and its scoring
// rules must hold exactly as documented.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/math_sprint/math_sprint_engine.dart';

/// Answers the current problem correctly with a fixed [elapsedFraction].
void answerCorrect(MathSprintEngine engine, {double elapsedFraction = 0.3}) {
  final problem = engine.currentProblem!;
  final idx = problem.options.indexOf(problem.answer);
  expect(idx, greaterThanOrEqualTo(0), reason: 'answer must be in options');
  final outcome = engine.submitAnswer(idx, elapsedFraction: elapsedFraction);
  expect(outcome.correct, isTrue);
}

/// Repeats the per-problem flow until [totalCorrect] correct answers are in.
void rackUpCorrect(MathSprintEngine engine, int totalCorrect) {
  for (var i = 0; i < totalCorrect; i++) {
    engine.next();
    answerCorrect(engine);
  }
}

void main() {
  group('problem generation', () {
    test('every problem is valid', () {
      final engine = MathSprintEngine(random: Random(42));
      for (var i = 0; i < 500; i++) {
        final p = engine.next();
        expect(p.options.length, 4);
        expect(p.options.toSet().length, 4, reason: 'options must be unique');
        expect(p.answer, inInclusiveRange(0, 100000));
        expect(p.options, contains(p.answer));
        for (final o in p.options) {
          expect(o, greaterThanOrEqualTo(0), reason: 'no negative options');
        }
        expect(p.expression, contains(p.symbol));
      }
    });

    test('level 1 only generates addition', () {
      final engine = MathSprintEngine(random: Random(1));
      for (var i = 0; i < 300; i++) {
        final p = engine.next();
        expect(p.operator, MathOperator.add);
        expect(p.a, inInclusiveRange(1, 20));
        expect(p.b, inInclusiveRange(1, 20));
        expect(p.answer, p.a + p.b);
      }
    });

    test('division is always exact and subtraction never negative', () {
      final engine = MathSprintEngine(random: Random(7));
      rackUpCorrect(engine, 21); // reach level 5
      for (var i = 0; i < 400; i++) {
        final p = engine.next();
        switch (p.operator) {
          case MathOperator.divide:
            expect(p.a % p.b, 0);
            expect(p.answer, p.a ~/ p.b);
          case MathOperator.subtract:
            expect(p.a - p.b, p.answer);
            expect(p.answer, greaterThanOrEqualTo(0));
          case MathOperator.add:
            expect(p.answer, p.a + p.b);
          case MathOperator.multiply:
            expect(p.answer, p.a * p.b);
        }
      }
    });

    test('operators unlock progressively', () {
      final engine = MathSprintEngine(random: Random(3));
      final allowed = <MathOperator>{MathOperator.add};
      for (var correct = 0; correct < 25; correct++) {
        for (var i = 0; i < 20; i++) {
          final p = engine.next();
          expect(allowed, contains(p.operator));
        }
        if (correct == 4) allowed.add(MathOperator.subtract); // level 2
        if (correct == 9) allowed.add(MathOperator.multiply); // level 3
        if (correct == 14) allowed.add(MathOperator.divide); // level 4
        answerCorrect(engine);
      }
    });
  });

  group('scoring', () {
    test('instant correct on level 1 scores base + full speed bonus', () {
      final engine = MathSprintEngine(random: Random(9));
      engine.next();
      final problem = engine.currentProblem!;
      final outcome = engine.submitAnswer(
        problem.options.indexOf(problem.answer),
        elapsedFraction: 0.0,
      );
      expect(outcome.correct, isTrue);
      expect(outcome.points, 10 + 10); // base(level1) + speed(10)
      expect(engine.score, 20);
    });

    test('slow correct answer earns fewer speed points', () {
      final engine = MathSprintEngine(random: Random(10));
      engine.next();
      final problem = engine.currentProblem!;
      final outcome = engine.submitAnswer(
        problem.options.indexOf(problem.answer),
        elapsedFraction: 0.9,
      );
      expect(outcome.correct, isTrue);
      expect(outcome.points, 10 + 1);
    });

    test('combo multiplier applies from 4-streak upward', () {
      expect(MathSprintEngine.comboMultiplierFor(0), 1);
      expect(MathSprintEngine.comboMultiplierFor(3), 1);
      expect(MathSprintEngine.comboMultiplierFor(4), 2);
      expect(MathSprintEngine.comboMultiplierFor(7), 2);
      expect(MathSprintEngine.comboMultiplierFor(8), 3);
      expect(MathSprintEngine.comboMultiplierFor(11), 3);
      expect(MathSprintEngine.comboMultiplierFor(12), 4);
    });

    test('fourth consecutive correct uses x2 multiplier', () {
      final engine = MathSprintEngine(random: Random(11));
      for (var i = 0; i < 3; i++) {
        engine.next();
        answerCorrect(engine);
      }
      engine.next();
      final problem = engine.currentProblem!;
      final outcome = engine.submitAnswer(
        problem.options.indexOf(problem.answer),
        elapsedFraction: 0.5,
      );
      expect(outcome.streak, 4);
      expect(outcome.comboMultiplier, 2);
      // base(level1)=10 + speed(5) = 15, times 2
      expect(outcome.points, 30);
    });

    test('wrong answer resets streak and loses a life', () {
      final engine = MathSprintEngine(random: Random(12));
      engine.next();
      answerCorrect(engine);
      engine.next();
      final problem = engine.currentProblem!;
      final wrongIdx =
          problem.options.indexWhere((o) => o != problem.answer);
      final outcome = engine.submitAnswer(wrongIdx, elapsedFraction: 0.5);
      expect(outcome.correct, isFalse);
      expect(outcome.points, 0);
      expect(outcome.streak, 0);
      expect(outcome.lives, MathSprintEngine.maxLives - 1);
      expect(engine.lives, MathSprintEngine.maxLives - 1);
    });

    test('timeout is scored as a miss', () {
      final engine = MathSprintEngine(random: Random(13));
      engine.next();
      final outcome = engine.submitTimeout();
      expect(outcome.correct, isFalse);
      expect(engine.lives, MathSprintEngine.maxLives - 1);
    });
  });

  group('level progression', () {
    test('level rises every 5 correct answers and is capped at 5', () {
      final engine = MathSprintEngine(random: Random(21));
      expect(engine.level, 1);
      for (var i = 1; i <= 30; i++) {
        engine.next();
        final outcomeBefore = engine.level;
        answerCorrect(engine);
        if (i % 5 == 0) {
          expect(engine.level, min(5, outcomeBefore + 1));
          expect(outcomeBefore < 5 ? engine.level == outcomeBefore + 1 : true, isTrue);
        } else {
          expect(engine.level, outcomeBefore);
        }
      }
      expect(engine.level, MathSprintEngine.maxLevel);
    });

    test('leveledUp flag fires exactly on the 5th correct answer', () {
      final engine = MathSprintEngine(random: Random(22));
      var leveledUpCount = 0;
      for (var i = 0; i < 12; i++) {
        engine.next();
        final problem = engine.currentProblem!;
        final outcome = engine.submitAnswer(
          problem.options.indexOf(problem.answer),
          elapsedFraction: 0.2,
        );
        if (outcome.leveledUp) leveledUpCount++;
      }
      expect(leveledUpCount, 2); // at 5 and 10 correct
    });
  });

  group('game over', () {
    test('run ends after three misses', () {
      final engine = MathSprintEngine(random: Random(31));
      engine.next();
      var outcome = engine.submitTimeout();
      expect(outcome.gameOver, isFalse);
      engine.next();
      outcome = engine.submitTimeout();
      expect(outcome.gameOver, isFalse);
      engine.next();
      outcome = engine.submitTimeout();
      expect(outcome.gameOver, isTrue);
      expect(engine.lives, 0);
      expect(engine.gameOver, isTrue);
    });

    test('accuracy and totals are tracked', () {
      final engine = MathSprintEngine(random: Random(32));
      engine.next();
      answerCorrect(engine);
      engine.next();
      final problem = engine.currentProblem!;
      final wrongIdx = problem.options.indexWhere((o) => o != problem.answer);
      engine.submitAnswer(wrongIdx, elapsedFraction: 0.5);
      expect(engine.totalAttempts, 2);
      expect(engine.totalCorrect, 1);
      expect(engine.accuracy, 50);
    });
  });

  group('determinism', () {
    test('same seed produces the same problem sequence', () {
      final a = MathSprintEngine(random: Random(5));
      final b = MathSprintEngine(random: Random(5));
      for (var i = 0; i < 20; i++) {
        final pa = a.next();
        final pb = b.next();
        expect(pa.expression, pb.expression);
        expect(pa.options, pb.options);
        expect(pa.answer, pb.answer);
      }
    });
  });

  group('reset', () {
    test('reset clears all run state', () {
      final engine = MathSprintEngine(random: Random(41));
      engine.next();
      answerCorrect(engine);
      engine.next();
      answerCorrect(engine);
      engine.next();
      final problem = engine.currentProblem!;
      final wrongIdx = problem.options.indexWhere((o) => o != problem.answer);
      engine.submitAnswer(wrongIdx, elapsedFraction: 0.5);
      expect(engine.score, greaterThan(0));
      expect(engine.lives, lessThan(MathSprintEngine.maxLives));

      engine.reset();
      expect(engine.score, 0);
      expect(engine.lives, MathSprintEngine.maxLives);
      expect(engine.streak, 0);
      expect(engine.totalAttempts, 0);
      expect(engine.totalCorrect, 0);
      expect(engine.currentProblem, isNull);
      expect(engine.level, 1);
    });
  });

  group('time budgets and base points', () {
    test('budget shrinks as levels climb', () {
      expect(MathSprintEngine.timeBudgetSeconds(1),
          greaterThan(MathSprintEngine.timeBudgetSeconds(5)));
      expect(MathSprintEngine.timeBudgetSeconds(1), 6.5);
      expect(MathSprintEngine.timeBudgetSeconds(5), 4.5);
    });

    test('base points grow with level', () {
      expect(MathSprintEngine.basePoints(1), 10);
      expect(MathSprintEngine.basePoints(5), 30);
    });

    test('default run duration is 60 seconds', () {
      expect(MathSprintEngine().runSeconds, 60);
    });
  });
}
