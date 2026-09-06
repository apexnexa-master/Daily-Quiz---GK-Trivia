import 'dart:collection';
import 'dart:math';

import 'silhouette_models.dart';

class LevelConfig {
  final int minArrows;
  final int maxArrows;
  final int minCells;
  final int maxCells;
  final int maxBends;
  final double largeArrowChance;
  final int maxAttempts;

  const LevelConfig({
    this.minArrows = 4,
    this.maxArrows = 20,
    this.minCells = 2,
    this.maxCells = 8,
    this.maxBends = 2,
    this.largeArrowChance = 0.3,
    this.maxAttempts = 30,
  });

  static const easy = LevelConfig(
    minArrows: 6,
    maxArrows: 14,
    minCells: 2,
    maxCells: 9,
    maxBends: 4,
    largeArrowChance: 0.4,
    maxAttempts: 48,
  );

  static const medium = LevelConfig(
    minArrows: 10,
    maxArrows: 22,
    minCells: 2,
    maxCells: 12,
    maxBends: 4,
    largeArrowChance: 0.5,
    maxAttempts: 44,
  );

  static const hard = LevelConfig(
    minArrows: 14,
    maxArrows: 32,
    minCells: 2,
    maxCells: 14,
    maxBends: 5,
    largeArrowChance: 0.6,
    maxAttempts: 36,
  );

  static const extreme = LevelConfig(
    minArrows: 18,
    maxArrows: 40,
    minCells: 2,
    maxCells: 16,
    maxBends: 6,
    largeArrowChance: 0.7,
    maxAttempts: 64,
  );
}

class PuzzleResult {
  final List<ArrowPiece> arrows;
  final bool solvable;
  final int totalCells;

  const PuzzleResult({
    required this.arrows,
    required this.solvable,
    required this.totalCells,
  });
}

/// A puzzle is solvable iff a greedy solver can peel every arrow.
///
/// This is exact for the game rule: an escapeable arrow can always be removed
/// first, because removing an arrow only frees cells and can never block
/// another arrow's escape. So removing any escapeable arrow greedily is
/// optimal - if no arrow can escape then the puzzle is unsolvable.
bool arrowsAreSolvable(List<ArrowPiece> arrows, int gridRows, int gridCols) {
  final occupied = <GridCell>{};
  for (final arrow in arrows) {
    if (arrow.status == ArrowStatus.active) {
      for (final cell in arrow.cells) {
        occupied.add(cell);
      }
    }
  }

  final active = arrows.toSet();
  while (active.isNotEmpty) {
    var progress = false;
    for (final arrow in active.toList()) {
      final head = arrow.headCell;
      final dir = arrow.direction;
      var r = head.row + dir.dy;
      var c = head.col + dir.dx;
      var clear = true;
      while (r >= 0 && r < gridRows && c >= 0 && c < gridCols) {
        if (occupied.contains(GridCell(r, c))) {
          clear = false;
          break;
        }
        r += dir.dy;
        c += dir.dx;
      }
      if (clear) {
        for (final cell in arrow.cells) {
          occupied.remove(cell);
        }
        active.remove(arrow);
        progress = true;
      }
    }
    if (!progress) return false;
  }
  return true;
}

class PuzzleGenerator {
  final int rows;
  final int cols;
  final List<List<bool>> mask;
  final LevelConfig config;
  final Random _rng;
  int _nextId = 0;

  late List<List<bool>> _occupied;

  PuzzleGenerator({
    required this.rows,
    required this.cols,
    required this.mask,
    this.config = LevelConfig.medium,
    int seed = 0,
  }) : _rng = seed == 0 ? Random() : Random(seed);

  bool _inBounds(int r, int c) =>
      r >= 0 && r < rows && c >= 0 && c < cols;

  int get _maskCellCount {
    var count = 0;
    for (var r = 0; r < rows; r++) {
      if (r >= mask.length) break;
      for (var c = 0; c < cols; c++) {
        if (c < mask[r].length && mask[r][c]) count++;
      }
    }
    return count;
  }

