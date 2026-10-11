import 'dart:collection';
import 'dart:math' as math;

import 'silhouette_models.dart';
import 'puzzle_generator.dart';

class SilhouetteLevel {
  final int id;
  final String name;
  final String themeEmoji;
  final String description;
  final int gridCols;
  final int gridRows;
  final List<List<bool>> mask;
  final List<ArrowPiece> Function() arrowFactory;
  final LevelConfig config;

  const SilhouetteLevel({
    required this.id,
    required this.name,
    required this.themeEmoji,
    required this.description,
    required this.gridCols,
    required this.gridRows,
    required this.mask,
    required this.arrowFactory,
    required this.config,
  });

  List<ArrowPiece> generateArrows() => arrowFactory();
}

List<ArrowPiece> _generateLevelArrows(SilhouetteLevel level) {
  final generator = PuzzleGenerator(
    rows: level.gridRows,
    cols: level.gridCols,
    mask: level.mask,
    config: level.config,
    seed: level.id,
  );
  return generator.generate().arrows;
}

/// Cache of generated boards, filled in strict level order so each level can
/// require at least as many arrows as the one before it. Generation is
/// deterministic and prefix-ordered, so the result is stable no matter which
/// level is opened first; once a level is generated its arrows are reused.
final List<int> _progressiveCounts = <int>[];
final Map<int, List<ArrowPiece>> _progressiveArrowCache =
    <int, List<ArrowPiece>>{};

/// Deterministic per-level arrow counts for the whole campaign (in level order).
/// Each level was generated with the previous level's count as its monotonic
/// floor, so these numbers are reproducible from the fixed per-level seeds and
/// let any level be generated in isolation. Regenerate them if the generator
/// ever changes (`test/silhouette_generator_test.dart` prints the live values).
const List<int> _kBakedCounts = <int>[
  18, 19, 24, 25, 26, 26, 26, 26, 28, 28, // Heart..Butterfly
  35, 35, 33, 33, 26, 34, 34, 37, 31, 36, // Sun..Key
  43, 37, 41, 44, 45, 46, 46, 49, 52, 53, // Cat..Lion
  49, 45, 57, 57, 49, 51, 69, 55, 60, 60, // Trishul..Umbrella
  63, 68, 69, 70, 70, 72, 66, 52, 61, 68, // Ice Cream..Cherry
  80, 78, 77, 78, // Pizza, Trophy, Pear, Whale
];

/// The arrow count of level [index] if it has already been generated.
int? cachedArrowCount(int index) =>
    index >= 0 && index < _progressiveCounts.length
        ? _progressiveCounts[index]
        : null;

/// The generated arrows of level [index] if available. The returned list is
/// the cache's own list, so callers that will mutate arrow state (the game
/// engine) must work on a clone via [cloneArrows].
List<ArrowPiece>? cachedArrows(int index) => _progressiveArrowCache[index];

void storeProgressionCounts(List<int> counts) {
  _progressiveCounts
    ..clear()
    ..addAll(counts);
}

void storeProgressionArrows(int index, List<ArrowPiece> arrows) {
  _progressiveArrowCache[index] = arrows;
}

/// Deep-enough copy of [src] for a fresh play-through: new [ArrowPiece]
/// instances (fresh mutable status/highlight/hint) sharing the immutable
/// [GridCell]s. Used so replaying a level never inherits escaped arrows from a
/// previous run.
List<ArrowPiece> cloneArrows(List<ArrowPiece> src) {
  return <ArrowPiece>[
    for (final a in src)
      ArrowPiece(
        id: a.id,
        cells: List<GridCell>.of(a.cells),
        direction: a.direction,
        colorIndex: a.colorIndex,
      ),
  ];
}

/// A [SilhouetteLevel] identical to [base] but whose arrows are served from
/// [arrows] (cloned per call) instead of being regenerated. The game screen
/// uses this to play a board that was generated ahead of time on a background
/// isolate.
SilhouetteLevel runtimeLevelWithArrows(
  SilhouetteLevel base,
  List<ArrowPiece> arrows,
) {
  return SilhouetteLevel(
    id: base.id,
    name: base.name,
    themeEmoji: base.themeEmoji,
    description: base.description,
    gridCols: base.gridCols,
    gridRows: base.gridRows,
    mask: base.mask,
    arrowFactory: () => cloneArrows(arrows),
    config: base.config,
  );
}

List<ArrowPiece> _generateProgressiveArrows(int index) {
  final existing = _progressiveArrowCache[index];
  if (existing != null) return existing;

  // The arrow counts are fully deterministic (fixed per-level seeds), so the
  // campaign's counts are baked in. That lets us generate only the requested
  // level with the correct monotonic floor instead of regenerating every
  // earlier level first (which would take many seconds when a high level is
  // opened directly). Falls back to the previous count when out of range.
  while (_progressiveCounts.length <= index) {
    _progressiveCounts.add(
      _progressiveCounts.length < _kBakedCounts.length
          ? _kBakedCounts[_progressiveCounts.length]
          : 0,
    );
  }
  final level = silhouetteLevels[index];
  final floor = index == 0 ? 0 : _progressiveCounts[index - 1];
  final generator = PuzzleGenerator(
    rows: level.gridRows,
    cols: level.gridCols,
    mask: level.mask,
    config: level.config,
    seed: level.id,
  );
  final result = generator.generate(floorArrows: floor);
  _progressiveCounts[index] = result.arrows.length;
  _progressiveArrowCache[index] = result.arrows;
  return result.arrows;
}

// ---------------------------------------------------------------------------
// Background generation. Building a large board can take a noticeable fraction
// of a second; on a full campaign the prefix up to a high level can take many
// seconds. Running it on a separate isolate keeps the UI (and its loading
// spinner) perfectly smooth instead of freezing the frame.
// ---------------------------------------------------------------------------

/// Plain, sendable description of a single level's generation inputs.
class LevelGenSpec {
  final int rows;
  final int cols;
  final int seed;
  final List<List<bool>> mask;
  final LevelConfig config;

  LevelGenSpec({
    required this.rows,
    required this.cols,
    required this.seed,
    required this.mask,
    required this.config,
  });
}

/// Work request for [generateProgressionTask]: every spec from level 0 up to
/// [targetIndex], plus the arrow counts already known (so the isolate can skip
/// regenerating levels whose count is not needed).
class ProgressionTask {
  final List<LevelGenSpec> specs;
  final List<int> knownCounts;
  final int targetIndex;

  ProgressionTask({
    required this.specs,
    required this.knownCounts,
    required this.targetIndex,
  });
}

class ProgressionOutput {
  final List<int> counts;

  /// Arrows of the requested (target) level. Empty on failure.
  final List<ArrowPiece> targetArrows;

  ProgressionOutput({required this.counts, required this.targetArrows});
}

ProgressionTask buildProgressionTask(int targetIndex) {
  final specs = <LevelGenSpec>[];
  final known = <int>[];
  for (var i = 0; i <= targetIndex; i++) {
    final level = silhouetteLevels[i];
    specs.add(LevelGenSpec(
      rows: level.gridRows,
      cols: level.gridCols,
      seed: level.id,
      mask: level.mask,
      config: level.config,
    ));
    known.add(
      i < targetIndex && i < _kBakedCounts.length ? _kBakedCounts[i] : -1,
    );
  }
  return ProgressionTask(
    specs: specs,
    knownCounts: known,
    targetIndex: targetIndex,
  );
}

/// Runs on a background isolate (via `compute`). Fills the arrow-count prefix
/// in order so each level keeps the monotonic floor, and returns the arrows of
/// the requested level. Levels whose count is already known are skipped.
ProgressionOutput generateProgressionTask(ProgressionTask task) {
  final counts = List<int>.of(task.knownCounts);
  List<ArrowPiece> target = const <ArrowPiece>[];
  for (var i = 0; i <= task.targetIndex; i++) {
    if (i < task.targetIndex && counts[i] >= 0) continue;
    final spec = task.specs[i];
    final floor = i == 0 ? 0 : counts[i - 1];
    final generator = PuzzleGenerator(
      rows: spec.rows,
      cols: spec.cols,
      mask: spec.mask,
      config: spec.config,
      seed: spec.seed,
    );
    final result = generator.generate(floorArrows: floor);
    counts[i] = result.arrows.length;
    if (i == task.targetIndex) target = result.arrows;
  }
  return ProgressionOutput(counts: counts, targetArrows: target);
}

/// Tiny drawing language for building tall, detailed silhouettes with lots of
/// interior features. Every level below is drawn as a big picture that fills
/// most of a portrait board (24+ rows) so the arrows read clearly and the
/// board uses the whole screen instead of floating as a small island.
class _MaskBuilder {
  final int rows;
  final int cols;
  final List<List<bool>> g;

  _MaskBuilder(this.rows, this.cols)
      : g = List.generate(rows, (_) => List.filled(cols, false));

  bool _inside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  _MaskBuilder set_(int r, int c) {
    if (_inside(r, c)) g[r][c] = true;
    return this;
  }

  _MaskBuilder clear(int r, int c) {
    if (_inside(r, c)) g[r][c] = false;
    return this;
  }

