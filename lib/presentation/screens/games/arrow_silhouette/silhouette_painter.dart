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

/// Erosion (onion-peel) depth of every mask cell, keyed `row * cols + col`.
/// The outermost ring has depth 0 and the value grows towards the centre. Used
/// to stagger the intro reveal so the design grows from the middle outwards.
Map<int, int> computeMaskDepths(List<List<bool>> mask, int cols) {
  final rows = mask.length;
  final remaining = <int>{};
  for (var r = 0; r < rows; r++) {
    final row = mask[r];
    for (var c = 0; c < row.length && c < cols; c++) {
      if (row[c]) remaining.add(r * cols + c);
    }
  }
  final depth = <int, int>{};
  bool stillRemaining(int r, int c) =>
      r >= 0 &&
      r < rows &&
      c >= 0 &&
      c < cols &&
      remaining.contains(r * cols + c);
  var d = 0;
  while (remaining.isNotEmpty) {
    final layer = <int>{};
    for (final idx in remaining) {
      final r = idx ~/ cols;
      final c = idx % cols;
      if (!stillRemaining(r - 1, c) ||
          !stillRemaining(r + 1, c) ||
          !stillRemaining(r, c - 1) ||
          !stillRemaining(r, c + 1)) {
        layer.add(idx);
      }
    }
    for (final idx in layer) {
      depth[idx] = d;
      remaining.remove(idx);
    }
    d++;
  }
  return depth;
}

/// Per-arrow intro reveal order (aligned with [arrows]): 0 = draw first, 1 =
/// draw last. Deepest arrows (towards the centre) reveal first.
List<double> computeArrowBuildOrder(
    List<ArrowPiece> arrows, Map<int, int> depths, int cols) {
  if (arrows.isEmpty) return const [];
  var maxDepth = 0;
  for (final d in depths.values) {
    if (d > maxDepth) maxDepth = d;
  }
  if (maxDepth == 0) return List<double>.filled(arrows.length, 0);
  return [
    for (final a in arrows)
      1 - ((depths[a.headCell.row * cols + a.headCell.col] ?? 0) / maxDepth),
  ];
}

class SilhouettePainter extends CustomPainter {
  final SilhouetteEngine engine;
  final double animationValue;
  final List<FlyOff> flyOffs;
  final Map<String, double> flyProgress;

  /// 0..1 intro "build the design" animation. When < 1 the faint dot
  /// silhouette grows from the middle outwards and the arrows draw themselves
  /// in (deepest first). At 1 the board is shown normally.
  final double introductionValue;

  /// Per-cell erosion depth (keyed `row * cols + col`) used to stagger the
  /// intro reveal. Null disables the staggered build.
  final Map<int, int>? maskDepths;

  /// Per-arrow (aligned with `engine.arrows`) reveal order, 0 = first to draw.
  final List<double>? arrowBuildOrder;

  /// Whether the surface is dark, so the faint background dots stay visible.
  final bool isDark;

