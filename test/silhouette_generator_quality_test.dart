import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/puzzle_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_levels.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_models.dart';

/// Encoded cell key for set lookups.
int _key(int r, int c, int cols) => r * cols + c;

ArrowDirection? _lastSegmentDirection(List<GridCell> path) {
  if (path.length < 2) return null;
  final prev = path[path.length - 2];
  final last = path.last;
  if (last.col > prev.col) return ArrowDirection.right;
  if (last.col < prev.col) return ArrowDirection.left;
  if (last.row > prev.row) return ArrowDirection.down;
  return ArrowDirection.up;
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

/// Largest connected component size (4-connectivity) of the true mask cells.
({int largest, int total}) _largestMaskComponent(List<List<bool>> mask) {
  final rows = mask.length;
  final cols = mask.isEmpty ? 0 : mask.first.length;
  final seen = <int>{};
  var largest = 0;
  var total = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!mask[r][c]) continue;
      total++;
    }
  }
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!mask[r][c] || seen.contains(_key(r, c, cols))) continue;
      var size = 0;
      final stack = <GridCell>[GridCell(r, c)];
      seen.add(_key(r, c, cols));
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        size++;
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nr = cur.row + d.$1;
          final nc = cur.col + d.$2;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          if (!mask[nr][nc]) continue;
          if (seen.add(_key(nr, nc, cols))) stack.add(GridCell(nr, nc));
        }
      }
      if (size > largest) largest = size;
    }
  }
  return (largest: largest, total: total);
}

/// Returns null when the board is geometrically valid, else a reason.
String? _validateGeometry(SilhouetteLevel level, List<ArrowPiece> arrows) {
  if (level.gridRows != level.mask.length) return 'row count mismatch';
  for (final row in level.mask) {
    if (row.length != level.gridCols) return 'col count mismatch';
  }
  final seen = <int>{};
  final ids = <String>{};
  for (final a in arrows) {
    if (!ids.add(a.id)) return 'duplicate id';
    if (a.cells.isEmpty) return 'empty arrow';
    if (a.cells.length > level.config.maxCells) return 'arrow too long';
    if (a.colorIndex < 0 || a.colorIndex > 5) return 'color out of range';
    final dir = _lastSegmentDirection(a.cells);
    if (dir == null || dir != a.direction) return 'direction mismatch';
    for (var i = 0; i < a.cells.length; i++) {
      final cell = a.cells[i];
      if (cell.row < 0 ||
          cell.row >= level.gridRows ||
          cell.col < 0 ||
          cell.col >= level.gridCols) {
        return 'out of bounds';
      }
      if (!level.mask[cell.row][cell.col]) return 'off-mask cell';
      if (i > 0) {
        final p = a.cells[i - 1];
        if ((cell.row - p.row).abs() + (cell.col - p.col).abs() != 1) {
          return 'disconnected cells';
        }
      }
      if (!seen.add(_key(cell.row, cell.col, level.gridCols))) return 'overlap';
    }
  }
  return null;
}

bool _sameLayout(List<ArrowPiece> a, List<ArrowPiece> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
    if (a[i].direction != b[i].direction) return false;
    if (a[i].colorIndex != b[i].colorIndex) return false;
    if (a[i].cells.length != b[i].cells.length) return false;
    for (var j = 0; j < a[i].cells.length; j++) {
      if (a[i].cells[j].row != b[i].cells[j].row ||
          a[i].cells[j].col != b[i].cells[j].col) {
        return false;
      }
    }
  }
  return true;
}

