// lib/core/scoring/game_performance.dart
// Normalizes raw game results into a comparable 0-100 performance score.
//
// Raw scores from different games are NOT comparable (9/10 correct, a 3.2s
// puzzle, 740 stroop points...). Every game exposes its own formula here that
// blends the characteristics that actually matter for that game: accuracy,
// difficulty, response speed, mistakes, moves and hints.
//
// The result feeds skill ratings, Brain Score, daily goal and - for the daily
// challenge - the normalized challenge score (0-1000).

import 'dart:math' as math;

import 'scoring_config.dart';

/// Raw result of one game session. The concrete subclass determines which
/// formula is used to produce the 0-100 performance score.
sealed class GamePerformanceInput {
  const GamePerformanceInput();

  /// Round-trips the input through its formula and returns a 0-100 score.
  int normalize();
}

/// GK Quiz / Battle (knowledge quizzes).
class QuizPerformanceInput extends GamePerformanceInput {
  final int correct;
  final int total;
  final int timeTakenSeconds;

  /// Average question difficulty 0-100 (easy ~40, medium ~70, hard ~90).
  final double avgDifficulty;

  const QuizPerformanceInput({
    required this.correct,
    required this.total,
    this.timeTakenSeconds = 0,
    this.avgDifficulty = 70,
  });

  @override
  int normalize() {
    if (total <= 0) return 0;
    final accuracy = correct.clamp(0, total) / total;
    final difficulty = avgDifficulty.clamp(0, 100) / 100;
    final budget = total * ScoringConfig.quizSecondsPerQuestion;
    final speed = budget > 0
        ? clamp01((budget - timeTakenSeconds) / budget)
        : 0.0;
    final score = accuracy * ScoringConfig.quizAccuracyWeight +
        difficulty * ScoringConfig.quizDifficultyWeight +
        speed * ScoringConfig.quizSpeedWeight;
    return toPercent(score);
  }
}

/// Arrow Puzzle. Difficulty-aware: a hard puzzle solved in reasonable time
/// must outrank an easy puzzle solved instantly.
class ArrowPerformanceInput extends GamePerformanceInput {
  final int level;

  /// Campaign level 1-100; 10 campaign levels map to one difficulty point.
  final bool completed;
  final int timeSeconds;
  final int movesUsed;
  final int targetMoves;
  final int hintsUsed;

  const ArrowPerformanceInput({
    required this.level,
    this.completed = false,
    this.timeSeconds = 0,
    this.movesUsed = 0,
    this.targetMoves = 0,
    this.hintsUsed = 0,
  });

  @override
  int normalize() {
    final difficulty = (level / 10).clamp(1.0, 10.0).round();
    final difficultyFactor = difficulty / 10.0;
    final expected = ScoringConfig.arrowExpectedSeconds(difficulty);
    final timeScore = completed
        ? clamp01(expected / math.max(timeSeconds, 1))
        : 0.0;
    final moveScore = completed
        ? clamp01(targetMoves / math.max(movesUsed, 1))
        : 0.0;
    final extraMoves = completed ? math.max(movesUsed - targetMoves, 0) : 0;
    final quality = completed
        ? clamp01(1.0 -
            hintsUsed * ScoringConfig.arrowHintPenalty -
            extraMoves * ScoringConfig.arrowExtraMovePenalty)
        : 0.0;
    final score = difficultyFactor * ScoringConfig.arrowDifficultyWeight +
        timeScore * ScoringConfig.arrowTimeWeight +
        moveScore * ScoringConfig.arrowMovesWeight +
        quality * ScoringConfig.arrowQualityWeight;
    return toPercent(score);
  }
}

/// Stroop Rush. Accuracy and reaction speed dominate; difficulty is the
/// active turn pacing (1-5 pips).
class StroopPerformanceInput extends GamePerformanceInput {
  final int correct;
  final int totalAttempts;

  /// Average correct-answer reaction time in milliseconds (nullable).
  final double? avgReactionMs;