  SilhouettePainter({
    required this.engine,
    this.animationValue = 1.0,
    this.flyOffs = const [],
    this.flyProgress = const {},
    this.introductionValue = 1.0,
    this.maskDepths,
    this.arrowBuildOrder,
    this.isDark = true,
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
    final intro = introductionValue.clamp(0.0, 1.0);

    _drawDotBackdrop(canvas, origin, cellSize, intro);
    _drawActiveArrows(canvas, origin, cellSize, intro);
    _drawBlockerLink(canvas, origin, cellSize);
    _drawFlyOffs(canvas, cellSize);
  }

  /// Reveal fraction for one element given its [stagger] (0 = first).
  static double _reveal(double intro, double stagger) =>
      ((intro - stagger * 0.65) / 0.35).clamp(0.0, 1.0);

  /// Faint dots marking the silhouette, so the design is legible without the
  /// blocky cell squares. During the intro they grow from the middle outwards.
  void _drawDotBackdrop(
      Canvas canvas, Offset origin, double cellSize, double intro) {
    final mask = engine.level.mask;
    final rows = engine.level.gridRows;
    final cols = engine.level.gridCols;
    if (mask.isEmpty) return;

    final dotColor = isDark ? Colors.white : const Color(0xFF334155);
    final baseAlpha = isDark ? 0.16 : 0.22;
    final radius = max(0.6, cellSize * 0.11);
    final paint = Paint();
    final depths = maskDepths;

    var maxDepth = 0;
    if (depths != null) {
      for (final d in depths.values) {
        if (d > maxDepth) maxDepth = d;
      }
    }

    for (var row = 0; row < rows && row < mask.length; row++) {
      final maskRow = mask[row];
      for (var col = 0; col < cols && col < maskRow.length; col++) {
        if (!maskRow[col]) continue;
        double alpha;
        if (depths == null || maxDepth == 0 || intro >= 1) {
          alpha = baseAlpha;
        } else {
          final depth = depths[row * cols + col] ?? 0;
          final stagger = 1 - depth / maxDepth; // inner cells appear first
          alpha = baseAlpha * _reveal(intro, stagger);
        }
        if (alpha <= 0.003) continue;
        paint.color = dotColor.withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(
            origin.dx + (col + 0.5) * cellSize,
            origin.dy + (row + 0.5) * cellSize,
          ),
          radius,
          paint,
        );
      }
    }
  }

