// lib/core/scoring/skill_ratings.dart
// Cognitive skill ratings with a gradual EWMA update.
//
// Each game contributes to one or more skills with weights that sum to 1.0.
// Ratings never jump: newSkill = old + (performance - old) * learningRate *
// skillWeight, with a faster learning rate for a new user's first few
// sessions in a skill.

import 'scoring_config.dart';
import 'scoring_store.dart';

class SkillRatings {
  final Map<String, double> ratings;
  final Map<String, int> sessions;

  const SkillRatings({
    this.ratings = const {},
    this.sessions = const {},
  });

  double rating(String skill) => ratings[skill] ?? 0.0;
  int sessionCount(String skill) => sessions[skill] ?? 0;

  bool hasData(String skill) => (sessions[skill] ?? 0) > 0;

  int get representedSkillCount =>
      ScoringConfig.allSkills.where(hasData).length;

  int get totalSessions =>
      ScoringConfig.allSkills.fold(0, (sum, s) => sum + sessionCount(s));

  Map<String, dynamic> toJson() => {
        'ratings': ratings,
        'sessions': sessions,
      };

  factory SkillRatings.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'];
    final rawSessions = json['sessions'];
    return SkillRatings(
      ratings: rawRatings is Map
          ? {
              for (final e in rawRatings.entries)
                e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
            }
          : const {},
      sessions: rawSessions is Map
          ? {
              for (final e in rawSessions.entries)
                e.key.toString(): (e.value as num?)?.toInt() ?? 0,
            }
          : const {},
    );
  }
}

/// Result of one game's skill update: the per-skill delta caused by this game.
class SkillUpdateResult {
  final SkillRatings ratings;
  final Map<String, double> deltas;

  const SkillUpdateResult({required this.ratings, required this.deltas});
}

class SkillRatingService {
  SkillRatingService._();
  static final SkillRatingService instance = SkillRatingService._();

  SkillRatings _cache = const SkillRatings();

  Future<SkillRatings> getRatings() async {
    _cache = SkillRatings.fromJson(
      ScoringStore.instance.readJson(ScoringStore.keySkillRatings),
    );
    return _cache;
  }

  double _learningRate(int sessionCount) =>
      sessionCount < ScoringConfig.newUserSessionThreshold
          ? ScoringConfig.newUserLearningRate
          : ScoringConfig.normalLearningRate;

  /// Applies one game's performance to its mapped skills and persists the
  /// new ratings. Returns the per-skill delta for the UI.
  Future<SkillUpdateResult> applyGamePerformance(
    String gameId,
    int performance,
  ) async {
    final weights = ScoringConfig.gameSkillWeights[gameId];
    if (weights == null) {
      throw StateError('No skill mapping configured for game "$gameId"');
    }

    final current = await getRatings();
    final ratings = Map<String, double>.from(current.ratings);
    final sessions = Map<String, int>.from(current.sessions);
    final deltas = <String, double>{};

    for (final entry in weights.entries) {
      final skill = entry.key;
      final weight = entry.value;
      final sessionCount = current.sessionCount(skill);
      final old = current.rating(skill);
      final effectiveRate = _learningRate(sessionCount) * weight;
      final next =
          (old + (performance - old) * effectiveRate).clamp(0.0, 100.0).toDouble();
      deltas[skill] = next - old;
      ratings[skill] = next;
      sessions[skill] = sessionCount + 1;
    }

    _cache = SkillRatings(ratings: ratings, sessions: sessions);
    await ScoringStore.instance.writeJson(
      ScoringStore.keySkillRatings,
      _cache.toJson(),
    );
    return SkillUpdateResult(ratings: _cache, deltas: deltas);
  }

  /// True when the game->skill weights for every configured game sum to 1.0.
  bool get configurationIsValid {
    try {
      ScoringConfig.validateGameSkillWeights();
      return true;
    } on StateError {
      return false;
    }
  }
}
