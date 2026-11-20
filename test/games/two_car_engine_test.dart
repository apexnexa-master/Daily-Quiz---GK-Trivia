import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/two_car/two_car_engine.dart';
import 'package:gk_quiz_app/presentation/screens/games/two_car/two_car_models.dart';

TwoCarItem _item({
  required int id,
  required int lane,
  required double x,
  required double y,
  required TwoCarItemKind kind,
}) {
  return TwoCarItem(id: id, lane: lane, x: x, y: y, kind: kind);
}

void main() {
  group('TwoCarEngine', () {
    test('start resets into a running state', () {
      final engine = TwoCarEngine(seed: 1);
      engine.setCarX(0, 0.2);
      engine.start();

      expect(engine.phase, TwoCarPhase.running);
      expect(engine.score, 0);
      expect(engine.coins, 0);
      expect(engine.carX, [0.5, 0.5]);
    });

    test('clamps car position inside its lane', () {
      final engine = TwoCarEngine(seed: 1);

      engine.setCarX(0, -1);
      engine.setCarX(1, 2);
      expect(engine.carX[0], TwoCarLayout.minCarX);
      expect(engine.carX[1], TwoCarLayout.maxCarX);

      engine.setCarX(2, 0.4);
      expect(engine.carX, [TwoCarLayout.minCarX, TwoCarLayout.maxCarX]);
      expect(
        TwoCarLayout.maxCarX + TwoCarLayout.carWidth / 2,
        lessThan(1),
      );
    });

    test('spawned items stay clear of the middle divider', () {
      final engine = TwoCarEngine(seed: 2);
      engine.start();
      for (var i = 0; i < 16; i++) {
        engine.update(0.05);
      }

      expect(engine.items, isNotEmpty);
      for (final item in engine.items) {
        expect(item.x, greaterThanOrEqualTo(TwoCarLayout.minCarX));
        expect(item.x, lessThanOrEqualTo(TwoCarLayout.maxCarX));
      }
    });

    test('collects a coin when the car overlaps it', () {
      final engine = TwoCarEngine(
        seed: 1,
        initialItems: [
          _item(
            id: 1,
            lane: 0,
            x: 0.5,
            y: 0.74,
            kind: TwoCarItemKind.coin,
          ),
        ],
      );
      engine.start();

      final result = engine.update(0.05);

      expect(result.collected, isTrue);
      expect(result.crashed, isFalse);
      expect(engine.coins, 1);
      expect(engine.score, 10);
      expect(engine.items, isEmpty);
      expect(engine.speed, greaterThan(0.30));
    });

    test('ends the run when a coin is missed', () {
      final engine = TwoCarEngine(
        seed: 1,
        initialItems: [
          _item(
            id: 1,
            lane: 1,
            x: 0.2,
            y: 0.87,
            kind: TwoCarItemKind.coin,
          ),
        ],
      );
      engine.start();
      engine.setCarX(1, 0.8);

      final result = engine.update(0.05);

      expect(result.missed, isTrue);
      expect(result.itemId, 1);
      expect(result.lane, 1);
      expect(result.collected, isFalse);
      expect(result.crashed, isFalse);
      expect(engine.phase, TwoCarPhase.gameOver);
      expect(engine.failure, TwoCarFailure.missedCoin);
      expect(engine.stars, 1);
    });

    test('ends the run when the car hits an obstacle', () {
      final engine = TwoCarEngine(
        seed: 1,
        initialItems: [
          _item(
            id: 1,
            lane: 0,
            x: 0.5,
            y: 0.74,
            kind: TwoCarItemKind.obstacle,
          ),
        ],
      );
      engine.start();

      final result = engine.update(0.05);

      expect(result.crashed, isTrue);
      expect(result.itemId, 1);
      expect(result.lane, 0);
      expect(engine.phase, TwoCarPhase.gameOver);
      expect(engine.failure, TwoCarFailure.obstacle);
      expect(engine.stars, 1);
      final elapsedAtCrash = engine.elapsed;
      expect(engine.update(0.05).crashed, isFalse);
      expect(engine.elapsed, elapsedAtCrash);
    });

    test('survives an obstacle when the car moves out of its path', () {
      final engine = TwoCarEngine(
        seed: 1,
        initialItems: [
          _item(
            id: 1,
            lane: 0,
            x: 0.5,
            y: 0.74,
            kind: TwoCarItemKind.obstacle,
          ),
        ],
      );
      engine.start();
      engine.setCarX(0, 0.15);

      final result = engine.update(0.05);

      expect(result.crashed, isFalse);
      expect(engine.phase, TwoCarPhase.running);
      expect(engine.items, hasLength(1));
    });

    test('snapshot items are detached from live items', () {
      final engine = TwoCarEngine(
        seed: 1,
        initialItems: [
          _item(
            id: 1,
            lane: 1,
            x: 0.5,
            y: 0.2,
            kind: TwoCarItemKind.coin,
          ),
        ],
      );
      engine.start();
      final snapshot = engine.snapshot(const {1});

      engine.items.first.y = 0.9;

      expect(snapshot.items.first.y, 0.2);
      expect(snapshot.activeLanes, {1});
    });
  });

  group('TwoCarInput', () {
    test('routes each pointer to the half it starts in', () {
      expect(TwoCarInput.laneForDx(80, 200), 0);
      expect(TwoCarInput.laneForDx(120, 200), 1);
      expect(TwoCarInput.laneForDx(-20, 200), 0);
      expect(TwoCarInput.laneForDx(220, 200), 1);
    });

    test('maps pointer x to a car position within its lane', () {
      expect(TwoCarInput.laneXForDx(80, 0, 200), closeTo(0.8, 0.0001));
      expect(TwoCarInput.laneXForDx(140, 1, 200), closeTo(0.4, 0.0001));
      expect(TwoCarInput.laneXForDx(-10, 0, 200), 0);
      expect(TwoCarInput.laneXForDx(210, 1, 200), 1);
    });
  });
}
