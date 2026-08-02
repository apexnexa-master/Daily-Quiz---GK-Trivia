import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import '../logic/grid_matrix.dart';
import '../logic/game_solver.dart';
import 'level_schema.dart';
import 'level_parser.dart';
import 'shape_masks.dart';

class DifficultyResult {
  final double difficultyIndex;
  final int maxLayerDepth;
  final int arrowCount;
  final int modifierCount;
  final double avgBranchingFactor;
  final int longestChain;
  final double interlockScore;

  DifficultyResult({
    required this.difficultyIndex,
    required this.maxLayerDepth,
    required this.arrowCount,
    required this.modifierCount,
    required this.avgBranchingFactor,
    this.longestChain = 0,
    this.interlockScore = 0,
  });
}

class GenerationConfig {
  final int minArrows;
  final int maxArrows;
  final double density;
  final List<double> layerRatios;
  final int? seed;
  final double minDifficulty;
  final double maxDifficulty;
  final bool includeModifiers;
  final int maxCandidates;

  GenerationConfig({
    this.minArrows = 3,
    this.maxArrows = 8,
    this.density = 0.0,
    this.layerRatios = const [1.0, 0.0, 0.0],
    this.seed,
    this.minDifficulty = 0.5,
    this.maxDifficulty = 8.0,
    this.includeModifiers = false,
    this.maxCandidates = 50,
  });

  static GenerationConfig forChapter(int chapterId) {
    switch (chapterId) {
      case 1:
        return GenerationConfig(
            density: 0.75, layerRatios: [1.0, 0.0, 0.0],
            minDifficulty: 1.0, maxDifficulty: 4.5);
      case 2:
        return GenerationConfig(
            density: 0.80, layerRatios: [0.55, 0.45, 0.0],
            minDifficulty: 5.0, maxDifficulty: 8.5,
            includeModifiers: true);
      case 3:
        return GenerationConfig(
            density: 0.85, layerRatios: [0.35, 0.45, 0.20],
            minDifficulty: 9.0, maxDifficulty: 14.0,
            includeModifiers: true);
      default:
        return GenerationConfig(
            density: 0.90, layerRatios: [0.20, 0.45, 0.35],
            minDifficulty: 14.0, maxDifficulty: 25.0,
            includeModifiers: true);
    }
  }
}

class ShapeHistoryBuffer {
  final int maxSize;
  final List<String> _history = [];

  ShapeHistoryBuffer({this.maxSize = 5});

  bool canUse(String shapeId) => !_history.contains(shapeId);

  void record(String shapeId) {
    _history.add(shapeId);
    if (_history.length > maxSize) {
      _history.removeAt(0);
    }
  }

  void clear() => _history.clear();
}


class ProceduralGenerator {
  final Random _random;
  final GenerationConfig config;
  final ShapeHistoryBuffer? historyBuffer;

  ProceduralGenerator({required this.config, this.historyBuffer})
      : _random = Random(config.seed);

  ProceduralGenerator.withSeed(int seed,
      {required this.config, this.historyBuffer})
      : _random = Random(seed);

