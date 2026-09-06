import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/puzzle_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_levels.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_models.dart';

void main() {
  group('Silhouette puzzle generator', () {
    for (final level in silhouetteLevels) {
      test('${level.name} puzzle is solvable and has curved arrows', () {
        final arrows = level.arrowFactory();
        final stats = _Stats.forLevel(arrows, level);
        // ignore: avoid_print
        print('${level.name}: ${stats.summary}');

        expect(stats.solvable, isTrue,
            reason: '${level.name} must be solvable by construction');
        expect(arrows, isNotEmpty);
        expect(arrows.length, lessThan(60));
        expect(stats.cellsUnique(),
            isTrue, reason: '${level.name}: arrows must not overlap');

        // Arrow heads must never point into (or graze) their own body/tail.
        expect(stats.headsClearOfOwnBody(), isTrue,
            reason: '${level.name}: arrow heads touch their own body');

        // At least some arrows are curved (2+ bends) so boards look nicer.
        expect(stats.curvedCount, greaterThanOrEqualTo(2),
            reason: '${level.name} should include multi-bend arrows');
      });
    }
  });
}

class _Stats {
  final List<ArrowPiece> arrows;
  final bool solvable;
  final int curvedCount;
  final double fillPercent;
  final String summary;
  final int gridRows;
  final int gridCols;

  _Stats._(
    this.arrows,
    this.solvable,
    this.curvedCount,
    this.fillPercent,
    this.summary,
    this.gridRows,
    this.gridCols,
  );

  bool cellsUnique() {
    final seen = <({int r, int c})>{};
    for (final arrow in arrows) {
      for (final cell in arrow.cells) {
        if (!seen.add((r: cell.row, c: cell.col))) return false;
      }
    }
    return true;
  }

  /// Every arrow's head corridor (the straight line it escapes along, plus
  /// the two lateral neighbours so the head never grazes its own arms) must be
  /// free of the arrow's own body/tail cells.
  bool headsClearOfOwnBody() {
    for (final arrow in arrows) {
      final own = arrow.cells.toSet();
      final head = arrow.headCell;
      final d = arrow.direction;
      final pdr = d.dx;
      final pdc = -d.dy;
      var r = head.row + d.dy;
      var c = head.col + d.dx;
      while (r >= 0 && r < gridRows && c >= 0 && c < gridCols) {
        if (own.contains(GridCell(r, c)) ||
            own.contains(GridCell(r + pdr, c + pdc)) ||
            own.contains(GridCell(r - pdr, c - pdc))) {
          return false;
        }
        r += d.dy;
        c += d.dx;
      }
    }
    return true;
  }

  factory _Stats.forLevel(List<ArrowPiece> arrows, SilhouetteLevel level) {
    final fill = <({int r, int c})>{};
    for (final arrow in arrows) {
      for (final cell in arrow.cells) {
        fill.add((r: cell.row, c: cell.col));
      }
    }
    var totalCells = _countMaskCells(level.mask);
    var curved = 0;
    for (final arrow in arrows) {
      if (_countBends(arrow.cells) >= 2) curved++;
    }
    final fillPercent =
        totalCells == 0 ? 100.0 : fill.length * 100.0 / totalCells;
    return _Stats._(
      arrows,
      arrowsAreSolvable(arrows, level.gridRows, level.gridCols),
      curved,
      fillPercent,
      'arrows=${arrows.length} fill=${fillPercent.toStringAsFixed(1)}% '
          'curved(bends>=2)=$curved',
      level.gridRows,
      level.gridCols,
    );
  }

  @override
  String toString() => summary;
}

int _countMaskCells(List<List<bool>> mask) {
  var count = 0;
  for (final row in mask) {
    for (final c in row) {
      if (c) count++;
    }
  }
  return count;
}

int _countBends(List<GridCell> path) {
  var bends = 0;
  for (var i = 2; i < path.length; i++) {
    final a = path[i - 2];
    final b = path[i - 1];
    final c = path[i];
    final d1 = (b.row - a.row, b.col - a.col);
    final d2 = (c.row - b.row, c.col - b.col);
    if (d1 != d2) bends++;
  }
  return bends;
}