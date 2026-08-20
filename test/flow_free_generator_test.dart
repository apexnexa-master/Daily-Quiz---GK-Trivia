import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/flow_free/flow_free_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/flow_free/flow_free_models.dart';

void main() {
  group('FlowPuzzleGenerator', () {
    test('generates valid grids for levels 1-25', () {
      final gen = FlowPuzzleGenerator();
      const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

      for (int i = 1; i <= 25; i++) {
        final level = gen.generateLevel(i);
        final grid = level.solution;
        final rows = level.rows;
        final cols = level.cols;
        bool ok = true;

        // Check all cells valid color
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (grid[r][c] < 0 || grid[r][c] >= level.pairs.length) {
              ok = false;
            }
          }
        }

        // Check no 2x2 blocks
        for (int r = 0; r < rows - 1; r++) {
          for (int c = 0; c < cols - 1; c++) {
            int v = grid[r][c];
            if (v == grid[r][c + 1] && v == grid[r + 1][c] && v == grid[r + 1][c + 1]) {
              ok = false;
            }
          }
        }

        // Check each color forms a valid path
        for (int color = 0; color < level.pairs.length; color++) {
          int endpoints = 0;
          int cellCount = 0;
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              if (grid[r][c] != color) continue;
              cellCount++;
              int same = 0;
              for (final d in dirs) {
                int nr = r + d[0], nc = c + d[1];
                if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] == color) same++;
              }
              if (same == 0 || same > 2) ok = false;
              if (same == 1) endpoints++;
            }
          }
          if (endpoints != 2) ok = false;
          if (cellCount < 2) ok = false;
        }

        expect(ok, true, reason: 'Level $i (${rows}x${cols}, ${level.pairs.length} colors) should be valid');
      }
    });
  });
}