  LevelData generate(int columns, int rows, ShapeMask shapeMask,
      {int levelId = 0, int chapterId = 0}) {
    final originalScaled = shapeMask.scaleToFit(columns, rows);
    final originalFilled = originalScaled.getFilledPositions();
    if (originalFilled.isEmpty) {
      return _generateEmptyLevel(columns, rows, shapeMask.id, levelId, chapterId);
    }

    final bool isShapeLevel = levelId > 0 && levelId % 5 == 0;
    final ShapeMask activeMask = isShapeLevel ? shapeMask : ShapeMask(
      id: shapeMask.id,
      name: shapeMask.name,
      width: columns,
      height: rows,
      cells: List.generate(rows, (_) => List.filled(columns, true)),
    );

    for (int i = 0; i < config.maxCandidates; i++) {
      final candidate =
          _buildBackwardBoard(columns, rows, activeMask, levelId, chapterId);
      if (candidate == null) continue;

      if (_validateSolvability(candidate)) {
        final parsed = LevelParser.buildLogicalGrid(candidate);
        final diff = calculateDifficulty(parsed.logicalGrid);

        // Validation criteria from prompt1.txt (only for 6x6 and above)
        if (columns >= 6 && rows >= 6) {
          final arrows = candidate.arrows;
          final straightCount = arrows.where((a) => a.shape == 'straight').length;
          final occupancy = _calculateBoardOccupancy(candidate, activeMask);
          final avgLength = arrows.map((a) => a.length).reduce((a, b) => a + b) / arrows.length;

          if (straightCount / arrows.length > 0.50) continue;
          final minOccupancy = isShapeLevel ? 0.85 : 0.80;
          if (occupancy < minOccupancy) continue;
          if (avgLength < 2.0) continue;

          final minInterlock = chapterId == 2 ? 30.0 : (chapterId >= 3 ? 45.0 : 0.0);
          if (diff.interlockScore < minInterlock) continue;
        }

        if (diff.difficultyIndex >= config.minDifficulty &&
            diff.difficultyIndex <= config.maxDifficulty) {
          historyBuffer?.record(activeMask.id);
          return candidate;
        }
      }
    }

    return _generateFallbackBackward(columns, rows, activeMask, levelId, chapterId);
  }


  LevelData _generateFallback(int columns, int rows, ShapeMask shapeMask,
      int levelId, int chapterId) {
    final filled = shapeMask.getFilledPositions();
    if (filled.isEmpty) {
      return _generateEmptyLevel(columns, rows, shapeMask.id, levelId, chapterId);
    }

    final arrows = <LevelArrowData>[];
    final dirs = ['up', 'down', 'left', 'right'];
    final colors = ['neutral', 'red', 'blue', 'green', 'yellow'];
    final count = config.minArrows.clamp(1, filled.length);

    final shuffled = [...filled];
    shuffled.shuffle(_random);
    final selected = shuffled.take(count).toList();

    for (int i = 0; i < selected.length; i++) {
      final pos = selected[i];
      final x = pos.x.toInt();
      final y = pos.y.toInt();
      if (x < 0 || x >= columns || y < 0 || y >= rows) continue;

      final direction = dirs[_random.nextInt(dirs.length)];
      final dx = direction == 'left' ? -1 : (direction == 'right' ? 1 : 0);
      final dy = direction == 'up' ? -1 : (direction == 'down' ? 1 : 0);

      // Verify that all segments for length 2 are in bounds
      final x1 = x + dx;
      final y1 = y + dy;
      if (x1 < 0 || x1 >= columns || y1 < 0 || y1 >= rows) continue;

      arrows.add(LevelArrowData(
        id: 'gen_A${arrows.length + 1}',
        startX: x,
        startY: y,
        length: 2,
        direction: direction,
        layer: 0,
        color: colors[_random.nextInt(colors.length)],
      ));
    }

    if (arrows.isEmpty) {
      return _generateEmptyLevel(columns, rows, shapeMask.id, levelId, chapterId);
    }

    return LevelData(
      metadata: LevelMetadata(
          levelId: levelId,
          chapterId: chapterId,
          targetMoves: arrows.length,
          shapeSilhouetteId: shapeMask.id),
      grid: LevelGrid(columns: columns, rows: rows),
      arrows: arrows,
    );
  }

  LevelData _generateEmptyLevel(int columns, int rows, String shapeId,
      int levelId, int chapterId) {
    return LevelData(
      metadata: LevelMetadata(
          levelId: levelId,
          chapterId: chapterId,
          targetMoves: 1,
          shapeSilhouetteId: shapeId),
      grid: LevelGrid(columns: columns, rows: rows),
      arrows: [
        LevelArrowData(
            id: 'gen_A1',
            startX: 0,
            startY: 0,
            length: 1,
            direction: 'right',
            layer: 0,
            color: 'neutral'),
      ],
    );
  }

  int _pickLayer() {
    final ratios = config.layerRatios;
    final total = ratios.fold(0.0, (a, b) => a + b);
    if (total <= 0) return 0;
    final r = _random.nextDouble();
    double cumulative = 0;
    for (int i = 0; i < ratios.length; i++) {
      cumulative += ratios[i] / total;
      if (r < cumulative) return i.clamp(0, 2);
    }
    return (ratios.length - 1).clamp(0, 2);
  }

