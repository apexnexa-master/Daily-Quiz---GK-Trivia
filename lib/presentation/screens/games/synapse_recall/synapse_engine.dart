// lib/presentation/screens/games/synapse_recall/synapse_engine.dart
// Pure game logic for Synapse Recall — rounds, sequence generation, scoring
// and session statistics. Kept free of Flutter UI so it is easily testable and
// so future game modes (position / reverse / dual recall) can be added by
// extending [SynapseGameMode] without rewriting the engine.

import 'dart:math' as math;
import 'dart:ui';

import 'memory_object.dart';
import 'synapse_config.dart';

/// Currently supported recall modes. Only [SynapseGameMode.sequence] ships in
/// this version; the enum exists so the architecture can grow new modes.
enum SynapseGameMode { sequence }

/// A single generated round: the target [sequence] plus a shuffled [candidates]
/// tile pool that contains the sequence and a few distractors.
class SynapseRound {
  final int number;
  final int length;
  final double viewSeconds;
  final List<MemoryObject> sequence;
  final List<MemoryObject> candidates;

  const SynapseRound({
    required this.number,
    required this.length,
    required this.viewSeconds,
    required this.sequence,
    required this.candidates,
  });
}

/// Immutable result of one recalled round.
class SynapseRoundResult {
  final bool correct;
  final int remembered;
  final int scoreGained;

  const SynapseRoundResult({
    required this.correct,
    required this.remembered,
    required this.scoreGained,
  });
}

/// Live statistics for the current session.
class SynapseSessionStats {
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correctRounds = 0;
  int totalRounds = 0;
  int longestCorrectSequence = 0;
  int maxLevelReached = 0;

  /// Remaining lives. Decremented on each wrong recall; reaching zero ends
  /// the session (game over) before all rounds are cleared.
  int lives = SynapseConfig.startingLives;

  bool get outOfLives => lives <= 0;

  int get accuracy =>
      totalRounds == 0 ? 0 : ((correctRounds / totalRounds) * 100).round();

  /// 0-100 performance used by the workout system.
  int get workoutScore => accuracy;
}

class SynapseRecallEngine {
  SynapseRecallEngine({math.Random? random})
      : _rng = random ?? math.Random();

  final math.Random _rng;
  final SynapseSessionStats stats = SynapseSessionStats();

  /// The full object catalog (every shape x every palette color).
  List<MemoryObject> get pool {
    final result = <MemoryObject>[];
    for (final shape in MemoryShape.values) {
      for (final color in MemoryPalette.colors) {
        result.add(MemoryObject(shape: shape, color: color));
      }
    }
    return result;
  }

  /// Colors available per round — early rounds use fewer colors so objects are
  /// easier to tell apart, higher rounds unlock the full palette.
  List<Color> _colorsForRound(int number) {
    if (number <= 2) return MemoryPalette.colors.sublist(0, 3);
    if (number <= 4) return MemoryPalette.colors.sublist(0, 4);
    if (number <= 6) return MemoryPalette.colors.sublist(0, 5);
    return MemoryPalette.colors;
  }

  /// Builds the round for a 1-based round [number].
  SynapseRound buildRound(int number) {
    final length = SynapseConfig.roundLengths[
        (number - 1).clamp(0, SynapseConfig.roundLengths.length - 1)];
    final colors = _colorsForRound(number);

    // Pick distinct shapes for the sequence (never ◆◆◆◆).
    final shapePool = List<MemoryShape>.of(MemoryShape.values)..shuffle(_rng);
    final sequenceShapes = shapePool.take(length).toList();
    final sequence = sequenceShapes
        .map((shape) =>
            MemoryObject(shape: shape, color: colors[_rng.nextInt(colors.length)]))
        .toList();

    // Candidate pool = sequence + distinct distractors.
    final usedShapes = sequenceShapes.toSet();
    final distractorShapes = shapePool
        .skip(length)
        .take(SynapseConfig.extraDistractors)
        .toList();
    final distractors = distractorShapes
        .map((shape) =>
            MemoryObject(shape: shape, color: colors[_rng.nextInt(colors.length)]))
        .toList();

    var candidates = [...sequence, ...distractors]..shuffle(_rng);
    // Keep the pool within comfortable tile counts.
    if (candidates.length < SynapseConfig.minCandidates) {
      final fillerShapes =
          shapePool.skip(length + distractorShapes.length).toList();
      for (final shape in fillerShapes) {
        if (candidates.length >= SynapseConfig.minCandidates) break;
        if (usedShapes.contains(shape)) continue;
        usedShapes.add(shape);
        candidates.add(MemoryObject(
            shape: shape, color: colors[_rng.nextInt(colors.length)]));
      }
    }
    candidates = candidates.take(SynapseConfig.maxCandidates).toList()
      ..shuffle(_rng);

    return SynapseRound(
      number: number,
      length: length,
      viewSeconds: SynapseConfig.viewSecondsForLength(length),
      sequence: sequence,
      candidates: candidates,
    );
  }

  /// Scores the player's [selection] against [round] and updates the session
  /// statistics. [remembered] is the longest correct prefix length.
  SynapseRoundResult submit(SynapseRound round, List<MemoryObject> selection) {
    var remembered = 0;
    for (var i = 0;
        i < selection.length && i < round.sequence.length;
        i++) {
      if (selection[i] == round.sequence[i]) {
        remembered++;
      } else {
        break;
      }
    }

    final correct = remembered == round.length && selection.length == round.length;

    stats.totalRounds++;
    int scoreGained = 0;
    if (correct) {
      stats.correctRounds++;
      stats.streak++;
      if (stats.streak > stats.bestStreak) stats.bestStreak = stats.streak;
      if (round.length > stats.longestCorrectSequence) {
        stats.longestCorrectSequence = round.length;
      }
      scoreGained = SynapseConfig.roundScore(round.length, stats.streak) +
          SynapseConfig.perfectRecallBonus;
      stats.score += scoreGained;
    } else {
      stats.streak = 0;
    }

    if (round.length > stats.maxLevelReached) {
      stats.maxLevelReached = round.length;
    }

    return SynapseRoundResult(
      correct: correct,
      remembered: remembered,
      scoreGained: scoreGained,
    );
  }

  /// The primary personal-best metric: longest sequence recalled correctly.
  int get longestCorrectSequence => stats.longestCorrectSequence;
}
