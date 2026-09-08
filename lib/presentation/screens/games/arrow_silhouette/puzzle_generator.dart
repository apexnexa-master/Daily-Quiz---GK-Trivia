import 'dart:math';

import 'silhouette_models.dart';

/// Difficulty profile for a silhouette level.
///
/// Controls how the generator builds arrows and how generous the star rating
/// is. `moveSlack` is the number of wasted taps a player is allowed while still
/// earning 3 stars.
class LevelConfig {
  final int minArrows;
  final int maxArrows;
  final int minCells;
  final int maxCells;
  final int maxBends;
  final double largeArrowChance;
  final int maxAttempts;
  final int moveSlack;

  const LevelConfig({
    this.minArrows = 4,
    this.maxArrows = 20,
    this.minCells = 3,
    this.maxCells = 11,
    this.maxBends = 4,
    this.largeArrowChance = 0.45,
    this.maxAttempts = 30,
    this.moveSlack = 8,
  });

  static const easy = LevelConfig(
    minArrows: 5,
    maxArrows: 18,
    minCells: 3,
    maxCells: 11,
    maxBends: 4,
    largeArrowChance: 0.45,
    maxAttempts: 56,
    moveSlack: 10,
  );

  static const medium = LevelConfig(
    minArrows: 8,
    maxArrows: 26,
    minCells: 3,
    maxCells: 13,
    maxBends: 5,
    largeArrowChance: 0.55,
    maxAttempts: 48,
    moveSlack: 8,
  );

  static const hard = LevelConfig(
    minArrows: 10,
    maxArrows: 36,
    minCells: 4,
    maxCells: 15,
    maxBends: 6,
    largeArrowChance: 0.65,
    maxAttempts: 40,
    moveSlack: 7,
  );

  static const extreme = LevelConfig(
    minArrows: 12,
    maxArrows: 46,
    minCells: 4,
    maxCells: 18,
    maxBends: 7,
    largeArrowChance: 0.7,
    maxAttempts: 56,
    moveSlack: 6,
  );

  /// Large boards (20+ columns): long flowing strokes that read as clean
  /// picture-maze contours, with enough attempted layouts to reach high fill.
  static const large = LevelConfig(
    minArrows: 16,
    maxArrows: 60,
    minCells: 4,
    maxCells: 18,
    maxBends: 7,
    largeArrowChance: 0.65,
    maxAttempts: 48,
    moveSlack: 6,
  );

