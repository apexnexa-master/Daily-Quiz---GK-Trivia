import 'package:vector_math/vector_math_64.dart';

enum Direction { up, down, left, right }

enum ArrowColor { neutral, red, blue, green, yellow }

enum ArrowState { active, escaping, escaped }

enum SpecialTileType { none, ice, portalEntrance, portalExit, colorLock, oneWayGate, breakableWall }

enum ArrowShape { straight, lShape, uShape, snake, zShape, hook }

class TileModifier {
  final String id;
  final SpecialTileType type;
  final Vector2 position;
  final String? targetPortalId;
  final Direction? exitDirection;
  final ArrowColor? requiredColor;
  final int hitPoints;

  TileModifier({
    required this.id,
    required this.type,
    required this.position,
    this.targetPortalId,
    this.exitDirection,
    this.requiredColor,
    this.hitPoints = 1,
  });
}

abstract class ArrowModifier {
  bool canPlayerTap(ArrowEntity arrow);
  void onPlayerTapped(ArrowEntity arrow);
}

class ArrowEntity {
  final String id;
  Vector2 tailPosition;
  final int length;
  Direction direction;
  final int layerId;
  final ArrowColor color;
  final ArrowShape shapeType;
  bool isEscaped;
  ArrowState state;
  DateTime? escapeStartTime;
  List<Vector2>? cachedExitRoute;

  ArrowEntity({
    required this.id,
    required this.tailPosition,
    required this.length,
    required this.direction,
    required this.layerId,
    this.color = ArrowColor.neutral,
    this.shapeType = ArrowShape.straight,
    this.isEscaped = false,
    this.state = ArrowState.active,
    this.escapeStartTime,
    this.cachedExitRoute,
  });

  static Vector2 getDirectionVector(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Vector2(0, -1);
      case Direction.down:
        return Vector2(0, 1);
      case Direction.left:
        return Vector2(-1, 0);
      case Direction.right:
        return Vector2(1, 0);
    }
  }

  static Vector2 turnCW(Direction dir) {
    switch (dir) {
      case Direction.up: return Vector2(1, 0);
      case Direction.down: return Vector2(-1, 0);
      case Direction.left: return Vector2(0, -1);
      case Direction.right: return Vector2(0, 1);
    }
  }

  static Vector2 turnCCW(Direction dir) {
    switch (dir) {
      case Direction.up: return Vector2(-1, 0);
      case Direction.down: return Vector2(1, 0);
      case Direction.left: return Vector2(0, 1);
      case Direction.right: return Vector2(0, -1);
    }
  }

  List<Vector2> getOccupiedCells() {
    return computeShapeCells(tailPosition, direction, length, shapeType);
  }

  static List<Vector2> computeShapeCells(Vector2 tail, Direction dir, int len, ArrowShape shape) {
    final dv = getDirectionVector(dir);
    final cw = turnCW(dir);
    final ccw = turnCCW(dir);

    switch (shape) {
      case ArrowShape.straight:
        return List.generate(len, (i) => tail + dv * i.toDouble());

      case ArrowShape.lShape:
        if (len < 2) {
          return List.generate(len, (i) => tail + dv * i.toDouble());
        }
        final cells = <Vector2>[];
        for (int i = 0; i < len - 1; i++) {
          cells.add(tail + dv * i.toDouble());
        }
        cells.add(tail + dv * (len - 2).toDouble() + cw);
        return cells;

      case ArrowShape.hook:
        if (len < 2) {
          return List.generate(len, (i) => tail + dv * i.toDouble());
        }
        final cells = <Vector2>[];
        for (int i = 0; i < len - 1; i++) {
          cells.add(tail + dv * i.toDouble());
        }
        cells.add(tail + dv * (len - 2).toDouble() + ccw);
        return cells;

      case ArrowShape.zShape:
        if (len < 3) {
          return List.generate(len, (i) => tail + dv * i.toDouble());
        }
        final cells = <Vector2>[];
        for (int i = 0; i < len - 2; i++) {
          cells.add(tail + dv * i.toDouble());
        }
        cells.add(tail + dv * (len - 3).toDouble() + cw);
        cells.add(tail + dv * (len - 3).toDouble() + cw + dv);
        return cells;

      case ArrowShape.uShape:
        if (len < 3) {
          return List.generate(len, (i) => tail + dv * i.toDouble());
        }
        final cells = <Vector2>[];
        final firstLegLen = len ~/ 2;
        // First leg going straight
        for (int i = 0; i < firstLegLen; i++) {
          cells.add(tail + dv * i.toDouble());
        }
        // Base of the U (step CW)
        final baseCell = tail + dv * (firstLegLen - 1).toDouble() + cw;
        cells.add(baseCell);
        // Second leg going backward (-dv)
        final secondLegLen = len - firstLegLen - 1;
        for (int i = 0; i < secondLegLen; i++) {
          cells.add(baseCell - dv * (i + 1).toDouble());
        }
        return cells;

      case ArrowShape.snake:
        if (len < 3) {
          return List.generate(len, (i) => tail + dv * i.toDouble());
        }
        final cells = <Vector2>[];
        final l1 = len ~/ 3;
        final l2 = len ~/ 3;
        final l3 = len - l1 - l2;
        // First leg along dv
        for (int i = 0; i < l1; i++) {
          cells.add(tail + dv * i.toDouble());
        }
        // Middle leg along cw
        final pivot1 = tail + dv * (l1 - 1).toDouble();
        for (int i = 0; i < l2; i++) {
          cells.add(pivot1 + cw * (i + 1).toDouble());
        }
        // Last leg along dv
        final pivot2 = pivot1 + cw * l2.toDouble();
        for (int i = 0; i < l3; i++) {
          cells.add(pivot2 + dv * (i + 1).toDouble());
        }
        return cells;
    }
  }

  Vector2 getTipPosition() {
    final cells = getOccupiedCells();
    return cells.last;
  }

  Direction getTipDirection() {
    if (shapeType == ArrowShape.straight) return direction;
    final cells = getOccupiedCells();
    if (cells.length < 2) return direction;
    final last = cells.last;
    final prev = cells[cells.length - 2];
    final dx = (last.x - prev.x).toInt();
    final dy = (last.y - prev.y).toInt();
    if (dx == 1) return Direction.right;
    if (dx == -1) return Direction.left;
    if (dy == 1) return Direction.down;
    if (dy == -1) return Direction.up;
    return direction;
  }
}

