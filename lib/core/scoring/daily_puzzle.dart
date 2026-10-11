// lib/core/scoring/daily_puzzle.dart
// Deterministic Daily Challenge puzzle selection.
//
// Every player must face the exact same board for a given calendar day, so the
// puzzle is chosen from the local date instead of a random seed. This is kept
// separate from [DailyChallengeService] (which only owns submission
// bookkeeping) so the selection rules stay small, pure and testable.

class DailyPuzzle {
  DailyPuzzle._();

  /// Stable integer key for [now]'s calendar day: `yyyymmdd` (local time).
  static int dateSeed([DateTime? now]) {
    final d = now ?? DateTime.now();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// Arrow Puzzle (silhouette) level id in `1..levelCount`, biased to the later,
  /// more interesting silhouettes so a daily is never trivially easy.
  static int silhouetteLevelId(int levelCount, [DateTime? now]) {
    if (levelCount <= 0) return 1;
    final seed = dateSeed(now);
    final min = (levelCount * 0.40).floor().clamp(1, levelCount);
    final span = levelCount - min + 1;
    return min + (seed % span);
  }

  /// Flow Free level number (>= 1). Mid-size boards (25..64) make a fair and
  /// consistently challenging daily puzzle.
  static int flowFreeLevelNumber([DateTime? now]) {
    final seed = dateSeed(now);
    return 25 + (seed % 40);
  }
}