  _MaskBuilder rect(int r0, int c0, int r1, int c1) {
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        set_(r, c);
      }
    }
    return this;
  }

  _MaskBuilder clearRect(int r0, int c0, int r1, int c1) {
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        clear(r, c);
      }
    }
    return this;
  }

  _MaskBuilder line(int r0, int c0, int r1, int c1) {
    var x = c0;
    var y = r0;
    final dx = (c1 - c0).abs();
    final sx = c0 < c1 ? 1 : -1;
    final dy = -(r1 - r0).abs();
    final sy = r0 < r1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      set_(y, x);
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
    return this;
  }

  _MaskBuilder clearLine(int r0, int c0, int r1, int c1) {
    var x = c0;
    var y = r0;
    final dx = (c1 - c0).abs();
    final sx = c0 < c1 ? 1 : -1;
    final dy = -(r1 - r0).abs();
    final sy = r0 < r1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      clear(y, x);
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
    return this;
  }

  /// A bent stroke of [width] parallel tracks; used for thick arms, trunks,
  /// handles and tails.
  _MaskBuilder stroke(int r0, int c0, int r1, int c1, {int width = 2}) {
    final pdx = c1 - c0;
    final pdy = r1 - r0;
    final len = math.sqrt(pdx * pdx + pdy * pdy);
    var nx = 0.0;
    var ny = 0.0;
    if (len > 0) {
      nx = pdx / len;
      ny = pdy / len;
    }
    for (var k = 0; k < width; k++) {
      final off = k - (width - 1) / 2;
      _lineI((r0 + ny * off).round(), (c0 + nx * off).round(),
          (r1 + ny * off).round(), (c1 + nx * off).round());
    }
    return this;
  }

  void _lineI(int r0, int c0, int r1, int c1) => line(r0, c0, r1, c1);

  _MaskBuilder ellipse(double cr, double cc, double rx, double ry) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = (c - cc) / rx;
        final dy = (r - cr) / ry;
        if (dx * dx + dy * dy <= 1.0) set_(r, c);
      }
    }
    return this;
  }

  _MaskBuilder carveEllipse(double cr, double cc, double rx, double ry) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = (c - cc) / rx;
        final dy = (r - cr) / ry;
        if (dx * dx + dy * dy <= 1.0) clear(r, c);
      }
    }
    return this;
  }

  _MaskBuilder disc(double cr, double cc, double radius) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final d = math.sqrt((c - cc) * (c - cc) + (r - cr) * (r - cr));
        if (d <= radius) set_(r, c);
      }
    }
    return this;
  }

  _MaskBuilder carve(double cr, double cc, double radius) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final d = math.sqrt((c - cc) * (c - cc) + (r - cr) * (r - cr));
        if (d <= radius) clear(r, c);
      }
    }
    return this;
  }

  _MaskBuilder circleRing(double cr, double cc, double radius,
      {double thickness = 1.6}) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final d = math.sqrt((c - cc) * (c - cc) + (r - cr) * (r - cr));
        if ((d - radius).abs() <= thickness) set_(r, c);
      }
    }
    return this;
  }

  /// 5-point star; [innerFactor] sets notch depth, [ringMin] carves the hub.
  _MaskBuilder star(double cr, double cc, double outer,
      {double innerFactor = 0.48, double? ringMin}) {
    final inner = outer * innerFactor;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = c - cc;
        final dy = r - cr;
        final d = math.sqrt(dx * dx + dy * dy);
        final a = math.atan2(dy, dx);
        final sa = _starRadius(a, outer, inner);
        if (d <= sa && (ringMin == null || d >= sa * ringMin)) set_(r, c);
      }
    }
    return this;
  }

  static double _starRadius(double a, double outer, double inner) {
    const T = 2 * math.pi / 5;
    final x = a % T;
    final core = math.cos(2 * math.pi * x / T);
    return (outer + inner) / 2 + (outer - inner) / 2 * core;
  }

  /// Diamond (rotated square) via the L1 "taxicab" norm.
  _MaskBuilder diamond(double cr, double cc, double radius,
      {double? ringMin}) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final d = (r - cr).abs() + (c - cc).abs();
        if (d <= radius && (ringMin == null || d >= radius * ringMin)) {
          set_(r, c);
        }
      }
    }
    return this;
  }

  /// Isoceles triangle. [rt] is the top (apex) row, [ct] the apex column;
  /// [rb] the bottom row and [halfW] the half-width of the base at [rb].
  _MaskBuilder triangle(int rt, double ct, int rb, double halfW) {
    for (var r = rt; r <= rb; r++) {
      final t = rb == rt ? 0.0 : (r - rt) / (rb - rt);
      final hw = halfW * (1 - t) + 0.4;
      for (var c = (ct - hw).ceil(); c <= (ct + hw).floor(); c++) {
        set_(r, c);
      }
    }
    return this;
  }

  /// Evenly spaced spokes radiating from a hub, from radius [r0] to [r1].
  _MaskBuilder rays(double cr, double cc, double r0, double r1, int count,
      {int width = 2}) {
    for (var k = 0; k < count; k++) {
      final a = k * 2 * math.pi / count;
      final s = math.sin(a);
      final c = math.cos(a);
      stroke(
        (cr + r0 * s).round(),
        (cc + r0 * c).round(),
        (cr + r1 * s).round(),
        (cc + r1 * c).round(),
        width: width,
      );
    }
    return this;
  }

  /// A ring of petal discs at radius [r] around a hub (flowers, suns, mandalas).
  _MaskBuilder petalRing(double cr, double cc, double r, double pr, int count) {
    for (var k = 0; k < count; k++) {
      final a = k * 2 * math.pi / count;
      disc(cr + r * math.sin(a), cc + r * math.cos(a), pr);
    }
    return this;
  }

  List<List<bool>> build() {
    weldMask(g);
    return g;
  }
}

/// Welds every separated island in [grid] back onto the main body along the
/// shortest possible bridge of empty cells, so a silhouette always reads as one
/// connected object. Decorative carve/clear operations (facet lines, ray gaps,
/// wing separations) frequently cut a shape into pieces; this undoes that.
/// [grid] is mutated in place.
void weldMask(List<List<bool>> grid) {
  final rows = grid.length;
  if (rows == 0) return;
  var cols = 0;
  for (final row in grid) {
    if (row.length > cols) cols = row.length;
  }
  if (cols == 0) return;

  bool inside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;
  bool filled(int r, int c) => inside(r, c) && c < grid[r].length && grid[r][c];
  int key(int r, int c) => r * cols + c;

  List<List<int>> components() {
    final label = List.generate(rows, (_) => List.filled(cols, -1));
    final comps = <List<int>>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!filled(r, c) || label[r][c] != -1) continue;
        final id = comps.length;
        final cells = <int>[];
        final q = Queue<int>()..add(key(r, c));
        label[r][c] = id;
        while (q.isNotEmpty) {
          final k = q.removeFirst();
          cells.add(k);
          final cr = k ~/ cols;
          final cc = k % cols;
          for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nr = cr + d.$1;
            final nc = cc + d.$2;
            if (!filled(nr, nc) || label[nr][nc] != -1) continue;
            label[nr][nc] = id;
            q.add(key(nr, nc));
          }
        }
        comps.add(cells);
      }
    }
    return comps;
  }

  void bridge(Set<int> main, Set<int> target) {
    final size = rows * cols;
    final dist = List<int>.filled(size, 1 << 30);
    final prev = List<int>.filled(size, -1);
    final deque = Queue<int>();
    for (final k in main) {
      dist[k] = 0;
      deque.addFirst(k);
    }
    var found = -1;
    while (deque.isNotEmpty) {
      final k = deque.removeFirst();
      if (target.contains(k)) {
        found = k;
        break;
      }
      final cr = k ~/ cols;
      final cc = k % cols;
      for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nr = cr + d.$1;
        final nc = cc + d.$2;
        if (!inside(nr, nc)) continue;
        final nk = key(nr, nc);
        final w = filled(nr, nc) ? 0 : 1; // filling an empty cell costs one
        final nd = dist[k] + w;
        if (nd < dist[nk]) {
          dist[nk] = nd;
          prev[nk] = k;
          if (w == 0) {
            deque.addFirst(nk);
          } else {
            deque.addLast(nk);
          }
        }
      }
    }
    if (found < 0) return;
    var cur = found;
    while (cur != -1) {
      final r = cur ~/ cols;
      final c = cur % cols;
      grid[r][c] = true;
      cur = prev[cur];
    }
  }

  for (var guard = 0; guard < rows * cols; guard++) {
    final comps = components();
    if (comps.length <= 1) return;
    comps.sort((a, b) => b.length.compareTo(a.length));
    bridge(comps.first.toSet(), comps[1].toSet());
  }
}

/// Fills one-cell-wide interior gaps/channels (a gutter that is only a single
/// cell wide, with solid cells on both sides). Silhouettes are meant to read as
/// solid pictures, and thin channels are also the cells the generator finds
/// hardest to cover, so closing them raises fill and legibility together.
void closeMask(List<List<bool>> grid) {
  final rows = grid.length;
  if (rows == 0) return;
  var cols = 0;
  for (final row in grid) {
    if (row.length > cols) cols = row.length;
  }
  if (cols == 0) return;
  bool filled(int r, int c) =>
      r >= 0 && r < rows && c >= 0 && c < cols && grid[r][c];

  for (var guard = 0; guard < rows * cols; guard++) {
    final toFill = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        if (grid[r][c]) continue;
        final vertical = filled(r - 1, c) && filled(r + 1, c);
        final horizontal = filled(r, c - 1) && filled(r, c + 1);
        if (vertical || horizontal) toFill.add((r, c));
      }
    }
    if (toFill.isEmpty) return;
    for (final (r, c) in toFill) {
      grid[r][c] = true;
    }
  }
}

