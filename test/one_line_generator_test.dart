import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_models.dart';

const trailLevels = {
  'MultiBridgeCastle',
  'SnowflakeNetwork',
  'AncientCityWithMultipleBridges',
};

void main() {
  group('OneLineGenerator', () {
    test('generates solvable levels across campaign and endless', () {
      final gen = OneLineGenerator();
      for (int i = 1; i <= 120; i++) {
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

        // Circuits have zero odd vertices; bridge-trail levels have
        // exactly two, which are the only legal start/finish endpoints.
        final degree = <int, int>{};
        for (final e in level.edges) {
          degree[e.a] = (degree[e.a] ?? 0) + 1;
          degree[e.b] = (degree[e.b] ?? 0) + 1;
        }
        for (final id in ids) {
          degree.putIfAbsent(id, () => 0);
        }
        final oddCount = degree.values.where((d) => d.isOdd).length;
        final expectedOdds = trailLevels.contains(level.name) ? 2 : 0;
        expect(oddCount, expectedOdds,
            reason: 'Level $i has $oddCount odd-degree vertices '
                '(expected $expectedOdds for ${level.name})');

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

    test('Anchor branches are directionally distinct', () {
      final level = OneLineGenerator().generateLevel(8);
      final pos = {for (final v in level.vertices) v.id: v.position};

      for (int i = 0; i < level.edges.length; i++) {
        for (int j = i + 1; j < level.edges.length; j++) {
          final a = level.edges[i];
          final b = level.edges[j];
          for (final shared in [a.a, a.b]) {
            if (!b.touches(shared)) continue;
            final va = pos[a.other(shared)]! - pos[shared]!;
            final vb = pos[b.other(shared)]! - pos[shared]!;
            final cross = va.dx * vb.dy - va.dy * vb.dx;
            final dot = va.dx * vb.dx + va.dy * vb.dy;
            expect(cross.abs() > 1e-4 || dot <= 0, isTrue,
                reason: 'Edges ${a.id}/${b.id} overlap at vertex $shared');
          }
        }
      }
    });

    test('later levels keep a hidden canonical solution start', () {
      final gen = OneLineGenerator();
      for (int n = 11; n <= 120; n++) {
        final level = gen.generateLevel(n);
        expect(level.startAnywhere, isFalse,
            reason: 'Level $n should be start-locked');
        expect(
            level.startVertex, inInclusiveRange(0, level.vertices.length - 1),
            reason: 'Level $n startVertex out of range');
        expect(level.solution.first, level.startVertex,
            reason: 'Level $n solution must begin at the locked start');
        if (trailLevels.contains(level.name)) {
          expect(level.solution.last, isNot(level.startVertex),
              reason: 'Level $n trail must finish at the other odd endpoint');
        } else {
          expect(level.solution.last, level.startVertex,
              reason: 'Level $n solution must close back at the locked start');
        }
      }
    });

    test('bridge trails keep two hidden valid endpoints', () {
      final gen = OneLineGenerator();
      for (int n = OneLineGenerator.campaignLevelCount - 2;
          n <= OneLineGenerator.campaignLevelCount;
          n++) {
        final level = gen.generateLevel(n);
        expect(trailLevels.contains(level.name), isTrue,
            reason: 'Level $n should be a bridge trail');
        expect(level.startAnywhere, isFalse);
        expect(level.hideNodeDots, isTrue);

        final degree = <int, int>{for (final v in level.vertices) v.id: 0};
        for (final e in level.edges) {
          degree[e.a] = degree[e.a]! + 1;
          degree[e.b] = degree[e.b]! + 1;
        }
        final odds = {
          for (final entry in degree.entries.where((e) => e.value.isOdd))
            entry.key,
        };
        expect(odds.length, 2);
        final upper = odds.reduce((a, b) =>
            level.vertices[a].position.dy <= level.vertices[b].position.dy
                ? a
                : b);
        final lower = odds.firstWhere((v) => v != upper);
        expect(level.startVertex, upper,
            reason: 'Level $n primary start should be the upper endpoint');
        expect(level.alternateStartVertex, lower,
            reason: 'Level $n should also accept the lower endpoint');
        expect(level.solution.last, lower,
            reason: 'Level $n primary solution should finish at the lower end');
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
        1: 'SimpleChair',
        2: 'SimpleTree',
        3: 'SimpleBoat',
        4: 'SimpleStar',
        5: 'SimpleDiamond',
        6: 'SimpleFish',
        7: 'SimplePentagon',
        8: 'Anchor',
        9: 'SimpleRocket',
        10: 'SimpleKey',
        11: 'SimplePrism',
        12: 'SimpleOwl',
        13: 'SmallHouse',
        14: 'FivePointStar',
        15: 'Sailboat',
        16: 'Umbrella',
        17: 'Fish',
        18: 'DiamondCrystal',
        19: 'Rocket',
        20: 'CoffeeCup',
        21: 'Butterfly',
        22: 'RoyalCrown',
        23: 'CrescentMoon',
        24: 'Apple',
        25: 'Candle',
        26: 'Kite',
        27: 'PaperAirplane',
        28: 'Mushroom',
        29: 'Turtle',
        30: 'Bell',
        31: 'Key',
        32: 'MountainLandscape',
        33: 'Windmill',
        34: 'Owl',
        35: 'Bicycle',
        36: 'Castle',
        37: 'SpiderWeb',
        38: 'Peacock',
        39: 'SailingShip',
        40: 'BranchingTree',
        41: 'InterlockingPentagons',
        42: 'Lighthouse',
        43: 'Elephant',
        44: 'Camera',
        45: 'FerrisWheel',
        46: 'Guitar',
        47: 'HotAirBalloon',
        48: 'Dolphin',
        49: 'ClockTower',
        50: 'TrainEngine',
        51: 'GeometricRose',
        52: 'Compass',
        53: 'TwinSquaresConnectedByBridge',
        54: 'TwinStarsConnectedByBridge',
        55: 'TwinHousesConnectedByBridge',
        56: 'TwoInterlockingRings',
        57: 'DoubleHelix',
        58: 'SuspensionBridge',
        59: 'GeometricDragon',
        60: 'GrandPiano',
        61: 'SpaceSatellite',
        62: 'MultiBridgeCastle',
        63: 'SnowflakeNetwork',
        64: 'AncientCityWithMultipleBridges',
      };

      expect(OneLineGenerator.campaignLevelCount, expected.length);
      expected.forEach((level, name) {
        expect(gen.generateLevel(level).name, name,
            reason: 'Level $level should be the $name figure');
      });
      // No curated level may silently degrade to the fallback polygon.
      for (int i = 1; i <= OneLineGenerator.campaignLevelCount; i++) {
        expect(gen.generateLevel(i).name, isNot('Polygon'),
            reason: 'Level $i fell back to the plain polygon');
      }
      // Every curated figure is a different shape.
      final names = [
        for (int i = 1; i <= OneLineGenerator.campaignLevelCount; i++)
          gen.generateLevel(i).name,
      ];
      expect(names.toSet().length, names.length,
          reason: 'Campaign repeats a figure');
    });

    test('campaign complexity climbs across tiers (difficulty ramp)', () {
      final gen = OneLineGenerator();
      double avg(int lo, int hi) {
        var total = 0;
        for (int i = lo; i <= hi; i++) {
          total += gen.generateLevel(i).edges.length;
        }
        return total / (hi - lo + 1);
      }

      final tiers = [
        avg(1, 10),
        avg(11, 20),
        avg(21, 30),
        avg(31, 40),
        avg(41, 52),
        avg(53, OneLineGenerator.campaignLevelCount),
      ];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], greaterThanOrEqualTo(tiers[i - 1]),
            reason: 'Campaign tier $i should not be easier than tier ${i - 1}');
      }
    });

    test('endless zone ships distinct hand-crafted studio figures', () {
      final gen = OneLineGenerator();
      const studio = [
        'MechanicalSpider',
        'Octopus',
        'PeacockWithDetailedFeathers',
        'ClockworkMachine',
        'TreehouseNetwork',
        'EagleWithSpreadWings',
        'CitySkylineNetwork',
        'ImpossibleKnot',
        'SolarSystem',
        'MechanicalRobot',
        'Phoenix',
        'GalacticConstellation',
        'InterconnectedClockTowers',
        'GiantGearNetwork',
        'TheUltimateKingdom',
      ];
      expect(OneLineGenerator.studioLevelCount, studio.length);
      final first = OneLineGenerator.campaignLevelCount + 1;
      final names = <String>[];
      for (var i = 0; i < studio.length; i++) {
        final level = gen.generateLevel(first + i);
        expect(level.name, studio[i],
            reason: 'Endless level ${first + i} should be ${studio[i]}');
        expect(level.edges.length, greaterThanOrEqualTo(6),
            reason: 'Endless level ${first + i} too sparse');
        expect(level.name, isNot('Polygon'),
            reason: 'Endless level ${first + i} fell back to the polygon');
        names.add(level.name);
      }
      expect(names.toSet().length, names.length,
          reason: 'Endless zone repeats a studio figure');
    });

    test('studio figures never reuse campaign names', () {
      final gen = OneLineGenerator();
      final campaign = {
        for (int i = 1; i <= OneLineGenerator.campaignLevelCount; i++)
          gen.generateLevel(i).name,
      };
      final first = OneLineGenerator.campaignLevelCount + 1;
      for (var i = 0; i < OneLineGenerator.studioLevelCount; i++) {
        expect(campaign.contains(gen.generateLevel(first + i).name), isFalse,
            reason:
                'Studio figure at level ${first + i} reuses a campaign name');
      }
    });
  });
}
