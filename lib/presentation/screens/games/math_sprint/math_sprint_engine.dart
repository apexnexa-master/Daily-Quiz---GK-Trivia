// lib/presentation/screens/games/math_sprint/math_sprint_engine.dart
// PURE DART — no Flutter imports, no BuildContext, no timers.
//
// Rules for a 60-second mental-arithmetic sprint:
//  - Level 1 + (correct answers / 5), capped at 5. Each level unlocks harder
//    operators and larger operands. Levels keep rising so the game always
//    feels like it is progressing.
//  - Correct = base points for the level + up to 10 speed bonus, scaled by a
//    streak combo multiplier. Wrong or timeout = lose a life (3 total).
//  - Run ends when the 60s clock runs out or lives hit zero.
//
// Everything is deterministic when constructed with a seeded [Random], which
// is what makes the logic unit-testable.

import 'dart:math';

enum MathOperator { add, subtract, multiply, divide }

/// One generated question plus four shuffled options (exactly one correct).
class MathProblem {
  final int a;
  final int b;
  final MathOperator operator;
  final int answer;
  final List<int> options;
  final int level;

  const MathProblem({
    required this.a,
    required this.b,
    required this.operator,
    required this.answer,
    required this.options,
    required this.level,
  });

  String get symbol => switch (operator) {
        MathOperator.add => '+',
        MathOperator.subtract => '−',
        MathOperator.multiply => '×',
        MathOperator.divide => '÷',
      };

  String get expression => '$a $symbol $b';
}

/// Result of grading one answer.
class AnswerOutcome {
  final bool correct;
  final int points;
  final int streak;
  final int level;
  final bool leveledUp;
  final int comboMultiplier;
  final int lives;
  final bool gameOver;

  const AnswerOutcome({
    required this.correct,
    required this.points,
    required this.streak,
    required this.level,
    required this.leveledUp,
    required this.comboMultiplier,
    required this.lives,
    required this.gameOver,
  });
}

class MathSprintEngine {
  MathSprintEngine({Random? random, this.runSeconds = 60})
      : _rng = random ?? Random();

  static const int maxLevel = 5;
  static const int maxLives = 3;

  final Random _rng;
  final int runSeconds;

  int _totalCorrect = 0;
  int _totalAttempts = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _score = 0;
  int _lives = maxLives;
  MathProblem? _current;

  /// Current difficulty level, derived from correct answers so it only ever
  /// moves forward.
  int get level => min(maxLevel, 1 + _totalCorrect ~/ 5);

  int get lives => _lives;
  int get score => _score;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  int get totalCorrect => _totalCorrect;
  int get totalAttempts => _totalAttempts;
  bool get gameOver => _lives <= 0;

  /// Percentage of answers correct (0-100).
  int get accuracy =>
      _totalAttempts == 0 ? 0 : (_totalCorrect * 100 / _totalAttempts).round();

  MathProblem? get currentProblem => _current;

  /// Seconds the player gets per problem at a given level.
  static double timeBudgetSeconds(int level) =>
      const [6.5, 6.0, 5.5, 5.0, 4.5][level - 1];

  double get currentTimeBudgetSeconds => timeBudgetSeconds(level);

  static int basePoints(int level) => const [10, 15, 20, 25, 30][level - 1];

  static int comboMultiplierFor(int streak) {
    if (streak >= 12) return 4;
    if (streak >= 8) return 3;
    if (streak >= 4) return 2;
    return 1;
  }

  /// Moves to the next question for the current level.
  MathProblem next() {
    _current = _generate();
    return _current!;
  }

  /// Grades the answer at [optionIndex]. [elapsedFraction] is the share of the
  /// time budget already used (0..1); smaller = faster = more speed points.
  AnswerOutcome submitAnswer(int optionIndex, {required double elapsedFraction}) {
    final problem = _current;
    if (problem == null) {
      throw StateError('No current problem. Call next() first.');
    }
    if (optionIndex < 0 || optionIndex >= problem.options.length) {
      throw RangeError.range(optionIndex, 0, problem.options.length - 1, 'optionIndex');
    }
    final correct = problem.options[optionIndex] == problem.answer;
    return correct ? _gradeCorrect(elapsedFraction) : _gradeMiss();
  }

  /// Called when the per-problem time budget expires (no tap in time).
  /// Never scored as a correct answer, regardless of which option is first.
  AnswerOutcome submitTimeout() => _gradeMiss();

