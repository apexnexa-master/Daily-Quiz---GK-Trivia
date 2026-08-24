// lib/presentation/screens/games/one_line/one_line_models.dart
//
// Data model for the One-Line (single-stroke / Eulerian path) puzzle.
// A level is a small planar graph: vertices with normalized board
// positions plus undirected edges. A puzzle is solved when the player
// traces every edge exactly once with one continuous stroke — an
// Eulerian trail. Levels always ship a precomputed solution so tests,
// hints and intro choreography can rely on it.

import 'package:flutter/material.dart';

/// Fraction of the board's shortest side kept as an inset between the
/// widget edge and the playable figure area. Shared by the painter
/// (drawing) and the screen (hit-testing) so both use IDENTICAL
/// geometry — a mismatch here makes strokes snap in the wrong place
/// near the figure's extremes.
const double kOneLineBoardInset = 0.03;

class OneLineVertex {
  final int id;

  /// Normalized position inside the square board, 0..1 on both axes.
  final Offset position;

  const OneLineVertex({required this.id, required this.position});
}

class OneLineEdge {
  final int id;
  final int a;
  final int b;

  const OneLineEdge({required this.id, required this.a, required this.b});

  int other(int vertexId) => vertexId == a ? b : a;
  bool touches(int vertexId) => a == vertexId || b == vertexId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneLineEdge && other.id == id && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(id, a, b);
}

class OneLineLevel {
  final int number;
  final String name;
  final String difficulty;
  final List<OneLineVertex> vertices;
  final List<OneLineEdge> edges;

  /// Vertex ids forming one full Eulerian trail (edges.length + 1 entries).
  final List<int> solution;
  final List<int> suggestedStarts;
  final int parSeconds;

  const OneLineLevel({
    required this.number,
    required this.name,
    required this.difficulty,
    required this.vertices,
    required this.edges,
    required this.solution,
    required this.suggestedStarts,
    required this.parSeconds,
  });

  int get edgeCount => edges.length;
}
