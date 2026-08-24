import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';

double _pointSegDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.distanceSquared;
  final t = len2 == 0
      ? 0.0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (a + ab * t - p).distance;
}

({bool crossing, double distance}) _segmentRelation(
    Offset a1, Offset a2, Offset b1, Offset b2) {
  final d1 = a2 - a1;
  final d2 = b2 - b1;
  final denom = d1.dx * d2.dy - d1.dy * d2.dx;
  if (denom.abs() > 1e-9) {
    final wx = b1.dx - a1.dx;
    final wy = b1.dy - a1.dy;
    final t = (wx * d2.dy - wy * d2.dx) / denom;
    final u = (wx * d1.dy - wy * d1.dx) / denom;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return (crossing: true, distance: 0.0);
    }
  }
  var best = _pointSegDist(a1, b1, b2);
  best = math.min(best, _pointSegDist(a2, b1, b2));
  best = math.min(best, _pointSegDist(b1, a1, a2));
  best = math.min(best, _pointSegDist(b2, a1, a2));
  return (crossing: false, distance: best);
}

void main() {
  final g = OneLineGenerator();

  test('every level is drawable: long strokes and generous line gaps',
      () {
    for (int n = 1; n <= 60; n++) {
      final lv = g.generateLevel(n);

      // No stroke shorter than the drag-friendly minimum.
      for (final e in lv.edges) {
        final len =
            (lv.vertices[e.b].position - lv.vertices[e.a].position)
                .distance;
        expect(
            len,
            greaterThanOrEqualTo(
                OneLineGenerator.minSpanFor(n) - 1e-6),
            reason: 'L$n ${lv.name} edge ${e.a}-${e.b} too short: $len');
      }

      // Non-adjacent segments stay far apart; crossings are steep.
      for (int i = 0; i < lv.edges.length; i++) {
        for (int j = i + 1; j < lv.edges.length; j++) {
          final e = lv.edges[i];
          final f = lv.edges[j];
          final adjacent = e.a == f.a || e.a == f.b || e.b == f.a ||
              e.b == f.b;
          if (adjacent) continue;
          final rel = _segmentRelation(
            lv.vertices[e.a].position,
            lv.vertices[e.b].position,
            lv.vertices[f.a].position,
            lv.vertices[f.b].position,
          );
          if (rel.crossing) {
            var acute = ((lv.vertices[e.b].position -
                        lv.vertices[e.a].position)
                    .direction -
                (lv.vertices[f.b].position - lv.vertices[f.a].position)
                    .direction);
            acute = acute.abs() % math.pi;
            if (acute > math.pi / 2) acute = math.pi - acute;
            expect(acute * 180 / math.pi,
                greaterThanOrEqualTo(OneLineGenerator.minCrossingAngleDeg),
                reason:
                    'L$n ${lv.name} shallow crossing edges ${e.a}-${e.b} '
                    'and ${f.a}-${f.b}');
          } else {
            expect(
                rel.distance,
                greaterThanOrEqualTo(
                    OneLineGenerator.minGapFor(n) - 1e-6),
                reason:
                    'L$n ${lv.name} edges ${e.a}-${e.b} and ${f.a}-${f.b} '
                    'too close: ${rel.distance}');
          }
        }
      }
    }
  });
}
