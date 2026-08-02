import 'grid_matrix.dart';
import 'solver_cache.dart';

class GameSolver {
  static const Duration maxComputationTime = Duration(milliseconds: 150);
  static SolverCache? _cache;

  static void bindCache(SolverCache cache) {
    _cache = cache;
  }

  static void clearCache() {
    _cache?.clear();
  }

  static List<ArrowEntity> getValidMoves(LogicalGrid grid) {
    if (_cache != null) {
      final cached = _cache!.getCachedValidMoves(grid);
      if (cached != null) return cached;
    }
    final result = _computeValidMoves(grid);
    if (_cache != null) {
      _cache!.setCachedValidMoves(grid, result);
    }
    return result;
  }

  static bool isCoveredByHigherLayer(LogicalGrid grid, ArrowEntity arrow) {
    for (final cell in arrow.getOccupiedCells()) {
      final cx = cell.x.toInt();
      final cy = cell.y.toInt();
      if (cx >= 0 && cx < grid.columns && cy >= 0 && cy < grid.rows) {
        for (int l = arrow.layerId + 1; l < 3; l++) {
          final occupant = grid.matrix[cx][cy][l];
          if (occupant != null && occupant.state == ArrowState.active) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static List<ArrowEntity> _computeValidMoves(LogicalGrid grid) {
    final escaping = List<ArrowEntity>.from(grid.escapingArrows);
    grid.escapingArrows.clear();

    try {
      final arrows = <ArrowEntity>{};
      for (int x = 0; x < grid.columns; x++) {
        for (int y = 0; y < grid.rows; y++) {
          for (int l = 0; l < 3; l++) {
            final occupant = grid.matrix[x][y][l];
            if (occupant != null && occupant.state == ArrowState.active) {
              arrows.add(occupant);
            }
          }
        }
      }
      return arrows.where((a) {
        if (isCoveredByHigherLayer(grid, a)) return false;
        final mod = grid.arrowModifiers[a.id];
        if (mod != null && !mod.canPlayerTap(a)) return false;
        return grid.checkExitPath(a);
      }).toList();
    } finally {
      grid.escapingArrows.addAll(escaping);
    }
  }

  static bool isBoardClear(LogicalGrid grid) {
    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occupant = grid.matrix[x][y][l];
          if (occupant != null && occupant.state == ArrowState.active) {
            return false;
          }
        }
      }
    }
    return true;
  }

  static bool checkDeadEnd(LogicalGrid grid) {
    if (isBoardClear(grid)) return false;
    return getValidMoves(grid).isEmpty;
  }

  static List<String>? findSolution(LogicalGrid grid) {
    if (_cache != null) {
      final cached = _cache!.getCachedSolution(grid);
      if (cached != null) return cached.isEmpty ? [] : cached;
    }

    if (isBoardClear(grid)) {
      if (_cache != null) _cache!.setCachedSolution(grid, []);
      return [];
    }

    final working = _cloneGrid(grid);
    final result = _solveCascade(working);
    if (_cache != null) _cache!.setCachedSolution(grid, result);
    return result;
  }

  static LogicalGrid _cloneGrid(LogicalGrid original) {
    final clone = LogicalGrid(columns: original.columns, rows: original.rows);
    for (int x = 0; x < original.columns; x++) {
      for (int y = 0; y < original.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occ = original.matrix[x][y][l];
          if (occ != null && occ.state == ArrowState.active) {
            clone.registerArrow(ArrowEntity(
              id: occ.id,
              tailPosition: occ.tailPosition,
              length: occ.length,
              direction: occ.direction,
              layerId: occ.layerId,
              color: occ.color,
              shapeType: occ.shapeType,
            ));
          }
        }
      }
    }
    for (final m in original.tileModifiers.values) {
      clone.addModifier(TileModifier(
        id: m.id,
        type: m.type,
        position: m.position,
        targetPortalId: m.targetPortalId,
        exitDirection: m.exitDirection,
        requiredColor: m.requiredColor,
        hitPoints: m.hitPoints,
      ));
    }
    return clone;
  }

  static List<String>? _solveCascade(LogicalGrid grid) {
    final solution = <String>[];
    final startTime = DateTime.now();
    while (true) {
      if (DateTime.now().difference(startTime) > maxComputationTime) {
        return null;
      }
      if (isBoardClear(grid)) return solution;
      final validMoves = getValidMoves(grid);
      if (validMoves.isEmpty) return null;
      final arrow = validMoves.first;
      grid.clearArrowFromMatrix(arrow);
      arrow.state = ArrowState.escaping;
      solution.add(arrow.id);
    }
  }

  static String? getHint(LogicalGrid grid) {
    final valid = getValidMoves(grid);
    if (valid.isEmpty) return null;
    return valid.first.id;
  }
}
