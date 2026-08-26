import 'dart:math';

import 'silhouette_models.dart';

class SilhouetteLevel {
  final int id;
  final String name;
  final String themeEmoji;
  final String description;
  final int gridCols;
  final int gridRows;
  final List<List<bool>> mask;
  final List<ArrowPiece> Function() arrowFactory;
  final int maxMoves;

  const SilhouetteLevel({
    required this.id,
    required this.name,
    required this.themeEmoji,
    required this.description,
    required this.gridCols,
    required this.gridRows,
    required this.mask,
    required this.arrowFactory,
    required this.maxMoves,
  });

  List<ArrowPiece> generateArrows() => arrowFactory();
}

List<List<bool>> _parseMask(String compact) {
  final lines = compact.split('\n').where((l) => l.trim().isNotEmpty);
  final rows = <List<bool>>[];
  for (final line in lines) {
    rows.add(line.trim().split('').map((c) => c == '1').toList());
  }
  return rows;
}

class ArrowPathFinder {
  final int rows;
  final int cols;
  final List<List<bool>> mask;
  final List<List<bool>> occupied;
  final Random _rng;
  int _nextId = 0;

  ArrowPathFinder(this.rows, this.cols, this.mask, {int seed = 0})
      : occupied = List.generate(rows, (_) => List.filled(cols, false)),
        _rng = seed == 0 ? Random() : Random(seed);

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Pick a random unoccupied mask cell.
  GridCell? _pickStart() {
    final candidates = <GridCell>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (mask[r][c] && !occupied[r][c]) {
          candidates.add(GridCell(r, c));
        }
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[_rng.nextInt(candidates.length)];
  }

  /// Attempt to create one arrow piece starting from a given cell, growing
  /// a random path of 2–8 cells in a consistent direction (with 90° turns).
  List<GridCell>? _growPath(GridCell start) {
    final r = _rng.nextDouble();
    final maxLen = r < 0.3 ? 6 + _rng.nextInt(3) : 2 + _rng.nextInt(4);
    final dirs = ArrowDirection.values.toList()..shuffle(_rng);
    for (final startDir in dirs) {
      final path = [start];
      var cur = start;
      var curDir = startDir;
      var turnsLeft = maxLen >= 6 ? 2 : 1;
      for (int i = 1; i < maxLen; i++) {
        final nr = cur.row + curDir.dy;
        final nc = cur.col + curDir.dx;
        if (_inBounds(nr, nc) &&
            mask[nr][nc] &&
            !occupied[nr][nc] &&
            !path.contains(GridCell(nr, nc))) {
          cur = GridCell(nr, nc);
          path.add(cur);
          // Maybe turn 90°
          if (turnsLeft > 0 && _rng.nextDouble() < 0.4) {
            final perpDirs = ArrowDirection.values
                .where((d) =>
                    d != curDir && d != curDir.opposite)
                .toList()
                  ..shuffle(_rng);
            curDir = perpDirs.first;
            turnsLeft--;
          }
        } else {
          break;
        }
      }
      if (path.length >= 2) return path;
    }
    return null;
  }

  /// Generate arrow pieces that densely fill the mask.
  List<ArrowPiece> generate() {
    final pieces = <ArrowPiece>[];
    int safety = 0;
    while (safety < 5000) {
      safety++;
      final start = _pickStart();
      if (start == null) break;
      final path = _growPath(start);
      if (path == null) {
        // Mark single cell as occupied so we move on
        occupied[start.row][start.col] = true;
        continue;
      }
      // Determine arrow direction from last segment
      final ArrowDirection dir;
      if (path.length >= 2) {
        final prev = path[path.length - 2];
        final last = path.last;
        if (last.col > prev.col) {
          dir = ArrowDirection.right;
        } else if (last.col < prev.col) {
          dir = ArrowDirection.left;
        } else if (last.row > prev.row) {
          dir = ArrowDirection.down;
        } else {
          dir = ArrowDirection.up;
        }
      } else {
        dir = ArrowDirection.values[_rng.nextInt(4)];
      }
      // Mark cells occupied
      for (final cell in path) {
        occupied[cell.row][cell.col] = true;
      }
      final colorIdx = _rng.nextInt(6);
      pieces.add(ArrowPiece(
        id: 'a${_nextId++}',
        cells: List.unmodifiable(path),
        direction: dir,
        colorIndex: colorIdx,
      ));
    }
    return pieces;
  }
}