class LogicalGrid {
  final int columns;
  final int rows;
  final List<List<List<ArrowEntity?>>> matrix;
  final Map<String, TileModifier> tileModifiers = {};
  final Map<String, List<TileModifier>> modifiersByCoord = {};
  final Map<String, ArrowModifier> arrowModifiers = {};
  final List<ArrowEntity> escapingArrows = [];

  LogicalGrid({required this.columns, required this.rows})
      : matrix = List.generate(
          columns,
          (_) => List.generate(rows, (_) => List.filled(3, null)),
        );

  void registerArrow(ArrowEntity arrow) {
    for (final cell in arrow.getOccupiedCells()) {
      final x = cell.x.toInt();
      final y = cell.y.toInt();
      if (_isInBounds(x, y)) {
        matrix[x][y][arrow.layerId] = arrow;
      }
    }
  }

  void clearArrowFromMatrix(ArrowEntity arrow) {
    for (final cell in arrow.getOccupiedCells()) {
      final x = cell.x.toInt();
      final y = cell.y.toInt();
      if (_isInBounds(x, y)) {
        matrix[x][y][arrow.layerId] = null;
      }
    }
  }

  void addModifier(TileModifier modifier) {
    tileModifiers[modifier.id] = modifier;
    final key = '${modifier.position.x.toInt()},${modifier.position.y.toInt()}';
    modifiersByCoord.putIfAbsent(key, () => []);
    modifiersByCoord[key]!.add(modifier);
  }

  List<TileModifier> getModifiersAt(int x, int y) {
    return modifiersByCoord['$x,$y'] ?? [];
  }

  bool _isInBounds(int x, int y) {
    return x >= 0 && x < columns && y >= 0 && y < rows;
  }

