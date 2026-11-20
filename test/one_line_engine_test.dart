import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_engine.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_models.dart';

void main() {
  final gen = OneLineGenerator();

  group('OneLineEngine', () {
    test('final parallel edge completes instead of being read as undo', () {
      const level = OneLineLevel(
        number: 99,
        name: 'parallel pair',
        difficulty: 'test',
        vertices: [
          OneLineVertex(id: 0, position: Offset.zero),
          OneLineVertex(id: 1, position: Offset(1, 1)),
        ],
        edges: [
          OneLineEdge(id: 0, a: 0, b: 1),
          OneLineEdge(id: 1, a: 0, b: 1),
        ],
        solution: [0, 1, 0],
        suggestedStarts: [0],
        parSeconds: 10,
      );
      final engine = OneLineEngine()..reset(level);
      expect(engine.startAt(0), isTrue);
      expect(engine.moveTo(1), 'traced');
      expect(engine.isComplete, isFalse);
      expect(engine.moveTo(0), 'traced');
      expect(engine.isComplete, isTrue);
    });

    test('win uses edge count for open trails and closed loops', () {
      const open = OneLineLevel(
        number: 101,
        name: 'open trail',
        difficulty: 'test',
        vertices: [
          OneLineVertex(id: 0, position: Offset(0, 0)),
          OneLineVertex(id: 1, position: Offset(0.5, 0)),
          OneLineVertex(id: 2, position: Offset(1, 0)),
        ],
        edges: [
          OneLineEdge(id: 0, a: 0, b: 1),
          OneLineEdge(id: 1, a: 1, b: 2),
        ],
        solution: [0, 1, 2],
        suggestedStarts: [0],
        parSeconds: 10,
      );
      final openEngine = OneLineEngine()..reset(open);
      expect(openEngine.startAt(0), isTrue);
      expect(openEngine.moveTo(1), 'traced');
      expect(openEngine.isComplete, isFalse);
      expect(openEngine.moveTo(2), 'traced');
      expect(openEngine.isComplete, isTrue);
      expect(openEngine.head, isNot(openEngine.tail));

      const loop = OneLineLevel(
        number: 102,
        name: 'closed loop',
        difficulty: 'test',
        vertices: [
          OneLineVertex(id: 0, position: Offset(0, 0)),
          OneLineVertex(id: 1, position: Offset(1, 0)),
          OneLineVertex(id: 2, position: Offset(0.5, 1)),
        ],
        edges: [
          OneLineEdge(id: 0, a: 0, b: 1),
          OneLineEdge(id: 1, a: 1, b: 2),
          OneLineEdge(id: 2, a: 2, b: 0),
        ],
        solution: [0, 1, 2, 0],
        suggestedStarts: [0],
        parSeconds: 10,
      );
      final loopEngine = OneLineEngine()..reset(loop);
      expect(loopEngine.startAt(0), isTrue);
      expect(loopEngine.moveTo(1), 'traced');
      expect(loopEngine.moveTo(2), 'traced');
      expect(loopEngine.isComplete, isFalse);
      expect(loopEngine.moveTo(0), 'traced');
      expect(loopEngine.isComplete, isTrue);
      expect(loopEngine.head, loopEngine.tail);
    });

    test('nodes can be revisited through unused edges', () {
      const bowtie = OneLineLevel(
        number: 103,
        name: 'bowtie',
        difficulty: 'test',
        vertices: [
          OneLineVertex(id: 0, position: Offset(0.5, 0.5)),
          OneLineVertex(id: 1, position: Offset(0, 0)),
          OneLineVertex(id: 2, position: Offset(1, 0)),
          OneLineVertex(id: 3, position: Offset(0, 1)),
          OneLineVertex(id: 4, position: Offset(1, 1)),
        ],
        edges: [
          OneLineEdge(id: 0, a: 0, b: 1),
          OneLineEdge(id: 1, a: 1, b: 2),
          OneLineEdge(id: 2, a: 2, b: 0),
          OneLineEdge(id: 3, a: 0, b: 3),
          OneLineEdge(id: 4, a: 3, b: 4),
          OneLineEdge(id: 5, a: 4, b: 0),
        ],
        solution: [0, 1, 2, 0, 3, 4, 0],
        suggestedStarts: [0],
        parSeconds: 10,
      );
      final engine = OneLineEngine()..reset(bowtie);
      expect(engine.startAt(0), isTrue);
      for (final vertex in bowtie.solution.skip(1)) {
        expect(engine.moveTo(vertex), 'traced',
            reason: 'vertex $vertex should use a fresh edge');
      }
      expect(engine.isComplete, isTrue);
      expect(engine.path.where((id) => id == 0).length, 3);
    });

    test('bridge trails complete from either odd endpoint', () {
      for (var n = OneLineGenerator.campaignLevelCount - 2;
          n <= OneLineGenerator.campaignLevelCount;
          n++) {
        final level = gen.generateLevel(n);
        expect(level.alternateStartVertex, isNotNull,
            reason: 'Level $n should expose a second legal start');
        final paths = <List<int>>[
          level.solution,
          level.solution.reversed.toList(),
        ];
        for (final path in paths) {
          final engine = OneLineEngine()..reset(level);
          expect(engine.startAt(path.first), isTrue,
              reason: 'Level $n should start at endpoint ${path.first}');
          for (var i = 1; i < path.length; i++) {
            expect(engine.moveTo(path[i]), 'traced',
                reason: 'Level $n step $i should follow the trail');
          }
          expect(engine.isComplete, isTrue,
              reason: 'Level $n trail should finish with every edge traced');
          expect(engine.path.last, path.last,
              reason: 'Level $n should finish at the other endpoint');
        }
      }
    });

    test('a wrong mid-edge start on a bridge trail dead-ends', () {
      for (var n = OneLineGenerator.campaignLevelCount - 2;
          n <= OneLineGenerator.campaignLevelCount;
          n++) {
        final level = gen.generateLevel(n);
        final engine = OneLineEngine()..reset(level);
        final hiddenStarts = <int?>[
          level.startVertex,
          level.alternateStartVertex,
        ];

        expect(engine.startOnEdge(level.edges.first.id, 0.5), isTrue,
            reason: 'Level $n should let the stroke start anywhere');
        expect(engine.head, isNot(anyOf(hiddenStarts)),
            reason: 'Level $n must not jump to a hidden solution endpoint');

        var stalled = false;
        for (var guard = 0; guard < 500 && !engine.isComplete; guard++) {
          final hint = engine.suggestNextEdge();
          if (hint == null) {
            stalled = true;
            break;
          }
          final far = engine.edgeById(hint)!.other(engine.head!);
          expect(engine.moveTo(far), 'traced',
              reason: 'Level $n hint must remain a legal move');
        }
        expect(engine.isComplete, isFalse,
            reason: 'Level $n must not solve from a wrong mid-edge start');
        expect(stalled || engine.isDeadEnd, isTrue,
            reason: 'Level $n wrong start should strand the stroke');
      }
    });

    test('startOnEdge splits the touched segment mid-stroke-free', () {
      final level = gen.generateLevel(1);
      final engine = OneLineEngine()..reset(level);

      final edge = level.edges.first;
      expect(engine.startOnEdge(edge.id, 0.5), isTrue);

      expect(engine.started, isTrue);
      // One edge became two half-edges.
      expect(engine.totalEdges, level.edges.length + 1);
      expect(engine.vertices.length, level.vertices.length + 1);
      expect(engine.path.length, 1);
      expect(engine.tracedCount, 0);

      // The split vertex sits at the end of the id space.
      final maxId =
          level.vertices.map((v) => v.id).reduce((a, b) => a > b ? a : b);
      expect(engine.head, maxId + 1);
    });

    test('starting exactly on an endpoint does not split', () {
      final level = gen.generateLevel(1);
      final engine = OneLineEngine()..reset(level);

      final edge = level.edges.first;
      expect(engine.startOnEdge(edge.id, 0.0), isTrue);
      expect(engine.totalEdges, level.edges.length);
      expect(engine.vertices.length, level.vertices.length);
      expect(engine.head, edge.a);
    });

    test('full circuit from a mid-edge touch completes the puzzle', () {
      // Mid-edge starts are a tutorial affordance (levels 1-10).
      for (int n = 1; n <= 10; n++) {
        final level = gen.generateLevel(n);
        final engine = OneLineEngine()..reset(level);

        final edge = level.edges.first;
        expect(engine.startOnEdge(edge.id, 0.37), isTrue);

        // Walk the pristine solution, but splice the split halves in:
        // ... -> a -> [p] -> b -> ... becomes p -> b -> ... -> a -> p.
        final sol = level.solution;
        int i = -1;
        for (int s = 0; s + 1 < sol.length; s++) {
          if ((sol[s] == edge.a && sol[s + 1] == edge.b) ||
              (sol[s] == edge.b && sol[s + 1] == edge.a)) {
            i = s;
            break;
          }
        }
        expect(i, greaterThanOrEqualTo(0),
            reason: 'Level $n solution must traverse the chosen edge');

        final pId = engine.head!;
        final walk = <int>[
          pId,
          ...sol.sublist(i + 1), // from the far endpoint around to v0
          if (i > 0) ...sol.sublist(1, i + 1),
          pId,
        ];

        var moves = 0;
        for (int s = 0; s + 1 < walk.length; s++) {
          final outcome = engine.moveTo(walk[s + 1]);
          expect(outcome, anyOf('traced', 'backtracked', null),
              reason: 'Step $s of level $n');
          if (outcome == 'traced') moves++;
        }
        expect(moves, level.edges.length + 1,
            reason: 'Level $n must trace both halves plus all others');
        expect(engine.isComplete, isTrue,
            reason: 'Level $n should be complete after the circuit walk');
      }
    });

    test('undo across the split and clearPath restore pristine graph', () {
      final level = gen.generateLevel(3);
      final engine = OneLineEngine()..reset(level);

      final edge = level.edges.first;
      engine.startOnEdge(edge.id, 0.5);
      final headAfterSplit = engine.head!;

      // Trace toward one endpoint, then undo back to the split point.
      final firstMove = engine.availableMovesFrom(headAfterSplit).first;
      expect(engine.moveTo(firstMove), 'traced');
      expect(engine.undo(), isTrue);
      expect(engine.path, [headAfterSplit]);
      expect(engine.tracedCount, 0);

      // Full clear removes the split entirely.
      engine.clearPath();
      expect(engine.started, isFalse);
      expect(engine.totalEdges, level.edges.length);
      expect(engine.vertices.length, level.vertices.length);

      // And the original start-at-vertex API still works.
      expect(engine.startAt(level.vertices.first.id), isTrue);
    });

    test('dead end detection still fires on wrong walks', () {
      // Greedy-walk a level taking the first option each time; the walk
      // must terminate either complete or visibly dead-ended.
      final level = gen.generateLevel(2);
      final engine = OneLineEngine()..reset(level);

      expect(engine.startAt(level.vertices.first.id), isTrue);
      var guard = 0;
      while (!engine.isComplete && guard++ < 200) {
        final moves = engine.availableMovesFrom(engine.head!);
        if (moves.isEmpty) {
          expect(engine.isDeadEnd, isTrue);
          break;
        }
        expect(engine.moveTo(moves.first), 'traced');
      }
      expect(engine.isComplete || engine.isDeadEnd, isTrue,
          reason: 'Walk must end complete or dead-ended');
    });

    test('suggestNextEdge always proposes a legal untraced edge', () {
      for (int n = 1; n <= 12; n++) {
        final level = gen.generateLevel(n);
        final engine = OneLineEngine()..reset(level);
        expect(engine.suggestNextEdge(), isNull,
            reason: 'Level $n: no suggestion before the stroke starts');
        final startId =
            level.startAnywhere ? level.vertices.first.id : level.startVertex;
        expect(engine.startAt(startId), isTrue,
            reason: 'Level $n: legal start rejected');

        // Follow ONLY hints; each must be untraced and incident to head,
        // and together they must solve the level.
        var guard = 0;
        while (!engine.isComplete && guard++ < 500) {
          final hint = engine.suggestNextEdge();
          expect(hint, isNotNull, reason: 'Level $n stalled at step $guard');
          expect(engine.tracedEdgeIds.contains(hint), isFalse,
              reason: 'Level $n hinted an already-traced edge');
          expect(engine.edgeById(hint!)!.touches(engine.head!), isTrue,
              reason: 'Level $n hinted an edge away from head');
          expect(engine.moveTo(engine.edgeById(hint)!.other(engine.head!)),
              'traced');
        }
        expect(engine.isComplete, isTrue,
            reason: 'Level $n must be solvable by hints alone');
        expect(engine.suggestNextEdge(), isNull,
            reason: 'Level $n: no hints once complete');
      }
    });

    test('hint stays silent instead of pointing into a stranded component', () {
      const level = OneLineLevel(
        number: 100,
        name: 'two separate loops',
        difficulty: 'test',
        vertices: [
          OneLineVertex(id: 0, position: Offset(0, 0)),
          OneLineVertex(id: 1, position: Offset(1, 0)),
          OneLineVertex(id: 2, position: Offset(0, 1)),
          OneLineVertex(id: 3, position: Offset(2, 0)),
          OneLineVertex(id: 4, position: Offset(3, 0)),
          OneLineVertex(id: 5, position: Offset(2, 1)),
        ],
        edges: [
          OneLineEdge(id: 0, a: 0, b: 1),
          OneLineEdge(id: 1, a: 1, b: 2),
          OneLineEdge(id: 2, a: 2, b: 0),
          OneLineEdge(id: 3, a: 3, b: 4),
          OneLineEdge(id: 4, a: 4, b: 5),
          OneLineEdge(id: 5, a: 5, b: 3),
        ],
        solution: [0, 1, 2, 0],
        suggestedStarts: [0],
        parSeconds: 10,
      );
      final engine = OneLineEngine()..reset(level);
      expect(engine.startAt(0), isTrue);
      expect(engine.moveTo(1), 'traced');
      expect(engine.moveTo(2), 'traced');
      expect(engine.moveTo(0), 'traced');

      // The head loop is closed but the other triangle is still untraced.
      expect(engine.isComplete, isFalse);
      expect(engine.tracedCount, 3);
      expect(engine.suggestNextEdge(), isNull,
          reason: 'No hint may point at edges unreachable from the head');
    });

    test('undo counts as a backtrack like drag-back undos', () {
      final level = gen.generateLevel(3);
      final engine = OneLineEngine()..reset(level);
      engine.startAt(level.vertices.first.id);
      final first = engine.availableMovesFrom(engine.head!).first;
      engine.moveTo(first);
      expect(engine.backtracks, 0);
      expect(engine.undo(), isTrue);
      expect(engine.backtracks, 1,
          reason: 'Button undo must be scored like a drag-back undo');
    });
  });
}
