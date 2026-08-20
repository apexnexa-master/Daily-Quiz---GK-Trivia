import 'one_line_models.dart';

class OneLineEngine {
  late OneLineLevel _level;
  late OneLineShape _shape;
  late List<OneLineEdge> _edges;
  List<int> _currentPath = [];
  Set<int> _traversedEdgeIds = {};

  OneLineLevel get level => _level;
  OneLineShape get shape => _shape;
  List<int> get currentPath => _currentPath;
  Set<int> get traversedEdgeIds => _traversedEdgeIds;

  void reset(OneLineLevel level) {
    _level = level;
    _shape = level.shape;
    // Deep copy edges so traversal state is fresh
    _edges = _shape.edges
        .map((e) => OneLineEdge(
              id: e.id,
              startVertexId: e.startVertexId,
              endVertexId: e.endVertexId,
            ))
        .toList();
    _currentPath = [];
    _traversedEdgeIds = {};
  }

  /// Start a path from a vertex
  bool startPath(int vertexId) {
    if (!_shape.vertices.any((v) => v.id == vertexId)) return false;
    _currentPath = [vertexId];
    return true;
  }

  /// Try to move to an adjacent vertex
  bool moveToVertex(int vertexId) {
    if (_currentPath.isEmpty) return false;

    final currentVertex = _currentPath.last;

    // Find edge between current and target
    final edge = _findEdge(currentVertex, vertexId);
    if (edge == null) return false;

    // Check if edge already traversed
    if (_traversedEdgeIds.contains(edge.id)) return false;

    // Traverse the edge
    _traversedEdgeIds.add(edge.id);
    edge.traversed = true;
    _currentPath.add(vertexId);
    return true;
  }

  /// Check if a specific edge can be traversed
  bool canTraverseEdge(int edgeId) {
    return !_traversedEdgeIds.contains(edgeId);
  }

  /// Check if there's an edge between two vertices
  OneLineEdge? _findEdge(int fromId, int toId) {
    for (final edge in _edges) {
      if ((edge.startVertexId == fromId && edge.endVertexId == toId) ||
          (edge.startVertexId == toId && edge.endVertexId == fromId)) {
        return edge;
      }
    }
    return null;
  }

  /// Check if the puzzle is complete (all edges traversed)
  bool isComplete() {
    return _traversedEdgeIds.length == _edges.length;
  }

  /// Check if the path has dead-ended (current vertex has no untraversed edges)
  bool isDeadEnd() {
    if (_currentPath.isEmpty) return false;
    final currentVertex = _currentPath.last;

    for (final edge in _edges) {
      if (_traversedEdgeIds.contains(edge.id)) continue;
      if (edge.startVertexId == currentVertex ||
          edge.endVertexId == currentVertex) {
        return false;
      }
    }
    return true;
  }

  /// Get progress as a fraction (0.0 to 1.0)
  double get progress {
    if (_edges.isEmpty) return 0.0;
    return _traversedEdgeIds.length / _edges.length;
  }

  /// Get count of traversed edges
  int get traversedCount => _traversedEdgeIds.length;

  /// Get total edge count
  int get totalEdges => _edges.length;

  /// Get current vertex (last in path)
  int? get currentVertex =>
      _currentPath.isEmpty ? null : _currentPath.last;

  /// Get untraversed edges connected to a vertex
  List<OneLineEdge> untraversedEdgesFrom(int vertexId) {
    return _edges
        .where((e) =>
            !_traversedEdgeIds.contains(e.id) &&
            (e.startVertexId == vertexId || e.endVertexId == vertexId))
        .toList();
  }

  /// Get all vertices connected by untraversed edges from a vertex
  List<int> availableMovesFrom(int vertexId) {
    final moves = <int>[];
    for (final edge in _edges) {
      if (_traversedEdgeIds.contains(edge.id)) continue;
      if (edge.startVertexId == vertexId) {
        moves.add(edge.endVertexId);
      } else if (edge.endVertexId == vertexId) {
        moves.add(edge.startVertexId);
      }
    }
    return moves;
  }
}
