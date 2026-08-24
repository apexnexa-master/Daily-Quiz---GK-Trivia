// lib/presentation/screens/games/one_line/one_line_engine.dart
//
// Pure game-state machine for One-Line puzzles. Owns the traced path
// and exposes only legal operations; the screen never mutates state
// directly.
//
// The stroke may BEGIN anywhere along the outline: [startOnEdge] splits
// the touched segment at parameter t into two half-edges joined by a
// virtual touch-point vertex. Generated levels are Eulerian circuits
// (connected, every degree even), so a full circuit from the touch
// point always exists. Win = every edge half traced; the stroke closes
// back where it began.

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'one_line_models.dart';

class OneLineEngine {
  /// Drag distance (as a fraction of an edge) past which the previewed
  /// segment commits to the far vertex.
  static const double commitFraction = 0.62;

  List<OneLineVertex> _pristineVertices = const [];
  List<OneLineEdge> _pristineEdges = const [];

  // Working graph — equals pristine until a mid-edge split occurs.
  List<OneLineVertex> _vertices = const [];
  List<OneLineEdge> _edges = const [];
  Map<int, OneLineEdge> _edgeById = {};
  Map<int, List<int>> _incident = {};

  final List<int> _path = [];
  final Set<int> _traced = {};
  int _backtracks = 0;
  int? _splitEdgeId;

  // Live drag preview: the untraced edge currently being drawn from
  // head, and how far along it (0..1) the pen has travelled.
  int? _previewEdgeId;
  double _previewT = 0;

  void reset(OneLineLevel level) {
    _pristineVertices = level.vertices;
    _pristineEdges = level.edges;
    _restorePristine();
    _path.clear();
    _traced.clear();
    _backtracks = 0;
    _splitEdgeId = null;
  }

  void _restorePristine() {
    _vertices = List.of(_pristineVertices);
    _edges = List.of(_pristineEdges);
    _rebuildIncident();
  }

  void _rebuildIncident() {
    _edgeById = {for (final e in _edges) e.id: e};
    _incident = {};
    for (final e in _edges) {
      (_incident[e.a] ??= []).add(e.id);
      (_incident[e.b] ??= []).add(e.id);
    }
  }

  /// Working graph accessors (include the split vertex/edges mid-run).
  List<OneLineVertex> get vertices => _vertices;
  List<OneLineEdge> get edges => _edges;
  List<int> get path => List.unmodifiable(_path);
  Set<int> get tracedEdgeIds => Set.unmodifiable(_traced);
  int? get splitEdgeId => _splitEdgeId;
  int get backtracks => _backtracks;

  int? get head => _path.isEmpty ? null : _path.last;
  int? get tail => _path.isEmpty ? null : _path.first;

  bool get started => _path.isNotEmpty;
  bool get isComplete => _edges.isNotEmpty && _traced.length == _edges.length;

  /// Live preview accessors for the painter.
  int? get previewEdgeId => started && !isComplete ? _previewEdgeId : null;
  double get previewT => _previewT.clamp(0.0, 1.0);

  void clearPreview() {
    _previewEdgeId = null;
    _previewT = 0;
  }

  /// The vertex at the far end of [edgeId] as seen from head.
  int? farVertexOf(int edgeId) {
    final e = _edgeById[edgeId];
    if (e == null || head == null) return null;
    return e.other(head!);
  }

  OneLineEdge? edgeById(int edgeId) => _edgeById[edgeId];

  /// Updates the live drag progress along an untraced edge incident to
  /// head. [t] is measured from head toward the far vertex. When the
  /// pen crosses the commit threshold the move fires automatically, so
  /// the stroke keeps flowing through junctions without lifting.
  /// Returns 'traced' when a commit happened this call.
  String? setPreview(int edgeId, double t) {
    if (!started || isComplete) return null;
    final e = _edgeById[edgeId];
    if (e == null || _traced.contains(e.id)) return null;
    final h = head!;
    if (!e.touches(h)) return null;

    if (t >= commitFraction) {
      clearPreview();
      return moveTo(e.other(h));
    }
    _previewEdgeId = edgeId;
    _previewT = t.clamp(0.0, 1.0);
    return null;
  }

  double get progress => _edges.isEmpty ? 0 : _traced.length / _edges.length;
  int get tracedCount => _traced.length;
  int get totalEdges => _edges.length;

  /// True when the stroke has begun but the head has no way to continue
  /// while edges remain elsewhere — a dead end.
  bool get isDeadEnd {
    if (!started || isComplete) return false;
    return availableMovesFrom(head!).isEmpty;
  }

  /// Vertex ids reachable from [vertexId] via an untraced edge.
  List<int> availableMovesFrom(int vertexId) {
    final moves = <int>[];
    for (final eid in _incident[vertexId] ?? const <int>[]) {
      if (_traced.contains(eid)) continue;
      moves.add(_edgeById[eid]!.other(vertexId));
    }
    return moves;
  }

  /// Begins a fresh stroke at [vertexId]. Fails mid-stroke; call
  /// [clearPath] first to restart the trace.
  bool startAt(int vertexId) {
    if (started) return false;
    if (!_vertices.any((v) => v.id == vertexId)) return false;
    _path.add(vertexId);
    return true;
  }