  /// Jumbo boards (22+ columns, 400+ cells): the flagship silhouette puzzles.
  /// Arrows may grow extra long and twist through several bends while the
  /// stroke budget still keeps the board from fragmenting into tiny picks.
  static const mega = LevelConfig(
    minArrows: 20,
    maxArrows: 90,
    minCells: 4,
    maxCells: 22,
    maxBends: 8,
    largeArrowChance: 0.7,
    maxAttempts: 40,
    moveSlack: 5,
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

  /// Soft piece budget. Dense contour boards average roughly 6 cells per arrow,
  /// so this is derived from the mask size rather than the difficulty cap
  /// alone. It throttles the tiny-filler passes (so boards don't fragment) but
  /// never stops the ring pass itself.
  int get _maxPieces {
    final bySize = (_maskCellCount / 4).ceil();
    final cap = config.maxArrows * 2;
    if (bySize < config.minArrows) return config.minArrows;
    return bySize > cap ? cap : bySize;
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

  /// Erosion-layer depth of every mask cell: repeatedly peel the 1-cell-thick
  /// outer ring of the remaining shape (like onion layers / picture-maze
  /// contour lines). Cells of a peel share a depth and trace the silhouette's
  /// outline, so arrows that follow them read clearly as the image.
  late final Map<GridCell, int> _depths = _computeDepths();

  Map<GridCell, int> _computeDepths() {
    final remaining = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      if (r >= mask.length) break;
      for (var c = 0; c < cols; c++) {
        if (c < mask[r].length && mask[r][c]) {
          remaining.add(GridCell(r, c));
        }
      }
    }
    final depth = <GridCell, int>{};
    var d = 0;
    while (remaining.isNotEmpty) {
      final layer = <GridCell>{};
      for (final cell in remaining) {
        // Peel any cell that touches cells already peeled or the outside.
        if (!remaining.contains(GridCell(cell.row - 1, cell.col)) ||
            !remaining.contains(GridCell(cell.row + 1, cell.col)) ||
            !remaining.contains(GridCell(cell.row, cell.col - 1)) ||
            !remaining.contains(GridCell(cell.row, cell.col + 1))) {
          layer.add(cell);
        }
      }
      for (final cell in layer) {
        depth[cell] = d;
        remaining.remove(cell);
      }
      d++;
    }
    return depth;
  }

  int _depthOf(GridCell c) {
    if (!_inBounds(c.row, c.col)) return 0;
    if (c.row >= mask.length || c.col >= mask[c.row].length || !mask[c.row][c.col]) {
      return 0;
    }
    return _depths[c] ?? 0;
  }

  int _crossSense(ArrowDirection a, ArrowDirection b) {
    final cross = a.dy * b.dx - a.dx * b.dy;
    if (cross > 0) return 1;
    if (cross < 0) return -1;
    return 0;
  }

  /// Build a solvable board by placing arrows that follow the silhouette's
  /// depth contours, innermost ring first.
  ///
  /// Each new arrow's head is checked to have a clear outward run w.r.t. every
  /// arrow already placed. When arrows are then removed in the reverse order -
  /// peel order [k, k-1, ..., 1] - arrow *i* only needs to clear the arrows
  /// still on the board ([1..i]), exactly the arrows that were on the board
  /// when it was placed. So the board is solvable by construction even though a
  /// contour arrow's head ray may cross cells that later arrows fill.
  List<ArrowPiece> _generateSolvableBoard() {
    _occupied = List.generate(rows, (_) => List.filled(cols, false));
    final pieces = <ArrowPiece>[];
    _nextId = 0;

    _placeSpiral(pieces);

    _topUpLeftovers(pieces);
    _microFill(pieces);
    _pocketFill(pieces);

    return pieces;
  }

  /// Fill the silhouette with long wall-following "snake" strokes, one arrow
  /// after another along a single spiral-like path. Starting from the deepest
  /// remaining cell, the snake carries straight on, then turns in one
  /// consistent sense when it is blocked, so it hugs the shape's contours the
  /// way a picture-maze path does. Repeated from the next-deepest free cell
  /// until the silhouette is covered.
  void _placeSpiral(List<ArrowPiece> pieces) {
    final maxDepth = _depths.values.reduce(max);
    var remaining = _getUnoccupiedMaskCells().toSet();
    var safety = 0;
    while (remaining.isNotEmpty && safety < 5000) {
      safety++;
      GridCell? start;
      var bestDepth = -1;
      for (final cell in remaining) {
        final d = _depthOf(cell);
        if (d > bestDepth) {
          bestDepth = d;
          start = cell;
        }
      }
      if (start == null) break;
      final trail = _walkSpiral(start, remaining);
      _chopAndPlaceTrails(pieces, [trail], maxDepth);
      remaining.removeAll(trail.toSet());
      remaining.removeWhere((c) => _occupied[c.row][c.col]);
      if (trail.length < 2) remaining.remove(start);
    }
  }

  /// Walk a wall-following snake from [start] through free cells, carrying
  /// straight on and turning in one consistent sense at walls, so the trail
  /// reads as a single flowing stroke that curves around the silhouette.
  List<GridCell> _walkSpiral(GridCell start, Set<GridCell> free) {
    final trail = <GridCell>[start];
    final inTrail = <GridCell>{start};
    var cur = start;
    final turnSense = _rng.nextBool() ? 1 : -1;
    var moveDir = _bestContourMove(start, inTrail, free,
        prevDir: null, turnSense: turnSense);
    var safety = 0;
    while (moveDir != null && safety < 1500) {
      safety++;
      final next = GridCell(cur.row + moveDir.dy, cur.col + moveDir.dx);
      trail.add(next);
      inTrail.add(next);
      cur = next;
      final chosen = _bestContourMove(cur, inTrail, free,
          prevDir: moveDir, turnSense: turnSense);
      if (chosen != null) {
        moveDir = chosen;
      } else {
        moveDir = null;
      }
    }
    return trail;
  }

  /// Pick the continuation direction for [at]: among free same-depth neighbours
  /// not already on the trail, prefer carrying straight on, then turning in the
  /// consistent [turnSense] direction. With no previous direction (first step)
  /// a random free neighbour is chosen.
  ArrowDirection? _bestContourMove(
    GridCell at,
    Set<GridCell> inTrail,
    Set<GridCell> free, {
    ArrowDirection? prevDir,
    int? turnSense,
  }) {
    ArrowDirection? best;
    var bestScore = 100;
    for (final d in ArrowDirection.values) {
      if (prevDir != null && d == prevDir.opposite) continue;
      final n = GridCell(at.row + d.dy, at.col + d.dx);
      if (inTrail.contains(n) || !free.contains(n)) continue;
      int score;
      if (prevDir == null) {
        score = _rng.nextInt(10); // arbitrary first move
      } else {
        if (d == prevDir) {
          score = 0;
        } else {
          final cross = _crossSense(prevDir, d);
          score = cross != 0 && turnSense != null && cross == turnSense ? 1 : 3;
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  /// Chop each trail in [trails] into arrows of ~6-8 cells (longer on harder
  /// levels), preferring split points with a straight tail so heads are clean.
  /// Returns true when at least one arrow was placed.
  bool _chopAndPlaceTrails(List<ArrowPiece> pieces,
      List<List<GridCell>> trails, int maxDepth) {
    var placedAny = false;
    for (final trail in trails) {
      final trailSet = trail.toSet();
      var start = 0;
      while (start < trail.length) {
        if (_occupied[trail[start].row][trail[start].col]) {
          start++;
          continue;
        }
        final target = _ringTargetLen(_depthOf(trail[start]), maxDepth);
        final chop = _pickChop(trail, start, target);
        if (chop == null) break;
        var end = chop;
        var placed = false;
        while (end >= start + _minSegLen) {
          if (_tryPlaceRingSegment(
              pieces, trail.sublist(start, end), trailSet)) {
            placed = true;
            break;
          }
          end--;
        }
        if (placed) {
          placedAny = true;
          start = end;
        } else {
          // Nothing worked from this head; its cells stay free for the gap
          // fillers.
          start++;
        }
      }
    }
    return placedAny;
  }

  int get _minSegLen => max(3, config.minCells);

  int _ringTargetLen(int depth, int maxDepth) {
    var len = 6 + _rng.nextInt(3); // 6..8
    if (config.maxCells > 12) len += _rng.nextInt(3); // up to 10 on hard+
    if (depth * 3 >= maxDepth * 2) len += 3; // inner rings: long flowing strokes
    if (cols >= 20) len += 2 + _rng.nextInt(3); // wide boards: longer flowing arms
    return len.clamp(_minSegLen, config.maxCells).toInt();
  }

  /// Choose the end index for the next ring segment near [target] cells long.
  /// Prefers an end where the segment finishes with a straight tail, stays
  /// within the per-arrow bend budget, and is a clean flowing curve (few
  /// direction reversals). Early-cut candidates that leave a hairpin or S-wiggle
  /// in the next segment are avoided by length-budgeting each chop.
  int? _pickChop(List<GridCell> trail, int start, int target) {
    final maxEnd = min(start + target + 2, trail.length);
    int? fallback;
    int? smoothCut;
    for (var end = maxEnd; end >= start + _minSegLen; end--) {
      if (end - start > config.maxCells) continue;
      if (end - start > trail.length - start) continue;
      final seg = trail.sublist(start, end);
      if (_countBends(seg) > config.maxBends) continue;
      if (_lastSegmentLength(seg) >= 2) {
        if (_signFlips(seg) <= 1) return end;
        smoothCut ??= end;
      }
      fallback ??= end;
    }
    return smoothCut ?? fallback;
  }

  /// Place one contour segment as an arrow. Tries the natural orientation, the
  /// reversed one, then grows a short outward "escape tail" from either end so
  /// the head reaches clear air. Every accepted arrow is validated against the
  /// arrows already on the board, preserving the reverse-peel guarantee.
  bool _tryPlaceRingSegment(
      List<ArrowPiece> pieces, List<GridCell> seg, Set<GridCell> trailSet) {
    if (seg.length < max(4, config.minCells)) return false;

    for (final cell in seg) {
      if (_occupied[cell.row][cell.col]) return false;
    }

    final own = seg.toSet();
    final avoid = {...own, ...trailSet};
    final reversed = seg.reversed.toList();
    final revOwn = reversed.toSet();
    final dir = _escapeDirection(seg, own);
    final revDir = _escapeDirection(reversed, revOwn);
    if (dir != null || revDir != null) {
      // Prefer the orientation whose head sits on the shallower (outer) end, so
      // finished arrows point toward the silhouette's rim - the classic
      // picture-maze flow - instead of stray heads aimed into the middle.
      if (dir != null && revDir == null) {
        _addPiece(pieces, seg, dir);
      } else if (revDir != null && dir == null) {
        _addPiece(pieces, reversed, revDir);
      } else if (_depthOf(seg.last) <= _depthOf(seg.first)) {
        _addPiece(pieces, seg, dir!);
      } else {
        _addPiece(pieces, reversed, revDir!);
      }
      return true;
    }

    for (var side = 0; side < 2; side++) {
      final path = List<GridCell>.of(side == 0 ? seg : reversed);
      var cur = path.last;
      for (var i = 0; i < 3; i++) {
        final next = _pickEscapeStep(cur, avoid);
        if (next == null) break;
        path.add(next);
        cur = next;
        final pOwn = path.toSet();
        final pDir = _escapeDirection(path, pOwn);
        if (pDir != null) {
          _addPiece(pieces, path, pDir);
          return true;
        }
        if (path.length >= config.maxCells) break;
      }
    }
    return false;
  }

  /// Next cell for an escape tail: the free in-mask neighbour closest to the
  /// silhouette edge (smallest depth), so the tail heads toward open air.
  GridCell? _pickEscapeStep(GridCell at, Set<GridCell> own) {
    GridCell? best;
    for (final d in ArrowDirection.values) {
      final n = GridCell(at.row + d.dy, at.col + d.dx);
      if (own.contains(n)) continue;
      if (!_isFree(n.row, n.col)) continue;
      if (best == null || _depthOf(n) < _depthOf(best)) best = n;
    }
    return best;
  }

  /// Unoccupied mask cells ordered deep-first.
  List<GridCell> _orderedUnoccupied() {
    final cells = _getUnoccupiedMaskCells();
    cells.sort((a, b) => _depthOf(b).compareTo(_depthOf(a)));
    return cells;
  }

  bool _isFree(int r, int c) {
    if (!_inBounds(r, c)) return false;
    if (r >= mask.length || c >= mask[r].length || !mask[r][c]) return false;
    return !_occupied[r][c];
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

  /// True when no cell of the board is covered by more than one arrow. The
  /// contour walker can revisit a cell in thin (1-cell wide) corridors, and
  /// such an attempt would double-cover the silhouette.
  bool _cellsUnique(List<ArrowPiece> arrows) {
    final seen = <int>{};
    for (final arrow in arrows) {
      for (final cell in arrow.cells) {
        if (!seen.add(cell.row * cols + cell.col)) return false;
      }
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

  /// Number of times the turn direction changes sign along [path]. Zero means
  /// the curve always turns the same way (a clean C-shaped arc); one means a
  /// single S; more means the path zig-zags, which reads as tangled on the
  /// board and animates badly when the arrow straightens and slides off.
  int _signFlips(List<GridCell> path) {
    var flips = 0;
    int? sense;
    for (var i = 2; i < path.length; i++) {
      final a = path[i - 2];
      final b = path[i - 1];
      final c = path[i];
      final d1 = (b.row - a.row, b.col - a.col);
      final d2 = (c.row - b.row, c.col - b.col);
      if (d1 == d2) continue;
      final cross = d1.$1 * d2.$2 - d1.$2 * d2.$1;
      final s = cross > 0 ? 1 : -1;
      if (sense == null) {
        sense = s;
      } else if (s != sense) {
        flips++;
        sense = s;
      }
    }
    return flips;
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

  /// Second pass: fill remaining holes with small arrows (3-8 cells), including
  /// short fillers. Short paths have short escape runs, so they succeed on
  /// awkward leftovers and make the silhouette denser.
  void _topUpLeftovers(List<ArrowPiece> pieces) {
    final leftover = _orderedUnoccupied();
    for (final start in leftover) {
      if (_occupied[start.row][start.col]) continue;
      if (pieces.length >= _maxPieces) break;
      var placed = false;
      for (var attempt = 0; attempt < 8 && !placed; attempt++) {
        final len = attempt == 0 ? 4 : _rng.nextInt(6) + 3;
        final bends = len <= 4
            ? (_rng.nextDouble() < 0.5 ? 1 : 0)
            : (_rng.nextDouble() < 0.45 ? 3 : 1);
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
  /// straight short arrow first, then small bent arrows (which sit snugly in
  /// corner/bend-shaped leftover spaces), until a full sweep places nothing.
  void _microFill(List<ArrowPiece> pieces) {
    const lens = [3, 4, 5, 6, 5, 6, 7, 8];
    const bends = [1, 1, 1, 2, 2, 2, 3, 3];
    for (var sweep = 0; sweep < 12; sweep++) {
      var progress = false;
      final empty = _orderedUnoccupied();
      for (final start in empty) {
        if (_occupied[start.row][start.col]) continue;
        if (pieces.length >= _maxPieces) break;
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

  /// Final density pass: squeezes the last few empty cells between strokes
  /// into tiny straight or L-shaped arrows so the silhouette fills almost
  /// completely. Each arrow still goes through the same solvability
  /// validation as every other arrow.
  void _pocketFill(List<ArrowPiece> pieces) {
    for (var sweep = 0; sweep < 12; sweep++) {
      var progress = false;
      final empty = _getUnoccupiedMaskCells();
      for (final start in empty) {
        if (_occupied[start.row][start.col]) continue;
        if (pieces.length >= _maxPieces) break;
        if (_tryStraightPocket(pieces, start)) {
          progress = true;
        } else if (_tryLPocket(pieces, start)) {
          progress = true;
        }
      }
      if (!progress) break;
    }
  }

  bool _tryStraightPocket(
      List<ArrowPiece> pieces, GridCell start) {
    for (final dir in ArrowDirection.values) {
      final v = GridCell(start.row + dir.dy, start.col + dir.dx);
      if (!_isFree(v.row, v.col)) continue;
      for (final len in [3, 2]) {
        final path = <GridCell>[];
        var cur = start;
        var ok = true;
        for (var i = 0; i < len; i++) {
          path.add(cur);
          final n = GridCell(cur.row + dir.dy, cur.col + dir.dx);
          if (!_isFree(n.row, n.col)) {
            ok = false;
            break;
          }
          cur = n;
        }
        if (!ok || path.length < len) continue;
        final own = path.toSet();
        final d = _escapeDirection(path, own);
        if (d != null) {
          _addPiece(pieces, path, d);
          return true;
        }
      }
    }
    return false;
  }

  bool _tryLPocket(List<ArrowPiece> pieces, GridCell start) {
    for (final dir in ArrowDirection.values) {
      final a = GridCell(start.row + dir.dy, start.col + dir.dx);
      if (!_isFree(a.row, a.col)) continue;
      for (final turn in ArrowDirection.values) {
        if (turn == dir || turn == dir.opposite) continue;
        final b = GridCell(a.row + turn.dy, a.col + turn.dx);
        if (!_isFree(b.row, b.col)) continue;
        final path = <GridCell>[start, a, b];
        final own = path.toSet();
        final d = _escapeDirection(path, own);
        if (d != null) {
          _addPiece(pieces, path, d);
          return true;
        }
      }
    }
    return false;
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
    final idealPieces = max(1, (totalCells / 7).ceil());
    for (var attempt = 0; attempt < config.maxAttempts; attempt++) {
      final arrows = _generateSolvableBoard();
      if (arrows.isEmpty) continue;
      // Belt and braces: the construction guarantees solvability, but a quick
      // greedy check lets us discard anything that slipped through.
      if (!arrowsAreSolvable(arrows, rows, cols)) continue;
      // Thin corridors can make a contour walk revisit a cell, which would
      // double-cover part of the silhouette; skip such attempts entirely.
      if (!_cellsUnique(arrows)) continue;

      var filled = 0;
      var curved = 0;
      for (final arrow in arrows) {
        filled += arrow.cells.length;
        if (_countBends(arrow.cells) >= 2) curved++;
      }

      final fillPct = filled * 1000 ~/ totalCells;
      // Reward fill and curved arrows, but penalize fragmentation (too many
      // tiny fillers) so the best-looking board wins.
      final overage = max(0, arrows.length - idealPieces);
      final score = fillPct + min(curved, 6) * 5 - overage;
      if (score > bestScore) {
        bestScore = score;
        best = arrows;
      }
      if (fillPct >= 940 && curved >= 2 && arrows.length <= idealPieces + 6) {
        break;
      }
    }

    return PuzzleResult(
      arrows: best ?? const [],
      solvable: true,
      totalCells: totalCells,
    );
  }
}