/// Nearest-neighbour resample of [src] onto an [outRows] x [outCols] grid,
/// then thin gaps are closed and the shape welded so scaling never leaves a
/// broken or holey silhouette. Used to grow the base silhouettes to a
/// level-appropriate size without redrawing them by hand.
List<List<bool>> resampleMask(List<List<bool>> src, int outRows, int outCols) {
  final srcRows = src.length;
  final srcCols = srcRows == 0 ? 0 : src[0].length;
  final out = List.generate(outRows, (_) => List.filled(outCols, false));
  if (srcRows == 0 || srcCols == 0) return out;
  for (var r = 0; r < outRows; r++) {
    final sr = ((r + 0.5) * srcRows / outRows).floor().clamp(0, srcRows - 1);
    for (var c = 0; c < outCols; c++) {
      final sc = ((c + 0.5) * srcCols / outCols).floor().clamp(0, srcCols - 1);
      final row = src[sr];
      out[r][c] = sc < row.length && row[sc];
    }
  }
  closeMask(out);
  weldMask(out);
  return out;
}


// ---------------------------------------------------------------------------
// Tall, detailed silhouettes. All boards are ~24 rows so the picture fills the
// screen and the generator can pack in plenty of arrows.
// ---------------------------------------------------------------------------

List<List<bool>> _heartMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(6.5, 5.2, 4.7);
  b.disc(6.5, 9.8, 4.7);
  b.triangle(6, 7.5, 21, 6.2);
  b.carve(4.2, 6.4, 1.0);
  b.carve(4.6, 8.6, 0.8);
  b.carve(12.2, 6.2, 0.8);
  b.carve(12.2, 8.8, 0.8);
  b.carve(16.0, 7.5, 0.8);
  return b.build();
}

List<List<bool>> _starMask() {
  final b = _MaskBuilder(24, 17);
  b.star(12.0, 8.0, 8.4, innerFactor: 0.45);
  b.carve(12.0, 8.0, 1.3);
  for (var k = 0; k < 5; k++) {
    final a = math.pi / 2 + k * 2 * math.pi / 5;
    b.carve(12.0 + 6.2 * math.sin(a), 8.0 + 6.2 * math.cos(a), 0.6);
  }
  b.diamond(1.5, 3.5, 1.2);
  b.disc(22.5, 13.0, 1.0);
  return b.build();
}

List<List<bool>> _pineappleMask() {
  final b = _MaskBuilder(24, 17);
  // Spiky crown of leaves.
  b.stroke(6, 8, 0, 8, width: 2);
  b.stroke(6, 8, 1, 5, width: 2);
  b.stroke(6, 8, 1, 11, width: 2);
  b.stroke(6, 8, 2, 2, width: 2);
  b.stroke(6, 8, 2, 14, width: 2);
  b.stroke(6, 8, 3, 0, width: 2);
  b.stroke(6, 8, 3, 16, width: 2);
  // Solid, plump body.
  b.ellipse(15.0, 8.0, 6.2, 9.0);
  // Diamond texture across the skin.
  for (var r = 7; r <= 22; r += 3) {
    for (var c = 3; c <= 13; c += 3) {
      b.carve(r.toDouble(), c.toDouble(), 0.45);
    }
  }
  return b.build();
}

List<List<bool>> _diamondMask() {
  final b = _MaskBuilder(24, 17);
  b.diamond(11.5, 8.0, 9.6);
  b.clearLine(10, 8, 18, 8);
  b.clearLine(10, 8, 16, 3);
  b.clearLine(10, 8, 16, 13);
  b.clearLine(10, 8, 5, 3);
  b.clearLine(10, 8, 5, 13);
  b.carve(3, 8, 0.7);
  b.carve(7, 2.6, 0.7);
  b.carve(7, 13.4, 0.7);
  b.carve(20, 8, 0.7);
  b.disc(23, 14, 0.8);
  return b.build();
}

List<List<bool>> _treeMask() {
  final b = _MaskBuilder(24, 17);
  b.triangle(1, 8.0, 11, 6.8);
  b.triangle(9, 8.0, 17, 6.4);
  b.triangle(15, 8.0, 21, 5.6);
  b.rect(21, 6, 23, 9);
  b.rect(23, 2, 23, 13);
  b.diamond(1.6, 8.0, 1.6);
  b.clearLine(3, 9, 8, 5);
  b.clearLine(10, 10, 15, 5);
  b.carve(4, 6.5, 0.6);
  b.carve(6, 9.5, 0.6);
  b.carve(8, 5.5, 0.6);
  b.carve(11, 10.5, 0.6);
  b.carve(13, 6, 0.6);
  b.carve(16, 10, 0.6);
  b.carve(18, 7, 0.6);
  return b.build();
}

List<List<bool>> _moonMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(12.0, 8.0, 8.2);
  b.carve(10.6, 10.2, 7.0);
  b.carve(8.0, 6.6, 0.8);
  b.carve(11.0, 9.4, 0.8);
  b.carve(14.5, 11.6, 0.7);
  b.carve(6.0, 9.0, 0.7);
  b.disc(3.0, 4.0, 0.7);
  b.disc(5.0, 12.5, 0.6);
  b.disc(20.0, 3.0, 0.7);
  b.disc(19.5, 13.0, 0.6);
  b.disc(22.0, 7.0, 0.6);
  return b.build();
}

List<List<bool>> _flowerMask() {
  final b = _MaskBuilder(24, 17);
  b.petalRing(4.0, 8.0, 5.0, 1.9, 8);
  b.disc(4.0, 8.0, 2.6);
  b.rect(9, 7, 15, 8);
  b.stroke(9, 8, 15, 3, width: 3);
  b.stroke(9, 7, 15, 12, width: 3);
  b.rect(16, 4, 22, 11);
  b.rect(16, 3, 16, 12);
  b.rect(22, 5, 23, 10);
  b.carve(4.0, 8.0, 0.9);
  return b.build();
}

List<List<bool>> _foxMask() {
  final b = _MaskBuilder(24, 17);
  // Pointy ears.
  b.diamond(2.5, 4.6, 2.6);
  b.diamond(2.5, 11.4, 2.6);
  // Broad head.
  b.disc(12.5, 8.0, 7.3);
  // Tapering snout.
  b.triangle(12, 8.0, 21, 3.9);
  // Eyes, nose and ear hollows.
  b.carve(10.5, 5.6, 1.1);
  b.carve(10.5, 10.4, 1.1);
  b.carve(18.0, 8.0, 0.9);
  b.carve(3.5, 4.6, 0.7);
  b.carve(3.5, 11.4, 0.7);
  return b.build();
}

List<List<bool>> _fishMask() {
  final b = _MaskBuilder(24, 19);
  b.ellipse(11.0, 8.5, 3.4, 7.1);
  b.disc(5.5, 9.8, 2.4);
  b.carve(4.8, 10.4, 0.6);
  b.stroke(15, 6, 20, 2, width: 3);
  b.stroke(15, 7, 20, 6, width: 3);
  b.stroke(15, 7, 20, 10, width: 3);
  b.stroke(9, 6, 12, 12, width: 2);
  b.clearLine(9, 7, 9, 10);
  b.clearLine(11, 6, 11, 11);
  b.clearLine(14, 6, 14, 11);
  b.clearLine(4, 7, 6, 6);
  b.disc(2.0, 12.5, 0.7);
  b.disc(1.0, 14.0, 0.6);
  b.disc(3.0, 15.0, 0.6);
  return b.build();
}

List<List<bool>> _butterflyMask() {
  final b = _MaskBuilder(24, 18);
  b.rect(5, 8, 18, 9);
  b.disc(4, 8.5, 1.4);
  b.stroke(4, 8, 1, 4, width: 2);
  b.stroke(4, 8, 1, 12, width: 2);
  b.ellipse(7, 4.2, 3.2, 5.0);
  b.ellipse(7, 12.8, 3.2, 5.0);
  b.ellipse(11, 3.2, 3.2, 5.4);
  b.ellipse(11, 13.8, 3.2, 5.4);
  b.carve(7, 4.4, 1.8);
  b.carve(7, 12.6, 1.8);
  b.carve(11.4, 3.4, 1.8);
  b.carve(11.4, 13.6, 1.8);
  for (var k = 0; k < 6; k++) {
    final a = 2 * math.pi * k / 6;
    b.carve(4.6 + 3.4 * math.sin(a), 4.6 + 3.4 * math.cos(a), 0.5);
    b.carve(4.6 + 3.4 * math.sin(a), 12.4 + 3.4 * math.cos(a), 0.5);
  }
  return b.build();
}

List<List<bool>> _sunMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(12.0, 8.0, 5.2);
  b.rays(12.0, 8.0, 6.4, 10.6, 14, width: 3);
  b.circleRing(12.0, 8.0, 3.6, thickness: 1.0);
  for (var k = 0; k < 8; k++) {
    final a = k * 2 * math.pi / 8;
    b.carve(12.0 + 6.4 * math.sin(a), 8.0 + 6.4 * math.cos(a), 0.55);
  }
  return b.build();
}

List<List<bool>> _lightningMask() {
  final b = _MaskBuilder(24, 16);
  final segs = [
    (2, 11),
    (7, 5),
    (10, 12),
    (14, 6),
    (17, 11),
    (20, 3),
    (22, 6),
  ];
  for (var i = 1; i < segs.length; i++) {
    b.stroke(segs[i - 1].$1, segs[i - 1].$2, segs[i].$1, segs[i].$2,
        width: 5);
  }
  b.diamond(1, 3.0, 1.6);
  b.diamond(23, 13.5, 1.6);
  b.disc(5, 14.5, 1.0);
  b.disc(11, 12, 1.1);
  b.disc(16, 6.5, 1.1);
  return b.build();
}

