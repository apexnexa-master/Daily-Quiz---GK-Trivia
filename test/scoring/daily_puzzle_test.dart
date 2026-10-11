import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/core/scoring/daily_puzzle.dart';

void main() {
  group('DailyPuzzle.dateSeed', () {
    test('encodes the calendar day as yyyymmdd', () {
      expect(DailyPuzzle.dateSeed(DateTime(2026, 8, 16)), 20260816);
      expect(DailyPuzzle.dateSeed(DateTime(2026, 1, 5)), 20260105);
      expect(DailyPuzzle.dateSeed(DateTime(2026, 12, 31)), 20261231);
    });

    test('ignores the time of day', () {
      expect(
        DailyPuzzle.dateSeed(DateTime(2026, 8, 16, 23, 59, 59)),
        DailyPuzzle.dateSeed(DateTime(2026, 8, 16, 0, 0, 1)),
      );
    });

    test('defaults to today when no date is passed', () {
      final now = DateTime.now();
      expect(
        DailyPuzzle.dateSeed(),
        now.year * 10000 + now.month * 100 + now.day,
      );
    });
  });

  group('DailyPuzzle.silhouetteLevelId', () {
    test('stays within 1..levelCount for a long span', () {
      for (var day = 1; day <= 90; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        final id = DailyPuzzle.silhouetteLevelId(54, date);
        expect(id, greaterThanOrEqualTo(1));
        expect(id, lessThanOrEqualTo(54));
      }
    });

    test('is deterministic for the same day', () {
      final a = DailyPuzzle.silhouetteLevelId(54, DateTime(2026, 8, 16));
      final b = DailyPuzzle.silhouetteLevelId(54, DateTime(2026, 8, 16));
      expect(a, b);
    });

    test('biases toward the later half of the campaign', () {
      final min = (54 * 0.40).floor();
      for (var day = 1; day <= 120; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        expect(DailyPuzzle.silhouetteLevelId(54, date), greaterThanOrEqualTo(min));
      }
    });

    test('handles a single-level campaign', () {
      expect(DailyPuzzle.silhouetteLevelId(1, DateTime(2026, 8, 16)), 1);
    });

    test('guards against a non-positive level count', () {
      expect(DailyPuzzle.silhouetteLevelId(0, DateTime(2026, 8, 16)), 1);
    });
  });

  group('DailyPuzzle.flowFreeLevelNumber', () {
    test('stays within 25..64 for a long span', () {
      for (var day = 1; day <= 90; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        final n = DailyPuzzle.flowFreeLevelNumber(date);
        expect(n, greaterThanOrEqualTo(25));
        expect(n, lessThanOrEqualTo(64));
      }
    });

    test('is deterministic for the same day', () {
      final a = DailyPuzzle.flowFreeLevelNumber(DateTime(2026, 8, 16));
      final b = DailyPuzzle.flowFreeLevelNumber(DateTime(2026, 8, 16));
      expect(a, b);
    });
  });
}
