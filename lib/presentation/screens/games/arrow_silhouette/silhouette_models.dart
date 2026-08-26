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

/// Arrow sliding off-screen, straightening as it goes.
/// Cells are projected onto the escape axis; as the arrow advances,
/// the projections linearize (equally spaced) giving a straightening effect.
class FlyOff {
  final ArrowPiece arrow;
  final Offset dir;
  final Offset origin;
  final double cellSize;
  final double total;

  final List<double> _projections;
  final List<Offset> _perps;
  final double _spacing;

  FlyOff._(
    this.arrow,
    this.dir,
    this.origin,
    this.cellSize,
    this.total,
    this._projections,
    this._perps,
    this._spacing,
  );

  factory FlyOff.forArrow(ArrowPiece arrow, Offset origin, double cellSize) {
    final dir = Offset(
      arrow.direction.dx.toDouble(),
      arrow.direction.dy.toDouble(),
    );

    final projections = <double>[];
    final perps = <Offset>[];
    for (final c in arrow.cells) {
      final cx = (c.col + 0.5) * cellSize;
      final cy = (c.row + 0.5) * cellSize;
      final proj = dir.dx * cx + dir.dy * cy;
      final perp = Offset(cx - dir.dx * proj, cy - dir.dy * proj);
      projections.add(proj);
      perps.add(perp);
    }

    double totalPathLen = 0;
    for (int i = 1; i < arrow.cells.length; i++) {
      final dx = (arrow.cells[i].col - arrow.cells[i - 1].col).toDouble();
      final dy = (arrow.cells[i].row - arrow.cells[i - 1].row).toDouble();
      totalPathLen += sqrt(dx * dx + dy * dy) * cellSize;
    }

    final spacing = arrow.cells.length > 1
        ? totalPathLen / (arrow.cells.length - 1)
        : 0.0;

    return FlyOff._(arrow, dir, origin, cellSize, cellSize * 10,
        projections, perps, spacing);
  }

  List<Offset> shaftPoints(double adv) {
    if (arrow.cells.isEmpty) return [];

    final minProj = _projections.first;

    final rawFactor = (adv / (cellSize * 2)).clamp(0.0, 1.0);
    final linearFactor = rawFactor * rawFactor * (3 - 2 * rawFactor);

    final headPerp = _perps.last;

    return List.generate(arrow.cells.length, (i) {
      final origProj = _projections[i] + adv;
      final linearProj = minProj + i * _spacing + adv;
      final proj = origProj + (linearProj - origProj) * linearFactor;

      final perp = Offset(
        _perps[i].dx + (headPerp.dx - _perps[i].dx) * linearFactor,
        _perps[i].dy + (headPerp.dy - _perps[i].dy) * linearFactor,
      );

      return Offset(
        origin.dx + dir.dx * proj + perp.dx,
        origin.dy + dir.dy * proj + perp.dy,
      );
    });
  }

  bool isTrackVisible(double adv) => adv < total;
}

class LevelResult {
  final int moves;
  final int maxMoves;
  final int stars;
  final Duration elapsed;
  final bool success;

  LevelResult({
    required this.moves,
    required this.maxMoves,
    required this.stars,
    required this.elapsed,
    required this.success,
  });
}