  /// Begins the stroke at parameter [t] (0..1, from edge.a toward
  /// edge.b) along untraced edge [edgeId]. Touches exactly on an
  /// endpoint simply start at that vertex; otherwise the edge is split
  /// into two half-edges around a new virtual vertex.
  bool startOnEdge(int edgeId, double t) {
    if (started) return false;
    final idx = _edges.indexWhere((e) => e.id == edgeId);
    if (idx < 0) return false;
    final edge = _edges[idx];

    if (t <= 0.001) return startAt(edge.a);
    if (t >= 0.999) return startAt(edge.b);

    // Split: A ── P ── B replaces A ── B. P has degree 2 (even), so the
    // all-even circuit invariant survives and the puzzle stays solvable
    // from precisely this spot.
    final va = _vertices.firstWhere((v) => v.id == edge.a);
    final vb = _vertices.firstWhere((v) => v.id == edge.b);
    final pId = _vertices.map((v) => v.id).reduce(math.max) + 1;
    final nextId = _nextEdgeId();
    final pa = OneLineEdge(id: nextId, a: edge.a, b: pId);
    final pb = OneLineEdge(id: nextId + 1, a: pId, b: edge.b);

    _vertices = [
      ..._vertices,
      OneLineVertex(
          id: pId, position: Offset.lerp(va.position, vb.position, t)!),
    ];
    _edges
      ..removeAt(idx)
      ..addAll([pa, pb]);
    _rebuildIncident();
    _splitEdgeId = edge.id;
    _path.add(pId);
    return true;
  }

  int _nextEdgeId() =>
      _edges.map((e) => e.id).fold(0, (m, id) => id > m ? id : m) + 1;

  void clearPath() {
    _restorePristine(); // undo any mid-edge split
    _path.clear();
    _traced.clear();
    _backtracks = 0;
    _splitEdgeId = null;
    clearPreview();
  }

  /// Attempts to extend the stroke to [vertexId].
  /// Returns one of: 'traced', 'backtracked', or null (illegal).
  String? moveTo(int vertexId) {
    if (!started) return null;
    final h = head!;
    if (vertexId == h) return null;

    // Stepping onto the previous vertex retraces backwards (undo).
    if (_path.length >= 2 && vertexId == _path[_path.length - 2]) {
      final lastEdge = _edgeBetween(h, vertexId);
      if (lastEdge != null) {
        _path.removeLast();
        _traced.remove(lastEdge.id);
        _backtracks++;
        clearPreview();
        return 'backtracked';
      }
    }

    final edge = _untracedEdgeBetween(h, vertexId);
    if (edge == null) return null;
    _traced.add(edge.id);
    _path.add(vertexId);
    clearPreview();
    return 'traced';
  }

  /// Removes the last traversal. Returns false when nothing to undo.
  /// Counts toward [backtracks] so button undos and drag-back undos
  /// are scored identically.
  bool undo() {
    if (_path.isEmpty) return false;
    if (_path.length == 1) {
      clearPath();
      return true;
    }
    final h = head!;
    final prev = _path[_path.length - 2];
    final edge = _edgeBetween(h, prev);
    if (edge != null) _traced.remove(edge.id);
    _path.removeLast();
    _backtracks++;
    clearPreview();
    return true;
  }

  /// Suggests the next edge to draw, computed by running Hierholzer's
  /// algorithm over the REMAINING (untraced) graph from the current
  /// head. Powers the in-game hint. Returns an untraced edge id, or
  /// null when nothing useful can be suggested.
  int? suggestNextEdge() {
    if (!started || isComplete) return null;

    // Adjacency over the remaining graph: v -> other -> edge id.
    final adj = <int, Map<int, int>>{};
    for (final e in _edges) {
      if (_traced.contains(e.id)) continue;
      (adj[e.a] ??= {})[e.b] = e.id;
      (adj[e.b] ??= {})[e.a] = e.id;
    }
    if (adj.isEmpty) return null;

    // Prefer continuing from the head; fall back to tail, then anywhere.
    var start = head!;
    if ((adj[start] ?? const {}).isEmpty) {
      final t = tail!;
      start = (adj[t] ?? const {}).isNotEmpty ? t : adj.keys.first;
    }

    // Iterative Hierholzer over the remaining multigraph.
    final consumed = <int>{};
    final stack = <int>[start];
    final out = <int>[];
    while (stack.isNotEmpty) {
      final v = stack.last;
      int? nextV;
      int? viaEdge;
      for (final entry in adj[v]!.entries) {
        if (!consumed.contains(entry.value)) {
          nextV = entry.key;
          viaEdge = entry.value;
          break;
        }
      }
      if (nextV == null) {
        out.add(stack.removeLast());
        continue;
      }
      consumed.add(viaEdge!);
      stack.add(nextV);
    }

    // First hop of the trail is the suggested move when the walk
    // actually covered edges (disconnected remainders still yield a
    // useful local loop).
    if (out.reversed.length >= 2) {
      final trail = out.reversed.toList();
      final eid = edgeIdBetweenUntraced(trail[0], trail[1]);
      if (eid != null) return eid;
    }
    return anyUntracedEdgeId();
  }

  /// First untraced edge between [u] and [v], if any.
  int? edgeIdBetweenUntraced(int u, int v) {
    for (final eid in _incident[u] ?? const <int>[]) {
      final e = _edgeById[eid]!;
      if (!_traced.contains(eid) && e.other(u) == v) return eid;
    }
    return null;
  }

  /// Any untraced edge incident to head, else any untraced edge.
  int? anyUntracedEdgeId() {
    for (final eid in _incident[head!] ?? const <int>[]) {
      if (!_traced.contains(eid)) return eid;
    }
    for (final e in _edges) {
      if (!_traced.contains(e.id)) return e.id;
    }
    return null;
  }

  OneLineEdge? _edgeBetween(int u, int v) {
    for (final eid in _incident[u] ?? const <int>[]) {
      if (_edgeById[eid]!.other(u) == v) return _edgeById[eid];
    }
    return null;
  }

  OneLineEdge? _untracedEdgeBetween(int u, int v) {
    for (final eid in _incident[u] ?? const <int>[]) {
      final e = _edgeById[eid]!;
      if (!_traced.contains(e.id) && e.other(u) == v) return e;
    }
    return null;
  }
}
