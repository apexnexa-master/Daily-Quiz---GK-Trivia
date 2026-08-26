import 'dart:math';

// ── Directions ───────────────────────────────────────────────────────────────

enum Dir { north, east, south, west }

extension DirX on Dir {
  int get dr {
    switch (this) {
      case Dir.north:
        return -1;
      case Dir.south:
        return 1;
      default:
        return 0;
    }
  }

  int get dc {
    switch (this) {
      case Dir.east:
        return 1;
      case Dir.west:
        return -1;
      default:
        return 0;
    }
  }

  Dir get opposite {
    switch (this) {
      case Dir.north:
        return Dir.south;
      case Dir.south:
        return Dir.north;
      case Dir.east:
        return Dir.west;
      case Dir.west:
        return Dir.east;
    }
  }

  bool get isHorizontal => this == Dir.east || this == Dir.west;
}

Dir _dirFromDelta(int dr, int dc) {
  if (dr < 0) return Dir.north;
  if (dr > 0) return Dir.south;
  if (dc > 0) return Dir.east;
  return Dir.west;
}

// ── Arrow (polyline) ────────────────────────────────────────────────────────

class MazeArrow {
  final int id;
  final List<(int, int)> path; // index 0 = head, last = tail
  final Dir fireDir;

  const MazeArrow({
    required this.id,
    required this.path,
    required this.fireDir,
  });

  (int, int) get head => path.first;
  int get length => path.length;

  Set<(int, int)> get occupiedCells => path.toSet();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MazeArrow && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Level ────────────────────────────────────────────────────────────────────

class MazeLevel {
  final int levelId;
  final int rows;
  final int cols;
  final List<bool> mask;
  final String shapeName;
  final List<MazeArrow> arrows;

  const MazeLevel({
    required this.levelId,
    required this.rows,
    required this.cols,
    required this.mask,
    required this.shapeName,
    required this.arrows,
  });

  bool isMasked(int row, int col) =>
      row >= 0 &&
      col >= 0 &&
      row < rows &&
      col < cols &&
      mask[row * cols + col];
}

// ── Mutable runtime board ────────────────────────────────────────────────────

class ArrowMazeBoard {
  final MazeLevel level;
  final Map<int, MazeArrow> _remaining = {};
  final Map<int, int> _owner = {}; // cellKey -> arrow id
  final Set<int> _removedCells = {};
  int _moveCount = 0;

  ArrowMazeBoard(this.level) {
    var id = 0;
    for (final a in level.arrows) {
      final arrow = MazeArrow(id: id, path: a.path, fireDir: a.fireDir);
      _remaining[id] = arrow;
      for (final cell in arrow.occupiedCells) {
        _owner[cell.$1 * level.cols + cell.$2] = id;
      }
      id++;
    }
  }

  int get cols => level.cols;
  int get pieceCount => _remaining.length;
  int get moveCount => _moveCount;
  bool get solved => _remaining.isEmpty;
  List<MazeArrow> get pieces =>
      _remaining.values.toList(growable: false);

  Set<int> get removedCells => _removedCells;

  bool _inBounds(int r, int c) =>
      r >= 0 && c >= 0 && r < level.rows && c < level.cols;

  /// Walk the firing ray from [arrow]'s head. Returns the first other arrow
  /// encountered, or null if the path is clear to the edge.
  MazeArrow? firstBlocker(MazeArrow arrow) {
    final (hr, hc) = arrow.head;
    final d = arrow.fireDir;
    var r = hr + d.dr;
    var c = hc + d.dc;
    while (_inBounds(r, c)) {
      final key = r * level.cols + c;
      final ownerId = _owner[key];
      if (ownerId != null && ownerId != arrow.id) {
        return _remaining[ownerId];
      }
      r += d.dr;
      c += d.dc;
    }
    return null;
  }

  bool isFree(MazeArrow arrow) => firstBlocker(arrow) == null;

  List<MazeArrow> freePieces() {
    final free =
        _remaining.values.where((a) => firstBlocker(a) == null).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return free;
  }

  /// Try to fire [arrow] off the board. Returns false if blocked.
  bool escape(MazeArrow arrow) {
    if (_remaining[arrow.id] == null) return false;
    if (!isFree(arrow)) return false;
    for (final cell in arrow.occupiedCells) {
      final key = cell.$1 * level.cols + cell.$2;
      _owner.remove(key);
      _removedCells.add(key);
    }
    _remaining.remove(arrow.id);
    _moveCount++;
    return true;
  }