List<List<bool>> _mushroomMask() {
  final b = _MaskBuilder(24, 17);
  b.ellipse(6.5, 8.0, 7.0, 5.0);
  b.carve(2.5, 6.5, 1.4);
  b.carve(3.0, 11.5, 1.0);
  b.carve(5.0, 3.5, 1.0);
  b.carve(8.0, 5.0, 0.7);
  b.carve(6.5, 13.0, 0.7);
  b.rect(12, 7, 19, 9);
  b.rect(18, 6, 19, 10);
  b.rect(12, 5, 13, 11);
  b.rect(21, 3, 22, 12);
  b.triangle(20, 1.5, 22, 0.8);
  b.triangle(20, 5.5, 22, 0.8);
  b.triangle(20, 10.5, 22, 0.8);
  b.triangle(20, 13.5, 22, 0.8);
  return b.build();
}

List<List<bool>> _cloudMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(6.5, 4.0, 4.2);
  b.disc(6.0, 10.5, 4.6);
  b.disc(9.0, 13.5, 3.0);
  b.rect(9, 1, 12, 15);
  b.line(16, 3, 21, 3);
  b.line(16, 6, 21, 6);
  b.line(16, 10, 21, 10);
  b.line(16, 13, 21, 13);
  b.disc(20, 7, 1.0);
  b.disc(21, 10, 1.2);
  b.disc(20, 3, 0.9);
  return b.build();
}

List<List<bool>> _crownMask() {
  final b = _MaskBuilder(24, 17);
  b.triangle(1, 2, 14, 1.3);
  b.triangle(0, 5, 13, 1.3);
  b.triangle(0, 8, 12, 1.3);
  b.triangle(0, 11, 13, 1.3);
  b.triangle(1, 14, 14, 1.3);
  b.rect(13, 1, 15, 15);
  b.rect(16, 3, 16, 12);
  b.clearRect(8, 0, 9, 16);
  b.diamond(14, 3, 1.0);
  b.diamond(14, 8, 1.2);
  b.diamond(14, 13, 1.0);
  b.stroke(16, 8, 17, 8, width: 2);
  b.diamond(19, 8, 4.0);
  b.carve(19, 8, 1.8);
  return b.build();
}

List<List<bool>> _rocketMask() {
  final b = _MaskBuilder(24, 16);
  b.triangle(0, 7.5, 4, 1.8);
  b.rect(3, 5, 13, 9);
  b.stroke(10, 5, 15, 2, width: 3);
  b.stroke(10, 9, 15, 12, width: 3);
  b.carve(6.5, 7.5, 1.2);
  b.carve(10.5, 7.5, 0.7);
  b.clearRect(5, 5, 5, 9);
  b.clearLine(12, 5, 12, 9);
  b.stroke(14, 5, 16, 4, width: 2);
  b.stroke(14, 9, 16, 10, width: 2);
  b.triangle(16, 7.5, 21, 2.2);
  b.disc(4, 2, 0.6);
  b.disc(9, 13, 0.7);
  b.disc(14, 2.5, 0.6);
  b.diamond(19, 4, 1.0);
  return b.build();
}

List<List<bool>> _ghostMask() {
  final b = _MaskBuilder(24, 16);
  b.disc(6.5, 7.5, 4.4);
  b.rect(11, 3, 16, 11);
  b.rect(16, 3, 16, 11);
  b.rect(17, 3, 18, 5);
  b.rect(17, 6, 18, 8);
  b.rect(17, 9, 18, 11);
  b.rect(18, 2, 19, 3);
  b.rect(18, 5, 19, 6);
  b.rect(18, 8, 19, 9);
  b.rect(18, 11, 19, 12);
  b.rect(19, 3, 19, 11);
  b.carve(5.2, 5.6, 0.9);
  b.carve(5.2, 9.4, 0.9);
  b.carve(8, 7.5, 0.8);
  b.carve(7.5, 4.0, 0.6);
  b.carve(7.5, 11.0, 0.6);
  b.disc(10, 1.5, 0.5);
  b.diamond(21, 13.5, 1.1);
  return b.build();
}

List<List<bool>> _snowmanMask() {
  final b = _MaskBuilder(24, 16);
  b.disc(17, 7.5, 4.6);
  b.disc(12.5, 7.5, 3.6);
  b.disc(8.5, 7.5, 2.7);
  b.rect(5, 4, 6, 10);
  b.rect(3, 6, 4, 8);
  b.carve(7, 6, 0.55);
  b.carve(7, 9, 0.55);
  b.triangle(7, 7.5, 9, 0.8);
  b.carve(9, 6, 0.4);
  b.carve(9, 7.5, 0.4);
  b.carve(9, 9, 0.4);
  b.clearRect(9, 4, 10, 10);
  b.stroke(10, 10, 12, 12, width: 2);
  b.stroke(10, 4, 13, 3, width: 2);
  b.stroke(10, 11, 13, 12, width: 2);
  b.carve(12, 7.5, 0.55);
  b.carve(14, 7.5, 0.55);
  b.carve(16, 7.5, 0.55);
  b.rect(22, 4, 22, 11);
  b.disc(2.5, 2, 1.0);
  b.disc(3, 13.5, 0.9);
  return b.build();
}

List<List<bool>> _batteryMask() {
  final b = _MaskBuilder(24, 15);
  b.rect(0, 5, 1, 8);
  b.rect(1, 3, 21, 10);
  b.clearRect(3, 6, 4, 8);
  b.clearRect(6, 5, 6, 8);
  b.clearRect(9, 5, 9, 8);
  b.clearRect(12, 5, 12, 8);
  b.clearRect(15, 5, 15, 8);
  b.clearRect(18, 5, 18, 8);
  b.clearRect(21, 5, 22, 8);
  b.disc(5, 2, 0.7);
  b.disc(5, 12, 0.7);
  b.disc(14, 13, 0.8);
  return b.build();
}

List<List<bool>> _keyMask() {
  final b = _MaskBuilder(24, 15);
  b.circleRing(5.0, 6.5, 3.6, thickness: 1.4);
  b.circleRing(5.0, 6.5, 1.4, thickness: 0.8);
  b.rect(8, 6, 21, 7);
  b.rect(8, 5, 10, 8);
  b.rect(13, 7, 14, 10);
  b.rect(16, 7, 17, 12);
  b.rect(19, 7, 20, 10);
  b.carve(10.5, 6.5, 0.6);
  b.carve(14, 6.5, 0.6);
  b.carve(18, 6.5, 0.6);
  return b.build();
}

List<List<bool>> _catMask() {
  final b = _MaskBuilder(24, 18);
  b.disc(5.5, 8.5, 3.4);
  b.triangle(1, 5, 5, 1.6);
  b.triangle(1, 12, 5, 1.6);
  b.carve(4.2, 7, 0.8);
  b.carve(4.2, 10, 0.8);
  b.triangle(6, 8.5, 8, 0.7);
  b.ellipse(14, 8.5, 5.2, 6.0);
  b.carveEllipse(14, 8.5, 3.0, 3.4);
  b.stroke(16, 2, 21, 5, width: 3);
  b.carve(19, 4, 0.6);
  b.disc(20, 6.5, 1.3);
  b.disc(20, 10.5, 1.3);
  b.carve(20, 6.5, 0.4);
  b.carve(20, 10.5, 0.4);
  return b.build();
}

List<List<bool>> _pawMask() {
  final b = _MaskBuilder(24, 15);
  b.ellipse(5, 7.0, 3.2, 2.4);
  b.disc(1.3, 4.2, 1.1);
  b.disc(1.3, 7.0, 1.15);
  b.disc(1.3, 9.8, 1.1);
  b.disc(3.6, 11.2, 0.8);
  b.disc(9, 7.0, 0.9);
  b.disc(12.5, 7.0, 0.9);
  b.ellipse(16.5, 7.0, 2.4, 1.8);
  b.disc(13.6, 5.2, 0.8);
  b.disc(13.6, 7.0, 0.85);
  b.disc(13.6, 8.8, 0.8);
  b.rect(22, 4, 22, 10);
  b.carve(5, 6.4, 0.5);
  b.carve(5, 7.6, 0.5);
  b.carve(5, 9.0, 0.5);
  b.carve(5, 5.2, 0.5);
  return b.build();
}

List<List<bool>> _bellMask() {
  final b = _MaskBuilder(24, 16);
  b.rect(0, 6, 1, 9);
  b.rect(1, 6, 1, 8);
  b.ellipse(7.5, 7.5, 4.4, 5.2);
  b.triangle(9, 7.5, 15, 5.0);
  b.rect(16, 7, 17, 7);
  b.disc(18.5, 7.5, 1.6);
  b.clearLine(3, 6, 3, 9);
  b.clearLine(6, 3, 10, 3);
  b.clearRect(10, 4, 14, 4);
  b.clearRect(10, 6, 14, 6);
  b.clearRect(10, 9, 14, 9);
  b.rect(21, 12, 22, 14);
  b.disc(22, 10.5, 0.9);
  b.disc(2, 13, 0.9);
  return b.build();
}

