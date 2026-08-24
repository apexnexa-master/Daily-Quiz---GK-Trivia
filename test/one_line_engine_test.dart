import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_engine.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_generator.dart';

void main() {
  final gen = OneLineGenerator();

  group('OneLineEngine', () {
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
      final maxId = level.vertices.map((v) => v.id).reduce((a, b) => a > b ? a : b);
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
      for (int n = 1; n <= 12; n++) {
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
      final firstMove =
          engine.availableMovesFrom(headAfterSplit).first;
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
      expect(
          engine.isComplete || engine.isDeadEnd, isTrue,
          reason: 'Walk must end complete or dead-ended');
    });

    test('suggestNextEdge always proposes a legal untraced edge', () {
      for (int n = 1; n <= 12; n++) {
        final level = gen.generateLevel(n);
        final engine = OneLineEngine()..reset(level);
        expect(engine.suggestNextEdge(), isNull,
            reason: 'Level $n: no suggestion before the stroke starts');
        engine.startAt(level.vertices.first.id);

        // Follow ONLY hints; each must be untraced and incident to head,
        // and together they must solve the level.
        var guard = 0;
        while (!engine.isComplete && guard++ < 500) {
          final hint = engine.suggestNextEdge();
          expect(hint, isNotNull, reason: 'Level $n stalled at step $guard');
          expect(engine.tracedEdgeIds.contains(hint), isFalse,
              reason: 'Level $n hinted an already-traced edge');
          expect(
              engine.edgeById(hint!)!.touches(engine.head!), isTrue,
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
