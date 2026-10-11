import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gk_quiz_app/presentation/screens/games/arrow_silhouette/silhouette_levels.dart';

void main() {
  test('compute() isolate output matches the synchronous path', () async {
    final task = buildProgressionTask(53);
    final sync = generateProgressionTask(task);
    final isolated = await compute(generateProgressionTask, task);

    expect(isolated.counts, sync.counts);
    expect(isolated.targetArrows.length, sync.targetArrows.length);
    expect(isolated.targetArrows, isNotEmpty);
    for (var i = 0; i < isolated.targetArrows.length; i++) {
      expect(
        isolated.targetArrows[i].cells.map((c) => c.row * 100 + c.col).toList(),
        sync.targetArrows[i].cells.map((c) => c.row * 100 + c.col).toList(),
      );
    }
  });
}
