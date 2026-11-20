import 'dart:ui' show Offset;

import 'one_line_models.dart';

class OneLineNavigation {
  static const double minTravelFraction = 0.18;
  static const double minAlignment = 0.30;
  static const double maxOffAxis = 1.15;
  static const double commitAt = 0.70;

  static int? chooseStartVertex({
    required Map<int, Offset> positions,
    required Offset pointer,
    required double snapRadius,
  }) {
    int? best;
    var bestDistance = snapRadius;
    for (final entry in positions.entries) {
      final distance = (pointer - entry.value).distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = entry.key;
      }
    }
    return best;
  }

  static ({int edgeId, int farId, double t})? choose({
    required Offset pointer,
    required int headId,
    required Offset head,
    required List<OneLineEdge> edges,
    required Set<int> tracedEdgeIds,
    required Map<int, Offset> positions,
    required double snapRadius,
  }) {
    final travel = pointer - head;
    final travelled = travel.distance;
    if (travelled < snapRadius * minTravelFraction) return null;
    final direction = travel / travelled;

    ({int edgeId, int farId, double t})? best;
    var bestScore = double.negativeInfinity;

    for (final edge in edges) {
      if (tracedEdgeIds.contains(edge.id) || !edge.touches(headId)) continue;
      final farId = edge.other(headId);
      final far = positions[farId];
      if (far == null) continue;
      final axis = far - head;
      final length = axis.distance;
      if (length <= 0) continue;

      final t = (travel.dx * axis.dx + travel.dy * axis.dy) / (length * length);
      if (t < 0.05) continue;
      final clamped = t.clamp(0.0, 1.0);
      final projected = head + axis * clamped;
      final offAxis = (pointer - projected).distance;
      if (offAxis > snapRadius * maxOffAxis) continue;

      final alignment =
          direction.dx * axis.dx / length + direction.dy * axis.dy / length;
      if (alignment < minAlignment) continue;

      final score =
          alignment - offAxis / (snapRadius * 4) - (1 - clamped) * 0.05;
      if (score > bestScore) {
        bestScore = score;
        best = (edgeId: edge.id, farId: farId, t: clamped);
      }
    }
    return best;
  }

  static bool shouldCommit({
    required double t,
    required Offset pointer,
    required Offset far,
    required double snapRadius,
  }) =>
      t >= commitAt || (pointer - far).distance <= snapRadius * 0.9;
}
