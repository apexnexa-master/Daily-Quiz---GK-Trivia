import 'package:flutter/material.dart';
import 'one_line_models.dart';
import 'one_line_engine.dart';

class OneLinePainter extends CustomPainter {
  final OneLineEngine engine;
  final bool isDark;
  final int? hoveredVertexId;

  OneLinePainter({
    required this.engine,
    required this.isDark,
    this.hoveredVertexId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shape = engine.shape;
    final padding = size.width * 0.08;
    final drawSize = Size(size.width - padding * 2, size.height - padding * 2);

    // Convert normalized positions to pixel positions
    Offset getPixelPos(OneLineVertex v) {
      return Offset(
        padding + v.position.dx * drawSize.width,
        padding + v.position.dy * drawSize.height,
      );
    }

    // Draw untraversed edges (muted)
    final mutedEdgePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final edge in shape.edges) {
      if (engine.traversedEdgeIds.contains(edge.id)) continue;
      final start = getPixelPos(shape.vertices.firstWhere(
          (v) => v.id == edge.startVertexId));
      final end = getPixelPos(shape.vertices
          .firstWhere((v) => v.id == edge.endVertexId));
      canvas.drawLine(start, end, mutedEdgePaint);
    }

    // Draw traversed edges (glowing)
    final traversedEdgePaint = Paint()
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final edge in shape.edges) {
      if (!engine.traversedEdgeIds.contains(edge.id)) continue;
      final start = getPixelPos(shape.vertices.firstWhere(
          (v) => v.id == edge.startVertexId));
      final end = getPixelPos(shape.vertices
          .firstWhere((v) => v.id == edge.endVertexId));

      // Glow
      final glowPaint = Paint()
        ..color = const Color(0xFFE040FB).withValues(alpha: 0.3)
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawLine(start, end, glowPaint);

      // Line
      traversedEdgePaint
        ..shader = LinearGradient(
          colors: [const Color(0xFFE040FB), const Color(0xFFAA00FF)],
        ).createShader(Rect.fromPoints(start, end));
      canvas.drawLine(start, end, traversedEdgePaint);
    }

    // Draw current path highlight
    if (engine.currentPath.length > 1) {
      final pathPaint = Paint()
        ..color = const Color(0xFFE040FB).withValues(alpha: 0.6)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      for (int i = 0; i < engine.currentPath.length - 1; i++) {
        final from = getPixelPos(shape.vertices
            .firstWhere((v) => v.id == engine.currentPath[i]));
        final to = getPixelPos(shape.vertices
            .firstWhere((v) => v.id == engine.currentPath[i + 1]));
        canvas.drawLine(from, to, pathPaint);
      }
    }

    // Draw vertices
    final vertexRadius = size.width * 0.035;
    for (final vertex in shape.vertices) {
      final pos = getPixelPos(vertex);
      final isOnPath = engine.currentPath.contains(vertex.id);
      final isStart = engine.currentPath.isNotEmpty &&
          engine.currentPath.first == vertex.id;
      final isCurrent =
          engine.currentVertex == vertex.id;
      final isHovered = hoveredVertexId == vertex.id;

      // Glow
      if (isCurrent || isHovered) {
        final glowPaint = Paint()
          ..color = const Color(0xFFE040FB).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawCircle(pos, vertexRadius + 8, glowPaint);
      }

      // Vertex circle
      final vertexPaint = Paint()
        ..color = isOnPath
            ? const Color(0xFFE040FB)
            : (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, vertexRadius, vertexPaint);

      // Border
      final borderPaint = Paint()
        ..color = isOnPath
            ? const Color(0xFFE040FB)
            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pos, vertexRadius, borderPaint);

      // Inner dot for start vertex
      if (isStart) {
        final innerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, vertexRadius * 0.4, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OneLinePainter oldDelegate) => true;
}
