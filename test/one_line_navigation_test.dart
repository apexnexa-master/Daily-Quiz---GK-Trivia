import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_models.dart';
import 'package:gk_quiz_app/presentation/screens/games/one_line/one_line_navigation.dart';

void main() {
  final positions = <int, Offset>{
    0: Offset.zero,
    1: const Offset(100, 0),
    2: const Offset(0, 100),
    3: const Offset(-100, 0),
  };
  final edges = <OneLineEdge>[
    const OneLineEdge(id: 10, a: 0, b: 1),
    const OneLineEdge(id: 11, a: 0, b: 2),
    const OneLineEdge(id: 12, a: 0, b: 3),
  ];

  ({int edgeId, int farId, double t})? pick(Offset pointer,
          {Set<int> traced = const <int>{}}) =>
      OneLineNavigation.choose(
        pointer: pointer,
        headId: 0,
        head: Offset.zero,
        edges: edges,
        tracedEdgeIds: traced,
        positions: positions,
        snapRadius: 30,
      );

  group('OneLineNavigation', () {
    test('a junction can be left in every available direction', () {
      expect(pick(const Offset(70, 0))?.edgeId, 10);
      expect(pick(const Offset(0, 70))?.edgeId, 11);
      expect(pick(const Offset(-70, 0))?.edgeId, 12);
    });

    test('diagonal drags choose the closest branch', () {
      expect(pick(const Offset(70, 25))?.edgeId, 10);
      expect(pick(const Offset(25, 70))?.edgeId, 11);
      expect(pick(const Offset(-70, -25))?.edgeId, 12);
    });

    test('tiny movement at the junction does not lock a direction', () {
      expect(pick(const Offset(2, 0)), isNull);
      expect(pick(const Offset(0, -3)), isNull);
    });

    test('already traced branches are never chosen again', () {
      expect(pick(const Offset(25, 70), traced: {10})?.edgeId, 11);
      expect(pick(const Offset(-70, 0), traced: {12}), isNull);
    });

    test('a finger still behind the junction does not pick a branch', () {
      expect(pick(const Offset(-40, 0), traced: {12}), isNull);
      expect(pick(const Offset(-15, -2), traced: {12}), isNull);
    });

    test('a start touch snaps to the nearest vertex inside the radius', () {
      int? start(Offset pointer, {double radius = 30}) =>
          OneLineNavigation.chooseStartVertex(
        positions: positions,
        pointer: pointer,
        snapRadius: radius,
      );

      expect(start(const Offset(8, 6)), 0);
      expect(start(const Offset(92, 9)), 1);
      expect(start(const Offset(6, 96)), 2);
      expect(start(const Offset(-94, 4)), 3);
      expect(start(const Offset(50, 50)), isNull);
      expect(start(const Offset(45, 45), radius: 70), 0);
    });

    test('commits only near the far vertex', () {
      final far = positions[1]!;
      expect(
          OneLineNavigation.shouldCommit(
              t: 0.4, pointer: const Offset(40, 0), far: far, snapRadius: 30),
          isFalse);
      expect(
          OneLineNavigation.shouldCommit(
              t: 0.9, pointer: const Offset(90, 0), far: far, snapRadius: 30),
          isTrue);
      expect(
          OneLineNavigation.shouldCommit(
              t: 0.7, pointer: const Offset(95, 0), far: far, snapRadius: 30),
          isTrue);
      expect(
          OneLineNavigation.shouldCommit(
              t: 0.6, pointer: const Offset(85, 0), far: far, snapRadius: 30),
          isTrue);
    });
  });
}
