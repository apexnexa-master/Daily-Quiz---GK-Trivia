import 'grid_matrix.dart';

class SolverCache {
  int _computeHash(LogicalGrid grid) {
    final parts = <String>[];
    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occ = grid.matrix[x][y][l];
          if (occ != null && occ.state == ArrowState.active) {
            parts.add('${occ.id}@$x,$y,$l');
          }
        }
      }
    }
    parts.sort();
    return Object.hashAll(parts);
  }

  final Map<int, List<String>?> _solutionCache = {};
  final Map<int, List<ArrowEntity>> _validMovesCache = {};
  int _currentLevelId = -1;

  void clear() {
    _solutionCache.clear();
    _validMovesCache.clear();
    _currentLevelId = -1;
  }

  void onLevelLoad(int levelId) {
    if (levelId != _currentLevelId) {
      clear();
      _currentLevelId = levelId;
    }
  }

  List<String>? getCachedSolution(LogicalGrid grid) {
    final h = _computeHash(grid);
    return _solutionCache[h];
  }

  void setCachedSolution(LogicalGrid grid, List<String>? solution) {
    final h = _computeHash(grid);
    _solutionCache[h] = solution;
  }

  List<ArrowEntity>? getCachedValidMoves(LogicalGrid grid) {
    final h = _computeHash(grid);
    return _validMovesCache[h];
  }

  void setCachedValidMoves(LogicalGrid grid, List<ArrowEntity> moves) {
    final h = _computeHash(grid);
    _validMovesCache[h] = moves;
  }

  int get validMovesCacheSize => _validMovesCache.length;
  int get solutionCacheSize => _solutionCache.length;
}