  int _pickLengthWithDistribution() {
    final r = _random.nextDouble();
    if (r < 0.05) return 1;
    if (r < 0.40) return 2;
    if (r < 0.75) return 3;
    if (r < 0.90) return 4;
    if (r < 0.97) return 5;
    return 6;
  }

  bool _validateSolvability(LevelData levelData) {
    try {
      final parsed = LevelParser.buildLogicalGrid(levelData);
      final solution = GameSolver.findSolution(parsed.logicalGrid);
      return solution != null && solution.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static DifficultyResult calculateDifficulty(LogicalGrid grid) {
    int maxLayerDepth = 0;
    final activeArrows = <String>{};
    int modifierCount = 0;

    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        int depth = 0;
        for (int l = 0; l < 3; l++) {
          final occupant = grid.matrix[x][y][l];
          if (occupant != null && occupant.state == ArrowState.active) {
            depth++;
            activeArrows.add(occupant.id);
          }
        }
        if (depth > maxLayerDepth) maxLayerDepth = depth;
        modifierCount += grid.getModifiersAt(x, y).length;
      }
    }

    final arrowCount = activeArrows.length;
    final validMoves = GameSolver.getValidMoves(grid);

    int longestChain = _calculateLongestChain(grid, activeArrows);
    double interlockScore = _calculateInterlockScore(grid, activeArrows);

    final avgBranching = validMoves.isEmpty ? 1.0 : validMoves.length.toDouble();

    final baseDI = (maxLayerDepth * 1.5) +
        (arrowCount / 10.0) +
        (modifierCount * 2.0) +
        (avgBranching / 3.0);

    final chainBonus = (longestChain / 5.0).clamp(0, 2.0);
    final interlockBonus = (interlockScore / 10.0).clamp(0, 1.5);
    final di = baseDI + chainBonus + interlockBonus;

    return DifficultyResult(
      difficultyIndex: di,
      maxLayerDepth: maxLayerDepth,
      arrowCount: arrowCount,
      modifierCount: modifierCount,
      avgBranchingFactor: avgBranching,
      longestChain: longestChain,
      interlockScore: interlockScore,
    );
  }

