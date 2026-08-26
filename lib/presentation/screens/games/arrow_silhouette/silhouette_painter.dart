import 'dart:math';

import 'package:flutter/material.dart';

import 'silhouette_models.dart';
import 'silhouette_engine.dart';

const List<Color> _arrowColors = [
  Color(0xFFFF3B5C),
  Color(0xFF3B82F6),
  Color(0xFF00D98B),
  Color(0xFFF7B731),
  Color(0xFF9B59B6),
  Color(0xFF00F1FE),
];

const List<Color> _arrowColorsDark = [
  Color(0xFFCC2E4A),
  Color(0xFF2F6AC2),
  Color(0xFF00AE6F),
  Color(0xFFC59226),
  Color(0xFF7C4790),
  Color(0xFF00C1CC),
];

class SilhouettePainter extends CustomPainter {
  final SilhouetteEngine engine;
  final double animationValue;
  final List<FlyOff> flyOffs;
  final Map<String, double> flyProgress;

  SilhouettePainter({
    required this.engine,
    this.animationValue = 1.0,
    this.flyOffs = const [],
    this.flyProgress = const {},
  });

  static Offset computeOrigin(Size canvasSize, int cols, int rows) {
    final cellSize = min(canvasSize.width / cols, canvasSize.height / rows);
    final gridW = cols * cellSize;
    final gridH = rows * cellSize;
    return Offset((canvasSize.width - gridW) / 2, (canvasSize.height - gridH) / 2);
  }

  static double computeCellSize(Size canvasSize, int cols, int rows) {
    return min(canvasSize.width / cols, canvasSize.height / rows);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = engine.level.gridRows;
    final cols = engine.level.gridCols;
    final cellSize = computeCellSize(size, cols, rows);
    final origin = computeOrigin(size, cols, rows);

    _drawGridMask(canvas, origin, cellSize, rows, cols, engine.level.mask);
    _drawActiveArrows(canvas, origin, cellSize);
    _drawFlyOffs(canvas, cellSize);
  }

  void _drawGridMask(Canvas canvas, Offset origin, double cellSize, int rows,
      int cols, List<List<bool>> mask) {
    final maskPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.3);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (mask[r][c]) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx + c * cellSize,
              origin.dy + r * cellSize,
              cellSize,
              cellSize,
            ),
            const Radius.circular(2),
          );
          canvas.drawRRect(rect, maskPaint);
          canvas.drawRRect(rect, borderPaint);
        }
      }
    }
  }

  void _drawActiveArrows(Canvas canvas, Offset origin, double cellSize) {
    // Build set of arrows currently being animated off
    final animatingIds = flyOffs.map((f) => f.arrow.id).toSet();
    for (final arrow in engine.arrows) {
      if (arrow.status == ArrowStatus.active && !animatingIds.contains(arrow.id)) {
        final points = arrow.cells
            .map((cell) => Offset(
                  origin.dx + (cell.col + 0.5) * cellSize,
                  origin.dy + (cell.row + 0.5) * cellSize,
                ))
            .toList();
        final color = _arrowColors[arrow.colorIndex % _arrowColors.length];
        final darkColor = _arrowColorsDark[arrow.colorIndex % _arrowColorsDark.length];
        _drawSmoothArrow(canvas, points, arrow.direction, color, darkColor,
            cellSize, arrow.highlighted, arrow.showHint);
      }
    }
  }

  /// Draw a smooth arrow: single continuous stroked path for the shaft,
  /// no per-segment rectangles, no visible joints.
  void _drawSmoothArrow(
    Canvas canvas,
    List<Offset> points,
    ArrowDirection direction,
    Color color,
    Color darkColor,
    double cellSize,
    bool highlighted,
    bool showHint,
  ) {
    if (points.isEmpty) return;

    final shaftWidth = cellSize * 0.22;
    final headLength = cellSize * 1.0;
    final headWidth = shaftWidth * 2.2;

    final fillColor = highlighted || showHint ? Colors.amber.shade400 : color;

    // --- Shadow ---
    if (points.length >= 2) {
      final shadowPath = Path();
      shadowPath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        shadowPath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        shadowPath.shift(const Offset(1.5, 2.0)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = shaftWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // --- Shaft: single continuous stroked path ---
    if (points.length >= 2) {
      final shaftPath = Path();
      shaftPath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        shaftPath.lineTo(points[i].dx, points[i].dy);
      }

      // Fill
      canvas.drawPath(
        shaftPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = shaftWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Outline
      canvas.drawPath(
        shaftPath,
        Paint()
          ..color = darkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = shaftWidth + 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Inner fill on top of outline
      canvas.drawPath(
        shaftPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = shaftWidth - 0.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      // Single dot
      canvas.drawCircle(points.first, shaftWidth / 2, Paint()..color = fillColor);
    }

    // --- Arrowhead ---
    // Always use the arrow's escape direction for the head, not the
    // last segment direction (which may differ mid-turn).
    final head = points.last;
    final normDir = Offset(direction.dx.toDouble(), direction.dy.toDouble());
    final perp = Offset(-normDir.dy, normDir.dx);
    final tip = head + normDir * (headLength * 0.35);

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(head.dx + perp.dx * headWidth / 2, head.dy + perp.dy * headWidth / 2)
      ..lineTo(head.dx - perp.dx * headWidth / 2, head.dy - perp.dy * headWidth / 2)
      ..close();

    canvas.drawPath(headPath, Paint()..color = darkColor);
    canvas.drawPath(
      headPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      headPath,
      Paint()
        ..color = darkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // --- Highlight / hint glow ---
    if (highlighted || showHint) {
      final pulse = showHint ? (sin(animationValue * pi * 4) + 1) / 2 : 1.0;
      final glowAlpha = showHint ? 0.15 + 0.15 * pulse : 0.25;
      final glowPaint = Paint()
        ..color = Colors.amber.withValues(alpha: glowAlpha)
        ..style = PaintingStyle.fill;
      for (final p in points) {
        final radius = showHint ? cellSize * 0.55 + 4 * pulse : cellSize * 0.55;
        canvas.drawCircle(p, radius, glowPaint);
      }
    }
  }

  void _drawFlyOffs(Canvas canvas, double cellSize) {
    for (final flyOff in flyOffs) {
      final arrow = flyOff.arrow;
      final color = _arrowColors[arrow.colorIndex % _arrowColors.length];
      final darkColor = _arrowColorsDark[arrow.colorIndex % _arrowColorsDark.length];

      final advance = flyProgress[arrow.id] ?? 0.0;
      final points = flyOff.shaftPoints(advance);
      if (points.isEmpty) continue;

      // Fade as it exits
      final fadeStart = flyOff.total * 0.5;
      final alpha = advance > fadeStart
          ? (1.0 - (advance - fadeStart) / (flyOff.total - fadeStart)).clamp(0.0, 1.0)
          : 1.0;

      final fadedColor = color.withValues(alpha: alpha);
      final fadedDark = darkColor.withValues(alpha: alpha * 0.8);

      _drawSmoothArrow(
        canvas, points, arrow.direction, fadedColor, fadedDark,
        cellSize, false, false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SilhouettePainter oldDelegate) {
    if (flyOffs.isNotEmpty) return true;
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.flyOffs.length != flyOffs.length ||
        !identical(oldDelegate.engine, engine);
  }
}
