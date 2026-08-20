import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/flow_free/flow_free_generator.dart';

void main() {
  test('All levels valid and unique', () {
    final grids = <String>[];
    final sw = Stopwatch()..start();
    for (int i = 1; i <= 50; i++) {
      final gen = FlowPuzzleGenerator();
      final level = gen.generateLevel(i);
      final flat = level.solution.expand((r) => r).join(',');
      grids.add(flat);
      final cells = level.pairs.length;
      final fallback = cells == 0 ? ' FAIL' : '';
      print('L${i.toString().padLeft(2)}: ${level.rows}x${level.cols} ${cells}c$fallback');
    }
    sw.stop();

    final unique = grids.toSet().length;
    print('');
    print('Unique: $unique / ${grids.length}');
    print('Total time: ${sw.elapsedMilliseconds}ms');
    expect(unique, equals(grids.length), reason: 'All levels must be unique');
    for (int i = 0; i < grids.length; i++) {
      expect(grids[i], isNot(startsWith('0,0,0,0,0,0')), reason: 'Level ${i+1} is fallback');
    }
  });
}
