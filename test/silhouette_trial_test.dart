import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/puzzle_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_models.dart';

bool _use(int r, int c) => _g[r][c];

List<List<bool>> _g = [];

int _maskCells() {
  var n = 0;
  for (final row in _g) {
    for (final c in row) {
      if (c) n++;
    }
  }
  return n;
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

void runTrial(String name, int seed, LevelConfig cfg,
    {bool board = false}) {
  final mask = _g
      .map((row) => row.map((c) => c).toList())
      .toList();
  final rows = mask.length;
  final cols = mask[0].length;
  final total = _maskCells();
  final arrows = PuzzleGenerator(
          rows: rows, cols: cols, mask: mask, config: cfg, seed: seed)
      .generate()
      .arrows;
  final covered = <({int r, int c})>{};
  var curved = 0;
  for (final a in arrows) {
    for (final c in a.cells) {
      covered.add((r: c.row, c: c.col));
    }
    if (_countBends(a.cells) >= 2) curved++;
  }
  var unique = true;
  final seen = <int>{};
  for (final a in arrows) {
    for (final c in a.cells) {
      if (!seen.add(c.row * cols + c.col)) {
        unique = false;
        break;
      }
    }
    if (!unique) break;
  }
  final solvable = arrowsAreSolvable(arrows, rows, cols);
  final fillPct = total == 0 ? 100.0 : covered.length * 100.0 / total;
  // ignore: avoid_print
  print('$name: arrows=${arrows.length} fill=${fillPct.toStringAsFixed(1)}% '
      'curved=$curved unique=$unique solvable=$solvable cells=$total');
  if (board) {
    final glyph = List.generate(
        rows, (r) => List.generate(cols, (c) => _use(r, c) ? '.' : ' '));
    for (var i = 0; i < arrows.length; i++) {
      final label = i < 26
          ? String.fromCharCode(97 + i)
          : String.fromCharCode(65 + (i - 26));
      final a = arrows[i];
      for (var j = 0; j < a.cells.length; j++) {
        final cell = a.cells[j];
        glyph[cell.row][cell.col] = j == a.cells.length - 1
            ? switch (a.direction) {
                ArrowDirection.up => '^',
                ArrowDirection.down => 'v',
                ArrowDirection.left => '<',
                ArrowDirection.right => '>',
              }
            : label;
      }
    }
    final sb = StringBuffer();
    for (var r = 0; r < glyph.length; r++) {
      sb
        ..write('  ${r.toString().padLeft(2)} ')
        ..writeAll(glyph[r]);
      if (r != glyph.length - 1) sb.writeln();
    }
    // ignore: avoid_print
    print(sb);
  }
}

void newGrid(int h, int w) {
  _g = List.generate(h, (_) => List.filled(w, false));
}

void fill(int r, int c) {
  if (r >= 0 && r < _g.length && c >= 0 && c < _g[0].length) _g[r][c] = true;
}

void unset(int r, int c) {
  if (r >= 0 && r < _g.length && c >= 0 && c < _g[0].length) _g[r][c] = false;
}

void addRect(int r0, int r1, int c0, int c1) {
  for (var r = r0; r <= r1; r++) {
    for (var c = c0; c <= c1; c++) {
      fill(r, c);
    }
  }
}

void addEllipse(double cr, double cc, double rx, double ry) {
  for (var r = (cr - ry).floor(); r <= (cr + ry).ceil(); r++) {
    for (var c = (cc - rx).floor(); c <= (cc + rx).ceil(); c++) {
      if (r < 0 || r >= _g.length || c < 0 || c >= _g[0].length) continue;
      final dx = (c - cc) / rx;
      final dy = (r - cr) / ry;
      if (dx * dx + dy * dy <= 1.0) fill(r, c);
    }
  }
}

void addCircleRing(double cr, double cc, double radius) {
  for (var r = 0; r < _g.length; r++) {
    for (var c = 0; c < _g[0].length; c++) {
      final d = (c - cc) * (c - cc) + (r - cr) * (r - cr);
      if (math.sqrt(d).roundToDouble() == radius) fill(r, c);
    }
  }
}

void addEllipseClearRing(double cr, double cc, double rx, double ry) {
  for (var k = 0; k < 96; k++) {
    final a = k * 2 * math.pi / 96;
    final c = (cc + rx * math.cos(a)).round();
    final r = (cr + ry * math.sin(a)).round();
    unset(r, c);
  }
}

void addLine(int r0, int c0, int r1, int c1) {
  var x = c0;
  var y = r0;
  final dx = (c1 - c0).abs();
  final sx = c0 < c1 ? 1 : -1;
  final dy = -(r1 - r0).abs();
  final sy = r0 < r1 ? 1 : -1;
  var err = dx + dy;
  while (true) {
    fill(y, x);
    if (x == c1 && y == r1) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
}

void rowFills(int r, List<int> cols) {
  for (final c in cols) {
    fill(r, c);
  }
}

const mediumCfg = LevelConfig(
    minArrows: 16, maxArrows: 60, minCells: 4, maxCells: 18,
    maxBends: 7, largeArrowChance: 0.65, maxAttempts: 48, moveSlack: 6);

const megaCfg = LevelConfig(
    minArrows: 20, maxArrows: 90, minCells: 4, maxCells: 22,
    maxBends: 8, largeArrowChance: 0.7, maxAttempts: 52, moveSlack: 5);

void main() {
  test('mask candidates', () {
    // ---- RANGOLI CANDIDATES (22x22) ----
    newGrid(22, 22);
    for (var r = 0; r < 22; r++) {
      for (var c = 0; c < 22; c++) {
        final nx = [r, 21 - r, c, 21 - c].reduce((a, b) => a < b ? a : b);
        final band = nx == 0 ||
            nx == 1 ||
            nx == 2 ||
            nx == 4 ||
            nx == 5 ||
            nx == 6 ||
            nx == 8 ||
            nx == 9 ||
            nx == 10;
        final spoke = (r - c).abs() <= 2 || ((r + c) - 21).abs() <= 2;
        if (band || spoke) fill(r, c);
      }
    }
    runTrial('RG-squares3+diag2', 25, megaCfg);

    // ---- RANGOLI: solid square + diagonal lattice channels ----
    newGrid(22, 22);
    addRect(0, 21, 0, 21);
    for (var r = 3; r <= 18; r++) {
      for (var c = 3; c <= 18; c++) {
        if ((r - c).abs() % 4 == 0 || ((r + c) - 21).abs() % 4 == 0) {
          unset(r, c);
        }
      }
    }
    runTrial('RG-lattice', 25, megaCfg);

    // ---- RANGOLI: concentric circle rings + 8 fat spokes ----
    newGrid(22, 22);
    addEllipse(10.5, 10.5, 2.5, 2.5);
    for (var k = 0; k < 8; k++) {
      final a = k * 2 * math.pi / 8;
      final r1 = (10.5 + 5 * math.sin(a)).round();
      final c1 = (10.5 + 5 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
    }
    for (final r in [4, 5, 7, 8, 10, 11]) {
      addCircleRing(10.5, 10.5, r.toDouble());
    }
    runTrial('RG-circles', 25, megaCfg, board: true);

    // ---- RANGOLI: fatter spokes + outer ring ----
    newGrid(22, 22);
    addEllipse(10.5, 10.5, 2.5, 2.5);
    for (var k = 0; k < 8; k++) {
      final a = k * 2 * math.pi / 8;
      final r1 = (10.5 + 5 * math.sin(a)).round();
      final c1 = (10.5 + 5 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
      addLine(9, 9, r1 - 1, c1 - 1);
      addLine(11, 11, r1 + 1, c1 + 1);
    }
    for (final r in [4, 5, 7, 8, 10, 11, 13]) {
      addCircleRing(10.5, 10.5, r.toDouble());
    }
    runTrial('RG-circles-fatspokes', 25, megaCfg);

    // ---- RANGOLI: sun mandala (16 rays + rings) ----
    newGrid(22, 22);
    addEllipse(10.5, 10.5, 3.0, 3.0);
    for (var k = 0; k < 16; k++) {
      final a = k * 2 * math.pi / 16;
      final r1 = (10.5 + 6 * math.sin(a)).round();
      final c1 = (10.5 + 6 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
      addLine(9, 9, r1 - 1, c1 - 1);
      addLine(11, 11, r1 + 1, c1 + 1);
    }
    for (final r in [7, 8]) {
      addCircleRing(10.5, 10.5, r.toDouble());
    }
    runTrial('RG-sun16', 25, megaCfg);

    // ---- CHAKRA attempts comparison ----
    const realMega = LevelConfig(
        minArrows: 20, maxArrows: 90, minCells: 4, maxCells: 22,
        maxBends: 8, largeArrowChance: 0.7, maxAttempts: 40, moveSlack: 5);
    newGrid(21, 21);
    addEllipse(10, 10, 1.7, 1.7);
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      final r1 = (10 + 7 * math.sin(a)).round();
      final c1 = (10 + 7 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
    }
    for (final r in [8, 9]) {
      addCircleRing(10, 10, r.toDouble());
    }
    runTrial('CHAKRA-orig-40att', 26, realMega);
    runTrial('CHAKRA-orig-52att', 26, megaCfg);
    newGrid(21, 21);
    addEllipse(10, 10, 2.4, 2.4);
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      final r1 = (10 + 7 * math.sin(a)).round();
      final c1 = (10 + 7 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
    }
    for (final r in [8, 9]) {
      addCircleRing(10, 10, r.toDouble());
    }
    runTrial('CHAKRA-fat-40att', 26, realMega);

    // ---- CHAKRA variants: thick spokes (3-wide), hub fatter ----
    newGrid(21, 21);
    addEllipse(10, 10, 2.4, 2.4);
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      final r1 = (10 + 7 * math.sin(a)).round();
      final c1 = (10 + 7 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
    }
    for (final r in [8, 9]) {
      addCircleRing(10, 10, r.toDouble());
    }
    runTrial('CHAKRA-thickhub', 26, megaCfg);

    // ---- DIYA: curved dish (ellipse ring) + flame ----
    newGrid(16, 19);
    addEllipse(5.0, 9, 1.6, 3.0);
    addEllipse(11.5, 9, 6.4, 4.0);
    addEllipseClearRing(11.0, 9, 4.0, 2.4);
    addRect(15, 15, 7, 11);
    runTrial('DIYA-curvedDish', 29, mediumCfg, board: true);

    // ---- DIYA: solid wide ellipse dish (no carve) + flame ----
    newGrid(16, 19);
    addEllipse(5.0, 9, 1.6, 3.0);
    addEllipse(11.0, 9, 6.4, 4.0);
    addRect(15, 15, 7, 11);
    runTrial('DIYA-solidDish', 29, mediumCfg, board: true);

    // ---- Print raw 1/0 rows for production masks ----
    // RANGOLI sun16
    newGrid(22, 22);
    addEllipse(10.5, 10.5, 3.0, 3.0);
    for (var k = 0; k < 16; k++) {
      final a = k * 2 * math.pi / 16;
      final r1 = (10.5 + 6 * math.sin(a)).round();
      final c1 = (10.5 + 6 * math.cos(a)).round();
      addLine(10, 10, r1, c1);
      addLine(9, 9, r1 - 1, c1 - 1);
      addLine(11, 11, r1 + 1, c1 + 1);
    }
    for (final r in [7, 8]) {
      addCircleRing(10.5, 10.5, r.toDouble());
    }
    // ignore: avoid_print
    print('--- RANGOLI SUN16 MASK (22x22) ---');
    for (var r = 0; r < 22; r++) {
      final row = List.generate(22, (c) => _g[r][c] ? '1' : '0').join();
      // ignore: avoid_print
      print(row);
    }
    // ignore: avoid_print
    print('--- DIYA SOLID DISH MASK (16x19) ---');
    newGrid(16, 19);
    addEllipse(5.0, 9, 1.6, 3.0);
    addEllipse(11.0, 9, 6.4, 4.0);
    addRect(15, 15, 7, 11);
    for (var r = 0; r < 16; r++) {
      final row = List.generate(19, (c) => _g[r][c] ? '1' : '0').join();
      // ignore: avoid_print
      print(row);
    }
  });
}