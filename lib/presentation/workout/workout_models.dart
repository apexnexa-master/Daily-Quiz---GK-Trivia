// lib/presentation/workout/workout_models.dart
// Data model for the Quick Brain Workout orchestration layer.
//
// A workout is a preset-driven sequence of existing games. Adding a new game
// later only requires a new [WorkoutGameDef] entry plus the launcher case in
// `WorkoutScreen` — the flow itself is driven by this list.

import 'package:flutter/material.dart';
import '../../routes/app_router.dart';
import '../../core/services/daily_progress_service.dart';

/// Identifiers for the currently playable games.
enum WorkoutGameId { gkQuiz, arrowPuzzle, stroopRush, synapseRecall }

/// Cognitive skills that are actually backed by playable games today.
enum WorkoutSkill {
  knowledge(
    pillar: BrainPillar.knowledge,
    labelEn: 'Knowledge',
    labelBn: 'জ্ঞান',
    labelHi: 'ज्ञान',
    emoji: '🧠',
    accent: Color(0xFFD4FF50),
  ),
  logic(
    pillar: BrainPillar.logic,
    labelEn: 'Logic',
    labelBn: 'যুক্তি',
    labelHi: 'तर्क',
    emoji: '🧩',
    accent: Color(0xFF00F1FE),
  ),
  speed(
    pillar: BrainPillar.speed,
    labelEn: 'Speed',
    labelBn: 'গতি',
    labelHi: 'गति',
    emoji: '⚡',
    accent: Color(0xFFECB2FF),
  ),
  memory(
    pillar: BrainPillar.memory,
    labelEn: 'Memory',
    labelBn: 'স্মৃতি',
    labelHi: 'स्मृति',
    emoji: '🔗',
    accent: Color(0xFFB388FF),
  );

  const WorkoutSkill({
    required this.pillar,
    required this.labelEn,
    required this.labelBn,
    required this.labelHi,
    required this.emoji,
    required this.accent,
  });

  final String pillar;
  final String labelEn;
  final String labelBn;
  final String labelHi;
  final String emoji;
  final Color accent;

  String label(String lang) =>
      lang == 'bn' ? labelBn : lang == 'hi' ? labelHi : labelEn;
}

/// A single playable game referenced by a workout.
class WorkoutGameDef {
  final WorkoutGameId id;
  final String titleEn;
  final String titleBn;
  final String titleHi;
  final WorkoutSkill skill;

  /// Key used for the existing daily-goal tracking (`GameType.*`).
  final String gameType;

  const WorkoutGameDef({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.titleHi,
    required this.skill,
    required this.gameType,
  });

  String title(String lang) =>
      lang == 'bn' ? titleBn : lang == 'hi' ? titleHi : titleEn;
}

/// An ordered list of games that form one workout session.
class WorkoutPreset {
  final String id;
  final String nameEn;
  final String nameBn;
  final String nameHi;
  final List<WorkoutGameDef> games;

  const WorkoutPreset({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.nameHi,
    required this.games,
  });

  String name(String lang) =>
      lang == 'bn' ? nameBn : lang == 'hi' ? nameHi : nameEn;
}

/// Built-in presets. Only "balanced" is surfaced on the Home screen today;
/// the others exist so the workout engine can be expanded later without
/// changing the orchestration flow.
class WorkoutPresets {
  WorkoutPresets._();

  static const String balancedId = 'balanced';

  static const WorkoutGameDef gkQuiz = WorkoutGameDef(
    id: WorkoutGameId.gkQuiz,
    titleEn: 'GK Quiz',
    titleBn: 'জিকে কুইজ',
    titleHi: 'जीके क्विज़',
    skill: WorkoutSkill.knowledge,
    gameType: GameType.challenge,
  );

  static const WorkoutGameDef arrowPuzzle = WorkoutGameDef(
    id: WorkoutGameId.arrowPuzzle,
    titleEn: 'Arrow Puzzle',
    titleBn: 'দিকনির্দেশ ধাঁধা',
    titleHi: 'दिशा पहेली',
    skill: WorkoutSkill.logic,
    gameType: GameType.arrow,
  );

