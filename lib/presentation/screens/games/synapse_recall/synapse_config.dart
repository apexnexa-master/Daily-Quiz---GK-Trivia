// lib/presentation/screens/games/synapse_recall/synapse_config.dart
// Central, tunable configuration for the Synapse Recall game.
//
// All difficulty timings, sequence lengths and scoring values live here so the
// game feel can be adjusted without touching gameplay logic.

class SynapseConfig {
  SynapseConfig._();

  /// Total rounds in one session (~2-4 min). Round N plays a sequence of
  /// [roundLengths][N-1] objects.
  static const int sessionRounds = 8;

  /// Objects shown per round (progressive difficulty, starting easy).
  static const List<int> roundLengths = [2, 3, 4, 5, 6, 7, 8, 9];

  /// Minimum number of tiles offered during recall (keeps early rounds easy).
  static const int minCandidates = 6;

  /// Maximum number of tiles offered during recall (keeps grids readable).
  static const int maxCandidates = 12;

  /// Distractors added beyond the sequence itself.
  static const int extraDistractors = 2;

  // ── Memorize viewing time ───────────────────────────────────────────────
  /// Base seconds granted per memorized object. Viewing time scales with the
  /// sequence but is clamped so late rounds stay challenging, not punishing.
  static const double viewSecondsPerItem = 1.15;
  static const double minViewSeconds = 3.0;
  static const double maxViewSeconds = 8.5;

  static double viewSecondsForLength(int length) {
    final raw = length * viewSecondsPerItem;
    return raw.clamp(minViewSeconds, maxViewSeconds);
  }

  // ── Timing / animation ──────────────────────────────────────────────────
  static const Duration countdownDuration = Duration(milliseconds: 900);
  static const int countdownStart = 3;
  static const Duration memorizeToRecallGap = Duration(milliseconds: 450);
  static const Duration correctAutoAdvance = Duration(milliseconds: 1350);

  // ── Scoring (configurable; not exposed to the player) ───────────────────
  /// Base points awarded for recalling a full sequence of a given length.
  /// Longer successful sequences are worth progressively more.
  static const Map<int, int> baseScoreByLength = {
    2: 70,
    3: 100,
    4: 130,
    5: 170,
    6: 220,
    7: 280,
    8: 350,
    9: 430,
  };

  /// Flat bonus for recalling a full sequence on the first pass.
  static const int perfectRecallBonus = 40;

  /// Points added per active streak step on a correct recall (capped).
  static const int streakBonusPerStep = 8;
  static const int maxStreakBonus = 80;

  static int baseScoreForLength(int length) =>
      baseScoreByLength[length] ?? 70 + (length - 2) * 60;

  static int roundScore(int length, int streak) {
    final streakBonus =
        (streak.clamp(0, 10) * streakBonusPerStep).clamp(0, maxStreakBonus);
    return baseScoreForLength(length) + streakBonus;
  }

  // ── Personal best keys ──────────────────────────────────────────────────
  static const String prefBestLongestSequence = 'synapse_best_longest_sequence';
  static const String prefBestScore = 'synapse_best_score';
  static const String prefBestStreak = 'synapse_best_streak';

  // ── Scoring note ────────────────────────────────────────────────────────
  // The exact formula above is intentionally kept internal. We reward recall
  // length + accuracy + progression. There is no speed reward and repeating
  // easy rounds cannot be exploited because difficulty always increases.
}