  /// Difficulty 1-5 (derived from the turn-time pacing).
  final int difficulty;

  const StroopPerformanceInput({
    required this.correct,
    required this.totalAttempts,
    this.avgReactionMs,
    this.difficulty = 1,
  });

  @override
  int normalize() {
    if (totalAttempts <= 0) return 0;
    final accuracy = correct.clamp(0, totalAttempts) / totalAttempts;
    final reaction = avgReactionMs == null
        ? accuracy
        : clamp01((ScoringConfig.stroopSlowReactionMs - avgReactionMs!) /
            (ScoringConfig.stroopSlowReactionMs -
                ScoringConfig.stroopFastReactionMs));
    final difficultyFactor = (difficulty.clamp(1, 5)) / 5.0;
    final score = accuracy * ScoringConfig.stroopAccuracyWeight +
        reaction * ScoringConfig.stroopReactionWeight +
        difficultyFactor * ScoringConfig.stroopDifficultyWeight;
    return toPercent(score);
  }
}

/// Synapse Recall. Longest sequence achieved and accuracy matter most; the
/// longest round length is also the difficulty.
class SynapsePerformanceInput extends GamePerformanceInput {
  final int maxSequenceLength;
  final int correctRounds;
  final int totalRounds;

  const SynapsePerformanceInput({
    required this.maxSequenceLength,
    required this.correctRounds,
    this.totalRounds = 8,
  });

  @override
  int normalize() {
    if (totalRounds <= 0) return 0;
    // Sequence lengths run 2..9 in the game engine → 0..100 range.
    final sequencePerf = clamp01((maxSequenceLength - 2) / 7);
    final accuracy = correctRounds.clamp(0, totalRounds) / totalRounds;
    final difficultyFactor = clamp01(maxSequenceLength / 9);
    final score = sequencePerf * ScoringConfig.synapseSequenceWeight +
        accuracy * ScoringConfig.synapseAccuracyWeight +
        difficultyFactor * ScoringConfig.synapseDifficultyWeight;
    return toPercent(score);
  }
}

/// Math Sprint. Accuracy and speed; the reached level is the difficulty.
class MathPerformanceInput extends GamePerformanceInput {
  final int correct;
  final int totalAttempts;

  /// Max level reached (1-5).
  final int maxLevel;

  /// Average seconds per answered question (nullable).
  final double? avgTimePerAnswerSeconds;

  const MathPerformanceInput({
    required this.correct,
    required this.totalAttempts,
    this.maxLevel = 1,
    this.avgTimePerAnswerSeconds,
  });

  @override
  int normalize() {
    if (totalAttempts <= 0) return 0;
    final accuracy = correct.clamp(0, totalAttempts) / totalAttempts;
    const budget = ScoringConfig.mathSecondsPerAnswerBudget;
    final speed = avgTimePerAnswerSeconds == null
        ? accuracy
        : clamp01((budget - avgTimePerAnswerSeconds!) / budget);
    final difficultyFactor = (maxLevel.clamp(1, 5)) / 5.0;
    final score = accuracy * ScoringConfig.mathAccuracyWeight +
        speed * ScoringConfig.mathSpeedWeight +
        difficultyFactor * ScoringConfig.mathDifficultyWeight;
    return toPercent(score);
  }
}

/// Battle Mode (GK quiz versus another player). Same formula as the quiz.
class BattlePerformanceInput extends GamePerformanceInput {
  final int correct;
  final int total;
  final int timeTakenSeconds;

  const BattlePerformanceInput({
    required this.correct,
    required this.total,
    this.timeTakenSeconds = 0,
  });

  @override
  int normalize() => QuizPerformanceInput(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
      ).normalize();
}

/// Pure entry point used by the progression engine.
class GamePerformanceService {
  GamePerformanceService._();

  static int calculate(GamePerformanceInput input) => input.normalize();
}

double clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

int toPercent(double v) => (clamp01(v) * 100).round().clamp(0, 100);