  /// Put back a previously escaped arrow (undo).
  void restore(MazeArrow arrow) {
    if (_remaining.containsKey(arrow.id)) return;
    _remaining[arrow.id] = arrow;
    for (final cell in arrow.occupiedCells) {
      final key = cell.$1 * level.cols + cell.$2;
      _owner[key] = arrow.id;
      _removedCells.remove(key);
    }
    if (_moveCount > 0) _moveCount--;
  }
}

// ── Level generator (grow algorithm) ─────────────────────────────────────────

class ArrowMazeGenerator {
  static const int totalLevels = 100;

  static MazeLevel generate(int levelId, {int? seed}) {
    final id = levelId.clamp(1, totalLevels);
    final rng = Random(seed ?? (id * 7919 + 104729));
    final spec = _difficultySpec(id);
    final maskInfo = _buildMask(spec.shape, spec.rows, spec.cols);

    final nArrows = _targetArrowCount(
      spec.rows,
      spec.cols,
      maskInfo.mask,
    );

    for (var attempt = 0; attempt < 15000; attempt++) {
      final r = Random(rng.nextInt(1 << 30));
      final board = _tryGrow(
        spec.rows,
        spec.cols,
        nArrows,
        maskInfo.mask,
        r,
      );
      if (board != null) {
        return MazeLevel(
          levelId: id,
          rows: spec.rows,
          cols: spec.cols,
          mask: maskInfo.mask,
          shapeName: maskInfo.name,
          arrows: board,
        );
      }
    }
    return _fallbackRect(id, spec.rows, spec.cols, maskInfo);
  }

  // ── Difficulty ──────────────────────────────────────────────────────────

  static ({int rows, int cols, String shape}) _difficultySpec(int levelId) {
    int rows, cols;
    if (levelId <= 5) {
      rows = 4;
      cols = 4;
    } else if (levelId <= 15) {
      rows = 5;
      cols = 5;
    } else if (levelId <= 30) {
      rows = 6;
      cols = 6;
    } else if (levelId <= 50) {
      rows = 7;
      cols = 7;
    } else if (levelId <= 75) {
      rows = 8;
      cols = 8;
    } else {
      rows = 9;
      cols = 9;
    }

    final rng = Random(levelId * 31);
    String shape;
    if (levelId <= 8) {
      shape = 'rect';
    } else if (levelId <= 20) {
      shape = ['rect', 'rect', 'circle'][rng.nextInt(3)];
    } else if (levelId <= 40) {
      shape = ['rect', 'circle', 'diamond'][rng.nextInt(3)];
    } else {
      shape = ['rect', 'circle', 'diamond', 'cross'][rng.nextInt(4)];
    }
    return (rows: rows, cols: cols, shape: shape);
  }

  static int _targetArrowCount(int rows, int cols, List<bool> mask) {
    final maskCells = mask.where((m) => m).length;
    final n = min(rows, cols);
    final target = n <= 4 ? 4 : n <= 6 ? n : n + 1;
    final maxA = maskCells ~/ 2;
    return target.clamp(1, maxA);
  }

  // ── Mask shapes ─────────────────────────────────────────────────────────

  static ({List<bool> mask, String name}) _buildMask(
    String shape,
    int rows,
    int cols,
  ) {
    switch (shape) {
      case 'circle':
        return (mask: _circleMask(rows, cols), name: 'Circle');
      case 'diamond':
        return (mask: _diamondMask(rows, cols), name: 'Diamond');
      case 'cross':
        return (mask: _crossMask(rows, cols), name: 'Cross');
      default:
        return (
          mask: List<bool>.filled(rows * cols, true),
          name: 'Grid',
        );
    }
  }

