import '../logic/game_solver.dart';
import 'level_schema.dart';

class LevelValidationResult {
  final bool isValid;
  final List<String> errors;

  LevelValidationResult({required this.isValid, required this.errors});
}

class LevelValidator {
  static LevelValidationResult validate(ParsedLevel parsed) {
    final errors = <String>[];

    _validateGridBounds(parsed, errors);
    _validateArrowPositions(parsed, errors);
    _validateModifierPositions(parsed, errors);
    _validateArrowIds(parsed, errors);
    _validateModifierIds(parsed, errors);
    _validatePortalLinks(parsed, errors);
    _validateSolvability(parsed, errors);

    return LevelValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static void _validateGridBounds(ParsedLevel parsed, List<String> errors) {
    final cols = parsed.levelData.grid.columns;
    final rows = parsed.levelData.grid.rows;
    if (cols < 1 || rows < 1) {
      errors.add('Grid dimensions must be at least 1x1');
    }
    if (cols > 14 || rows > 14) {
      errors.add('Grid dimensions exceed maximum 14x14');
    }
  }

  static void _validateArrowPositions(
      ParsedLevel parsed, List<String> errors) {
    final cols = parsed.levelData.grid.columns;
    final rows = parsed.levelData.grid.rows;
    for (final ad in parsed.levelData.arrows) {
      if (ad.startX < 0 || ad.startX >= cols) {
        errors.add('Arrow ${ad.id}: start_x ${ad.startX} out of grid width');
      }
      if (ad.startY < 0 || ad.startY >= rows) {
        errors.add('Arrow ${ad.id}: start_y ${ad.startY} out of grid height');
      }
      if (ad.length < 1 || ad.length > 8) {
        errors.add('Arrow ${ad.id}: length ${ad.length} out of range (1-8)');
      }
      if (ad.layer < 0 || ad.layer > 2) {
        errors.add('Arrow ${ad.id}: layer ${ad.layer} out of range (0-2)');
      }
    }
  }

  static void _validateModifierPositions(
      ParsedLevel parsed, List<String> errors) {
    final cols = parsed.levelData.grid.columns;
    final rows = parsed.levelData.grid.rows;
    for (final md in parsed.levelData.tileModifiers) {
      if (md.x < 0 || md.x >= cols) {
        errors.add('Modifier ${md.id}: x ${md.x} out of grid width');
      }
      if (md.y < 0 || md.y >= rows) {
        errors.add('Modifier ${md.id}: y ${md.y} out of grid height');
      }
    }
  }

  static void _validateArrowIds(ParsedLevel parsed, List<String> errors) {
    final ids = <String>{};
    for (final ad in parsed.levelData.arrows) {
      if (ids.contains(ad.id)) {
        errors.add('Duplicate arrow id: ${ad.id}');
      }
      ids.add(ad.id);
    }
  }

  static void _validateModifierIds(ParsedLevel parsed, List<String> errors) {
    final ids = <String>{};
    for (final md in parsed.levelData.tileModifiers) {
      if (ids.contains(md.id)) {
        errors.add('Duplicate modifier id: ${md.id}');
      }
      ids.add(md.id);
    }
  }

  static void _validatePortalLinks(
      ParsedLevel parsed, List<String> errors) {
    final modsById = <String, LevelTileModifierData>{};
    for (final md in parsed.levelData.tileModifiers) {
      modsById[md.id] = md;
    }

    for (final md in parsed.levelData.tileModifiers) {
      if (md.type == 'portal_entrance') {
        if (md.targetPortalId == null) {
          errors.add(
              'Portal entrance ${md.id} is missing target_portal_id');
        } else if (!modsById.containsKey(md.targetPortalId)) {
          errors.add(
              'Portal entrance ${md.id} targets nonexistent ${md.targetPortalId}');
        } else {
          final target = modsById[md.targetPortalId]!;
          if (target.type != 'portal_exit') {
            errors.add(
                'Portal entrance ${md.id} target ${md.targetPortalId} is not a portal_exit');
          }
        }
      }
    }
  }

  static void _validateSolvability(
      ParsedLevel parsed, List<String> errors) {
    final solution = GameSolver.findSolution(parsed.logicalGrid);
    if (solution == null) {
      errors.add('Level has no valid solution (dead end)');
    }
  }
}