List<List<bool>> _carMask() {
  final b = _MaskBuilder(24, 19);
  b.rect(11, 2, 15, 16);
  b.rect(6, 5, 11, 13);
  b.rect(3, 2, 5, 16);
  b.clearRect(7, 6, 9, 8);
  b.clearRect(7, 10, 9, 12);
  b.carve(14, 4.5, 2.1);
  b.carve(14, 12.5, 2.1);
  b.clearRect(12, 2, 12, 8);
  b.clearRect(12, 10, 12, 16);
  b.rect(20, 0, 21, 18);
  b.clearRect(20, 2, 20, 5);
  b.clearRect(20, 8, 20, 11);
  b.clearRect(20, 15, 20, 17);
  b.disc(3.5, 12, 1.7);
  b.disc(1.5, 15, 1.3);
  b.disc(0.5, 17, 0.8);
  b.disc(2, 1.5, 1.5);
  return b.build();
}

List<List<bool>> _rangoliMask() {
  final b = _MaskBuilder(26, 26);
  const cr = 12.5;
  const cc = 12.5;
  b.disc(cr, cc, 2.2);
  b.diamond(cr, cc, 3.4, ringMin: 0.55);
  b.circleRing(cr, cc, 5.0, thickness: 1.0);
  b.rays(cr, cc, 1.5, 10.5, 16, width: 2);
  b.petalRing(cr, cc, 8.0, 2.0, 8);
  b.circleRing(cr, cc, 11.0, thickness: 1.0);
  b.petalRing(cr, cc, 11.0, 1.4, 16);
  b.disc(1.5, 1.5, 1.6);
  b.disc(1.5, 24.5, 1.6);
  b.disc(24.5, 1.5, 1.6);
  b.disc(24.5, 24.5, 1.6);
  b.disc(1.5, 12.5, 2.0);
  b.disc(12.5, 1.5, 2.0);
  b.disc(24.5, 12.5, 2.0);
  b.disc(12.5, 24.5, 2.0);
  return b.build();
}

List<List<bool>> _chakraMask() {
  final b = _MaskBuilder(26, 26);
  const cr = 12.5;
  const cc = 12.5;
  b.circleRing(cr, cc, 8.8, thickness: 2.2);
  b.circleRing(cr, cc, 5.4, thickness: 1.6);
  b.circleRing(cr, cc, 11.8, thickness: 1.2);
  b.rays(cr, cc, 1.2, 8.4, 8, width: 2);
  b.rays(cr, cc, 9.2, 11.9, 24, width: 1);
  b.disc(cr, cc, 4.7);
  b.disc(2, 12.5, 1.0);
  b.disc(24.5, 12.5, 1.0);
  return b.build();
}

List<List<bool>> _tajMahalMask() {
  final b = _MaskBuilder(24, 23);
  b.disc(9, 10.5, 4.8);
  b.triangle(2, 10.5, 7, 1.3);
  b.stroke(2, 10, 0, 10, width: 2);
  b.disc(0, 10.5, 0.7);
  b.rect(9, 5, 16, 16);
  b.rect(12, 2, 16, 4);
  b.rect(12, 18, 16, 20);
  b.rect(0, 1, 16, 2);
  b.rect(0, 20, 16, 21);
  b.disc(0, 1.5, 0.9);
  b.disc(0, 20.5, 0.9);
  b.clearRect(9, 6, 15, 6);
  b.clearRect(9, 10, 15, 10);
  b.clearRect(9, 16, 15, 16);
  b.clearRect(4, 2, 10, 2);
  b.clearRect(4, 20, 10, 20);
  b.rect(17, 2, 18, 20);
  b.rect(19, 0, 19, 22);
  b.clearLine(11, 8, 14, 8);
  return b.build();
}

List<List<bool>> _lotusMask() {
  final b = _MaskBuilder(24, 19);
  b.petalRing(8.0, 9.0, 3.0, 2.6, 6);
  b.petalRing(8.0, 9.0, 5.0, 4.2, 8);
  b.disc(8.0, 9.0, 2.6);
  b.rect(17, 8, 20, 9);
  b.circleRing(20, 9.0, 4.5, thickness: 0.9);
  b.circleRing(22, 9.0, 6.0, thickness: 0.8);
  b.ellipse(20, 15.5, 3.0, 1.2);
  b.clearRect(20, 15, 20, 16);
  b.carve(8.0, 9.0, 1.0);
  for (var k = 0; k < 6; k++) {
    final a = k * 2 * math.pi / 6;
    b.carve(8.0 + 3.4 * math.sin(a), 9.0 + 3.4 * math.cos(a), 0.7);
  }
  return b.build();
}

List<List<bool>> _diyaMask() {
  final b = _MaskBuilder(24, 19);
  b.ellipse(6.5, 9.0, 1.6, 3.6);
  b.triangle(1, 9.0, 5, 1.0);
  b.circleRing(6.5, 9.0, 2.3, thickness: 0.7);
  b.disc(12, 9.0, 4.6);
  b.circleRing(12, 9.0, 3.5, thickness: 0.9);
  b.triangle(12, 13.5, 14, 1.2);
  b.stroke(12, 14, 13, 15, width: 2);
  b.carve(4.0, 9.0, 0.8);
  b.rect(16, 6, 20, 11);
  b.rect(20, 4, 21, 13);
  b.rect(22, 5, 23, 12);
  for (var k = 0; k < 5; k++) {
    final a = k * 2 * math.pi / 5;
    b.carve(12 + 3.5 * math.sin(a), 9 + 3.5 * math.cos(a), 0.45);
  }
  return b.build();
}

List<List<bool>> _lionMask() {
  final b = _MaskBuilder(24, 19);
  b.disc(11, 9.0, 6.9);
  b.petalRing(11, 9.0, 7.1, 1.9, 14);
  b.disc(5.5, 5.2, 1.5);
  b.disc(5.5, 12.8, 1.5);
  b.carve(9.6, 7.4, 0.7);
  b.carve(9.6, 10.6, 0.7);
  b.diamond(11.4, 9.0, 0.9);
  b.disc(12.5, 9.0, 1.4);
  b.clearLine(14, 8, 15, 9);
  b.clearLine(14, 10, 15, 9);
  b.carve(12.3, 5.8, 0.4);
  b.carve(12.6, 6.4, 0.4);
  b.carve(12.2, 9.0, 0.4);
  b.carve(12.6, 11.6, 0.4);
  b.carve(12.3, 12.2, 0.4);
  b.rect(22, 6, 23, 12);
  return b.build();
}

List<List<bool>> _trishulMask() {
  final b = _MaskBuilder(24, 13);
  b.rect(1, 5, 23, 7);
  b.stroke(0, 1, 8, 5, width: 3);
  b.stroke(0, 11, 8, 7, width: 3);
  b.triangle(0, 6, 9, 2.6);
  b.rect(4, 0, 6, 12);
  b.circleRing(16, 6, 2.3, thickness: 1.0);
  b.disc(16, 6, 0.8);
  b.disc(20, 11.5, 0.9);
  b.disc(20, 0.5, 0.9);
  b.rect(20, 3, 21, 9);
  b.rect(22, 2, 23, 10);
  return b.build();
}

List<List<bool>> _balloonMask() {
  final b = _MaskBuilder(24, 19);
  b.ellipse(9, 9.0, 5.8, 6.6);
  b.triangle(2, 9.0, 8, 1.6);
  b.clearRect(4, 5, 14, 5);
  b.clearRect(4, 13, 14, 13);
  b.circleRing(9, 9.0, 2.8, thickness: 0.9);
  b.stroke(11, 6, 17, 6, width: 1);
  b.stroke(11, 12, 17, 12, width: 1);
  b.rect(17, 6, 19, 12);
  b.carve(18, 9, 0.5);
  b.disc(21, 14, 1.2);
  b.disc(6, 1.6, 1.5);
  b.disc(3, 17, 1.6);
  b.disc(2, 12, 1.2);
  return b.build();
}

List<List<bool>> _snailMask() {
  final b = _MaskBuilder(24, 18);
  // Solid spiral shell (a filled disc with a carved two-cell spiral groove) so
  // it stays dense and fills completely even when scaled up for later levels.
  const cr = 11.5;
  const cc = 9.5;
  b.disc(cr, cc, 7.4);
  for (var k = 0; k < 120; k++) {
    final a = 0.35 * k;
    final rr = 0.8 + 0.11 * k;
    if (rr > 7.0) break;
    b.carve(cr + rr * math.sin(a), cc + rr * math.cos(a), 0.9);
  }
  b.carve(cr, cc, 0.8);
  // Foot / body and head.
  b.rect(16, 2, 18, 15);
  b.disc(15.5, 4.0, 1.9);
  b.stroke(14, 3, 11, 0, width: 2);
  b.stroke(14, 5, 12, 2, width: 2);
  return b.build();
}

List<List<bool>> _omMask() {
  final b = _MaskBuilder(24, 17);
  b.circleRing(5, 4.6, 2.0, thickness: 1.2);
  b.circleRing(5, 11.4, 2.0, thickness: 1.2);
  b.circleRing(5, 8.0, 5.2, thickness: 1.0);
  b.stroke(8, 8, 15, 8, width: 2);
  b.disc(12, 8.0, 1.1);
  b.circleRing(17.5, 8.0, 2.4, thickness: 1.1);
  b.circleRing(20.5, 8.0, 3.0, thickness: 1.0);
  b.disc(21, 2.5, 0.7);
  b.disc(3, 14.5, 0.7);
  return b.build();
}