  static const WorkoutGameDef stroopRush = WorkoutGameDef(
    id: WorkoutGameId.stroopRush,
    titleEn: 'Stroop Rush',
    titleBn: 'স্ট্রুপ রাশ',
    titleHi: 'स्ट्रूप रश',
    skill: WorkoutSkill.speed,
    gameType: GameType.stroop,
  );

  static const WorkoutGameDef synapseRecall = WorkoutGameDef(
    id: WorkoutGameId.synapseRecall,
    titleEn: 'Synapse Recall',
    titleBn: 'সিন্যাপ্স রিকল',
    titleHi: 'सिनैप्स रिकॉल',
    skill: WorkoutSkill.memory,
    gameType: GameType.synapse,
  );

  static const WorkoutPreset balanced = WorkoutPreset(
    id: balancedId,
    nameEn: 'Balanced',
    nameBn: 'সমন্বিত',
    nameHi: 'संतुलित',
    games: [gkQuiz, arrowPuzzle, synapseRecall, stroopRush],
  );

  // Future presets (kept internal; not exposed on Home yet).
  static const WorkoutPreset speedFocus = WorkoutPreset(
    id: 'speed_focus',
    nameEn: 'Speed Focus',
    nameBn: 'গতি ফোকাস',
    nameHi: 'गति फोकस',
    games: [stroopRush, arrowPuzzle, stroopRush],
  );

  static const WorkoutPreset logicFocus = WorkoutPreset(
    id: 'logic_focus',
    nameEn: 'Logic Focus',
    nameBn: 'যুক্তি ফোকাস',
    nameHi: 'तर्क फोकस',
    games: [arrowPuzzle, gkQuiz, arrowPuzzle],
  );

  static const WorkoutPreset brainMix = WorkoutPreset(
    id: 'brain_mix',
    nameEn: 'Brain Mix',
    nameBn: 'ব্রেন মিক্স',
    nameHi: 'ब्रेन मिक्स',
    games: [gkQuiz, stroopRush, arrowPuzzle],
  );

  static const List<WorkoutPreset> all = [
    balanced,
    speedFocus,
    logicFocus,
    brainMix,
  ];

  static WorkoutPreset byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return balanced;
  }
}

/// Lightweight context passed into a game screen while it is running inside
/// a workout. The screen uses it to show the tiny progress banner and, when
/// the game naturally finishes, pops back with the session score (0-100).
class WorkoutStep {
  final WorkoutGameDef game;
  final int index; // 0-based position in the preset
  final int total;

  const WorkoutStep({
    required this.game,
    required this.index,
    required this.total,
  });

  /// Route used to launch this game (must accept a `workoutStep` argument).
  String get route {
    switch (game.id) {
      case WorkoutGameId.gkQuiz:
        return AppRouter.quiz;
      case WorkoutGameId.arrowPuzzle:
        return AppRouter.arrowPuzzle;
      case WorkoutGameId.stroopRush:
        return AppRouter.stroopRush;
      case WorkoutGameId.synapseRecall:
        return AppRouter.synapseRecall;
    }
  }
}

/// Result of a single game inside a workout. [score] is a 0-100 percentage;
/// it is null when the user abandoned the game before it produced a result.
class WorkoutGameResult {
  final WorkoutGameDef game;
  final int? score;

  const WorkoutGameResult({required this.game, this.score});

  /// A game counts as completed only when it produced a real score (> 0).
  /// A session where the player scored nothing does not count as completed.
  bool get completed => score != null && score! > 0;
}

/// Full snapshot of a finished workout, used by the results screen.
class WorkoutSessionResult {
  final WorkoutPreset preset;
  final List<WorkoutGameResult> games;

  const WorkoutSessionResult({required this.preset, required this.games});

  int get completedCount => games.where((g) => g.completed).length;

  /// Average of every completed game, 0 when nothing was completed.
  int get overallScore {
    final scores = games.where((g) => g.completed).map((g) => g.score!).toList();
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }
}
