import 'dart:math';

import 'two_car_models.dart';

class TwoCarEngine {
  final Random _random;
  final List<TwoCarItem> _items = <TwoCarItem>[];
  final List<double> _carX = <double>[0.5, 0.5];
  final List<TwoCarItem> _seedItems;

  TwoCarPhase _phase = TwoCarPhase.ready;
  TwoCarFailure _failure = TwoCarFailure.none;
  int _score = 0;
  int _coins = 0;
  int _nextId = 1;
  double _elapsed = 0;
  double _spawnIn = 0.75;

  TwoCarEngine({int? seed, Iterable<TwoCarItem>? initialItems})
      : _random = Random(seed ?? DateTime.now().millisecondsSinceEpoch),
        _seedItems =
            initialItems?.map((item) => item.copy()).toList(growable: false) ??
                const <TwoCarItem>[];

  TwoCarPhase get phase => _phase;
  TwoCarFailure get failure => _failure;
  int get score => _score;
  int get coins => _coins;
  double get elapsed => _elapsed;
  int get elapsedSeconds => _elapsed.round();
  double get speed => (0.30 + _elapsed * 0.005).clamp(0.30, 0.70).toDouble();
  List<TwoCarItem> get items => List<TwoCarItem>.unmodifiable(_items);
  List<double> get carX => List<double>.unmodifiable(_carX);

  int get stars {
    if (_phase != TwoCarPhase.gameOver) return 0;
    if (_coins >= 15) return 3;
    if (_coins >= 8) return 2;
    return 1;
  }

  void start() {
    reset();
    _phase = TwoCarPhase.running;
  }

  void reset() {
    _phase = TwoCarPhase.ready;
    _failure = TwoCarFailure.none;
    _score = 0;
    _coins = 0;
    _nextId = 1;
    _elapsed = 0;
    _spawnIn = 0.75;
    _items
      ..clear()
      ..addAll(_seedItems.map((item) => item.copy()));
    _carX[0] = 0.5;
    _carX[1] = 0.5;
  }

  void setCarX(int lane, double x) {
    if (lane != 0 && lane != 1) return;
    _carX[lane] = TwoCarLayout.clampCarX(x);
  }

  TwoCarUpdateResult update(double delta) {
    if (_phase != TwoCarPhase.running || delta <= 0) {
      return const TwoCarUpdateResult();
    }

    final dt = delta.clamp(0.0, 0.05).toDouble();
    final step = speed * dt;
    _elapsed += dt;

    for (final item in _items) {
      item.y += step;
    }

    var collected = false;
    final survivors = <TwoCarItem>[];
    for (final item in _items) {
      if (item.y > 1.16) continue;

      final dy = (item.y - TwoCarLayout.carY).abs();
      final dx = (item.x - _carX[item.lane]).abs();
      final touchesCar = dy <=
              TwoCarLayout.carHeight / 2 +
                  TwoCarLayout.itemHalfHeight(item.kind) &&
          dx <=
              TwoCarLayout.carWidth / 2 + TwoCarLayout.itemHalfWidth(item.kind);

      if (touchesCar) {
        if (item.kind == TwoCarItemKind.obstacle) {
          _phase = TwoCarPhase.gameOver;
          _failure = TwoCarFailure.obstacle;
          _items
            ..clear()
            ..addAll(survivors)
            ..add(item);
          return TwoCarUpdateResult(
            collected: collected,
            crashed: true,
            itemId: item.id,
            lane: item.lane,
          );
        }
        collected = true;
        _coins += 1;
        _score += 10;
        continue;
      }

      if (item.kind == TwoCarItemKind.coin &&
          item.y > TwoCarLayout.missY(item.kind)) {
        _phase = TwoCarPhase.gameOver;
        _failure = TwoCarFailure.missedCoin;
        _items
          ..clear()
          ..addAll(survivors)
          ..add(item);
        return TwoCarUpdateResult(
          collected: collected,
          missed: true,
          itemId: item.id,
          lane: item.lane,
        );
      }
      survivors.add(item);
    }

    _items
      ..clear()
      ..addAll(survivors);

    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnWave();
      _spawnIn = _spawnInterval;
    }

    return TwoCarUpdateResult(collected: collected);
  }

  TwoCarSnapshot snapshot(Set<int> activeLanes) => TwoCarSnapshot(
        phase: _phase,
        carX: List<double>.unmodifiable(_carX),
        items: _items.map((item) => item.copy()).toList(growable: false),
        activeLanes: Set<int>.unmodifiable(activeLanes),
        score: _score,
        coins: _coins,
        elapsed: _elapsed,
        speed: speed,
      );

  double get _spawnInterval =>
      (1.30 - _elapsed * 0.010).clamp(0.55, 1.30).toDouble();

  void _spawnWave() {
    final firstLane = _random.nextInt(2);
    final obstacleChance =
        (0.14 + _elapsed * 0.0035).clamp(0.14, 0.45).toDouble();
    _items.add(_createItem(
      lane: firstLane,
      kind: _random.nextDouble() < obstacleChance
          ? TwoCarItemKind.obstacle
          : TwoCarItemKind.coin,
      y: -0.08,
    ));

    final secondLaneChance =
        (0.20 + _elapsed * 0.004).clamp(0.20, 0.70).toDouble();
    if (_random.nextDouble() < secondLaneChance) {
      _items.add(_createItem(
        lane: 1 - firstLane,
        kind: _random.nextDouble() <
                (0.10 + _elapsed * 0.0025).clamp(0.10, 0.38).toDouble()
            ? TwoCarItemKind.obstacle
            : TwoCarItemKind.coin,
        y: -0.18,
      ));
    }
  }

  TwoCarItem _createItem({
    required int lane,
    required TwoCarItemKind kind,
    required double y,
  }) {
    final x = _random
        .nextDouble()
        .clamp(TwoCarLayout.minCarX, TwoCarLayout.maxCarX)
        .toDouble();
    final item = TwoCarItem(
      id: _nextId++,
      lane: lane,
      x: x,
      y: y,
      kind: kind,
    );
    return item;
  }
}