  void _drawActiveArrows(
      Canvas canvas, Offset origin, double cellSize, double intro) {
    // Build set of arrows currently being animated off
    final animatingIds = flyOffs.map((f) => f.arrow.id).toSet();
    for (var index = 0; index < engine.arrows.length; index++) {
      final arrow = engine.arrows[index];
      if (arrow.status == ArrowStatus.active && !animatingIds.contains(arrow.id)) {
        final build = (intro >= 1 || arrowBuildOrder == null)
            ? 1.0
            : _reveal(intro, arrowBuildOrder![index]);
        if (build <= 0.003) continue;
        final points = arrow.cells
            .map((cell) => Offset(
                  origin.dx + (cell.col + 0.5) * cellSize,
                  origin.dy + (cell.row + 0.5) * cellSize,
                ))
            .toList();
        final color = _arrowColors[arrow.colorIndex % _arrowColors.length];
        final darkColor = _arrowColorsDark[arrow.colorIndex % _arrowColorsDark.length];
        _drawSmoothArrow(
          canvas,
          points,
          arrow.direction,
          color,
          darkColor,
          cellSize,
          arrow.highlighted,
          arrow.showHint,
          isBlocked: arrow.id == engine.blockedFlashId,
          build: build,
        );
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
    bool showHint, {
    bool isBlocked = false,
    double build = 1.0,
  }) {
    if (points.isEmpty) return;

    final fullyBuilt = build >= 0.999;
    final visible = fullyBuilt
        ? points
        : points.sublist(0, max(1, (points.length * build).ceil()));

    final shaftWidth = cellSize * 0.22;
    final headLength = cellSize * 1.0;
    final headWidth = shaftWidth * 2.2;

    final fillColor =
        isBlocked ? const Color(0xFFFF1A3C) : (highlighted || showHint ? Colors.amber.shade400 : color);
    final pulse = isBlocked
        ? (sin(animationValue * pi * 6) + 1) / 2
        : (showHint ? (sin(animationValue * pi * 4) + 1) / 2 : 1.0);

    // --- Shadow ---
    if (visible.length >= 2) {
      final shadowPath = Path();
      shadowPath.moveTo(visible.first.dx, visible.first.dy);
      for (int i = 1; i < visible.length; i++) {
        shadowPath.lineTo(visible[i].dx, visible[i].dy);
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
    if (visible.length >= 2) {
      final shaftPath = Path();
      shaftPath.moveTo(visible.first.dx, visible.first.dy);
      for (int i = 1; i < visible.length; i++) {
        shaftPath.lineTo(visible[i].dx, visible[i].dy);
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
      canvas.drawCircle(visible.first, shaftWidth / 2, Paint()..color = fillColor);
    }

    // While the design is still being drawn in, cap the growing stroke with a
    // soft rounded tip instead of the arrowhead.
    if (!fullyBuilt) {
      canvas.drawCircle(
        visible.last,
        shaftWidth / 2,
        Paint()..color = darkColor,
      );
      canvas.drawCircle(
        visible.last,
        shaftWidth / 2 - 0.4,
        Paint()..color = fillColor,
      );
      return;
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

    // --- Highlight / hint / blocked glow ---
    if (highlighted || showHint) {
      final glowAlpha = showHint ? 0.15 + 0.15 * pulse : 0.25;
      final glowPaint = Paint()
        ..color = Colors.amber.withValues(alpha: glowAlpha)
        ..style = PaintingStyle.fill;
      for (final p in points) {
        final radius = showHint ? cellSize * 0.55 + 4 * pulse : cellSize * 0.55;
        canvas.drawCircle(p, radius, glowPaint);
      }
    }
    if (isBlocked) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF1A3C).withValues(alpha: 0.25 + 0.25 * pulse)
        ..style = PaintingStyle.fill;
      for (final p in points) {
        canvas.drawCircle(p, cellSize * 0.55 + 5 * pulse, glowPaint);
      }
    }
  }

  /// A faint dashed guide from the arrow the player tapped to the cell of the
  /// arrow that is blocking it, so the cause of a blocked tap is obvious.
  void _drawBlockerLink(Canvas canvas, Offset origin, double cellSize) {
    final fromId = engine.blockedFromId;
    final impact = engine.blockedImpactCell;
    if (fromId == null || impact == null) return;

    ArrowPiece? from;
    for (final a in engine.arrows) {
      if (a.id == fromId) {
        from = a;
        break;
      }
    }
    if (from == null) return;

    final head = from.headCell;
    final start = Offset(
      origin.dx + (head.col + 0.5) * cellSize,
      origin.dy + (head.row + 0.5) * cellSize,
    );
    final end = Offset(
      origin.dx + (impact.col + 0.5) * cellSize,
      origin.dy + (impact.row + 0.5) * cellSize,
    );
    if ((end - start).distance <= 0.5) return;

    final paint = Paint()
      ..color = const Color(0xFFFF1A3C).withValues(alpha: 0.6)
      ..strokeWidth = max(1.5, cellSize * 0.09)
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas, start, end, cellSize, paint);
    canvas.drawCircle(end, max(2.0, cellSize * 0.13), paint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    double cellSize,
    Paint paint,
  ) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    final dash = cellSize * 0.3;
    final gap = cellSize * 0.22;
    var d = 0.0;
    while (d < total) {
      final segEnd = min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * segEnd, paint);
      d = segEnd + gap;
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

      // Stay fully visible while riding the arrow's own rails across the board;
      // only fade in the final stretch once the tail has cleared the grid, so
      // the arrow never shrinks or vanishes mid-travel.
      final fadeEnd = flyOff.total;
      final fadeStart = max(0.0, flyOff.total - cellSize * 2);
      final alpha = advance > fadeStart
          ? (1.0 - (advance - fadeStart) / (fadeEnd - fadeStart)).clamp(0.0, 1.0)
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
    if (!identical(oldDelegate.engine, engine)) return true;
    // The intro "build the design" animation must repaint every frame.
    if (oldDelegate.introductionValue != introductionValue) return true;
    if (oldDelegate.isDark != isDark) return true;
    if (engine.blockedFlashId != oldDelegate.engine.blockedFlashId) return true;
    if (engine.blockedFromId != oldDelegate.engine.blockedFromId) return true;
    if (engine.blockedImpactCell != oldDelegate.engine.blockedImpactCell) {
      return true;
    }
    final hintsHere = engine.arrows.any((a) => a.showHint);
    final hintsThere = oldDelegate.engine.arrows.any((a) => a.showHint);
    if (hintsHere != hintsThere) return true;
    // Only the hint/blocked pulses animate; when idle the ticker is stopped,
    // so ignore animationValue to skip redundant repaints.
    if (hintsHere || engine.blockedFlashId != null) {
      if (oldDelegate.animationValue != animationValue) return true;
    }
    return false;
  }
}
