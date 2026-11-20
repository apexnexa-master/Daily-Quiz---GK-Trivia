enum TwoCarItemKind { coin, obstacle }

enum TwoCarPhase { ready, running, gameOver }

enum TwoCarFailure { none, obstacle, missedCoin }

class TwoCarLayout {
  static const double carY = 0.78;
  static const double carWidth = 0.24;
  static const double carHeight = 0.10;
  static const double coinWidth = 0.14;
  static const double coinHeight = 0.075;
  static const double obstacleWidth = 0.20;
  static const double obstacleHeight = 0.095;
  static const double laneEdgePadding = 0.08;
  static const double minCarX = carWidth / 2 + laneEdgePadding;
  static const double maxCarX = 1.0 - minCarX;

  static double clampCarX(double x) => x.clamp(minCarX, maxCarX).toDouble();

  static double itemHalfWidth(TwoCarItemKind kind) =>
      (kind == TwoCarItemKind.coin ? coinWidth : obstacleWidth) / 2;

  static double itemHalfHeight(TwoCarItemKind kind) =>
      (kind == TwoCarItemKind.coin ? coinHeight : obstacleHeight) / 2;

  static double missY(TwoCarItemKind kind) =>
      carY + carHeight / 2 + itemHalfHeight(kind) + 0.015;
}

class TwoCarItem {
  final int id;
  final int lane;
  final double x;
  double y;
  final TwoCarItemKind kind;

  TwoCarItem({
    required this.id,
    required this.lane,
    required this.x,
    required this.y,
    required this.kind,
  });

  TwoCarItem copy() => TwoCarItem(
        id: id,
        lane: lane,
        x: x,
        y: y,
        kind: kind,
      );
}

class TwoCarSnapshot {
  final TwoCarPhase phase;
  final List<double> carX;
  final List<TwoCarItem> items;
  final Set<int> activeLanes;
  final int score;
  final int coins;
  final double elapsed;
  final double speed;

  const TwoCarSnapshot({
    required this.phase,
    required this.carX,
    required this.items,
    required this.activeLanes,
    required this.score,
    required this.coins,
    required this.elapsed,
    required this.speed,
  });
}

class TwoCarUpdateResult {
  final bool collected;
  final bool crashed;
  final bool missed;
  final int? itemId;
  final int? lane;

  const TwoCarUpdateResult({
    this.collected = false,
    this.crashed = false,
    this.missed = false,
    this.itemId,
    this.lane,
  });
}

class TwoCarInput {
  static int laneForDx(double dx, double boardWidth) {
    if (boardWidth <= 0) return 0;
    return dx >= boardWidth / 2 ? 1 : 0;
  }

  static double laneXForDx(double dx, int lane, double boardWidth) {
    if (boardWidth <= 0) return 0.5;
    final laneWidth = boardWidth / 2;
    final localX = dx - lane * laneWidth;
    return (localX / laneWidth).clamp(0.0, 1.0).toDouble();
  }
}