List<ArrowPiece> _generateLevelArrows(SilhouetteLevel level) {
  final finder = ArrowPathFinder(
    level.gridRows,
    level.gridCols,
    level.mask,
    seed: level.id,
  );
  return finder.generate();
}

final heartMaskCompact = '''
0000111111110000
0001111111111000
0011111111111100
0111111111111110
0111111111111110
1111111111111111
1111111111111111
1111111111111111
1111111111111111
0111111111111110
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
0000000110000000
''';

final starMaskCompact = '''
0000001100000000
0000011110000000
0000111111000000
0001111111100000
1111111111111110
0111111111111100
0011111111111000
0001111111110000
0011110001111000
0111100000111100
1111000000011110
1110000000001110
1000000000000010
''';

final birdMaskCompact = '''
0000000111000000
0000001111100000
0000011111110000
0000111111111000
0001111111111100
0011111111111110
0111111111111100
1111111111111000
0111111111110000
0011111111100000
0001111111000000
0000111110000000
0000011100000000
''';

final diamondMaskCompact = '''
0000000110000000
0000001111000000
0000011111100000
0000111111110000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
0000000110000000
''';

final treeMaskCompact = '''
0000000110000000
0000001111000000
0000011111100000
0000111111110000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0000001111000000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
''';

final moonMaskCompact = '''
0000001111000000
0000111111110000
0001111111111000
0011111101111100
0111111000111110
0111110000011110
1111100000001111
1111100000001111
0111110000011110
0111111000111110
0011111101111100
0001111111111000
0000111111110000
0000001111000000
''';

final flowerMaskCompact = '''
0000001111000000
0000111111110000
0001111001111000
0111100000011110
0111000000001110
1110000000000111
1110000000000111
0111000000001110
0111100000011110
0001111001111000
0000111111110000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
''';

final shieldMaskCompact = '''
0000111111110000
0001111111111000
0011111111111100
0111111111111110
0111111111111110
1111111111111111
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
''';

final List<SilhouetteLevel> silhouetteLevels = [
  SilhouetteLevel(
    id: 1,
    name: 'Heart',
    themeEmoji: '\u2764\uFE0F',
    description: 'Fill the heart with arrows',
    gridCols: 16,
    gridRows: 17,
    mask: _parseMask(heartMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[0]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 2,
    name: 'Star',
    themeEmoji: '\u2B50',
    description: 'Fill the star with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(starMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[1]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 3,
    name: 'Bird',
    themeEmoji: '\uD83D\uDC26',
    description: 'Fill the bird with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(birdMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[2]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 4,
    name: 'Diamond',
    themeEmoji: '\uD83D\uDC8E',
    description: 'Fill the diamond with arrows',
    gridCols: 16,
    gridRows: 16,
    mask: _parseMask(diamondMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[3]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 5,
    name: 'Tree',
    themeEmoji: '\uD83C\uDF33',
    description: 'Fill the tree with arrows',
    gridCols: 16,
    gridRows: 14,
    mask: _parseMask(treeMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[4]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 6,
    name: 'Moon',
    themeEmoji: '\uD83C\uDF19',
    description: 'Fill the crescent moon with arrows',
    gridCols: 16,
    gridRows: 14,
    mask: _parseMask(moonMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[5]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 7,
    name: 'Flower',
    themeEmoji: '\uD83C\uDF3C',
    description: 'Fill the flower with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(flowerMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[6]),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 8,
    name: 'Shield',
    themeEmoji: '\uD83D\uDEE1\uFE0F',
    description: 'Fill the shield with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(shieldMaskCompact),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[7]),
    maxMoves: 35,
  ),
];