  bool isBlockedForArrow(ArrowEntity movingArrow, int x, int y) {
    if (!_isInBounds(x, y)) return false;

    for (int l = movingArrow.layerId; l < 3; l++) {
      final occupant = matrix[x][y][l];
      if (occupant != null &&
          occupant.id != movingArrow.id &&
          occupant.state == ArrowState.active) {
        return true;
      }
    }

    final now = DateTime.now();
    for (final esc in escapingArrows) {
      if (esc.id == movingArrow.id) continue;
      if (esc.layerId < movingArrow.layerId) continue;

      final startTime = esc.escapeStartTime;
      if (startTime == null) continue;

      final elapsedMs = now.difference(startTime).inMilliseconds;
      final slideDistanceA = elapsedMs / 80.0;

      esc.cachedExitRoute ??= getExitRoute(esc);
      final routeA = esc.cachedExitRoute!;

      int iA = -1;
      for (int i = 0; i < routeA.length; i++) {
        if (routeA[i].x.toInt() == x && routeA[i].y.toInt() == y) {
          iA = i;
          break;
        }
      }
      if (iA == -1) continue;

      movingArrow.cachedExitRoute ??= getExitRoute(movingArrow);
      final routeB = movingArrow.cachedExitRoute!;
      int iB = -1;
      for (int i = 0; i < routeB.length; i++) {
        if (routeB[i].x.toInt() == x && routeB[i].y.toInt() == y) {
          iB = i;
          break;
        }
      }
      if (iB == -1) continue;

      final startB = (iB - movingArrow.length).toDouble();
      final endB = iB.toDouble();

      final startA = (iA - esc.length).toDouble() - slideDistanceA;
      final endA = iA.toDouble() - slideDistanceA;

      final overlapStart = startB > startA ? startB : startA;
      final overlapEnd = endB < endA ? endB : endA;

      final effectiveStart = 0.0 > overlapStart ? 0.0 : overlapStart;

      if (effectiveStart < overlapEnd) {
        return true;
      }
    }

    return false;
  }

  List<Vector2> getExitRoute(ArrowEntity arrow) {
    if (arrow.cachedExitRoute != null) {
      return arrow.cachedExitRoute!;
    }
    final route = List<Vector2>.from(arrow.getOccupiedCells());
    if (route.isEmpty) return route;

    final dir = arrow.getTipDirection();
    final step = ArrowEntity.getDirectionVector(dir);

    var pos = arrow.getTipPosition();
    var portalJumps = 0;
    var currentDir = dir;
    var currentStep = step;

    while (true) {
      pos += currentStep;
      final cx = pos.x.toInt();
      final cy = pos.y.toInt();
      if (!_isInBounds(cx, cy)) {
        route.add(pos);
        break;
      }

      route.add(pos);

      final mods = modifiersByCoord['$cx,$cy'];
      if (mods != null) {
        bool jumped = false;
        for (final m in mods) {
          if (m.type == SpecialTileType.portalEntrance) {
            portalJumps++;
            if (portalJumps > 8) break;
            TileModifier? exitPortal;
            for (final tm in tileModifiers.values) {
              if (tm.id == m.targetPortalId &&
                  tm.type == SpecialTileType.portalExit) {
                exitPortal = tm;
                break;
              }
            }
            if (exitPortal != null) {
              final newDir = exitPortal.exitDirection ?? currentDir;
              pos = exitPortal.position - ArrowEntity.getDirectionVector(newDir);
              currentDir = newDir;
              currentStep = ArrowEntity.getDirectionVector(newDir);
              jumped = true;
            }
            break;
          }
        }
        if (jumped) continue;
      }
    }

    // Extend route out of bounds by length + 5 to let the tail exit
    for (int i = 0; i < arrow.length + 5; i++) {
      pos += currentStep;
      route.add(pos);
    }

    arrow.cachedExitRoute = route;
    return route;
  }

