import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import '../logic/grid_matrix.dart';
import 'level_schema.dart';

class LevelParseException implements Exception {
  final String message;
  LevelParseException(this.message);

  @override
  String toString() => 'LevelParseException: $message';
}

class LevelParser {
  static LevelData parseLevelData(Map<String, dynamic> json) {
    try {
      final metaJson = json['metadata'] as Map<String, dynamic>;
      final metadata = LevelMetadata(
        schemaVersion: metaJson['schema_version'] as String? ?? '1.0.0',
        levelId: metaJson['level_id'] as int,
        chapterId: metaJson['chapter_id'] as int,
        targetMoves: metaJson['target_moves'] as int,
        bossMoveLimit: metaJson['boss_move_limit'] as int? ?? 0,
        shapeSilhouetteId: metaJson['shape_silhouette_id'] as String?,
      );

      final gridJson = json['grid'] as Map<String, dynamic>;
      final grid = LevelGrid(
        columns: gridJson['columns'] as int,
        rows: gridJson['rows'] as int,
      );

      final arrowsJson = json['arrows'] as List<dynamic>;
      final arrows = arrowsJson.map((a) {
        final am = a as Map<String, dynamic>;
        return LevelArrowData(
          id: am['id'] as String,
          startX: am['start_x'] as int,
          startY: am['start_y'] as int,
          length: am['length'] as int,
          direction: am['direction'] as String,
          layer: am['layer'] as int,
          color: am['color'] as String? ?? 'neutral',
          shape: am['shape'] as String? ?? 'straight',
        );
      }).toList();

      final modsJson = json['tile_modifiers'] as List<dynamic>? ?? [];
      final tileModifiers = modsJson.map((m) {
        final mm = m as Map<String, dynamic>;
        return LevelTileModifierData(
          id: mm['id'] as String,
          type: mm['type'] as String,
          x: mm['x'] as int,
          y: mm['y'] as int,
          targetPortalId: mm['target_portal_id'] as String?,
          exitDirection: mm['exit_direction'] as String?,
          requiredColor: mm['required_color'] as String?,
          hitPoints: mm['hit_points'] as int?,
        );
      }).toList();

      return LevelData(
        metadata: metadata,
        grid: grid,
        arrows: arrows,
        tileModifiers: tileModifiers,
      );
    } catch (e) {
      if (e is LevelParseException) rethrow;
      throw LevelParseException('Failed to parse level data: $e');
    }
  }

  static ParsedLevel buildLogicalGrid(LevelData levelData) {
    final logicalGrid = LogicalGrid(
      columns: levelData.grid.columns,
      rows: levelData.grid.rows,
    );
    final arrowEntities = <ArrowEntity>[];

    for (final ad in levelData.arrows) {
      final arrow = ArrowEntity(
        id: ad.id,
        tailPosition: Vector2(ad.startX.toDouble(), ad.startY.toDouble()),
        length: ad.length,
        direction: parseDirection(ad.direction),
        layerId: ad.layer,
        color: parseColor(ad.color),
        shapeType: parseShape(ad.shape),
      );
      logicalGrid.registerArrow(arrow);
      arrowEntities.add(arrow);
    }

    for (final md in levelData.tileModifiers) {
      final modifier = TileModifier(
        id: md.id,
        type: parseModifierType(md.type),
        position: Vector2(md.x.toDouble(), md.y.toDouble()),
        targetPortalId: md.targetPortalId,
        exitDirection: md.exitDirection != null
            ? parseDirection(md.exitDirection!)
            : null,
        requiredColor: md.requiredColor != null
            ? parseColor(md.requiredColor!)
            : null,
        hitPoints: md.hitPoints ?? 1,
      );
      logicalGrid.addModifier(modifier);
    }

    return ParsedLevel(
      levelData: levelData,
      logicalGrid: logicalGrid,
      arrowEntities: arrowEntities,
    );
  }

  static ParsedLevel parseAndBuild(Map<String, dynamic> json) {
    final levelData = parseLevelData(json);
    _validateLevelData(levelData);
    return buildLogicalGrid(levelData);
  }

  static void _validateLevelData(LevelData data) {
    final cols = data.grid.columns;
    final rows = data.grid.rows;
    final arrowIds = <String>{};
    final modIds = <String>{};

    for (final a in data.arrows) {
      if (a.startX < 0 || a.startX >= cols) {
        throw LevelParseException('Arrow ${a.id}: start_x ${a.startX} out of grid width');
      }
      if (a.startY < 0 || a.startY >= rows) {
        throw LevelParseException('Arrow ${a.id}: start_y ${a.startY} out of grid height');
      }
      if (a.length < 1 || a.length > 6) {
        throw LevelParseException('Arrow ${a.id}: length ${a.length} out of range (1-6)');
      }
      if (a.layer < 0 || a.layer > 2) {
        throw LevelParseException('Arrow ${a.id}: layer ${a.layer} out of range (0-2)');
      }
      if (arrowIds.contains(a.id)) {
        throw LevelParseException('Duplicate arrow id: ${a.id}');
      }
      arrowIds.add(a.id);
    }

    for (final m in data.tileModifiers) {
      if (m.x < 0 || m.x >= cols) {
        throw LevelParseException('Modifier ${m.id}: x ${m.x} out of grid width');
      }
      if (m.y < 0 || m.y >= rows) {
        throw LevelParseException('Modifier ${m.id}: y ${m.y} out of grid height');
      }
      if (modIds.contains(m.id)) {
        throw LevelParseException('Duplicate modifier id: ${m.id}');
      }
      modIds.add(m.id);
    }
  }

  static ParsedLevel parseJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return parseAndBuild(json);
    } catch (e) {
      if (e is LevelParseException) rethrow;
      throw LevelParseException('Failed to parse JSON string: $e');
    }
  }
}