  static List<bool> _circleMask(int rows, int cols) {
    final cx = (cols - 1) / 2;
    final cy = (rows - 1) / 2;
    final rx = cols / 2 + 0.4;
    final ry = rows / 2 + 0.4;
    final m = List<bool>.filled(rows * cols, false);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = (c - cx) / rx;
        final dy = (r - cy) / ry;
        m[r * cols + c] = dx * dx + dy * dy <= 1;
      }
    }
    return m;
  }

  static List<bool> _diamondMask(int rows, int cols) {
    final cx = (cols - 1) / 2;
    final cy = (rows - 1) / 2;
    final radius = min(rows, cols) / 2 + 0.35;
    final m = List<bool>.filled(rows * cols, false);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m[r * cols + c] = (r - cy).abs() + (c - cx).abs() <= radius;
      }
    }
    return m;
  }

  static List<bool> _crossMask(int rows, int cols) {
    final loR = rows ~/ 3;
    final hiR = rows - 1 - loR;
    final loC = cols ~/ 3;
    final hiC = cols - 1 - loC;
    final m = List<bool>.filled(rows * cols, false);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m[r * cols + c] = (r >= loR && r <= hiR) || (c >= loC && c <= hiC);
      }
    }
    return m;
  }

  // ── Grow algorithm ──────────────────────────────────────────────────────

  static List<MazeArrow>? _tryGrow(
    int rows,
    int cols,
    int nArrows,
    List<bool> mask,
    Random rng,
  ) {
    final occupied = <int>{};
    final headSet = <int>{};
    final paths = <List<(int, int)>>[];
    final fireDirs = <Dir>[];

    // Seed: place nArrows 2-cell arrows
    for (var k = 0; k < nArrows; k++) {
      var placed = false;
      for (var attempt = 0; attempt < 800; attempt++) {
        final hr = rng.nextInt(rows);
        final hc = rng.nextInt(cols);
        final hKey = hr * cols + hc;
        if (!mask[hKey] || occupied.contains(hKey)) continue;

        final dirs = Dir.values.toList()..shuffle(rng);
        var dirOk = false;
        for (final d in dirs) {
          final br = hr + d.dr;
          final bc = hc + d.dc;
          if (!_inBounds(br, bc, rows, cols)) continue;
          final bKey = br * cols + bc;
          if (!mask[bKey] || occupied.contains(bKey)) continue;

          // Check firing ray doesn't hit existing heads
          var rayClear = true;
          var rr = hr + d.dr;
          var cc = hc + d.dc;
          while (_inBounds(rr, cc, rows, cols)) {
            if (headSet.contains(rr * cols + cc)) {
              rayClear = false;
              break;
            }
            rr += d.dr;
            cc += d.dc;
          }
          if (!rayClear) continue;

          final path = [(hr, hc), (br, bc)];
          paths.add(path);
          fireDirs.add(d.opposite);
          occupied.add(hKey);
          occupied.add(bKey);
          headSet.add(hKey);
          dirOk = true;
          placed = true;
          break;
        }
        if (dirOk) break;
      }
      if (!placed) return null;
    }

    // Extend tails
    const straightBias = 9;
    var extended = true;
    while (extended) {
      extended = false;
      final order = List<int>.generate(paths.length, (i) => i)..shuffle(rng);
      for (final pi in order) {
        final path = paths[pi];
        if (path.length < 2) return null;
        final tail = path.last;
        final prev = path[path.length - 2];

        final cands = _neighborCandidates(
          tail,
          prev,
          rows,
          cols,
          occupied,
          mask,
        );
        // Remove cells on the firing ray of this arrow
        final (hr, hc) = path.first;
        final d = fireDirs[pi].opposite;
        final filtered = cands.where((c) {
          var r = hr + d.dr;
          var c2 = hc + d.dc;
          while (_inBounds(r, c2, rows, cols)) {
            if (r == c.$1 && c2 == c.$2) return false;
            r += d.dr;
            c2 += d.dc;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) continue;

        // Prefer straight continuation
        final incoming = _dirFromDelta(
          tail.$1 - prev.$1,
          tail.$2 - prev.$2,
        );
        final straight =
            filtered.where((c) => _dirFromDelta(c.$1 - tail.$1, c.$2 - tail.$2) == incoming).toList();
        final turn =
            filtered.where((c) => _dirFromDelta(c.$1 - tail.$1, c.$2 - tail.$2) != incoming).toList();

        (int, int) next;
        if (straight.isNotEmpty && turn.isNotEmpty) {
          next = rng.nextInt(10) < straightBias
              ? straight[rng.nextInt(straight.length)]
              : turn[rng.nextInt(turn.length)];
        } else if (straight.isNotEmpty) {
          next = straight[rng.nextInt(straight.length)];
        } else {
          next = filtered[rng.nextInt(filtered.length)];
        }

        path.add(next);
        occupied.add(next.$1 * cols + next.$2);
        extended = true;
      }
    }

    // Validate
    if (paths.length < 2) return null;

    var filledCount = 0;
    for (final p in paths) {
      filledCount += p.length;
    }
    if (filledCount > rows * cols * 0.85) return null;

    // Check heads not on each other's rays
    for (var i = 0; i < paths.length; i++) {
      final (hr, hc) = paths[i].first;
      final d = fireDirs[i].opposite;
      var r = hr + d.dr;
      var c = hc + d.dc;
      while (_inBounds(r, c, rows, cols)) {
        if (headSet.contains(r * cols + c)) return null;
        r += d.dr;
        c += d.dc;
      }
    }

    // At most half fireable
    var fireable = 0;
    for (var i = 0; i < paths.length; i++) {
      if (_canFire(paths[i].first, fireDirs[i].opposite, rows, cols, paths, i)) {
        fireable++;
      }
    }
    if (paths.length > 1 && fireable * 2 > paths.length) return null;

    // Greedy solvable
    if (!_greedySolvable(rows, cols, paths, fireDirs)) return null;

    return List.generate(paths.length, (i) {
      return MazeArrow(id: i, path: paths[i], fireDir: fireDirs[i]);
    });
  }

  static bool _greedySolvable(
    int rows,
    int cols,
    List<List<(int, int)>> paths,
    List<Dir> fireDirs,
  ) {
    final alive = List<bool>.filled(paths.length, true);
    final cellOwner = List<int?>.filled(rows * cols, null);
    for (var i = 0; i < paths.length; i++) {
      for (final (r, c) in paths[i]) {
        cellOwner[r * cols + c] = i;
      }
    }

    var remaining = paths.length;
    var found = true;
    while (found && remaining > 0) {
      found = false;
      for (var i = 0; i < paths.length; i++) {
        if (!alive[i]) continue;
        if (_canFireOnCellOwner(
          paths[i].first,
          fireDirs[i].opposite,
          rows,
          cols,
          cellOwner,
          i,
        )) {
          for (final (r, c) in paths[i]) {
            cellOwner[r * cols + c] = null;
          }
          alive[i] = false;
          remaining--;
          found = true;
          break;
        }
      }
    }
    return remaining == 0;
  }

  static bool _canFire(
    (int, int) head,
    Dir fireDir,
    int rows,
    int cols,
    List<List<(int, int)>> allPaths,
    int skipIndex,
  ) {
    var r = head.$1 + fireDir.dr;
    var c = head.$2 + fireDir.dc;
    while (_inBounds(r, c, rows, cols)) {
      for (var i = 0; i < allPaths.length; i++) {
        if (i == skipIndex) continue;
        for (final (pr, pc) in allPaths[i]) {
          if (pr == r && pc == c) return false;
        }
      }
      r += fireDir.dr;
      c += fireDir.dc;
    }
    return true;
  }

  static bool _canFireOnCellOwner(
    (int, int) head,
    Dir fireDir,
    int rows,
    int cols,
    List<int?> cellOwner,
    int skipIndex,
  ) {
    var r = head.$1 + fireDir.dr;
    var c = head.$2 + fireDir.dc;
    while (_inBounds(r, c, rows, cols)) {
      final owner = cellOwner[r * cols + c];
      if (owner != null && owner != skipIndex) return false;
      r += fireDir.dr;
      c += fireDir.dc;
    }
    return true;
  }

  static List<(int, int)> _neighborCandidates(
    (int, int) tail,
    (int, int) prev,
    int rows,
    int cols,
    Set<int> occupied,
    List<bool> mask,
  ) {
    final out = <(int, int)>[];
    for (final d in Dir.values) {
      final nr = tail.$1 + d.dr;
      final nc = tail.$2 + d.dc;
      if (!_inBounds(nr, nc, rows, cols)) continue;
      if (nr == prev.$1 && nc == prev.$2) continue;
      final key = nr * cols + nc;
      if (!mask[key] || occupied.contains(key)) continue;
      out.add((nr, nc));
    }
    return out;
  }

  static bool _inBounds(int r, int c, int rows, int cols) =>
      r >= 0 && c >= 0 && r < rows && c < cols;

  // ── Fallback ────────────────────────────────────────────────────────────

  static MazeLevel _fallbackRect(
    int id,
    int rows,
    int cols,
    ({List<bool> mask, String name}) maskInfo,
  ) {
    final rng = Random(id * 3571);
    final arrows = <MazeArrow>[];
    final occupied = <int>{};
    var idCounter = 0;

    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (maskInfo.mask[r * cols + c]) cells.add((r, c));
      }
    }
    cells.shuffle(rng);

    final n = _targetArrowCount(rows, cols, maskInfo.mask);
    for (final (r, c) in cells) {
      if (arrows.length >= n) break;
      final hKey = r * cols + c;
      if (occupied.contains(hKey)) continue;

      final dirs = Dir.values.toList()..shuffle(rng);
      for (final d in dirs) {
        final br = r + d.dr;
        final bc = c + d.dc;
        if (!_inBounds(br, bc, rows, cols)) continue;
        final bKey = br * cols + bc;
        if (occupied.contains(bKey)) continue;
        if (!maskInfo.mask[bKey]) continue;

        arrows.add(MazeArrow(
          id: idCounter++,
          path: [(r, c), (br, bc)],
          fireDir: d.opposite,
        ));
        occupied.add(hKey);
        occupied.add(bKey);
        break;
      }
    }

    return MazeLevel(
      levelId: id,
      rows: rows,
      cols: cols,
      mask: maskInfo.mask,
      shapeName: maskInfo.name,
      arrows: arrows,
    );
  }
}