List<List<bool>> _castleMask() {
  final b = _MaskBuilder(24, 23);
  b.rect(0, 1, 19, 4);
  b.rect(0, 18, 19, 21);
  b.rect(0, 1, 0, 4);
  b.rect(0, 18, 0, 21);
  b.rect(3, 6, 20, 13);
  b.triangle(0, 9.5, 5, 3.4);
  b.stroke(0, 9, 0, 9, width: 2);
  b.clearRect(15, 10, 19, 11);
  b.clearRect(5, 6, 11, 6);
  b.clearRect(5, 13, 11, 13);
  b.clearRect(4, 9, 10, 9);
  b.clearRect(4, 2, 9, 2);
  b.clearRect(4, 12, 9, 12);
  b.clearRect(4, 19, 9, 19);
  b.clearRect(4, 20, 9, 20);
  b.clearRect(6, 1, 12, 1);
  b.rect(20, 3, 21, 19);
  b.rect(22, 0, 22, 22);
  b.clearLine(11, 5, 14, 5);
  return b.build();
}

List<List<bool>> _penguinMask() {
  final b = _MaskBuilder(24, 17);
  b.ellipse(12, 8.0, 5.6, 7.2);
  b.disc(5, 8.0, 3.0);
  b.carveEllipse(12.5, 8.0, 3.0, 4.4);
  b.carve(3.8, 6.4, 0.55);
  b.carve(3.8, 9.6, 0.55);
  b.triangle(5, 8.0, 7, 1.1);
  b.stroke(9, 3, 14, 1, width: 3);
  b.stroke(9, 13, 14, 15, width: 3);
  b.disc(20, 5.5, 1.2);
  b.disc(20, 10.5, 1.2);
  b.rect(22, 2, 22, 13);
  b.carve(8.5, 5.0, 0.5);
  b.carve(8.5, 11.0, 0.5);
  return b.build();
}

List<List<bool>> _owlMask() {
  final b = _MaskBuilder(24, 17);
  b.ellipse(13, 8.0, 5.2, 6.2);
  b.disc(6.5, 8.0, 3.8);
  b.triangle(0, 4, 4, 1.1);
  b.triangle(0, 12, 4, 1.1);
  b.carve(5.2, 6.0, 1.3);
  b.carve(5.2, 10.0, 1.3);
  b.disc(5.2, 6.0, 0.65);
  b.disc(5.2, 10.0, 0.65);
  b.triangle(7, 8.0, 9, 0.9);
  b.carveEllipse(9, 3.4, 1.4, 2.8);
  b.carveEllipse(9, 12.6, 1.4, 2.8);
  b.clearLine(11, 4, 11, 12);
  b.clearLine(14, 4, 14, 12);
  b.rect(20, 2, 21, 13);
  b.triangle(19, 13, 21, 1.4);
  b.carve(6.8, 7.2, 0.4);
  b.carve(6.8, 8.8, 0.4);
  return b.build();
}

List<List<bool>> _elephantMask() {
  final b = _MaskBuilder(24, 21);
  b.ellipse(12, 9.5, 6.4, 6.8);
  b.disc(6.5, 6.5, 3.4);
  b.stroke(7, 6, 14, 3, width: 3);
  b.circleRing(15, 2.6, 1.1, thickness: 0.9);
  b.ellipse(9, 14, 1.9, 3.4);
  b.carve(9, 14, 0.9);
  b.carve(4.8, 7.6, 0.5);
  b.triangle(8, 5.8, 12, 1.1);
  b.carve(8.2, 5.8, 0.5);
  b.rect(18, 3, 21, 6);
  b.rect(18, 7, 21, 10);
  b.rect(18, 12, 21, 14);
  b.rect(18, 16, 21, 17);
  b.disc(21.5, 5, 1.2);
  b.disc(21.5, 12.5, 1.2);
  b.rect(23, 3, 23, 17);
  b.carve(8.5, 8.2, 0.6);
  b.carve(10.5, 8.2, 0.6);
  b.carve(12.5, 8.2, 0.6);
  return b.build();
}

List<List<bool>> _cactusMask() {
  final b = _MaskBuilder(24, 15);
  b.rect(0, 6, 16, 9);
  b.clearRect(2, 7, 14, 7);
  b.rect(2, 2, 6, 4);
  b.rect(5, 4, 6, 6);
  b.rect(7, 2, 13, 4);
  b.rect(2, 10, 6, 12);
  b.rect(5, 8, 6, 10);
  b.rect(7, 12, 13, 14);
  b.disc(0, 3, 1.1);
  b.disc(0, 11, 1.1);
  b.disc(0, 7.5, 1.2);
  b.rect(17, 3, 21, 10);
  b.rect(17, 2, 17, 11);
  b.rect(21, 4, 22, 9);
  b.rect(23, 5, 23, 8);
  b.clearLine(11, 6, 13, 6);
  return b.build();
}

List<List<bool>> _umbrellaMask() {
  final b = _MaskBuilder(24, 19);
  b.ellipse(8, 9.0, 8.4, 5.8);
  b.rect(8, 0, 9, 18);
  b.clearRect(3, 4, 8, 4);
  b.clearRect(3, 8, 8, 8);
  b.clearRect(3, 12, 8, 12);
  b.clearRect(3, 16, 8, 16);
  b.clearRect(8, 2, 8, 16);
  b.stroke(11, 9, 19, 9, width: 2);
  b.circleRing(21, 10.5, 1.2, thickness: 0.9);
  b.stroke(13, 15, 17, 16, width: 1);
  b.stroke(14, 2, 18, 3, width: 1);
  b.disc(19, 5, 0.8);
  b.disc(20, 7, 0.8);
  b.disc(20, 12, 0.8);
  b.disc(19, 14, 0.8);
  return b.build();
}

List<List<bool>> _iceCreamMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(1.8, 8.0, 1.0);
  b.line(0, 8, 2, 8);
  b.disc(5, 6.5, 3.0);
  b.disc(7.5, 8.5, 3.0);
  b.disc(10, 7.0, 2.5);
  b.stroke(9, 5, 11, 4, width: 2);
  b.stroke(8, 10, 10, 11, width: 2);
  b.triangle(12, 8.0, 20, 3.6);
  b.clearLine(13, 10, 19, 6);
  b.clearLine(13, 6, 19, 10);
  b.clearLine(14, 5, 15, 11);
  b.carve(3.5, 7, 0.4);
  b.carve(3, 6, 0.35);
  b.carve(9, 11, 0.4);
  b.carve(5.5, 9, 0.35);
  b.carve(10.5, 12.5, 0.4);
  return b.build();
}

List<List<bool>> _anchorMask() {
  final b = _MaskBuilder(24, 17);
  b.circleRing(2.5, 8.0, 1.9, thickness: 1.1);
  b.rect(4, 7, 19, 8);
  b.rect(5, 3, 8, 12);
  b.stroke(11, 8, 16, 4, width: 3);
  b.stroke(11, 8, 16, 12, width: 3);
  b.triangle(17, 6, 20, 1.0);
  b.triangle(17, 9.5, 20, 1.0);
  b.triangle(19, 7.5, 23, 1.9);
  b.triangle(19, 7.5, 23, 1.9);
  b.clearRect(10, 5, 11, 9);
  b.carve(8, 7.5, 0.6);
  b.disc(22, 2, 0.8);
  b.disc(23, 14, 0.8);
  b.disc(3, 14, 0.7);
  return b.build();
}

List<List<bool>> _hourglassMask() {
  final b = _MaskBuilder(24, 13);
  b.rect(0, 3, 1, 9);
  b.rect(1, 3, 1, 9);
  b.rect(22, 3, 23, 9);
  b.triangle(2, 6.0, 11, 3.6);
  b.triangle(13, 6.0, 21, 3.6);
  b.rect(11, 5, 13, 6);
  b.carve(7, 6.0, 2.6);
  b.disc(17.5, 6.0, 1.9);
  b.disc(16.5, 4.4, 1.1);
  b.disc(16.5, 7.6, 1.1);
  b.rect(22, 4, 23, 8);
  b.disc(3, 12.5, 0.7);
  b.disc(3, 0.5, 0.7);
  return b.build();
}

List<List<bool>> _guitarMask() {
  final b = _MaskBuilder(24, 17);
  b.rect(1, 6, 2, 10);
  b.rect(3, 7, 9, 8);
  b.clearRect(5, 7, 5, 8);
  b.clearRect(7, 7, 7, 8);
  b.ellipse(12, 8.0, 3.4, 2.8);
  b.ellipse(16.5, 8.0, 4.0, 5.4);
  b.rect(13, 5, 14, 11);
  b.carve(16.5, 8.0, 1.5);
  b.clearLine(11, 7, 20, 7);
  b.clearLine(11, 8, 20, 8);
  b.clearRect(20, 6, 21, 10);
  b.disc(1, 3.5, 0.6);
  b.disc(1, 12.5, 0.6);
  b.disc(3.5, 2.8, 0.6);
  b.disc(3.5, 13.2, 0.6);
  b.carve(18, 11, 0.5);
  b.disc(23, 4, 0.8);
  b.disc(23, 12, 0.8);
  return b.build();
}

List<List<bool>> _sailboatMask() {
  final b = _MaskBuilder(24, 19);
  b.rect(1, 8, 16, 9);
  b.triangle(2, 8.5, 14, 5.4);
  b.triangle(2, 8.5, 12, 2.6);
  b.triangle(0, 8.5, 2, 1.6);
  b.ellipse(20, 8.5, 4.6, 1.7);
  b.clearRect(20, 6, 21, 11);
  b.circleRing(22, 8.5, 3.2, thickness: 0.8);
  b.circleRing(23.5, 8.5, 4.6, thickness: 0.7);
  b.disc(3, 16, 1.3);
  b.disc(18, 3, 1.4);
  b.clearLine(4, 5, 7, 6);
  return b.build();
}