  AnswerOutcome _gradeCorrect(double elapsedFraction) {
    _totalAttempts++;
    final levelBefore = level;
    _totalCorrect++;
    _streak++;
    if (_streak > _bestStreak) _bestStreak = _streak;
    final ef = elapsedFraction.clamp(0.0, 1.0);
    final speedBonus = ((1 - ef) * 10).round().clamp(0, 10);
    final earned = (basePoints(levelBefore) + speedBonus) * comboMultiplierFor(_streak);
    _score += earned;
    return _outcome(correct: true, points: earned, levelBefore: levelBefore);
  }

  AnswerOutcome _gradeMiss() {
    _totalAttempts++;
    _streak = 0;
    _lives--;
    return _outcome(correct: false, points: 0, levelBefore: level);
  }

  AnswerOutcome _outcome({
    required bool correct,
    required int points,
    required int levelBefore,
  }) {
    final levelAfter = level;
    return AnswerOutcome(
      correct: correct,
      points: points,
      streak: _streak,
      level: levelAfter,
      leveledUp: levelAfter > levelBefore,
      comboMultiplier: comboMultiplierFor(_streak),
      lives: _lives,
      gameOver: gameOver,
    );
  }

  /// Resets all run state so the same engine can be reused for a new run.
  void reset() {
    _totalCorrect = 0;
    _totalAttempts = 0;
    _streak = 0;
    _bestStreak = 0;
    _score = 0;
    _lives = maxLives;
    _current = null;
  }

  // ── Generation helpers ────────────────────────────────────────────────

  MathProblem _generate() {
    final lvl = level;
    final op = _pickOperator(lvl);
    final (a, b) = _pickOperands(op, lvl);
    final answer = _solve(a, b, op);
    final options = _buildOptions(answer);
    return MathProblem(
      a: a,
      b: b,
      operator: op,
      answer: answer,
      options: options,
      level: lvl,
    );
  }

  MathOperator _pickOperator(int lvl) {
    final pool = switch (lvl) {
      1 => const [MathOperator.add],
      2 => const [MathOperator.add, MathOperator.subtract],
      3 => const [MathOperator.add, MathOperator.subtract, MathOperator.multiply],
      _ => const [MathOperator.add, MathOperator.subtract, MathOperator.multiply, MathOperator.divide],
    };
    return pool[_rng.nextInt(pool.length)];
  }

  (int, int) _pickOperands(MathOperator op, int lvl) {
    const addMax = [20, 30, 50, 70, 95];
    return switch (op) {
      MathOperator.add => (_rng.nextInt(addMax[lvl - 1]) + 1, _rng.nextInt(addMax[lvl - 1]) + 1),
      MathOperator.subtract => () {
          final maxA = addMax[lvl - 1];
          final a = _rng.nextInt(maxA - 4) + 5;
          return (a, _rng.nextInt(a) + 1);
        }(),
      MathOperator.multiply => () {
          final aMax = lvl == 3 ? 9 : 12;
          return (_rng.nextInt(aMax - 1) + 2, _rng.nextInt(8) + 2);
        }(),
      MathOperator.divide => () {
          final divisor = _rng.nextInt(8) + 2;
          final quotient = _rng.nextInt(11) + 2;
          return (divisor * quotient, divisor);
        }(),
    };
  }

  int _solve(int a, int b, MathOperator op) {
    return switch (op) {
      MathOperator.add => a + b,
      MathOperator.subtract => a - b,
      MathOperator.multiply => a * b,
      MathOperator.divide => a ~/ b,
    };
  }

  /// Builds 4 unique non-negative options including the correct answer, biased
  /// toward values near [answer] so the wrong options feel plausible.
  List<int> _buildOptions(int answer) {
    final options = <int>{answer};
    const deltas = [1, -1, 2, -2, 10, -10, 5, -5, 3, -3, 4, -4];
    for (final d in deltas) {
      if (options.length >= 4) break;
      final candidate = answer + d;
      if (candidate >= 0) options.add(candidate);
    }
    var guard = 0;
    while (options.length < 4 && guard < 50) {
      final candidate = answer + _rng.nextInt(15) - 7;
      if (candidate >= 0) options.add(candidate);
      guard++;
    }
    return options.toList()..shuffle(_rng);
  }
}