  static int _calculateLongestChain(LogicalGrid grid, Set<String> activeArrows) {
    final arrowMap = <String, ArrowEntity>{};
    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occ = grid.matrix[x][y][l];
          if (occ != null && activeArrows.contains(occ.id)) {
            arrowMap[occ.id] = occ;
          }
        }
      }
    }

    int maxChain = 0;
    for (final arrow in arrowMap.values) {
      final chain = _chainDepth(arrow, arrowMap, grid, <String>{});
      if (chain > maxChain) maxChain = chain;
    }
    return maxChain;
  }

  static int _chainDepth(ArrowEntity arrow, Map<String, ArrowEntity> allArrows,
      LogicalGrid grid, Set<String> visited) {
    if (visited.contains(arrow.id)) return 0;
    visited.add(arrow.id);

    final blockers = <ArrowEntity>{};
    var pos = arrow.getTipPosition();
    var dir = arrow.getTipDirection();

    while (true) {
      final step = ArrowEntity.getDirectionVector(dir);
      pos += step;
      final cx = pos.x.toInt();
      final cy = pos.y.toInt();
      if (cx < 0 || cx >= grid.columns || cy < 0 || cy >= grid.rows) break;

      bool blocked = false;
      for (int l = arrow.layerId; l < 3; l++) {
        final occ = grid.matrix[cx][cy][l];
        if (occ != null && occ.id != arrow.id &&
            allArrows.containsKey(occ.id)) {
          blockers.add(occ);
          blocked = true;
        }
      }
      if (!blocked) break;
    }

    if (blockers.isEmpty) return 1;

    int maxDepth = 0;
    for (final b in blockers) {
      final d = _chainDepth(b, allArrows, grid, Set.from(visited));
      if (d > maxDepth) maxDepth = d;
    }
    return maxDepth + 1;
  }

  static double _calculateInterlockScore(
      LogicalGrid grid, Set<String> activeArrows) {
    if (activeArrows.length < 2) return 0;

    final arrowMap = <String, ArrowEntity>{};
    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occ = grid.matrix[x][y][l];
          if (occ != null && activeArrows.contains(occ.id)) {
            arrowMap[occ.id] = occ;
          }
        }
      }
    }

    if (arrowMap.isEmpty) return 0;

    final n = arrowMap.length;
    int totalBlockingPairs = 0;

    for (final a in arrowMap.values) {
      for (final b in arrowMap.values) {
        if (a.id == b.id) continue;
        final cellsA = a.getOccupiedCells();
        for (final cellA in cellsA) {
          final cx = cellA.x.toInt();
          final cy = cellA.y.toInt();
          if (grid.isBlockedForArrow(b, cx, cy)) {
            totalBlockingPairs++;
            break;
          }
        }
      }
    }

    final maxPairs = n * (n - 1);
    return maxPairs > 0 ? (totalBlockingPairs.toDouble() / maxPairs) * 100 : 0;
  }

  static String _directionToString(Direction d) {
    switch (d) {
      case Direction.up:
        return 'up';
      case Direction.down:
        return 'down';
      case Direction.left:
        return 'left';
      case Direction.right:
        return 'right';
    }
  }

  static String _shapeToString(ArrowShape s) {
    switch (s) {
      case ArrowShape.straight: return 'straight';
      case ArrowShape.lShape: return 'lShape';
      case ArrowShape.uShape: return 'uShape';
      case ArrowShape.snake: return 'snake';
      case ArrowShape.zShape: return 'zShape';
      case ArrowShape.hook: return 'hook';
    }
  }

  static String _colorToString(ArrowColor c) {
    switch (c) {
      case ArrowColor.neutral:
        return 'neutral';
      case ArrowColor.red:
        return 'red';
      case ArrowColor.blue:
        return 'blue';
      case ArrowColor.green:
        return 'green';
      case ArrowColor.yellow:
        return 'yellow';
    }
  }

  static int gridSizeForLevel(int levelId) {
    if (levelId <= 25) return 6;
    if (levelId <= 50) return 8;
    if (levelId <= 75) return 10;
    if (levelId <= 100) return 12;
    return 14;
  }

  ArrowShape _pickShapeWithDistribution(int chapterId) {
    final r = _random.nextDouble();
    if (chapterId >= 2) {
      if (r < 0.25) return ArrowShape.straight;
      if (r < 0.55) return ArrowShape.lShape;
      if (r < 0.73) return ArrowShape.snake;
      if (r < 0.85) return ArrowShape.hook;
      if (r < 0.95) return ArrowShape.uShape;
      return ArrowShape.zShape;
    } else {
      if (r < 0.35) return ArrowShape.straight;
      if (r < 0.60) return ArrowShape.lShape;
      if (r < 0.75) return ArrowShape.snake;
      if (r < 0.85) return ArrowShape.hook;
      if (r < 0.95) return ArrowShape.uShape;
      return ArrowShape.zShape;
    }
  }

  int _getMinLengthForShape(ArrowShape shape) {
    switch (shape) {
      case ArrowShape.straight: return 1;
      case ArrowShape.lShape: return 2;
      case ArrowShape.hook: return 2;
      case ArrowShape.uShape: return 2;
      case ArrowShape.zShape: return 3;
      case ArrowShape.snake: return 3;
    }
  }

  double _calculateBoardOccupancy(LevelData level, ShapeMask shapeMask) {
    final occupied = <String>{};
    for (final arrow in level.arrows) {
      final cells = ArrowEntity.computeShapeCells(
        Vector2(arrow.startX.toDouble(), arrow.startY.toDouble()),
        parseDirection(arrow.direction),
        arrow.length,
        parseShape(arrow.shape),
      );
      for (final cell in cells) {
        occupied.add('${cell.x.toInt()},${cell.y.toInt()}');
      }
    }
    final scaled = shapeMask.scaleToFit(level.grid.columns, level.grid.rows);
    final allowed = scaled.getFilledPositions().length;
    final total = allowed > 0 ? allowed : (level.grid.columns * level.grid.rows);
    return total == 0 ? 0.0 : occupied.length / total;
  }

  LevelData? _buildBackwardBoard(int columns, int rows, ShapeMask shapeMask, int levelId, int chapterId) {
    final grid = LogicalGrid(columns: columns, rows: rows);
    final placedEntities = <ArrowEntity>[];
    final rng = _random;

    final bool isShapeLevel = levelId > 0 && levelId % 5 == 0;
    final chapterConfig = GenerationConfig.forChapter(chapterId);

    double targetOccupancy;
    if (isShapeLevel) {
      targetOccupancy = 0.88 + rng.nextDouble() * 0.07; // 0.88 to 0.95
    } else {
      if (chapterId == 1) {
        targetOccupancy = 0.80 + rng.nextDouble() * 0.05;
      } else if (chapterId == 2) {
        targetOccupancy = 0.85 + rng.nextDouble() * 0.05;
      } else {
        targetOccupancy = 0.90 + rng.nextDouble() * 0.05;
      }
    }

    final scaled = shapeMask.scaleToFit(columns, rows);
    final allowedCells = scaled.getFilledPositions();
    final allowedSet = allowedCells.map((v) => '${v.x.toInt()},${v.y.toInt()}').toSet();

    final totalCells = allowedCells.isNotEmpty ? allowedCells.length : columns * rows;
    final targetOccupiedCells = (totalCells * targetOccupancy).round().clamp(3, totalCells);

    // Calculate perimeter cells if shape level
    final perimeterCells = <Vector2>[];
    if (isShapeLevel) {
      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < columns; x++) {
          if (scaled.cells[y][x]) {
            bool isPerimeter = false;
            final neighbors = [
              Vector2((x - 1).toDouble(), y.toDouble()),
              Vector2((x + 1).toDouble(), y.toDouble()),
              Vector2(x.toDouble(), (y - 1).toDouble()),
              Vector2(x.toDouble(), (y + 1).toDouble()),
            ];
            for (final n in neighbors) {
              final nx = n.x.toInt();
              final ny = n.y.toInt();
              if (nx < 0 || nx >= columns || ny < 0 || ny >= rows || !scaled.cells[ny][nx]) {
                isPerimeter = true;
                break;
              }
            }
            if (isPerimeter) {
              perimeterCells.add(Vector2(x.toDouble(), y.toDouble()));
            }
          }
        }
      }
    }

    final colorValues = [
      ArrowColor.neutral, ArrowColor.red, ArrowColor.blue,
      ArrowColor.green, ArrowColor.yellow,
    ];

    final mods = <LevelTileModifierData>[];
    if (chapterConfig.includeModifiers || config.includeModifiers) {
      _placeModifiersBackward(grid, mods, columns, rows);
    }

    int arrowIdCounter = 1;
    int attempts = 0;
    int maxAttempts = 1200;

    final occupied2D = <String>{};

    double getPerimeterOccupancy() {
      if (perimeterCells.isEmpty) return 1.0;
      int occupiedCount = 0;
      for (final p in perimeterCells) {
        if (occupied2D.contains('${p.x.toInt()},${p.y.toInt()}')) {
          occupiedCount++;
        }
      }
      return occupiedCount / perimeterCells.length;
    }

    while (occupied2D.length < targetOccupiedCells && attempts < maxAttempts) {
      attempts++;

      int tx = 0;
      int ty = 0;
      bool selectedFromPerimeter = false;
      Direction? forcedDir;

      if (isShapeLevel && perimeterCells.isNotEmpty) {
        final perimeterOcc = getPerimeterOccupancy();
        if (perimeterOcc < 0.75 && rng.nextDouble() < 0.85) {
          final freePerimeter = perimeterCells.where((p) => !occupied2D.contains('${p.x.toInt()},${p.y.toInt()}')).toList();
          if (freePerimeter.isNotEmpty) {
            final cell = freePerimeter[rng.nextInt(freePerimeter.length)];
            tx = cell.x.toInt();
            ty = cell.y.toInt();
            selectedFromPerimeter = true;

            final onLeft = (tx - 1 < 0 || !scaled.cells[ty][tx - 1]);
            final onRight = (tx + 1 >= columns || !scaled.cells[ty][tx + 1]);
            final onTop = (ty - 1 < 0 || !scaled.cells[ty - 1][tx]);
            final onBottom = (ty + 1 >= rows || !scaled.cells[ty + 1][tx]);

            if (onLeft || onRight) {
              if (onTop || onBottom) {
                forcedDir = rng.nextBool() 
                    ? (rng.nextBool() ? Direction.up : Direction.down)
                    : (rng.nextBool() ? Direction.left : Direction.right);
              } else {
                forcedDir = rng.nextBool() ? Direction.up : Direction.down;
              }
            } else if (onTop || onBottom) {
              forcedDir = rng.nextBool() ? Direction.left : Direction.right;
            }
          }
        }
      }

      if (!selectedFromPerimeter) {
        if (allowedCells.isNotEmpty) {
          final cell = allowedCells[rng.nextInt(allowedCells.length)];
          tx = cell.x.toInt();
          ty = cell.y.toInt();
        } else {
          tx = rng.nextInt(columns);
          ty = rng.nextInt(rows);
        }
      }

      final mid = columns ~/ 2;
      final isOnSpine = tx == mid || tx == mid - 1;

      Direction dir;
      if (isShapeLevel) {
        if (selectedFromPerimeter && forcedDir != null) {
          dir = forcedDir;
        } else {
          if (isOnSpine) {
            dir = rng.nextBool() ? Direction.up : Direction.down;
          } else {
            dir = tx < mid - 1 ? Direction.left : Direction.right;
          }
        }
      } else {
        dir = Direction.values[rng.nextInt(4)];
      }

      ArrowShape shape = _pickShapeWithDistribution(chapterId);
      int length;
      int layer;

      if (isShapeLevel) {
        if (isOnSpine) {
          layer = 2;
          length = 3 + rng.nextInt(2); // 3 or 4
          final minLen = _getMinLengthForShape(shape);
          if (length < minLen) length = minLen;
        } else {
          layer = rng.nextBool() ? 1 : 0;
          length = rng.nextBool() ? 1 : 2;
          if (shape == ArrowShape.zShape || shape == ArrowShape.snake) {
            shape = rng.nextBool() ? ArrowShape.straight : ArrowShape.lShape;
          }
          final minLen = _getMinLengthForShape(shape);
          if (length < minLen) length = minLen;
          if (length > 2) length = 2;
        }
      } else {
        length = _pickLengthWithDistribution();
        final minLen = _getMinLengthForShape(shape);
        if (length < minLen) length = minLen;
        layer = _pickLayer();
      }

      final cells = ArrowEntity.computeShapeCells(
        Vector2(tx.toDouble(), ty.toDouble()), dir, length, shape);

      bool inBounds = true;
      for (final cell in cells) {
        final cx = cell.x.toInt();
        final cy = cell.y.toInt();
        if (cx < 0 || cx >= columns || cy < 0 || cy >= rows) {
          inBounds = false;
          break;
        }
        if (allowedCells.isNotEmpty && !allowedSet.contains('$cx,$cy')) {
          inBounds = false;
          break;
        }
      }
      if (!inBounds) continue;

      bool overlapsSameLayer = false;
      for (final cell in cells) {
        final cx = cell.x.toInt();
        final cy = cell.y.toInt();
        if (grid.matrix[cx][cy][layer] != null) {
          overlapsSameLayer = true;
          break;
        }
      }
      if (overlapsSameLayer) continue;

      bool coveredByHigher = false;
      for (final cell in cells) {
        final cx = cell.x.toInt();
        final cy = cell.y.toInt();
        for (int hl = layer + 1; hl < 3; hl++) {
          if (grid.matrix[cx][cy][hl] != null) {
            coveredByHigher = true;
            break;
          }
        }
        if (coveredByHigher) break;
      }
      if (coveredByHigher) continue;

      final entity = ArrowEntity(
        id: 'gen_A$arrowIdCounter',
        tailPosition: Vector2(tx.toDouble(), ty.toDouble()),
        length: length,
        direction: dir,
        layerId: layer,
        color: colorValues[rng.nextInt(colorValues.length)],
        shapeType: shape,
      );

      if (!_isOverlapAcceptable(entity, placedEntities)) continue;

      if (!grid.checkExitPath(entity)) continue;

      grid.registerArrow(entity);
      placedEntities.add(entity);
      arrowIdCounter++;

      for (final cell in cells) {
        occupied2D.add('${cell.x.toInt()},${cell.y.toInt()}');
      }
    }

    if (placedEntities.length < 3) return null;

    final levelArrows = placedEntities.map((e) => LevelArrowData(
      id: e.id,
      startX: e.tailPosition.x.toInt(),
      startY: e.tailPosition.y.toInt(),
      length: e.length,
      direction: _directionToString(e.direction),
      layer: e.layerId,
      color: _colorToString(e.color),
      shape: _shapeToString(e.shapeType),
    )).toList();

    return LevelData(
      metadata: LevelMetadata(
        levelId: levelId,
        chapterId: chapterId,
        targetMoves: levelArrows.length,
        shapeSilhouetteId: shapeMask.id,
      ),
      grid: LevelGrid(columns: columns, rows: rows),
      arrows: levelArrows,
      tileModifiers: mods,
    );
  }

  void _placeModifiersBackward(LogicalGrid grid, List<LevelTileModifierData> mods, int columns, int rows) {
    final rng = _random;
    final numIce = rng.nextInt(3);
    final placedCoords = <String>{};

    for (int i = 0; i < numIce; i++) {
      final x = rng.nextInt(columns);
      final y = rng.nextInt(rows);
      final key = '$x,$y';
      if (!placedCoords.contains(key)) {
        placedCoords.add(key);
        final mod = TileModifier(
          id: 'gen_M_ice_$i',
          type: SpecialTileType.ice,
          position: Vector2(x.toDouble(), y.toDouble()),
        );
        grid.addModifier(mod);
        mods.add(LevelTileModifierData(
          id: mod.id,
          type: 'ice',
          x: x,
          y: y,
        ));
      }
    }

    if (rng.nextDouble() < 0.3 && columns > 2 && rows > 2) {
      final entX = rng.nextInt(columns);
      final entY = rng.nextInt(rows);
      final extX = rng.nextInt(columns);
      final extY = rng.nextInt(rows);
      final entKey = '$entX,$entY';
      final extKey = '$extX,$extY';

      if (entKey != extKey && !placedCoords.contains(entKey) && !placedCoords.contains(extKey)) {
        placedCoords.add(entKey);
        placedCoords.add(extKey);
        final exitDir = Direction.values[rng.nextInt(4)];

        final entMod = TileModifier(
          id: 'gen_M_portal_ent',
          type: SpecialTileType.portalEntrance,
          position: Vector2(entX.toDouble(), entY.toDouble()),
          targetPortalId: 'gen_M_portal_ext',
        );
        final extMod = TileModifier(
          id: 'gen_M_portal_ext',
          type: SpecialTileType.portalExit,
          position: Vector2(extX.toDouble(), extY.toDouble()),
          exitDirection: exitDir,
        );

        grid.addModifier(entMod);
        grid.addModifier(extMod);

        mods.add(LevelTileModifierData(
          id: entMod.id,
          type: 'portal_entrance',
          x: entX,
          y: entY,
          targetPortalId: 'gen_M_portal_ext',
        ));
        mods.add(LevelTileModifierData(
          id: extMod.id,
          type: 'portal_exit',
          x: extX,
          y: extY,
          exitDirection: _directionToString(exitDir),
        ));
      }
    }

    if (rng.nextDouble() < 0.25) {
      final x = rng.nextInt(columns);
      final y = rng.nextInt(rows);
      final key = '$x,$y';
      if (!placedCoords.contains(key)) {
        placedCoords.add(key);
        final gateDir = Direction.values[rng.nextInt(4)];
        final mod = TileModifier(
          id: 'gen_M_gate',
          type: SpecialTileType.oneWayGate,
          position: Vector2(x.toDouble(), y.toDouble()),
          exitDirection: gateDir,
        );
        grid.addModifier(mod);
        mods.add(LevelTileModifierData(
          id: mod.id,
          type: 'one_way_gate',
          x: x,
          y: y,
          exitDirection: _directionToString(gateDir),
        ));
      }
    }
  }

  LevelData _generateFallbackBackward(int columns, int rows, ShapeMask shapeMask, int levelId, int chapterId) {
    for (int i = 0; i < 50; i++) {
      final candidate = _buildBackwardBoard(columns, rows, shapeMask, levelId, chapterId);
      if (candidate != null && _validateSolvability(candidate)) {
        return candidate;
      }
    }
    return _generateFallback(columns, rows, shapeMask, levelId, chapterId);
  }

  bool _isOverlapAcceptable(ArrowEntity candidate, List<ArrowEntity> existingEntities) {
    final candidateCells = candidate.getOccupiedCells();
    final candidateCoords = candidateCells.map((c) => '${c.x.toInt()},${c.y.toInt()}').toSet();

    for (final existing in existingEntities) {
      final existingCells = existing.getOccupiedCells();
      final existingCoords = existingCells.map((c) => '${c.x.toInt()},${c.y.toInt()}').toSet();

      final intersection = candidateCoords.intersection(existingCoords);
      if (intersection.isEmpty) continue;

      if (candidate.layerId == existing.layerId) {
        return false;
      }

      final isCandHorizontal = candidate.direction == Direction.left || candidate.direction == Direction.right;
      final isExistHorizontal = existing.direction == Direction.left || existing.direction == Direction.right;
      if (isCandHorizontal == isExistHorizontal) {
        return false;
      }

      final lower = candidate.layerId < existing.layerId ? candidate : existing;

      if (intersection.length > 1) {
        return false;
      }

      if (lower.length == 1) {
        return false;
      }

      final lowerCells = lower.getOccupiedCells();
      int coveredCount = 0;

      for (final cell in lowerCells) {
        final cx = cell.x.toInt();
        final cy = cell.y.toInt();
        final cellKey = '$cx,$cy';

        bool cellIsCovered = false;

        if (candidate.layerId > lower.layerId && candidateCoords.contains(cellKey)) {
          cellIsCovered = true;
        }

        if (existing.layerId > lower.layerId && existingCoords.contains(cellKey)) {
          cellIsCovered = true;
        }

        if (!cellIsCovered) {
          for (final other in existingEntities) {
            if (other.id == candidate.id || other.id == existing.id) continue;
            if (other.layerId > lower.layerId) {
              final otherCells = other.getOccupiedCells();
              if (otherCells.any((oc) => oc.x.toInt() == cx && oc.y.toInt() == cy)) {
                cellIsCovered = true;
                break;
              }
            }
          }
        }

        if (cellIsCovered) {
          coveredCount++;
        }
      }

      if (coveredCount >= lower.length) {
        return false;
      }
    }
    return true;
  }
}