List<List<bool>> _ladybugMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(8, 8.0, 4.6);
  b.disc(6, 4.8, 1.6);
  b.stroke(5, 4, 3, 2, width: 2);
  b.stroke(5, 6, 4, 3, width: 2);
  b.clearLine(5, 10, 12, 10);
  b.carve(7, 6.4, 0.7);
  b.carve(10, 7.2, 0.8);
  b.carve(6.6, 10, 0.8);
  b.carve(9.8, 10.6, 0.78);
  b.carve(6.8, 8.2, 0.6);
  b.carve(10.2, 8.6, 0.6);
  b.stroke(10, 4, 11, 2, width: 2);
  b.stroke(10, 6, 12, 5, width: 2);
  b.stroke(10, 11, 12, 10, width: 2);
  b.stroke(10, 13, 11, 15, width: 2);
  b.ellipse(18, 8.0, 7.0, 2.0);
  b.stroke(19, 1, 21, 0, width: 2);
  b.clearLine(18, 4, 18, 12);
  b.clearLine(18, 6, 18, 6);
  b.disc(7, 3, 0.5);
  b.disc(15, 15, 0.7);
  return b.build();
}

List<List<bool>> _envelopeMask() {
  final b = _MaskBuilder(24, 19);
  // A plump, rounded letter with a peaked flap: blobby body fills densely.
  b.ellipse(12.5, 9, 8.2, 8.2);
  b.triangle(4, 9, 14, 6.8);
  b.carve(8, 9, 0.9);
  b.carve(16, 5, 0.7);
  b.carve(16, 13, 0.7);
  return b.build();
}

List<List<bool>> _lockMask() {
  final b = _MaskBuilder(24, 15);
  // A single fat blob: round body merged with a solid shackle so the whole
  // padlock fills as one piece.
  b.disc(15, 7, 6.6);
  b.disc(6.5, 7, 4.6);
  b.rect(5, 4, 9, 10);
  b.carve(15, 7, 1.2);
  b.carve(11, 5, 0.7);
  b.carve(11, 9, 0.7);
  return b.build();
}

List<List<bool>> _musicNoteMask() {
  final b = _MaskBuilder(24, 15);
  // A single eighth note: a rounded head, a straight stem up its right side,
  // and a flag sweeping off the top. (A beamed pair reads as a "goalpost" at
  // this resolution, so avoid two parallel stems.)
  b.ellipse(18.5, 4.5, 3.8, 2.8);
  b.stroke(2, 7, 17, 7, width: 3);
  b.stroke(2, 7, 6, 13, width: 4);
  b.stroke(4, 9, 8, 12, width: 4);
  return b.build();
}

List<List<bool>> _cherryMask() {
  final b = _MaskBuilder(24, 17);
  b.disc(17, 6, 4.4);
  b.disc(18, 11.5, 4.0);
  b.stroke(15, 6, 4, 8, width: 2);
  b.stroke(15, 11, 4, 8, width: 2);
  b.ellipse(3, 9, 3.2, 1.5);
  b.carve(16, 5.5, 0.6);
  b.carve(17, 11, 0.6);
  return b.build();
}

List<List<bool>> _pizzaMask() {
  final b = _MaskBuilder(24, 19);
  b.triangle(2, 9.5, 21, 8.6);
  b.ellipse(3, 9.5, 8.2, 2.1);
  b.carve(9, 7, 1.2);
  b.carve(13, 11, 1.2);
  b.carve(16, 8, 1.2);
  b.carve(19, 9, 1.0);
  return b.build();
}

List<List<bool>> _trophyMask() {
  final b = _MaskBuilder(24, 19);
  // Plump bowl with chunky side handles, a short stem and a round base: all
  // blobs merged together so the trophy fills densely.
  b.disc(9, 9, 6.2);
  b.disc(9, 2.8, 2.8);
  b.disc(9, 15.2, 2.8);
  b.rect(13, 8, 17, 10);
  b.disc(21, 9, 4.2);
  b.carve(9, 9, 1.0);
  return b.build();
}

List<List<bool>> _pearMask() {
  final b = _MaskBuilder(24, 19);
  // Two stacked lobes (small on top, big below) so it reads as a pear and
  // avoids the pure-disc symmetry the ring packer handles poorly.
  b.disc(7.5, 9, 4.6);
  b.disc(15, 9, 7.0);
  b.stroke(3, 9, 5, 9, width: 2);
  b.ellipse(3, 13, 2.4, 1.1);
  b.carve(9, 9, 0.9);
  b.carve(17, 6, 0.7);
  return b.build();
}

List<List<bool>> _whaleMask() {
  final b = _MaskBuilder(24, 21);
  b.ellipse(13, 9, 6.0, 6.6);
  b.stroke(9, 14, 5, 20, width: 3);
  b.stroke(16, 14, 20, 20, width: 3);
  b.triangle(6, 10, 10, 1.3);
  b.carve(11, 5, 0.7);
  b.disc(3, 4, 0.9);
  b.disc(2, 6, 0.6);
  b.disc(5, 3, 0.6);
  return b.build();
}

// ---------------------------------------------------------------------------
// Level catalogue.
// ---------------------------------------------------------------------------

