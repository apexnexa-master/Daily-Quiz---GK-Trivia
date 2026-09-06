import 'dart:math';

import 'package:flutter/animation.dart';

enum ArrowDirection { up, down, left, right }

extension ArrowDirectionExt on ArrowDirection {
  int get dx {
    switch (this) {
      case ArrowDirection.left:
        return -1;
      case ArrowDirection.right:
        return 1;
      case ArrowDirection.up:
      case ArrowDirection.down:
        return 0;
    }
  }

  int get dy {
    switch (this) {
      case ArrowDirection.up:
        return -1;
      case ArrowDirection.down:
        return 1;
      case ArrowDirection.left:
      case ArrowDirection.right:
        return 0;
    }
  }

  ArrowDirection get opposite {
    switch (this) {
      case ArrowDirection.up:
        return ArrowDirection.down;
      case ArrowDirection.down:
        return ArrowDirection.up;
      case ArrowDirection.left:
        return ArrowDirection.right;
      case ArrowDirection.right:
        return ArrowDirection.left;
    }
  }
}

enum ArrowStatus { active, escaping, escaped }

class GridCell {
  final int row;
  final int col;

  const GridCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCell && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class ArrowPiece {
  final String id;
  final List<GridCell> cells;
  final ArrowDirection direction;
  final int colorIndex;
  ArrowStatus status;
  bool highlighted;
  bool showHint;

  ArrowPiece({
    required this.id,
    required this.cells,
    required this.direction,
    required this.colorIndex,
    this.status = ArrowStatus.active,
    this.highlighted = false,
    this.showHint = false,
  });

  GridCell get headCell => cells.last;

  GridCell get tailCell => cells.first;

  bool get isEscapeable => status == ArrowStatus.active;
}

/// Arrow gliding off like a train on its own track, keeping its shape as it
/// travels. The head leaves through its clear escape lane while every body cell
/// follows the arrow's own winding path behind it, so nothing straightens first
/// and bends ride through the bends just the way a snake follows the rails.
/// Cells are spaced by constant chords along the rail, so the arrow never
/// shrinks or stretches while its bend travels over the smoothed track.
class FlyOff {
  final ArrowPiece arrow;
  final Offset dir;
  final double cellSize;
  final double total;

  /// Resting cell-centre world positions (the arrow's frozen shape).
  final List<Offset> _base;

  /// World-space rail: the arrow's resting cell centres, then a straight
  /// continuation of the head's escape direction for the whole slide length.
  final List<Offset> _rail;

  /// Cumulative arc length at each [rail] point (starts at 0).
  final List<double> _arc;

  /// Arc position of each cell's resting centre on the rail.
  final List<double> _rest;

  /// Resting straight-line distance between consecutive cells.
  final List<double> _chords;

  FlyOff._(this.arrow, this.dir, this.cellSize, this.total, this._base,
      this._rail, this._arc, this._rest, this._chords);

  factory FlyOff.forArrow(ArrowPiece arrow, Offset origin, double cellSize,
      {required int gridRows, required int gridCols}) {
    final dir = Offset(
      arrow.direction.dx.toDouble(),
      arrow.direction.dy.toDouble(),
    );

    final base = <Offset>[
      for (final c in arrow.cells)
        origin +
            Offset(
              (c.col + 0.5) * cellSize,
              (c.row + 0.5) * cellSize,
            ),
    ];

    var pathLen = 0.0;
    for (var i = 1; i < base.length; i++) {
      pathLen += (base[i] - base[i - 1]).distance;
    }

    final headCell = arrow.cells.last;
    final hx = headCell.col + 0.5;
    final hy = headCell.row + 0.5;
    final exitCells = switch (arrow.direction) {
      ArrowDirection.right => (gridCols - hx),
      ArrowDirection.left => hx,
      ArrowDirection.down => (gridRows - hy),
      ArrowDirection.up => hy,
    };

    // The arrow rides the whole way out: total slide distance is what the tail
    // needs to fully clear the board (path length + escape lane to the rim +
    // one cell of margin), so it never disappears while still inside.
    final total = cellSize * max(6.0, pathLen / cellSize + exitCells + 1.0);

    final head = base.last;
    final extCount = (total / cellSize).ceil();
    final ctl = <Offset>[
      ...base,
      for (var k = 1; k <= extCount; k++) head + dir * (cellSize * k),
    ];

    // Round the 90-degree corners of the cell lattice with a clamped
    // Catmull-Rom spine and sample it densely. The cells ride this smoothed
    // rail, so the arrow glides gently around bends instead of wriggling as
    // sharp lattice corners pass through it.
    final rail = _smoothRail(ctl, cellSize);
    final arc = <double>[0.0];
    for (var i = 1; i < rail.length; i++) {
      arc.add(arc[i - 1] + (rail[i] - rail[i - 1]).distance);
    }

    final rest = <double>[];
    for (final p in base) {
      rest.add(_nearestArc(p, rail, arc));
    }
    final chords = <double>[];
    for (var i = 0; i < base.length - 1; i++) {
      chords.add((base[i + 1] - base[i]).distance);
    }

    return FlyOff._(arrow, dir, cellSize, total, base, rail, arc, rest, chords);
  }

