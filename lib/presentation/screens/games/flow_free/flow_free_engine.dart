import 'flow_free_models.dart';

class _GridSnapshot {
  final List<List<int>> grid;
  final Map<int, List<FlowCell>> paths;

  _GridSnapshot(this.grid, this.paths);

  _GridSnapshot copy() {
    final g = grid.map((r) => List<int>.from(r)).toList();
    final p = paths.map((k, v) => MapEntry(k, List<FlowCell>.from(v)));
    return _GridSnapshot(g, p);
  }
}

class FlowGameState {
  final FlowLevel level;
  final List<List<int>> grid;
  final Map<int, List<FlowCell>> paths;
  int? activePairId;
  bool isComplete = false;

  final List<_GridSnapshot> _undoStack = [];

  FlowGameState._({
    required this.level,
    required this.grid,
    required this.paths,
  });

  factory FlowGameState(FlowLevel level) {
    final grid = List.generate(
      level.rows,
      (_) => List.filled(level.cols, -1),
    );
    for (final pair in level.pairs) {
      grid[pair.start.row][pair.start.col] = pair.id;
      grid[pair.end.row][pair.end.col] = pair.id;
    }
    return FlowGameState._(
      level: level,
      grid: grid,
      paths: {},
    );
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void reset() {
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final pair = _getPairAt(r, c);
        grid[r][c] = pair != null ? pair.id : -1;
      }
    }
    paths.clear();
    activePairId = null;
    isComplete = false;
    _undoStack.clear();
  }

  void _saveSnapshot() {
    _undoStack.add(_GridSnapshot(grid, paths).copy());
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    final snap = _undoStack.removeLast();
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        grid[r][c] = snap.grid[r][c];
      }
    }
    paths.clear();
    for (final entry in snap.paths.entries) {
      paths[entry.key] = List<FlowCell>.from(entry.value);
    }
    activePairId = null;
    isComplete = false;
    return true;
  }

  int? _ownerAt(int row, int col) {
    final v = grid[row][col];
    if (v == -1 || v >= level.pairs.length) return null;
    return v;
  }

  void startDrawing(FlowCell cell) {
    final targetPairId = _ownerAt(cell.row, cell.col);
    if (targetPairId == null) return;

    _saveSnapshot();

    final pair = level.pairs[targetPairId];
    final isEndpoint = (cell.row == pair.start.row && cell.col == pair.start.col) ||
        (cell.row == pair.end.row && cell.col == pair.end.col);

    if (isEndpoint) {
      activePairId = targetPairId;
      _clearPath(targetPairId);
      paths[targetPairId] = [cell];
    } else {
      activePairId = targetPairId;
      final existingPath = paths[targetPairId];
      if (existingPath != null) {
        final idx = existingPath.indexOf(cell);
        if (idx >= 0) {
          for (int i = existingPath.length - 1; i > idx; i--) {
            final removed = existingPath.removeAt(i);
            if (!_isEndpoint(removed.row, removed.col)) {
              grid[removed.row][removed.col] = -1;
            }
          }
        }
      }
    }
  }

  void extendPath(FlowCell cell) {
    if (activePairId == null) return;

    final path = paths[activePairId];
    if (path == null || path.isEmpty) return;

    final last = path.last;

    final dr = (cell.row - last.row).abs();
    final dc = (cell.col - last.col).abs();
    if (dr + dc != 1) return;

    if (cell.row == last.row && cell.col == last.col) return;

    final existingIndex = path.indexOf(cell);
    if (existingIndex >= 0) {
      for (int i = path.length - 1; i > existingIndex; i--) {
        final removed = path.removeAt(i);
        if (!_isEndpoint(removed.row, removed.col)) {
          grid[removed.row][removed.col] = -1;
        }
      }
      _checkCompletion();
      return;
    }

    final targetVal = grid[cell.row][cell.col];
    final pair = level.pairs[activePairId!];
    final isOurOtherEndpoint =
        (cell.row == pair.end.row && cell.col == pair.end.col) ||
        (cell.row == pair.start.row && cell.col == pair.start.col);

    if (targetVal != -1 && !isOurOtherEndpoint) {
      return;
    }

    path.add(cell);
    if (!isOurOtherEndpoint) {
      grid[cell.row][cell.col] = activePairId!;
    }

    if (isOurOtherEndpoint) {
      activePairId = null;
    }

    _checkCompletion();
  }

  void finishDrawing() {
    activePairId = null;
  }

  void _clearPath(int pairId) {
    final path = paths[pairId];
    if (path == null) return;

    for (final cell in path) {
      if (!_isEndpoint(cell.row, cell.col)) {
        grid[cell.row][cell.col] = -1;
      }
    }
    paths.remove(pairId);
  }

  void _checkCompletion() {
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (grid[r][c] == -1) return;
      }
    }

    for (final pair in level.pairs) {
      final path = paths[pair.id];
      if (path == null || path.length < 2) return;
      final startsAtEndpoint = (path.first.row == pair.start.row &&
              path.first.col == pair.start.col) ||
          (path.first.row == pair.end.row && path.first.col == pair.end.col);
      final endsAtEndpoint = (path.last.row == pair.start.row &&
              path.last.col == pair.start.col) ||
          (path.last.row == pair.end.row && path.last.col == pair.end.col);
      if (!startsAtEndpoint || !endsAtEndpoint) return;
    }

    isComplete = true;
  }

  FlowPair? _getPairAt(int row, int col) {
    for (final pair in level.pairs) {
      if ((pair.start.row == row && pair.start.col == col) ||
          (pair.end.row == row && pair.end.col == col)) {
        return pair;
      }
    }
    return null;
  }

  bool _isEndpoint(int row, int col) {
    return _getPairAt(row, col) != null;
  }

  int? getPairIdAt(int row, int col) {
    if (row < 0 || row >= level.rows || col < 0 || col >= level.cols) {
      return null;
    }
    final v = grid[row][col];
    if (v == -1 || v >= level.pairs.length) return null;
    return v;
  }

  bool pathConnectsPair(List<FlowCell> path, FlowPair pair) {
    if (path.length < 2) return false;
    final startsAtEndpoint =
        (path.first.row == pair.start.row && path.first.col == pair.start.col) ||
            (path.first.row == pair.end.row && path.first.col == pair.end.col);
    final endsAtEndpoint =
        (path.last.row == pair.start.row && path.last.col == pair.start.col) ||
            (path.last.row == pair.end.row && path.last.col == pair.end.col);
    return startsAtEndpoint && endsAtEndpoint;
  }

  /// True when every pair has a continuous pipe joining its two endpoints,
  /// even while some cells of the grid are still empty.
  bool get allPairsConnected {
    for (final pair in level.pairs) {
      final path = paths[pair.id];
      if (path == null || !pathConnectsPair(path, pair)) return false;
    }
    return true;
  }

  List<FlowCell> get emptyCells {
    final cells = <FlowCell>[];
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (grid[r][c] == -1) cells.add(FlowCell(r, c));
      }
    }
    return cells;
  }

  int get filledCells {
    int count = 0;
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (grid[r][c] != -1) count++;
      }
    }
    return count;
  }

  int get totalCells => level.rows * level.cols;
}