void main() {
  group('Silhouette generator quality', () {
    for (final level in silhouetteLevels) {
      test('${level.name}: geometry is valid, connected and solvable', () {
        final arrows = level.generateArrows();
        expect(arrows, isNotEmpty, reason: '${level.name} produced no arrows');
        expect(_validateGeometry(level, arrows), isNull);

        // No two arrows share a cell.
        expect(_cellsUnique(arrows, level.gridCols), isTrue);

        // Every arrow's escape ray matches the engine rule (clear of all cells).
        expect(_allEscapesConsistent(arrows, level), isTrue);
        expect(arrowsAreSolvable(arrows, level.gridRows, level.gridCols), isTrue);

        // Silhouette is essentially one connected picture (allow tiny
        // decorative dots up to 10% of cells).
        final comp = _largestMaskComponent(level.mask);
        // ignore: avoid_print
        print('CONN ${level.name}: ${comp.largest}/${comp.total} '
            '(${(comp.largest / comp.total * 100).toStringAsFixed(0)}%)');
        expect(comp.largest, greaterThanOrEqualTo((comp.total * 0.9).floor()),
            reason: '${level.name}: silhouette is fragmented '
                '(${comp.largest}/${comp.total} in largest component)');
      });

      test('${level.name}: arrow length / bend distribution is varied', () {
        final arrows = level.generateArrows();
        final lengths = arrows.map((a) => a.cells.length).toSet();
        // Not a monoculture: at least two distinct arrow lengths.
        expect(lengths.length, greaterThanOrEqualTo(2),
            reason: '${level.name} all arrows are the same length');

        final bends = arrows.map((a) => _countBends(a.cells)).toList();
        final curved = bends.where((b) => b >= 2).length;
        final straight = bends.where((b) => b == 0).length;
        expect(curved, greaterThanOrEqualTo(2));
        expect(straight, greaterThanOrEqualTo(1),
            reason: '${level.name} has no straight arrows');

        // Longest arrow must respect the difficulty cap.
        final longest = arrows.map((a) => a.cells.length).reduce(
            (a, b) => a > b ? a : b);
        expect(longest, lessThanOrEqualTo(level.config.maxCells));
      });

      test('${level.name}: generation is deterministic', () {
        final a = level.generateArrows();
        final b = level.generateArrows();
        expect(_sameLayout(a, b), isTrue,
            reason: '${level.name} generated different boards across runs');
      });

      test('${level.name}: neighbouring arrows rarely share a colour', () {
        final arrows = level.generateArrows();
        // Map each cell to the arrow that owns it, so we only measure colour
        // clashes *between different arrows* (adjacent cells of one arrow are
        // trivially the same colour).
        final arrowByKey = <int, int>{};
        final colorByKey = <int, int>{};
        for (var i = 0; i < arrows.length; i++) {
          for (final c in arrows[i].cells) {
            final k = _key(c.row, c.col, level.gridCols);
            arrowByKey[k] = i;
            colorByKey[k] = arrows[i].colorIndex;
          }
        }
        var edges = 0;
        var sameColor = 0;
        final counted = <int>{};
        for (final a in arrows) {
          for (final c in a.cells) {
            for (final d in const [(1, 0), (0, 1)]) {
              final nr = c.row + d.$1;
              final nc = c.col + d.$2;
              final k1 = _key(c.row, c.col, level.gridCols);
              final k2 = _key(nr, nc, level.gridCols);
              final c1 = colorByKey[k1];
              final c2 = colorByKey[k2];
              if (c1 == null || c2 == null) continue;
              if (arrowByKey[k1] == arrowByKey[k2]) continue; // same arrow
              // unique undirected pair
              final edgeId = k1 < k2 ? k1 * 100000 + k2 : k2 * 100000 + k1;
              if (!counted.add(edgeId)) continue;
              edges++;
              if (c1 == c2) sameColor++;
            }
          }
        }
        if (edges == 0) return;
        final ratio = sameColor / edges;
        expect(ratio, lessThan(0.5),
            reason: '${level.name}: ${(ratio * 100).toStringAsFixed(0)}% of '
                'adjacent cell edges join same-coloured arrows');
      });
    }

    test('representative heart mask is robust across many seeds', () {
      final heart = silhouetteLevels.first;
      for (final seed in [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 101, 202, 303]) {
        final result = PuzzleGenerator(
          rows: heart.gridRows,
          cols: heart.gridCols,
          mask: heart.mask,
          config: heart.config,
          seed: seed,
        ).generate();
        expect(result.arrows, isNotEmpty, reason: 'seed $seed produced nothing');
        expect(result.solvable, isTrue, reason: 'seed $seed unsolvable');
        expect(_cellsUnique(result.arrows, heart.gridCols), isTrue,
            reason: 'seed $seed has overlapping arrows');
        expect(_validateGeometry(heart, result.arrows), isNull,
            reason: 'seed $seed is geometrically invalid');
        expect(
            arrowsAreSolvable(
                result.arrows, heart.gridRows, heart.gridCols),
            isTrue,
            reason: 'seed $seed fails independent solvability');
      }
    });

    test('generation stays within the mobile time budget', () {
      final sw = Stopwatch()..start();
      for (final level in silhouetteLevels) {
        level.generateArrows();
      }
      sw.stop();
      // Generous bound: all 46 boards must generate well under 30 seconds
      // (typically ~7s including test overhead) so a single board never
      // janks the UI on a phone.
      expect(sw.elapsedMilliseconds, lessThan(30000),
          reason: 'generating all levels took ${sw.elapsedMilliseconds}ms');
    });
  });
}

bool _cellsUnique(List<ArrowPiece> arrows, int cols) {
  final seen = <int>{};
  for (final a in arrows) {
    for (final c in a.cells) {
      if (!seen.add(_key(c.row, c.col, cols))) return false;
    }
  }
  return true;
}

/// Mirrors [SilhouetteEngine.canEscape]: with every arrow on the board, at least
/// one arrow is removable (otherwise the puzzle would open in a dead end).
bool _allEscapesConsistent(List<ArrowPiece> arrows, SilhouetteLevel level) {
  final occ = <int>{};
  for (final a in arrows) {
    for (final c in a.cells) {
      occ.add(_key(c.row, c.col, level.gridCols));
    }
  }
  var removable = 0;
  for (final a in arrows) {
    var r = a.headCell.row + a.direction.dy;
    var c = a.headCell.col + a.direction.dx;
    var clear = true;
    while (r >= 0 && r < level.gridRows && c >= 0 && c < level.gridCols) {
      if (occ.contains(_key(r, c, level.gridCols))) {
        clear = false;
        break;
      }
      r += a.direction.dy;
      c += a.direction.dx;
    }
    if (clear) removable++;
  }
  return removable >= 1;
}
