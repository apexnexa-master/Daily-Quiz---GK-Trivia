import 'package:flutter/material.dart';

class OneLineVertex {
  final int id;
  final Offset position;
  const OneLineVertex({required this.id, required this.position});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneLineVertex && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class OneLineEdge {
  final int id;
  final int startVertexId;
  final int endVertexId;
  bool traversed;

  OneLineEdge({
    required this.id,
    required this.startVertexId,
    required this.endVertexId,
    this.traversed = false,
  });

  int otherVertex(int vertexId) {
    return vertexId == startVertexId ? endVertexId : startVertexId;
  }
}

class OneLineShape {
  final String name;
  final List<OneLineVertex> vertices;
  final List<OneLineEdge> edges;
  final bool hasEulerPath;
  final List<int> oddDegreeVertices;
  final int suggestedStartVertex;

  const OneLineShape({
    required this.name,
    required this.vertices,
    required this.edges,
    this.hasEulerPath = true,
    this.oddDegreeVertices = const [],
    this.suggestedStartVertex = 0,
  });

  int degreeOf(int vertexId) {
    int count = 0;
    for (final edge in edges) {
      if (edge.startVertexId == vertexId || edge.endVertexId == vertexId) {
        count++;
      }
    }
    return count;
  }

  List<int> adjacentVertices(int vertexId) {
    final adjacent = <int>[];
    for (final edge in edges) {
      if (edge.startVertexId == vertexId) {
        adjacent.add(edge.endVertexId);
      } else if (edge.endVertexId == vertexId) {
        adjacent.add(edge.startVertexId);
      }
    }
    return adjacent;
  }
}

class OneLineLevel {
  final int levelNumber;
  final OneLineShape shape;
  final String hint;
  final int parTime;
  const OneLineLevel({
    required this.levelNumber,
    required this.shape,
    required this.hint,
    required this.parTime,
  });
}
