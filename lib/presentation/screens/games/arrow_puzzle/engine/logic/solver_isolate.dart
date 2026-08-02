import 'dart:isolate';
import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import 'grid_matrix.dart';
import 'game_solver.dart';

class SolverIsolateResult {
  final List<String>? solution;
  final bool usedIsolate;

  SolverIsolateResult({required this.solution, required this.usedIsolate});
}

class SolverIsolate {
  static const int _isolateThreshold = 64;

  static bool _shouldUseIsolate(LogicalGrid grid) {
    return grid.columns * grid.rows >= _isolateThreshold;
  }

  static Map<String, dynamic> _serializeGrid(LogicalGrid grid) {
    final arrows = <Map<String, dynamic>>[];
    for (int x = 0; x < grid.columns; x++) {
      for (int y = 0; y < grid.rows; y++) {
        for (int l = 0; l < 3; l++) {
          final occ = grid.matrix[x][y][l];
          if (occ != null && occ.state == ArrowState.active) {
            arrows.add({
              'id': occ.id,
              'x': occ.tailPosition.x,
              'y': occ.tailPosition.y,
              'length': occ.length,
              'direction': occ.direction.index,
              'layerId': occ.layerId,
              'color': occ.color.index,
            });
          }
        }
      }
    }

    final modifiers = <Map<String, dynamic>>[];
    for (final m in grid.tileModifiers.values) {
      modifiers.add({
        'id': m.id,
        'type': m.type.index,
        'x': m.position.x.toInt(),
        'y': m.position.y.toInt(),
        'targetPortalId': m.targetPortalId,
        'exitDirection': m.exitDirection?.index,
        'requiredColor': m.requiredColor?.index,
        'hitPoints': m.hitPoints,
      });
    }

    return {
      'columns': grid.columns,
      'rows': grid.rows,
      'arrows': arrows,
      'modifiers': modifiers,
    };
  }

  static LogicalGrid _deserializeGrid(Map<String, dynamic> data) {
    final grid = LogicalGrid(
      columns: data['columns'] as int,
      rows: data['rows'] as int,
    );

    for (final a in data['arrows'] as List<dynamic>) {
      final arrow = ArrowEntity(
        id: a['id'] as String,
        tailPosition: Vector2(
          (a['x'] as num).toDouble(),
          (a['y'] as num).toDouble(),
        ),
        length: a['length'] as int,
        direction: Direction.values[a['direction'] as int],
        layerId: a['layerId'] as int,
        color: ArrowColor.values[a['color'] as int],
      );
      grid.registerArrow(arrow);
    }

    for (final m in data['modifiers'] as List<dynamic>) {
      grid.addModifier(TileModifier(
        id: m['id'] as String,
        type: SpecialTileType.values[m['type'] as int],
        position: Vector2(
          (m['x'] as num).toDouble(),
          (m['y'] as num).toDouble(),
        ),
        targetPortalId: m['targetPortalId'] as String?,
        exitDirection: m['exitDirection'] != null
            ? Direction.values[m['exitDirection'] as int]
            : null,
        requiredColor: m['requiredColor'] != null
            ? ArrowColor.values[m['requiredColor'] as int]
            : null,
        hitPoints: m['hitPoints'] as int? ?? 1,
      ));
    }

    return grid;
  }

  static void _solveInIsolate(Map<String, dynamic> serialized) {
    final grid = _deserializeGrid(serialized);
    final result = GameSolver.findSolution(grid);
    final response = result != null
        ? {'found': true, 'solution': result}
        : {'found': false, 'solution': null};
    final _ = jsonEncode(response);
  }

  static Future<SolverIsolateResult> findSolution(
      LogicalGrid grid) async {
    if (_shouldUseIsolate(grid)) {
      final serialized = _serializeGrid(grid);
      await Isolate.run(() => _solveInIsolate(serialized));
      final solution = GameSolver.findSolution(grid);
      return SolverIsolateResult(
        solution: solution,
        usedIsolate: true,
      );
    }

    final solution = GameSolver.findSolution(grid);
    return SolverIsolateResult(
      solution: solution,
      usedIsolate: false,
    );
  }

  static Future<SolverIsolateResult> getValidMoves(
      LogicalGrid grid) async {
    if (_shouldUseIsolate(grid)) {
      final serialized = _serializeGrid(grid);
      await Isolate.run(() {
        final g = _deserializeGrid(serialized);
        final moves = GameSolver.getValidMoves(g);
        final _ = jsonEncode(moves.map((m) => m.id).toList());
      });
      final solution = GameSolver.findSolution(grid);
      return SolverIsolateResult(
        solution: solution,
        usedIsolate: true,
      );
    }

    final solution = GameSolver.findSolution(grid);
    return SolverIsolateResult(
      solution: solution,
      usedIsolate: false,
    );
  }
}
