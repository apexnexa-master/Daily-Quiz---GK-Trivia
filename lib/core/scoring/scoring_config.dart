// lib/core/scoring/scoring_config.dart
// Central configuration for the scoring & progression system.
//
// Every tunable constant lives here so scoring can be adjusted from one
// place without scattering magic numbers across the app. Bump [scoringVersion]
// whenever a formula changes so historically stored results are not silently
// recalculated with a new formula.

import 'dart:math' as math;

import '../services/daily_progress_service.dart';

class ScoringConfig {
  ScoringConfig._();

  /// Version of the scoring formulas. Stored with every snapshot so old
  /// results can be kept historically consistent if a formula changes.
  static const int scoringVersion = 1;

  // ── Cognitive skills ──────────────────────────────────────────
  // The five pillars match the existing BrainPillar keys so the current
  // Home/profile UI keeps working. "Focus" from the design spec maps to
  // [BrainPillar.reaction], which is what the app already labels Reaction.
  static const String skillKnowledge = BrainPillar.knowledge;
  static const String skillLogic = BrainPillar.logic;
  static const String skillSpeed = BrainPillar.speed;
  static const String skillMemory = BrainPillar.memory;
  static const String skillFocus = BrainPillar.reaction;

  static const List<String> allSkills = [
    skillKnowledge,
    skillLogic,
    skillMemory,
    skillSpeed,
    skillFocus,
  ];

  // Equal base weights for the Brain Score (they can be tuned per pillar).
  static const double skillWeightKnowledge = 0.20;
  static const double skillWeightLogic = 0.20;
  static const double skillWeightMemory = 0.20;
  static const double skillWeightSpeed = 0.20;
  static const double skillWeightFocus = 0.20;

  static double skillWeight(String skill) {
    switch (skill) {
      case skillKnowledge:
        return skillWeightKnowledge;
      case skillLogic:
        return skillWeightLogic;
      case skillMemory:
        return skillWeightMemory;
      case skillSpeed:
        return skillWeightSpeed;
      case skillFocus:
        return skillWeightFocus;
    }
    throw ArgumentError('Unknown cognitive skill: $skill');
  }

  // ── Skill rating update (gradual EWMA) ────────────────────────
  // newSkill = old + (performance - old) * learningRate * skillWeight
  // New users learn faster for their first few sessions in a skill, then the
  // rating settles so one game can never drastically move the Brain Score.
  static const double normalLearningRate = 0.15;
  static const double newUserLearningRate = 0.30;
  static const int newUserSessionThreshold = 5;

  // ── Brain Score status ────────────────────────────────────────
  static const int minSessionsForEstablished = 5;
  static const int minSkillsForEstablished = 3;
  static const int historySize = 30;

  // ── XP (engagement, separate from Brain Score) ────────────────
  static const int practiceXp = 10;
  static const int dailyChallengeXp = 25;
  static const int workoutXp = 30;
  static const int dailyGoalXp = 15;
  static const int perfectBonusXp = 5;
  static const int battleXp = 10;
  static const int dailyXpCap = 150;

  // Anti-farming for practice mode: the first few practice sessions pay full
  // XP, the next few pay half, everything after pays a quarter. The daily cap
  // is a hard ceiling on top of this.
  static const int practiceFullXpCount = 5;
  static const int practiceHalfXpCount = 5;
  static const double practiceDiminishedMultiplier = 0.25;

  // Workout XP keeps a small performance-linked component on top of the base
  // so the results screen still shows meaningful "Brain Points".
  static const double workoutPerformanceXpMultiplier = 0.1;

  // ── Leaderboard ───────────────────────────────────────────────
  static const int dailyScoreMax = 1000;
  static const int weeklyBestChallenges = 5;

  // ── Per-game performance formulas ─────────────────────────────
  static const int quizSecondsPerQuestion = 30;
  static const double quizAccuracyWeight = 0.60;
  static const double quizDifficultyWeight = 0.25;
  static const double quizSpeedWeight = 0.15;

  static const double arrowDifficultyWeight = 0.40;
  static const double arrowTimeWeight = 0.30;
  static const double arrowMovesWeight = 0.20;
  static const double arrowQualityWeight = 0.10;
  static const double arrowSecondsPerDifficultyPoint = 2.2;
  static const double arrowHintPenalty = 0.08;
  static const double arrowExtraMovePenalty = 0.02;

  static const double stroopAccuracyWeight = 0.50;
  static const double stroopReactionWeight = 0.30;
  static const double stroopDifficultyWeight = 0.20;
  static const int stroopFastReactionMs = 250;
  static const int stroopSlowReactionMs = 900;

  static const double synapseSequenceWeight = 0.50;
  static const double synapseAccuracyWeight = 0.30;
  static const double synapseDifficultyWeight = 0.20;

  static const double mathAccuracyWeight = 0.50;
  static const double mathSpeedWeight = 0.30;
  static const double mathDifficultyWeight = 0.20;
  static const double mathSecondsPerAnswerBudget = 6.0;

  // ── Per-game → skill mapping (weights must sum to 1.0) ────────
  static const Map<String, Map<String, double>> gameSkillWeights = {
    // GK Quiz: Knowledge primary, Focus secondary.
    'quiz': {skillKnowledge: 0.70, skillFocus: 0.30},
    // Arrow Puzzle: Logic primary, Speed secondary.
    'arrow': {skillLogic: 0.70, skillSpeed: 0.30},
    // Stroop Rush: Focus primary and Speed primary.
    'stroop': {skillFocus: 0.50, skillSpeed: 0.50},
    // Synapse Recall: Memory primary, Focus secondary.
    'synapse': {skillMemory: 0.70, skillFocus: 0.30},
    // Math Sprint: Speed primary, Logic secondary.
    'math': {skillSpeed: 0.70, skillLogic: 0.30},
    // Battle: Knowledge primary, Speed secondary.
    'battle': {skillKnowledge: 0.60, skillSpeed: 0.40},
    // Flow Free: Logic primary, Memory secondary.
    'flowFree': {skillLogic: 0.70, skillMemory: 0.30},
    // One-Line Drawing: Logic primary, Speed secondary.
    'oneLine': {skillLogic: 0.70, skillSpeed: 0.30},
  };

  /// Validates that every game's skill weights sum to 1.0 within a small
  /// epsilon, so a misconfigured new game is rejected instead of silently
  /// producing a biased skill update.
  static void validateGameSkillWeights() {
    const tolerance = 0.001;
    for (final entry in gameSkillWeights.entries) {
      final sum = entry.value.values.fold(0.0, (a, b) => a + b);
      if ((sum - 1.0).abs() > tolerance) {
        throw StateError(
          'Game "${entry.key}" skill weights sum to $sum, expected 1.0',
        );
      }
    }
  }

  /// Computes the expected completion time (seconds) for an Arrow Puzzle of
  /// the given difficulty (1-10). A harder puzzle is expected to take longer,
  /// so a fast solve of a hard puzzle beats a fast solve of an easy one.
  static double arrowExpectedSeconds(int difficulty) =>
      arrowSecondsPerDifficultyPoint * math.max(1, difficulty);
}
