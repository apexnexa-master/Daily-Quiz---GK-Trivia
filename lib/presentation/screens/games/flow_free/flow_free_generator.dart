import 'dart:math';
import 'package:flutter/material.dart';
import 'flow_free_models.dart';

class FlowPuzzleGenerator {
  FlowPuzzleGenerator();

  FlowLevel generateLevel(int number) {
    final config = _difficultyForLevel(number);
    final grid = _generateGrid(config.rows, config.cols, config.numColors, number);
    return _buildLevel(grid, number);
  }

  _DifficultyConfig _difficultyForLevel(int level) {
    if (level <= 3) return const _DifficultyConfig(5, 5, 4, 'easy');
    if (level <= 7) return const _DifficultyConfig(5, 5, 5, 'easy');
    if (level <= 12) return const _DifficultyConfig(5, 5, 5, 'medium');
    if (level <= 18) return const _DifficultyConfig(6, 6, 5, 'medium');
    if (level <= 25) return const _DifficultyConfig(6, 6, 6, 'hard');
    if (level <= 35) return const _DifficultyConfig(7, 7, 6, 'hard');
    if (level <= 50) return const _DifficultyConfig(7, 7, 7, 'hard');
    return const _DifficultyConfig(8, 8, 7, 'expert');
  }

  static const _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  List<List<int>> _generateGrid(int rows, int cols, int numColors, int level) {
    for (int attempt = 0; attempt < 120; attempt++) {
      final seedRng = Random(level * 31 + attempt * 7919);
      final grid = List.generate(rows, (_) => List.filled(cols, -1));

      final targets = _colorTargets(rows, cols, numColors);
      final colorOrder = List.generate(numColors, (i) => i)..shuffle(seedRng);

      if (_placeAllColors(grid, rows, cols, colorOrder, targets, 0, seedRng)) {
        if (_isValidGrid(grid, rows, cols, numColors)) return grid;
      }
    }

    return List.generate(rows, (_) => List.filled(cols, 0));
  }

  List<int> _colorTargets(int rows, int cols, int numColors) {
    final total = rows * cols;
    final base = total ~/ numColors;
    final rem = total - base * numColors;
    return List.generate(numColors, (i) => base + (i < rem ? 1 : 0));
  }

