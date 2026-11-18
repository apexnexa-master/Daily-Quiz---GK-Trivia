import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_models.dart';

void main() {
  group('OneLineGenerator', () {
    test('generates solvable levels for 1-60', () {
      final gen = OneLineGenerator();
      for (int i = 1; i <= 60; i++) {
        final level = gen.generateLevel(i);
        expect(level.edges, isNotEmpty, reason: 'Level $i should have edges');
        expect(level.vertices.length, greaterThanOrEqualTo(3),
            reason: 'Level $i should have at least 3 vertices');
        expect(level.solution, isNotNull,
            reason: 'Level $i should carry a solution trail');

        // Every edge connects two existing vertices.
        final ids = level.vertices.map((v) => v.id).toSet();
        for (final e in level.edges) {
          expect(ids.contains(e.a), isTrue,
              reason: 'Level $i edge ${e.id} endpoint A missing');
          expect(ids.contains(e.b), isTrue,
              reason: 'Level $i edge ${e.id} endpoint B missing');
          expect(e.a != e.b, isTrue,
              reason: 'Level $i edge ${e.id} is a self-loop');
        }

        // No duplicate edges.
        final keys = level.edges
            .map((e) => e.a < e.b ? '${e.a}-${e.b}' : '${e.b}-${e.a}')
            .toSet();
        expect(keys.length, level.edges.length,
            reason: 'Level $i has duplicate edges');

        // Eulerian CIRCUIT condition: zero odd-degree vertices. This is
        // what lets the player start the stroke anywhere on the outline.
        final degree = <int, int>{};
        for (final e in level.edges) {
          degree[e.a] = (degree[e.a] ?? 0) + 1;
          degree[e.b] = (degree[e.b] ?? 0) + 1;
        }
        for (final id in ids) {
          degree.putIfAbsent(id, () => 0);
        }
        final oddCount = degree.values.where((d) => d.isOdd).length;
        expect(oddCount, 0,
            reason: 'Level $i has $oddCount odd-degree vertices '
                '(circuits must have none)');

        // Connectivity: BFS from any vertex reaches all vertices.
        final adj = <int, List<int>>{};
        for (final e in level.edges) {
          adj.putIfAbsent(e.a, () => []).add(e.b);
          adj.putIfAbsent(e.b, () => []).add(e.a);
        }
        final start = level.vertices.first.id;
        final seen = <int>{start};
        final queue = [start];
        while (queue.isNotEmpty) {
          final cur = queue.removeAt(0);
          for (final next in adj[cur] ?? const <int>[]) {
            if (seen.add(next)) queue.add(next);
          }
        }
        expect(seen.length, level.vertices.length,
            reason: 'Level $i graph is not connected');

        // Positions stay inside the unit square.
        for (final v in level.vertices) {
          expect(v.position.dx, inInclusiveRange(0.0, 1.0),
              reason: 'Level $i vertex ${v.id} x out of bounds');
          expect(v.position.dy, inInclusiveRange(0.0, 1.0),
              reason: 'Level $i vertex ${v.id} y out of bounds');
        }

        // Difficulty metadata present and sane.
        expect(level.parSeconds, greaterThan(0),
            reason: 'Level $i parSeconds must be positive');
      }
    });

    test('is solvable from ANY point on tutorial levels (1-10)', () {
      final gen = OneLineGenerator();
      final rng = Random(42);

      for (int n = 1; n <= 10; n++) {
        final level = gen.generateLevel(n);
        expect(level.startAnywhere, isTrue,
            reason: 'Level $n should allow starting anywhere');
        final idMax = level.vertices.map((v) => v.id).reduce(max);

        // Sample several touch points per level: random edge + t.
        for (int sample = 0; sample < 6; sample++) {
          final edge = level.edges[rng.nextInt(level.edges.length)];
          final t = rng.nextDouble();

          // Simulate the engine's mid-edge split at parameter t.
          final pId = idMax + 1;
          final splitEdges = <OneLineEdge>[
            ...level.edges.where((e) => e.id != edge.id),
            OneLineEdge(id: 1000 + sample * 2, a: edge.a, b: pId),
            OneLineEdge(id: 1001 + sample * 2, a: pId, b: edge.b),
          ];

          final trail = OneLineGenerator.hierholzer(idMax + 2, splitEdges, pId);
          expect(trail, isNotNull,
              reason: 'Level $n unsolvable starting mid-edge '
                  '${edge.id} at t=$t');
          expect(trail!.first, pId,
              reason: 'Trail from split point must begin at it');
          expect(trail.last, pId,
              reason: 'Circuit must close back at the start point');
          expect(trail.length, splitEdges.length + 1);
        }
      }
    });

    test('locked levels (11+) pin the start to one glowing vertex', () {
      final gen = OneLineGenerator();
      for (int n = 11; n <= 60; n++) {
        final level = gen.generateLevel(n);
        expect(level.startAnywhere, isFalse,
            reason: 'Level $n should be start-locked');
        expect(
            level.startVertex, inInclusiveRange(0, level.vertices.length - 1),
            reason: 'Level $n startVertex out of range');
        expect(level.solution.first, level.startVertex,
            reason: 'Level $n solution must begin at the locked start');
        expect(level.solution.last, level.startVertex,
            reason: 'Level $n solution must close back at the locked start');
      }
    });

    test('is deterministic per number', () {
      final gen = OneLineGenerator();
      for (int i = 1; i <= 20; i++) {
        final a = gen.generateLevel(i);
        final b = gen.generateLevel(i);
        expect(a.name, b.name, reason: 'Level $i name differs');
        expect(a.vertices.map((v) => v.id), b.vertices.map((v) => v.id),
            reason: 'Level $i vertex order differs');
        expect(a.edges.map((e) => '${e.a}:${e.b}'),
            b.edges.map((e) => '${e.a}:${e.b}'),
            reason: 'Level $i edge list differs');
        expect(a.solution, b.solution, reason: 'Level $i solution differs');
      }
    });

    test('solution traverses every edge exactly once', () {
      final gen = OneLineGenerator();
      for (int i = 1; i <= 40; i++) {
        final level = gen.generateLevel(i);
        final trail = level.solution;
        expect(trail.length, level.edges.length + 1,
            reason: 'Trail length must be edges+1');

        final edgeKeys = level.edges
            .map((e) => e.a < e.b ? '${e.a}-${e.b}' : '${e.b}-${e.a}')
            .toSet();
        final usedPairs = <String>{};
        bool adjacent(int a, int b) =>
            edgeKeys.contains(a < b ? '$a-$b' : '$b-$a');

        for (int step = 0; step + 1 < trail.length; step++) {
          final from = trail[step];
          final to = trail[step + 1];
          expect(adjacent(from, to), isTrue,
              reason:
                  'Step $step of level $i uses a non-adjacent pair $from->$to');
          usedPairs.add(from < to ? '$from-$to' : '$to-$from');
        }
        expect(usedPairs.length, level.edges.length,
            reason: 'Level $i trail repeats an edge');
      }
    });

    test('difficulty tiers escalate edge counts on average', () {
      final gen = OneLineGenerator();
      double avg(int lo, int hi) {
        var total = 0;
        for (int i = lo; i <= hi; i++) {
          total += gen.generateLevel(i).edges.length;
        }
        return total / (hi - lo + 1);
      }

      final early = avg(2, 6);
      final mid = avg(7, 12);
      final hard = avg(13, 20);
      expect(hard, greaterThanOrEqualTo(mid),
          reason: 'Hard tier should not be easier than medium');
      expect(mid, greaterThanOrEqualTo(early),
          reason: 'Medium tier should not be easier than easy');
    });

    test('campaign ships the hand-crafted figures in order', () {
      final gen = OneLineGenerator();
      const expected = {
        1: 'House',
        2: 'Tree',
        3: 'Boat',
        4: 'Swallow',
        5: 'Crown',
        6: 'Diamond',
        7: 'Fish',
        8: 'Star',
        9: 'Pentagram',
        10: 'Rocket',
        11: 'Bird',
        12: 'Cat',
        13: 'Flower',
        14: 'Pinwheel',
        15: 'Octahedron',
        16: 'Starburst',
        17: 'Lattice',
        18: 'Key',
        19: 'Bloom',
        20: 'Prism',
        21: 'DiamondChain',
        22: 'OctoWeb',
        23: 'Lotus',
        24: 'Enneagram',
        25: 'Weave',
        26: 'Decagram',
        27: 'Heart',
        28: 'Filigree',
        29: 'Mandala',
        30: 'Webbing',
        31: 'Rosette',
      };
      expected.forEach((level, name) {
        expect(gen.generateLevel(level).name, name,
            reason: 'Level $level should be the $name figure');
      });
      // No curated level may silently degrade to the fallback polygon.
      for (int i = 1; i <= 31; i++) {
        expect(gen.generateLevel(i).name, isNot('Polygon'),
            reason: 'Level $i fell back to the plain polygon');
      }
      // Every curated figure is a different shape.
      final names = [
        for (int i = 1; i <= 31; i++) gen.generateLevel(i).name,
      ];
      expect(names.toSet().length, names.length,
          reason: 'Campaign repeats a figure');
    });

    test('campaign edge counts climb level-wise (difficulty ramp)', () {
      final gen = OneLineGenerator();
      var prev = 0;
      for (int i = 1; i <= 31; i++) {
        final e = gen.generateLevel(i).edges.length;
        // Level 4 is a deliberate showcase spike (the swallow figure),
        // so resume the ramp from level 5 onwards.
        if (i == 5) {
          prev = e;
          continue;
        }
        expect(e, greaterThanOrEqualTo(prev),
            reason: 'Level $i ($e edges) should not be easier than '
                'level ${i - 1} ($prev edges)');
        prev = e;
      }
    });

    test('endless zone ships fresh symmetric figures', () {
      final gen = OneLineGenerator();
      const families = {'Mandala', 'Rosette', 'Flower'};
      final names = <String>[];
      for (int i = 32; i <= 60; i++) {
        final level = gen.generateLevel(i);
        expect(level.edges.length, greaterThanOrEqualTo(6),
            reason: 'Level $i too sparse');
        expect(families.contains(level.name), isTrue,
            reason: 'Level $i should be a symmetric figure, got ${level.name}');
        names.add(level.name);
      }
      // Every family shows up across the endless levels...
      expect(names.toSet(), families,
          reason: 'Endless zone should rotate through all figure families');
      // ...and consecutive levels never repeat the exact same layout.
      for (var i = 1; i < names.length; i++) {
        expect(names[i], isNot(names[i - 1]),
            reason: 'Consecutive endless levels should differ');
      }
    });
  });
}
