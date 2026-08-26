import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'silhouette_models.dart';
import 'silhouette_levels.dart';

class SilhouetteEngine {
  final SilhouetteLevel level;
  late List<ArrowPiece> arrows;
  late List<List<bool>> _occupied;
  int moveCount = 0;
  int hintCount = 0;
  final List<_UndoState> _undoStack = [];

  SilhouetteEngine(this.level) {
    arrows = level.generateArrows();
    _initOccupied();
  }

  void _initOccupied() {
    _occupied = List.generate(
      level.gridRows,
      (r) => List.generate(level.gridCols, (c) {
        for (final a in arrows) {
          if (a.status == ArrowStatus.active &&
              a.cells.any((cell) => cell.row == r && cell.col == c)) {
            return true;
          }
        }
        return false;
      }),
    );
  }

  void _refreshOccupied() {
    for (int r = 0; r < level.gridRows; r++) {
      for (int c = 0; c < level.gridCols; c++) {
        _occupied[r][c] = false;
      }
    }
    for (final a in arrows) {
      if (a.status == ArrowStatus.active) {
        for (final cell in a.cells) {
          _occupied[cell.row][cell.col] = true;
        }
      }
    }
  }

  int get activeCount =>
      arrows.where((a) => a.status == ArrowStatus.active).length;

  bool get allEscaped => arrows.every((a) => a.status != ArrowStatus.active);

  bool get canUndo => _undoStack.isNotEmpty && moveCount > 0;

  /// Check if there are any deadlock states.
  bool get isDeadlocked {
    for (final arrow in arrows) {
      if (arrow.isEscapeable && canEscape(arrow)) {
        return false;
      }
    }
    return activeCount > 0;
  }

  bool inBounds(int r, int c) =>
      r >= 0 && r < level.gridRows && c >= 0 && c < level.gridCols;

  /// Check if an arrow can escape in its escape direction.
  /// The escape path goes from the head cell outward in the arrow's direction.
  bool canEscape(ArrowPiece arrow) {
    if (!arrow.isEscapeable) return false;
    final head = arrow.headCell;
    final dir = arrow.direction;
    int r = head.row + dir.dy;
    int c = head.col + dir.dx;
    // Scan outward until we leave the grid
    while (inBounds(r, c)) {
      if (_occupied[r][c]) return false;
      r += dir.dy;
      c += dir.dx;
    }
    return true;
  }

  /// Attempt to escape an arrow. Returns true if successful.
  bool escapeArrow(ArrowPiece arrow) {
    if (!canEscape(arrow)) return false;
    _undoStack.add(_UndoState(
      arrowId: arrow.id,
      previousStatus: arrow.status,
      moveCount: moveCount,
    ));
    arrow.status = ArrowStatus.escaping;
    moveCount++;
    // Mark cells as free
    for (final cell in arrow.cells) {
      _occupied[cell.row][cell.col] = false;
    }
    return true;
  }

  /// Called when escape animation finishes.
  void completeEscape(ArrowPiece arrow) {
    arrow.status = ArrowStatus.escaped;
    _refreshOccupied();
  }

  /// Mark arrow as escaped (for undo/redo).
  void markEscaped(ArrowPiece arrow) {
    arrow.status = ArrowStatus.escaped;
    for (final cell in arrow.cells) {
      _occupied[cell.row][cell.col] = false;
    }
  }

  /// Unescape an arrow (for undo).
  void unescapeArrow(ArrowPiece arrow) {
    arrow.status = ArrowStatus.active;
    for (final cell in arrow.cells) {
      _occupied[cell.row][cell.col] = true;
    }
  }

  bool undo() {
    if (!canUndo) return false;
    final state = _undoStack.removeLast();
    final arrow = arrows.firstWhere((a) => a.id == state.arrowId);
    if (state.previousStatus == ArrowStatus.active) {
      arrow.status = ArrowStatus.active;
      for (final cell in arrow.cells) {
        _occupied[cell.row][cell.col] = true;
      }
    } else {
      arrow.status = state.previousStatus;
      _refreshOccupied();
    }
    moveCount = state.moveCount;
    return true;
  }

  /// Tap test: find which arrow was tapped at a given pixel position.
  ArrowPiece? hitTest(Offset position, Offset origin, double cellSize) {
    // Find which grid cell was tapped
    final col = ((position.dx - origin.dx) / cellSize).floor();
    final row = ((position.dy - origin.dy) / cellSize).floor();
    if (!inBounds(row, col)) return null;
    // Find active arrow at this cell
    for (final arrow in arrows) {
      if (arrow.isEscapeable &&
          arrow.cells.any((c) => c.row == row && c.col == col)) {
        return arrow;
      }
    }
    return null;
  }

  /// Convert grid cell to pixel center.
  Offset cellToPixel(GridCell cell, Offset origin, double cellSize) {
    return Offset(
      origin.dx + (cell.col + 0.5) * cellSize,
      origin.dy + (cell.row + 0.5) * cellSize,
    );
  }

  /// Get the center of an arrow (average of its cells).
  Offset arrowCenter(ArrowPiece arrow, Offset origin, double cellSize) {
    if (arrow.cells.isEmpty) return origin;
    double cx = 0, cy = 0;
    for (final cell in arrow.cells) {
      cx += cell.col + 0.5;
      cy += cell.row + 0.5;
    }
    return Offset(
      origin.dx + (cx / arrow.cells.length) * cellSize,
      origin.dy + (cy / arrow.cells.length) * cellSize,
    );
  }

  /// Highlight an arrow.
  void highlightArrow(ArrowPiece? arrow) {
    for (final a in arrows) {
      a.highlighted = false;
    }
    if (arrow != null) arrow.highlighted = true;
  }

  /// Show hint on a random escapeable arrow.
  ArrowPiece? showHint() {
    final escapeable = arrows
        .where((a) => a.isEscapeable && canEscape(a) && !a.showHint)
        .toList();
    if (escapeable.isEmpty) return null;
    final rng = Random();
    final hint = escapeable[rng.nextInt(escapeable.length)];
    hint.showHint = true;
    hintCount++;
    return hint;
  }

  LevelResult result(Duration elapsed) {
    final success = allEscaped;
    int stars = 0;
    if (success) {
      final ratio = moveCount / level.maxMoves;
      if (ratio <= 1.0) {
        stars = 3;
      } else if (ratio <= 1.3) {
        stars = 2;
      } else {
        stars = 1;
      }
    }
    return LevelResult(
      moves: moveCount,
      maxMoves: level.maxMoves,
      stars: stars,
      elapsed: elapsed,
      success: success,
    );
  }
}

class _UndoState {
  final String arrowId;
  final ArrowStatus previousStatus;
  final int moveCount;

  _UndoState({
    required this.arrowId,
    required this.previousStatus,
    required this.moveCount,
  });
}
