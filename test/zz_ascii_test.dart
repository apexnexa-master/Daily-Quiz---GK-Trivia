import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';

void main() {
  test('ascii', () {
    final gen = OneLineGenerator();
    final out = StringBuffer();
    for (final n in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 18, 27]) {
      final lv = gen.generateLevel(n);
      final W = 62, H = 31;
      final grid = List.generate(H, (_) => List.filled(W, ' '));
      void put(double x, double y, String c) {
        final cx = (x * (W - 1)).round().clamp(0, W - 1);
        final cy = (y * (H - 1)).round().clamp(0, H - 1);
        grid[cy][cx] = c;
      }

      for (final e in lv.edges) {
        final a = lv.vertices[e.a].position;
        final b = lv.vertices[e.b].position;
        const steps = 80;
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          put(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t, '*');
        }
      }
      for (final v in lv.vertices) {
        put(v.position.dx, v.position.dy, 'o');
      }
      out.writeln('===== L$n ${lv.name} (v=${lv.vertices.length} '
          'e=${lv.edges.length}) =====');
      for (final row in grid) {
        out.writeln(row.join());
      }
    }
    // ignore: avoid_print
    print(out.toString());
  });
}