LevelData generateDailyChallengeLevel(int seed) {
  final random = Random(seed);
  final shape = kShapeMasks[random.nextInt(kShapeMasks.length)];
  const cols = 6;
  const rows = 9;
  final generator = ProceduralGenerator(
    config: GenerationConfig(
      seed: seed,
      density: 0.55,
      layerRatios: [0.8, 0.2, 0.0],
      minDifficulty: 1.0,
      maxDifficulty: 5.0,
    ),
  );
  return generator.generate(cols, rows, shape);
}

LevelData generateLevelForChapter(int levelId, int chapterId, {int? seed}) {
  final rng = seed != null ? Random(seed) : Random();
  
  ShapeMask shape;
  int cols;
  int rows;
  
  if (levelId % 5 == 0) {
    final shapeIndex = ((levelId ~/ 5) - 1) % 6;
    final shapeId = [
      'kinetic_rocket',
      'royal_crown',
      'imperial_sword',
      'faceted_diamond',
      'large_heart',
      'horse_face'
    ][shapeIndex];
    shape = getShapeById(shapeId);
    cols = shape.width;
    rows = shape.height;
  } else {
    shape = kShapeMasks[rng.nextInt(kShapeMasks.length)];
    final size = ProceduralGenerator.gridSizeForLevel(levelId);
    cols = size;
    rows = (size * 1.5).round();
  }
  
  final config = GenerationConfig.forChapter(chapterId);
  final generator = ProceduralGenerator(config: config);
  
  return generator.generate(cols, rows, shape,
      levelId: levelId, chapterId: chapterId);
}