  /// Clamped Catmull-Rom spine through [ctl], sampled at a few points per cell
  /// of arc length so arc-length motion along it is smooth. Collinear runs
  /// (like the straight escape lane) stay straight; corners become rounded
  /// fillets.
  static List<Offset> _smoothRail(List<Offset> ctl, double cellSize) {
    final out = <Offset>[ctl.first];
    for (var i = 0; i < ctl.length - 1; i++) {
      final p0 = ctl[i == 0 ? 0 : i - 1];
      final p1 = ctl[i];
      final p2 = ctl[i + 1];
      final p3 = ctl[(i + 2 >= ctl.length) ? ctl.length - 1 : i + 2];
      final spanLen = (p2 - p1).distance;
      final count = spanLen <= 0
          ? 1
          : max(3, ((spanLen / (cellSize * 0.5)) + 0.9999).ceil());
      for (var j = 1; j <= count; j++) {
        final t = j / count;
        final t2 = t * t;
        final t3 = t2 * t;
        out.add(Offset(
          0.5 *
              (2 * p1.dx +
                  (-p0.dx + p2.dx) * t +
                  (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                  (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
          0.5 *
              (2 * p1.dy +
                  (-p0.dy + p2.dy) * t +
                  (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                  (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
        ));
      }
    }
    return out;
  }

  /// Arc position on [rail] closest to [p] (binary search over the arc array).
  static double _nearestArc(Offset p, List<Offset> rail, List<double> arc) {
    var lo = 0, hi = rail.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if ((rail[mid] - p).distance < (rail[mid + 1] - p).distance) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return arc[lo];
  }

  Offset _pointAt(double t) {
    if (t <= 0) return _rail.first;
    for (var i = 1; i < _rail.length; i++) {
      if (t <= _arc[i]) {
        final seg = _arc[i] - _arc[i - 1];
        final f = seg <= 0 ? 0.0 : (t - _arc[i - 1]) / seg;
        return _rail[i - 1] + (_rail[i] - _rail[i - 1]) * f;
      }
    }
    return _rail.last;
  }

  int _arcIndex(double t) {
    var lo = 0, hi = _arc.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_arc[mid] <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Cell [i] rides [adv] further along the rail than its resting position, so
  /// the whole arrow advances along its own curved track without straightening.
  /// Each cell is placed at a constant straight-line distance from the cell in
  /// front of it (its resting chord), so the arrow keeps its exact resting size
  /// even while its bends travel over the corners of the smoothed track.
  List<Offset> shaftPoints(double adv) {
    if (adv <= 0) return _base;
    final n = arrow.cells.length;
    if (n == 1) return [_pointAt(_rest[0] + adv)];

    final out = List<Offset>.filled(n, Offset.zero);
    out[n - 1] = _pointAt(_rest[n - 1] + adv);
    var tPrev = _rest[n - 1] + adv;
    for (var i = n - 2; i >= 0; i--) {
      final target = _chords[i];
      var trav = 0.0;
      var j = _arcIndex(tPrev);
      var p = out[i + 1];
      while (true) {
        if (j <= 0) {
          out[i] = p;
          tPrev = _arc[0];
          break;
        }
        final q = _rail[j - 1];
        final step = (p - q).distance;
        if (trav + step >= target) {
          final f = step > 0 ? (target - trav) / step : 0.0;
          out[i] = q + (p - q) * f;
          tPrev = _arc[j - 1] + f * (_arc[j] - _arc[j - 1]);
          break;
        }
        trav += step;
        p = q;
        j -= 1;
      }
    }
    return out;
  }

  bool isTrackVisible(double adv) => adv < total;
}

class LevelResult {
  final int moves;
  final int maxMoves;
  final int idealMoves;
  final int stars;
  final Duration elapsed;
  final bool success;

  LevelResult({
    required this.moves,
    required this.maxMoves,
    required this.idealMoves,
    required this.stars,
    required this.elapsed,
    required this.success,
  });
}
