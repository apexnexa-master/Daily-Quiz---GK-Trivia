import '../logic/grid_matrix.dart';

class LevelMetadata {
  final String schemaVersion;
  final int levelId;
  final int chapterId;
  final int targetMoves;
  final int bossMoveLimit;
  final String? shapeSilhouetteId;

  LevelMetadata({
    this.schemaVersion = '1.0.0',
    required this.levelId,
    required this.chapterId,
    required this.targetMoves,
    this.bossMoveLimit = 0,
    this.shapeSilhouetteId,
  });
}

class LevelGrid {
  final int columns;
  final int rows;

  LevelGrid({required this.columns, required this.rows});
}

class LevelArrowData {
  final String id;
  final int startX;
  final int startY;
  final int length;
  final String direction;
  final int layer;
  final String color;
  final String shape;

  LevelArrowData({
    required this.id,
    required this.startX,
    required this.startY,
    required this.length,
    required this.direction,
    required this.layer,
    this.color = 'neutral',
    this.shape = 'straight',
  });
}

class LevelTileModifierData {
  final String id;
  final String type;
  final int x;
  final int y;
  final String? targetPortalId;
  final String? exitDirection;
  final String? requiredColor;
  final int? hitPoints;

  LevelTileModifierData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.targetPortalId,
    this.exitDirection,
    this.requiredColor,
    this.hitPoints,
  });
}

class LevelData {
  final LevelMetadata metadata;
  final LevelGrid grid;
  final List<LevelArrowData> arrows;
  final List<LevelTileModifierData> tileModifiers;

  LevelData({
    required this.metadata,
    required this.grid,
    required this.arrows,
    this.tileModifiers = const [],
  });
}

class ParsedLevel {
  final LevelData levelData;
  final LogicalGrid logicalGrid;
  final List<ArrowEntity> arrowEntities;

  ParsedLevel({
    required this.levelData,
    required this.logicalGrid,
    required this.arrowEntities,
  });
}

Direction parseDirection(String dir) {
  switch (dir) {
    case 'up':
      return Direction.up;
    case 'down':
      return Direction.down;
    case 'left':
      return Direction.left;
    case 'right':
      return Direction.right;
    default:
      throw ArgumentError('Unknown direction: $dir');
  }
}

ArrowColor parseColor(String color) {
  switch (color) {
    case 'neutral':
      return ArrowColor.neutral;
    case 'red':
      return ArrowColor.red;
    case 'blue':
      return ArrowColor.blue;
    case 'green':
      return ArrowColor.green;
    case 'yellow':
      return ArrowColor.yellow;
    default:
      throw ArgumentError('Unknown color: $color');
  }
}

ArrowShape parseShape(String shape) {
  switch (shape) {
    case 'straight':
      return ArrowShape.straight;
    case 'lShape':
      return ArrowShape.lShape;
    case 'uShape':
      return ArrowShape.uShape;
    case 'snake':
      return ArrowShape.snake;
    case 'zShape':
      return ArrowShape.zShape;
    case 'hook':
      return ArrowShape.hook;
    default:
      return ArrowShape.straight;
  }
}

SpecialTileType parseModifierType(String type) {
  switch (type) {
    case 'ice':
      return SpecialTileType.ice;
    case 'portal_entrance':
      return SpecialTileType.portalEntrance;
    case 'portal_exit':
      return SpecialTileType.portalExit;
    case 'color_lock':
      return SpecialTileType.colorLock;
    case 'one_way_gate':
      return SpecialTileType.oneWayGate;
    case 'breakable_wall':
      return SpecialTileType.breakableWall;
    default:
      throw ArgumentError('Unknown modifier type: $type');
  }
}