  List<GridCell> _getUnoccupiedMaskCells() {
    final cells = <GridCell>[];
    for (var r = 0; r < rows; r++) {
      if (r >= mask.length) break;
      for (var c = 0; c < cols; c++) {
        if (c < mask[r].length && mask[r][c] && !_occupied[r][c]) {
          cells.add(GridCell(r, c));
        }
      }
    }
    return cells;
  }

  /// Distance from each mask cell to the nearest mask edge (multi-source BFS
  /// seeded at cells touching the shape's outside).
  late final Map<GridCell, int> _depths = _computeDepths();

  Map<GridCell, int> _computeDepths() {
    final dist = <GridCell, int>{};
    final queue = Queue<GridCell>();
    bool inMask(int r, int c) =>
        _inBounds(r, c) &&
        r < mask.length &&
        c < mask[r].length &&
        mask[r][c];
    for (var r = 0; r < rows; r++) {
      if (r >= mask.length) break;
      for (var c = 0; c < cols; c++) {
        if (c >= mask[r].length || !mask[r][c]) continue;
        if (!inMask(r + 1, c) ||
            !inMask(r - 1, c) ||
            !inMask(r, c + 1) ||
            !inMask(r, c - 1)) {
          dist[GridCell(r, c)] = 0;
          queue.add(GridCell(r, c));
        }
      }
    }
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      final d = dist[cur]! + 1;
      final options = [
        (cur.row - 1, cur.col),
        (cur.row + 1, cur.col),
        (cur.row, cur.col - 1),
        (cur.row, cur.col + 1),
      ];
      for (final (nr, nc) in options) {
        final n = GridCell(nr, nc);
        if (inMask(nr, nc) && !dist.containsKey(n)) {
          dist[n] = d;
          queue.add(n);
        }
      }
    }
    return dist;
  }

  int _depthOf(GridCell c) {
    if (!_inBounds(c.row, c.col)) return 0;
    if (c.row >= mask.length || c.col >= mask[c.row].length || !mask[c.row][c.col]) {
      return 0;
    }
    return _depths[c] ?? 0;
  }

  /// Unoccupied mask cells ordered deep-first. Placing deeper (interior) cells
  /// before shallower (edge) ones means pockets never get walled off by arrows
  /// that come later, so the silhouette fills far more densely.
  List<GridCell> _orderedUnoccupied() {
    final cells = _getUnoccupiedMaskCells();
    cells.sort((a, b) => _depthOf(b).compareTo(_depthOf(a)));
    return cells;
  }

  GridCell? _pickStartExcluding(Set<GridCell> failed) {
    final cells = _getUnoccupiedMaskCells();
    if (cells.isEmpty) return null;
    final fresh = <GridCell>[];
    for (final cell in cells) {
      if (!failed.contains(cell)) fresh.add(cell);
    }
    if (fresh.isEmpty) return null;
    return fresh[_rng.nextInt(fresh.length)];
  }

  /// Curved growth: walks from [start] toward [targetLen], turning 90 degrees
  /// on a random basis (up to [maxBends]) and also turning when the straight
  /// continuation is blocked, so arrows curl around the silhouette. With
  /// [outward] (default) the initial direction and every turn prefer moving
  /// toward shallower cells, so the head settles near the shape's edge where
  /// its escape line is least likely to be blocked.
  List<GridCell>? _growPath(GridCell start, int targetLen, int maxBends,
      {bool outward = true}) {
    final initialDirs = ArrowDirection.values.toList();
    if (outward) {
      initialDirs.sort((a, b) =>
          _depthOf(GridCell(start.row + a.dy, start.col + a.dx)).compareTo(
              _depthOf(GridCell(start.row + b.dy, start.col + b.dx))));
    } else {
      initialDirs.shuffle(_rng);
    }
    for (final initDir in initialDirs) {
      final path = <GridCell>[start];
      var cur = start;
      var curDir = initDir;
      var turnsLeft = maxBends;

      bool stepFree(int r, int c) =>
          _isFree(r, c) && !path.contains(GridCell(r, c));

      for (var i = 1; i < targetLen; i++) {
        if (!stepFree(cur.row + curDir.dy, cur.col + curDir.dx)) {
          if (turnsLeft <= 0) break;
          final turn = outward
              ? _outwardTurnBetween(curDir, cur)
              : _randomTurnBetween(curDir);
          final tr = cur.row + turn.dy;
          final tc = cur.col + turn.dx;
          if (!stepFree(tr, tc)) break;
          curDir = turn;
          turnsLeft--;
          cur = GridCell(tr, tc);
          path.add(cur);
          continue;
        }
        cur = GridCell(cur.row + curDir.dy, cur.col + curDir.dx);
        path.add(cur);
        if (turnsLeft > 0 && _rng.nextDouble() < 0.45) {
          final turn = outward
              ? _outwardTurnBetween(curDir, cur)
              : _randomTurnBetween(curDir);
          final tr = cur.row + turn.dy;
          final tc = cur.col + turn.dx;
          if (stepFree(tr, tc)) {
            curDir = turn;
            turnsLeft--;
          }
        }
      }

      if (path.length >= config.minCells) {
        final withTail = _straightenTip(path);
        if (withTail != null) return withTail;
      }
    }
    return null;
  }

  /// A perpendicular turn that leans toward the shape's edge (shallower cells)
  /// most of the time, keeping the arrow's head pointed toward open space.
  ArrowDirection _outwardTurnBetween(ArrowDirection dir, GridCell at) {
    final options = switch (dir) {
      ArrowDirection.up || ArrowDirection.down => [
          ArrowDirection.left,
          ArrowDirection.right
        ],
      _ => [ArrowDirection.up, ArrowDirection.down],
    };
    options.sort((a, b) =>
        _depthOf(GridCell(at.row + a.dy, at.col + a.dx)).compareTo(
            _depthOf(GridCell(at.row + b.dy, at.col + b.dx))));
    if (_rng.nextDouble() < 0.65) return options.first;
    return options[_rng.nextInt(options.length)];
  }

  /// Ensure the arrow has a straight tail (at least 2 cells) so the head is
  /// drawn off the end of the shaft and never right at a bend. Straight arrows
  /// are fine as-is. Bent arrows extend their tip straight if the last segment
  /// is a single cell and room allows; otherwise the path is rejected so a
  /// different shape is tried.
  List<GridCell>? _straightenTip(List<GridCell> path) {
    if (_countBends(path) == 0) return path;
    final dir = _lastSegmentDirection(path);
    if (dir == null) return null;
    final extended = List<GridCell>.from(path);
    var cur = extended.last;
    while (_lastSegmentLength(extended) < 2) {
      final nr = cur.row + dir.dy;
      final nc = cur.col + dir.dx;
      // Must not step onto the arrow's own body or another arrow.
      if (!_isFree(nr, nc) || extended.contains(GridCell(nr, nc))) return null;
      cur = GridCell(nr, nc);
      extended.add(cur);
    }
    return extended;
  }

  int _lastSegmentLength(List<GridCell> path) {
    if (path.length < 2) return path.length;
    final last = path.last;
    final prev = path[path.length - 2];
    final dr = last.row - prev.row;
    final dc = last.col - prev.col;
    var len = 1;
    for (var i = path.length - 2; i >= 1; i--) {
      final a = path[i];
      final b = path[i - 1];
      if (a.row - b.row == dr && a.col - b.col == dc) {
        len++;
      } else {
        break;
      }
    }
    return len;
  }

  bool _isFree(int r, int c) {
    if (!_inBounds(r, c)) return false;
    if (r >= mask.length || c >= mask[r].length || !mask[r][c]) return false;
    return !_occupied[r][c];
  }

  ArrowDirection _randomTurnBetween(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:
      case ArrowDirection.down:
        return _rng.nextDouble() < 0.5
            ? ArrowDirection.left
            : ArrowDirection.right;
      case ArrowDirection.left:
      case ArrowDirection.right:
        return _rng.nextDouble() < 0.5
            ? ArrowDirection.up
            : ArrowDirection.down;
    }
  }

  ArrowDirection? _lastSegmentDirection(List<GridCell> path) {
    if (path.length < 2) return null;
    final prev = path[path.length - 2];
    final last = path.last;
    if (last.col > prev.col) return ArrowDirection.right;
    if (last.col < prev.col) return ArrowDirection.left;
    if (last.row > prev.row) return ArrowDirection.down;
    return ArrowDirection.up;
  }

  /// The escape direction is always the arrow's last-segment direction, so the
  /// head projects straight out of the shaft tip instead of sitting on a bend.
  /// Returns null when that outward line is blocked by other arrows or self.
  ArrowDirection? _escapeDirection(List<GridCell> path, Set<GridCell> own) {
    final dir = _lastSegmentDirection(path);
    if (dir == null) return null;
    if (!_hasClearRun(path.last, dir, own)) return null;
    return dir;
  }

  bool _hasClearRun(GridCell head, ArrowDirection dir, Set<GridCell> own) {
    final pdy = dir.dx;
    final pdx = -dir.dy;
    var r = head.row + dir.dy;
    var c = head.col + dir.dx;
    while (_inBounds(r, c)) {
      final cell = GridCell(r, c);
      if (own.contains(cell) || _occupied[r][c]) return false;
      // Lateral clearance: the head must not graze the arrow's own body or
      // tail as it points across a pocket formed by its own arms.
      if (own.contains(GridCell(r + pdy, c + pdx))) return false;
      if (own.contains(GridCell(r - pdy, c - pdx))) return false;
      r += dir.dy;
      c += dir.dx;
    }
    return true;
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

  /// Build a solvable board by placing arrows in peel order.
  ///
  /// Placements happen so that each new arrow's head has a clear outward run
  /// w.r.t. every earlier arrow. When arrows are then removed in the reverse
  /// game - peel order [k, k-1, ..., 1] - arrow *i* only needs to clear the
  /// arrows still on the board ([1..i]), which is guaranteed by construction.
  List<ArrowPiece> _generateSolvableBoard() {
    _occupied = List.generate(rows, (_) => List.filled(cols, false));
    final pieces = <ArrowPiece>[];
    final failed = <GridCell>{};
    _nextId = 0;

    // Big curved anchors first: they are removed last, so their escape lines
    // may freely cross every region that later arrows will fill.
    _placeCurvyAnchors(pieces);

    // Interleave main arrows with pocket-filling sweeps, in small depth-ordered
    // batches. Filling each band of pockets right after the arrows around it
    // are placed keeps the silhouette dense instead of leaving hollow spots.
    for (var round = 0; round < 8; round++) {
      _placeMainArrows(pieces, failed, config.maxArrows ~/ 8 + 1);
      _microFill(pieces);
      if (round.isEven) _topUpLeftovers(pieces);
    }

    _topUpLeftovers(pieces);
    _microFill(pieces);
    _microFill(pieces);

    return pieces;
  }

  void _placeMainArrows(
      List<ArrowPiece> pieces, Set<GridCell> failed, int budget) {
    final candidates = _orderedUnoccupied();
    var idx = 0;
    var placedThisRound = 0;
    var safety = 0;
    final maxSafety = 400 + budget * 60;
    while (safety < maxSafety &&
        placedThisRound < budget &&
        idx < candidates.length) {
      safety++;
      if (pieces.length >= config.maxArrows * 2) break;
      final start = candidates[idx++];
      if (failed.contains(start)) continue;
      if (_occupied[start.row][start.col]) continue;

      final isLarge = _rng.nextDouble() < config.largeArrowChance;
      final targetLen = isLarge
          ? max(config.maxCells - 1, config.minCells) + _rng.nextInt(2)
          : config.minCells +
              _rng.nextInt(max(1, config.maxCells - config.minCells));
      final capped = targetLen.clamp(config.minCells, config.maxCells).toInt();
      final bends = isLarge ? config.maxBends : max(1, config.maxBends - 1);

      if (_tryPlaceAt(pieces, start, capped, bends)) {
        placedThisRound++;
      } else {
        failed.add(start);
      }
    }
  }

  bool _tryPlaceAt(
      List<ArrowPiece> pieces, GridCell start, int targetLen, int bends) {
    for (var attempt = 0; attempt < 8; attempt++) {
      final path = _growPath(start, targetLen, bends);
      if (path == null) continue;
      final own = path.toSet();
      final dir = _escapeDirection(path, own);
      if (dir == null) continue;
      _addPiece(pieces, path, dir);
      return true;
    }
    return false;
  }

  /// Place several large curved arrows up front so every board has big
  /// multi-bend arrows (organic, realistic look). More anchors for bigger
  /// shapes.
  void _placeCurvyAnchors(List<ArrowPiece> pieces) {
    final totalCells = _maskCellCount;
    final budget = (totalCells ~/ 20).clamp(4, 9);
    var placed = 0;
    var safety = 0;
    while (placed < budget && safety < budget * 60) {
      safety++;
      final start = _pickStartExcluding(const {});
      if (start == null) break;
      final targetLen = max(config.maxCells, config.minCells + 1);
      final path = _growPath(start, targetLen, config.maxBends);
      if (path == null || _countBends(path) < 2) continue;
      final own = path.toSet();
      final dir = _escapeDirection(path, own);
      if (dir == null) continue;
      _addPiece(pieces, path, dir);
      placed++;
    }
  }

  void _addPiece(
      List<ArrowPiece> pieces, List<GridCell> path, ArrowDirection dir) {
    for (final cell in path) {
      _occupied[cell.row][cell.col] = true;
    }
    pieces.add(ArrowPiece(
      id: 'a${_nextId++}',
      cells: List.unmodifiable(path),
      direction: dir,
      colorIndex: _rng.nextInt(6),
    ));
  }

  /// Second pass: fill remaining holes with small arrows (2-6 cells), including
  /// straight 2-cell fillers. Short paths have short escape runs, so they
  /// succeed on awkward leftovers and make the silhouette denser.
  void _topUpLeftovers(List<ArrowPiece> pieces) {
    final leftover = _orderedUnoccupied();
    for (final start in leftover) {
      if (_occupied[start.row][start.col]) continue;
      var placed = false;
      for (var attempt = 0; attempt < 8 && !placed; attempt++) {
        final len = attempt == 0 ? 2 : _rng.nextInt(5) + 2;
        final bends = len == 2 ? 0 : (_rng.nextDouble() < 0.4 ? 2 : 1);
        final path = _growPath(start, len, bends);
        if (path == null) continue;
        final own = path.toSet();
        final dir = _escapeDirection(path, own);
        if (dir == null) continue;
        _addPiece(pieces, path, dir);
        placed = true;
      }
    }
  }

  /// Exhaustive gap filler: repeatedly sweeps every empty cell trying a
  /// straight 2-cell arrow first, then small bent arrows (which sit snugly in
  /// corner/bend-shaped leftover spaces), until a full sweep places nothing.
  void _microFill(List<ArrowPiece> pieces) {
    const lens = [2, 3, 3, 4, 3, 4, 5];
    const bends = [0, 1, 2, 1, 1, 2, 2];
    for (var sweep = 0; sweep < 12; sweep++) {
      var progress = false;
      final empty = _orderedUnoccupied();
      for (final start in empty) {
        if (_occupied[start.row][start.col]) continue;
        for (var i = 0; i < lens.length; i++) {
          final path = _growPath(start, lens[i], bends[i]);
          if (path == null) continue;
          final own = path.toSet();
          final dir = _escapeDirection(path, own);
          if (dir == null) continue;
          _addPiece(pieces, path, dir);
          progress = true;
          break;
        }
      }
      if (!progress) break;
    }
  }

  /// Generate a solvable puzzle. Every board built here is solvable by
  /// construction; several random ones are produced and the best-looking
  /// (highest fill, more curved arrows) is returned.
  PuzzleResult generate() {
    final totalCells = _maskCellCount;
    if (totalCells == 0) {
      return const PuzzleResult(arrows: [], solvable: true, totalCells: 0);
    }

    List<ArrowPiece>? best;
    var bestScore = -1;
    for (var attempt = 0; attempt < config.maxAttempts; attempt++) {
      final arrows = _generateSolvableBoard();
      if (arrows.isEmpty) continue;

      var filled = 0;
      var curved = 0;
      for (final arrow in arrows) {
        filled += arrow.cells.length;
        if (_countBends(arrow.cells) >= 2) curved++;
      }

      final fillPct = filled * 1000 ~/ totalCells;
      final score = fillPct + min(curved, 6) * 5;
      if (score > bestScore) {
        bestScore = score;
        best = arrows;
      }
      if (fillPct >= 920 && curved >= 3) break;
    }

    return PuzzleResult(
      arrows: best ?? const [],
      solvable: true,
      totalCells: totalCells,
    );
  }
}