  bool _placeAllColors(
    List<List<int>> grid, int rows, int cols,
    List<int> colorOrder, List<int> targets, int ci, Random rng,
  ) {
    if (ci == colorOrder.length) {
      return _isFull(grid, rows, cols);
    }

    final color = colorOrder[ci];
    final targetLen = targets[color];

    final empty = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == -1) empty.add((r, c));
      }
    }
    if (empty.length < targetLen) return false;

    final starts = List<(int, int)>.from(empty)..shuffle(rng);
    final maxTries = min(starts.length, 10);

    for (int s = 0; s < maxTries; s++) {
      final (sr, sc) = starts[s];
      final path = <(int, int)>[];
      if (_growPath(grid, sr, sc, rows, cols, targetLen, color, path, rng)) {
        if (_placeAllColors(grid, rows, cols, colorOrder, targets, ci + 1, rng)) {
          return true;
        }
        for (final (r, c) in path) {
          grid[r][c] = -1;
        }
      }
    }
    return false;
  }

  bool _growPath(
    List<List<int>> grid, int sr, int sc,
    int rows, int cols, int targetLen, int color,
    List<(int, int)> path, Random rng,
  ) {
    grid[sr][sc] = color;
    path.add((sr, sc));

    if (path.length == targetLen) return true;

    final (lr, lc) = path.last;
    final neighbors = <(int, int)>[];
    for (final (dr, dc) in _dirs) {
      final nr = lr + dr, nc = lc + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      if (grid[nr][nc] != -1) continue;
      if (_cellDegree(grid, nr, nc, rows, cols, color) >= 2) continue;
      if (_wouldMake2x2(grid, nr, nc, rows, cols, color)) continue;
      neighbors.add((nr, nc));
    }
    neighbors.shuffle(rng);

    for (final (nr, nc) in neighbors) {
      if (_growPath(grid, nr, nc, rows, cols, targetLen, color, path, rng)) {
        return true;
      }
    }

    grid[sr][sc] = -1;
    path.removeLast();
    return false;
  }

  int _cellDegree(List<List<int>> grid, int r, int c, int rows, int cols, int color) {
    int deg = 0;
    for (final (dr, dc) in _dirs) {
      final nr = r + dr, nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      if (grid[nr][nc] == color) deg++;
    }
    return deg;
  }

  bool _wouldMake2x2(List<List<int>> grid, int r, int c, int rows, int cols, int color) {
    for (int dr = 0; dr <= 1; dr++) {
      for (int dc = 0; dc <= 1; dc++) {
        final pr = r - dr, pc = c - dc;
        if (pr < 0 || pr + 1 >= rows || pc < 0 || pc + 1 >= cols) continue;
        int cnt = 0;
        for (int rr = 0; rr <= 1; rr++) {
          for (int cc = 0; cc <= 1; cc++) {
            final cr = pr + rr, cc2 = pc + cc;
            final v = (cr == r && cc2 == c) ? color : grid[cr][cc2];
            if (v == color) cnt++;
          }
        }
        if (cnt == 4) return true;
      }
    }
    return false;
  }

  bool _isFull(List<List<int>> grid, int rows, int cols) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == -1) return false;
      }
    }
    return true;
  }

  bool _isValidGrid(List<List<int>> grid, int rows, int cols, int numColors) {
    if (_hasTwoByTwo(grid, rows, cols)) return false;
    for (int color = 0; color < numColors; color++) {
      if (!_isColorValid(grid, rows, cols, color)) return false;
    }
    return true;
  }

  bool _isColorValid(List<List<int>> grid, int rows, int cols, int color) {
    int endpoints = 0;
    int cells = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != color) continue;
        cells++;
        int same = 0;
        for (final (dr, dc) in _dirs) {
          final nr = r + dr, nc = c + dc;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] == color) {
            same++;
          }
        }
        if (same == 0) return false;
        if (same > 2) return false;
        if (same == 1) endpoints++;
      }
    }
    if (cells < 2) return false;
    if (endpoints != 2) return false;
    return true;
  }

  bool _hasTwoByTwo(List<List<int>> grid, int rows, int cols) {
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cols - 1; c++) {
        final v = grid[r][c];
        if (v >= 0 && v == grid[r][c + 1] && v == grid[r + 1][c] && v == grid[r + 1][c + 1]) {
          return true;
        }
      }
    }
    return false;
  }

  FlowLevel _buildLevel(List<List<int>> grid, int number) {
    final rows = grid.length;
    final cols = grid[0].length;
    int numColors = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] >= numColors) numColors = grid[r][c] + 1;
      }
    }
    final colors = _paletteColors(numColors);
    final pairs = <FlowPair>[];
    for (int color = 0; color < numColors; color++) {
      final endpoints = <FlowCell>[];
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (grid[r][c] != color) continue;
          int same = 0;
          for (final (dr, dc) in _dirs) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] == color) {
              same++;
            }
          }
          if (same == 1) endpoints.add(FlowCell(r, c));
        }
      }
      if (endpoints.length >= 2) {
        pairs.add(FlowPair(
          id: color, color: colors[color],
          start: endpoints[0], end: endpoints[1],
        ));
      }
    }
    final difficulty = numColors <= 4 ? 'easy' : numColors <= 5 ? 'medium' : 'hard';
    return FlowLevel(
      number: number, rows: rows, cols: cols,
      pairs: pairs, solution: grid, difficulty: difficulty,
    );
  }

  List<Color> _paletteColors(int count) {
    const palette = [
      Color(0xFF00E5FF), Color(0xFFFF6D00), Color(0xFF76FF03),
      Color(0xFFFFEB3B), Color(0xFFE040FB), Color(0xFFFF9100),
      Color(0xFF00BFA5), Color(0xFF7C4DFF),
    ];
    return palette.sublist(0, count.clamp(0, palette.length));
  }
}

class _DifficultyConfig {
  final int rows, cols, numColors;
  final String difficulty;
  const _DifficultyConfig(this.rows, this.cols, this.numColors, this.difficulty);
}