  List<Vector2> getBlockedExitRoute(ArrowEntity arrow) {
    final route = <Vector2>[];
    final cells = arrow.getOccupiedCells();
    final dir = arrow.getTipDirection();
    final step = ArrowEntity.getDirectionVector(dir);

    var pos = arrow.getTipPosition();
    var portalJumps = 0;
    var currentDir = dir;
    var currentStep = step;

    while (true) {
      pos += currentStep;
      final cx = pos.x.toInt();
      final cy = pos.y.toInt();
      if (!_isInBounds(cx, cy)) {
        break;
      }

      bool isSelf = false;
      for (final c in cells) {
        if (c.x.toInt() == cx && c.y.toInt() == cy) {
          isSelf = true;
          break;
        }
      }
      if (isSelf) {
        route.add(Vector2(cx.toDouble(), cy.toDouble()));
        continue;
      }

      route.add(Vector2(cx.toDouble(), cy.toDouble()));

      if (isBlockedForArrow(arrow, cx, cy)) {
        break;
      }

      final mods = modifiersByCoord['$cx,$cy'];
      if (mods != null) {
        bool blockedByMod = false;
        for (final m in mods) {
          switch (m.type) {
            case SpecialTileType.colorLock:
              if (m.requiredColor != null && arrow.color != m.requiredColor) {
                blockedByMod = true;
              }
              break;
            case SpecialTileType.breakableWall:
              if (m.hitPoints > 0) {
                blockedByMod = true;
              }
              break;
            case SpecialTileType.oneWayGate:
              if (m.exitDirection != null && currentDir != m.exitDirection) {
                blockedByMod = true;
              }
              break;
            case SpecialTileType.portalEntrance:
              portalJumps++;
              if (portalJumps > 8) {
                blockedByMod = true;
                break;
              }
              TileModifier? exitPortal;
              for (final tm in tileModifiers.values) {
                if (tm.id == m.targetPortalId &&
                    tm.type == SpecialTileType.portalExit) {
                  exitPortal = tm;
                  break;
                }
              }
              if (exitPortal == null) {
                blockedByMod = true;
                break;
              }
              final newDir = exitPortal.exitDirection ?? currentDir;
              pos = exitPortal.position - ArrowEntity.getDirectionVector(newDir);
              currentDir = newDir;
              currentStep = ArrowEntity.getDirectionVector(newDir);
              break;
            default:
              break;
          }
          if (blockedByMod) break;
        }
        if (blockedByMod) break;
      }
    }
    return route;
  }

  bool checkExitPath(ArrowEntity arrow) {
    final cells = arrow.getOccupiedCells();
    final dir = arrow.getTipDirection();
    final step = ArrowEntity.getDirectionVector(dir);

    var pos = arrow.getTipPosition();
    var portalJumps = 0;
    var currentDir = dir;
    var currentStep = step;

      while (true) {
        pos += currentStep;
        final cx = pos.x.toInt();
        final cy = pos.y.toInt();
        if (!_isInBounds(cx, cy)) break;

        // Skip if the coordinate belongs to the same arrow
        bool isSelf = false;
        for (final c in cells) {
          if (c.x.toInt() == cx && c.y.toInt() == cy) {
            isSelf = true;
            break;
          }
        }
        if (isSelf) continue;

        if (isBlockedForArrow(arrow, cx, cy)) return false;

        final mods = modifiersByCoord['$cx,$cy'];
        if (mods == null) continue;

        for (final m in mods) {
          switch (m.type) {
            case SpecialTileType.colorLock:
              if (m.requiredColor != null && arrow.color != m.requiredColor) {
                return false;
              }
              break;
            case SpecialTileType.breakableWall:
              if (m.hitPoints > 0) return false;
              break;
            case SpecialTileType.oneWayGate:
              if (m.exitDirection != null && currentDir != m.exitDirection) {
                return false;
              }
              break;
            case SpecialTileType.portalEntrance:
              portalJumps++;
              if (portalJumps > 8) return false;
              TileModifier? exitPortal;
              for (final tm in tileModifiers.values) {
                if (tm.id == m.targetPortalId &&
                    tm.type == SpecialTileType.portalExit) {
                  exitPortal = tm;
                  break;
                }
              }
              if (exitPortal == null) return false;
              final newDir = exitPortal.exitDirection ?? currentDir;
              pos = exitPortal.position -
                  ArrowEntity.getDirectionVector(newDir);
              currentDir = newDir;
              currentStep = ArrowEntity.getDirectionVector(newDir);
              break;
            case SpecialTileType.portalExit:
            case SpecialTileType.ice:
            case SpecialTileType.none:
              break;
          }
      }
    }
    return true;
  }
}