final List<SilhouetteLevel> _baseLevels = [
  SilhouetteLevel(
    id: 1,
    name: 'Heart',
    themeEmoji: '\u2764\uFE0F',
    description: 'Fill the big heart with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _heartMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[0]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 2,
    name: 'Star',
    themeEmoji: '\u2B50',
    description: 'Fill the shining star with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _starMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[1]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 3,
    name: 'Pineapple',
    themeEmoji: '\uD83C\uDF4D',
    description: 'Fill the juicy pineapple with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _pineappleMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[2]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 4,
    name: 'Diamond',
    themeEmoji: '\uD83D\uDC8E',
    description: 'Fill the faceted diamond with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _diamondMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[3]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 5,
    name: 'Tree',
    themeEmoji: '\uD83C\uDF32',
    description: 'Fill the tall Christmas tree with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _treeMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[4]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 6,
    name: 'Moon',
    themeEmoji: '\uD83C\uDF19',
    description: 'Fill the crescent moon with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _moonMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[5]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 7,
    name: 'Flower',
    themeEmoji: '\uD83C\uDF3C',
    description: 'Fill the blooming flower with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _flowerMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[6]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 8,
    name: 'Fox',
    themeEmoji: '\uD83E\uDD8A',
    description: 'Fill the sly fox with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _foxMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[7]),
    config: LevelConfig.extreme,
  ),
  SilhouetteLevel(
    id: 9,
    name: 'Fish',
    themeEmoji: '\uD83D\uDC1F',
    description: 'Fill the swimming fish with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _fishMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[8]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 10,
    name: 'Butterfly',
    themeEmoji: '\uD83E\uDD8B',
    description: 'Fill the butterfly\u2019s wings with arrows',
    gridCols: 18,
    gridRows: 24,
    mask: _butterflyMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[9]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 11,
    name: 'Sun',
    themeEmoji: '\u2600\uFE0F',
    description: 'Fill the blazing sun with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _sunMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[10]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 12,
    name: 'Lightning',
    themeEmoji: '\u26A1',
    description: 'Fill the lightning bolt with arrows',
    gridCols: 16,
    gridRows: 24,
    mask: _lightningMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[11]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 13,
    name: 'Mushroom',
    themeEmoji: '\uD83C\uDF44',
    description: 'Fill the toadstool with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _mushroomMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[12]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 14,
    name: 'Cloud',
    themeEmoji: '\u2601\uFE0F',
    description: 'Fill the rainy cloud with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _cloudMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[13]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 15,
    name: 'Crown',
    themeEmoji: '\uD83D\uDC51',
    description: 'Fill the royal crown with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _crownMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[14]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 16,
    name: 'Rocket',
    themeEmoji: '\uD83D\uDE80',
    description: 'Fill the rocket to the stars with arrows',
    gridCols: 16,
    gridRows: 24,
    mask: _rocketMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[15]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 17,
    name: 'Ghost',
    themeEmoji: '\uD83D\uDC7B',
    description: 'Fill the friendly ghost with arrows',
    gridCols: 16,
    gridRows: 24,
    mask: _ghostMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[16]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 18,
    name: 'Snowman',
    themeEmoji: '\u26C4',
    description: 'Fill the snowman with arrows',
    gridCols: 16,
    gridRows: 24,
    mask: _snowmanMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[17]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 19,
    name: 'Battery',
    themeEmoji: '\uD83D\uDD0B',
    description: 'Fill the charged battery with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _batteryMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[18]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 20,
    name: 'Key',
    themeEmoji: '\uD83D\uDD11',
    description: 'Fill the ornate key with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _keyMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[19]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 21,
    name: 'Cat',
    themeEmoji: '\uD83D\uDC31',
    description: 'Fill the sitting cat with arrows',
    gridCols: 18,
    gridRows: 24,
    mask: _catMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[20]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 22,
    name: 'Paw',
    themeEmoji: '\uD83D\uDC3E',
    description: 'Fill the paw prints with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _pawMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[21]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 23,
    name: 'Bell',
    themeEmoji: '\uD83D\uDD14',
    description: 'Fill the ringing bell with arrows',
    gridCols: 16,
    gridRows: 24,
    mask: _bellMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[22]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 24,
    name: 'Car',
    themeEmoji: '\uD83D\uDE97',
    description: 'Fill the sports car with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _carMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[23]),
    config: LevelConfig.extreme,
  ),
  SilhouetteLevel(
    id: 25,
    name: 'Rangoli',
    themeEmoji: '\uD83C\uDF38',
    description: 'Fill the festive rangoli mandala with arrows',
    gridCols: 26,
    gridRows: 26,
    mask: _rangoliMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[24]),
    config: LevelConfig.mega,
  ),
  SilhouetteLevel(
    id: 26,
    name: 'Chakra',
    themeEmoji: '\u2638\uFE0F',
    description: 'Fill the Dharma chakra with arrows',
    gridCols: 26,
    gridRows: 26,
    mask: _chakraMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[25]),
    config: LevelConfig.mega,
  ),
  SilhouetteLevel(
    id: 27,
    name: 'Taj Mahal',
    themeEmoji: '\uD83D\uDDC4\uFE0F',
    description: 'Fill the Taj Mahal with arrows',
    gridCols: 23,
    gridRows: 24,
    mask: _tajMahalMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[26]),
    config: LevelConfig.mega,
  ),
  SilhouetteLevel(
    id: 28,
    name: 'Lotus Flower',
    themeEmoji: '\uD83C\uDF3B',
    description: 'Fill the lotus in the pond with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _lotusMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[27]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 29,
    name: 'Diya',
    themeEmoji: '\uD83C\uDF87',
    description: 'Fill the glowing diya lamp with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _diyaMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[28]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 30,
    name: 'Lion',
    themeEmoji: '\uD83E\uDD81',
    description: 'Fill the lion\u2019s mane with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _lionMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[29]),
    config: LevelConfig.mega,
  ),
  SilhouetteLevel(
    id: 31,
    name: 'Trishul',
    themeEmoji: '\uD83D\uDEE1\uFE0F',
    description: 'Fill the trident of power with arrows',
    gridCols: 13,
    gridRows: 24,
    mask: _trishulMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[30]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 32,
    name: 'Hot Air Balloon',
    themeEmoji: '\uD83C\uDF88',
    description: 'Fill the hot air balloon with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _balloonMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[31]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 33,
    name: 'Snail',
    themeEmoji: '\uD83D\uDC0C',
    description: 'Fill the spiral snail shell with arrows',
    gridCols: 18,
    gridRows: 24,
    mask: _snailMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[32]),
    config: LevelConfig.mega,
  ),
  SilhouetteLevel(
    id: 34,
    name: 'Om',
    themeEmoji: '\u0950',
    description: 'Fill the Om symbol with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _omMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[33]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 35,
    name: 'Castle',
    themeEmoji: '\uD83C\uDFF0',
    description: 'Fill the lofty castle with arrows',
    gridCols: 23,
    gridRows: 24,
    mask: _castleMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[34]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 36,
    name: 'Penguin',
    themeEmoji: '\uD83D\uDC27',
    description: 'Fill the waddling penguin with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _penguinMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[35]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 37,
    name: 'Owl',
    themeEmoji: '\uD83E\uDD89',
    description: 'Fill the wise owl with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _owlMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[36]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 38,
    name: 'Elephant',
    themeEmoji: '\uD83D\uDC18',
    description: 'Fill the elephant with arrows',
    gridCols: 21,
    gridRows: 24,
    mask: _elephantMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[37]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 39,
    name: 'Cactus',
    themeEmoji: '\uD83C\uDF35',
    description: 'Fill the desert cactus with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _cactusMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[38]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 40,
    name: 'Umbrella',
    themeEmoji: '\u2614',
    description: 'Fill the rainswept umbrella with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _umbrellaMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[39]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 41,
    name: 'Ice Cream',
    themeEmoji: '\uD83C\uDF68',
    description: 'Fill the ice cream sundae with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _iceCreamMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[40]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 42,
    name: 'Anchor',
    themeEmoji: '\u2693',
    description: 'Fill the ship anchor with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _anchorMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[41]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 43,
    name: 'Hourglass',
    themeEmoji: '\u23F3',
    description: 'Fill the runaway hourglass with arrows',
    gridCols: 13,
    gridRows: 24,
    mask: _hourglassMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[42]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 44,
    name: 'Guitar',
    themeEmoji: '\uD83C\uDFB8',
    description: 'Fill the acoustic guitar with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _guitarMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[43]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 45,
    name: 'Sailboat',
    themeEmoji: '\u26F5',
    description: 'Fill the sailboat riding the waves with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _sailboatMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[44]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 46,
    name: 'Ladybug',
    themeEmoji: '\uD83D\uDC1E',
    description: 'Fill the ladybug on its leaf with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _ladybugMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[45]),
    config: LevelConfig.easy,
  ),
  SilhouetteLevel(
    id: 47,
    name: 'Envelope',
    themeEmoji: '\u2709\uFE0F',
    description: 'Fill the sealed envelope with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _envelopeMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[46]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 48,
    name: 'Lock',
    themeEmoji: '\uD83D\uDD12',
    description: 'Fill the padlock with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _lockMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[47]),
    config: LevelConfig.hard,
  ),
  SilhouetteLevel(
    id: 49,
    name: 'Music Note',
    themeEmoji: '\uD83C\uDFB5',
    description: 'Fill the music note with arrows',
    gridCols: 15,
    gridRows: 24,
    mask: _musicNoteMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[48]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 50,
    name: 'Cherry',
    themeEmoji: '\uD83C\uDF52',
    description: 'Fill the cherries with arrows',
    gridCols: 17,
    gridRows: 24,
    mask: _cherryMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[49]),
    config: LevelConfig.medium,
  ),
  SilhouetteLevel(
    id: 51,
    name: 'Pizza',
    themeEmoji: '\uD83C\uDF55',
    description: 'Fill the pizza slice with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _pizzaMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[50]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 52,
    name: 'Trophy',
    themeEmoji: '\uD83C\uDFC6',
    description: 'Fill the champion trophy with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _trophyMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[51]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 53,
    name: 'Pear',
    themeEmoji: '\uD83C\uDF50',
    description: 'Fill the ripe pear with arrows',
    gridCols: 19,
    gridRows: 24,
    mask: _pearMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[52]),
    config: LevelConfig.large,
  ),
  SilhouetteLevel(
    id: 54,
    name: 'Whale',
    themeEmoji: '\uD83D\uDC0B',
    description: 'Fill the giant whale with arrows',
    gridCols: 21,
    gridRows: 24,
    mask: _whaleMask(),
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[53]),
    config: LevelConfig.mega,
  ),
];

// ---------------------------------------------------------------------------
// Level progression.
//
// The hand-drawn silhouettes above are authored at a fixed, modest size. To make
// the campaign actually ramp up - bigger pictures, more arrows and tighter
// packing as the player advances - every level is scaled to a per-level cell
// budget and given a progressively tougher generator profile. Early levels stay
// compact and gentle; late levels grow into large boards that spill past the
// screen and must be panned / zoomed to solve.
// ---------------------------------------------------------------------------

int _countMaskCells(List<List<bool>> mask) {
  var count = 0;
  for (final row in mask) {
    for (final cell in row) {
      if (cell) count++;
    }
  }
  return count;
}

/// Number of steps in the original campaign ramp. Difficulty is scaled against
/// the absolute level index over this fixed span (never against the current
/// catalogue length), so appending new levels at the end leaves every earlier
/// level's board and difficulty byte-for-byte identical.
const double _progressionSpan = 45.0;

/// Upper bound on the ramp so the largest boards stay fillable.
const double _progressionMax = 1.15;

double _progressionT(int i) => math.min(_progressionMax, i / _progressionSpan);

/// Cell budget for level index [i]. Grows smoothly from a small intro board to
/// a jumbo finale so arrow counts climb with the level.
int _targetCellCount(int i) {
  final t = _progressionT(i);
  return (110 + 350 * t).round(); // 110 cells -> up to ~510 cells
}

/// Difficulty profile that scales with the level: more arrows allowed, and
/// arrow strokes get a touch shorter so the same silhouette packs in more
/// pieces (tighter fill), while the star rating tightens. The explicit
/// [targetArrows] climbs smoothly so every level is denser than the one before.
LevelConfig _progressionConfig(int i) {
  final t = _progressionT(i);
  return LevelConfig(
    minArrows: (6 + 32 * t).round(),
    maxArrows: (24 + 80 * t).round(),
    minCells: 3,
    maxCells: (13 - 3 * t).round(),
    maxBends: (4 + 4 * t).round(),
    largeArrowChance: 0.48 - 0.11 * t,
    maxAttempts: (46 + 28 * t).round(),
    moveSlack: (10 - 6 * t).round(),
    targetArrows: (18 + 56 * t).round(),
  );
}

List<SilhouetteLevel> _buildProgression(List<SilhouetteLevel> base) {
  final result = <SilhouetteLevel>[];
  for (var i = 0; i < base.length; i++) {
    final b = base[i];
    final baseCells = _countMaskCells(b.mask);
    final target = _targetCellCount(i);
    final scale =
        math.sqrt(target / math.max(1, baseCells)).clamp(0.55, 2.4).toDouble();
    final outRows = math.max(14, (b.gridRows * scale).round());
    final outCols = math.max(11, (b.gridCols * scale).round());
    final mask = resampleMask(b.mask, outRows, outCols);
    result.add(SilhouetteLevel(
      id: b.id,
      name: b.name,
      themeEmoji: b.themeEmoji,
      description: b.description,
      gridRows: outRows,
      gridCols: outCols,
      mask: mask,
      arrowFactory: () => _generateProgressiveArrows(i),
      config: _progressionConfig(i),
    ));
  }
  return result;
}

final List<SilhouetteLevel> silhouetteLevels = _buildProgression(_baseLevels);
