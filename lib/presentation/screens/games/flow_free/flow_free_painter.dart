import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'flow_free_models.dart';

class FlowFreePainter extends CustomPainter {
  final FlowLevel level;
  final Map<int, List<FlowCell>> paths;
  final int? activePairId;
  final List<List<int>> grid;

  /// When true nothing is drawn at all (used during intro/countdown).
  final bool hidden;

  /// 0..1 grid construction animation. Null means the grid is fully built.
  final double? buildProgress;

  /// 0..1 endpoint dots pop-in. Null means dots are fully shown.
  final double? dotsProgress;

  FlowFreePainter({
    required this.level,
    required this.paths,
    required this.grid,
    this.activePairId,
    this.hidden = false,
    this.buildProgress,
    this.dotsProgress,
  });

  /// Diagonal wave: each cell pops in along its (row + col) anti-diagonal.
  /// Every cell reaches full scale exactly when progress hits 1.0.
  double _cellScale(int r, int c) {
    if (buildProgress == null) return 1.0;
    final span = level.rows + level.cols - 2;
    final wave = span <= 0 ? 0.0 : (r + c) / span;
    const window = 0.28;
    final start = wave * (1.0 - window);
    if (buildProgress! <= start) return 0.0;
    final t = ((buildProgress! - start) / window).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hidden) return;

    final cellW = size.width / level.cols;
    final cellH = size.height / level.rows;
    final cs = min(cellW, cellH);
    final ox = (size.width - cs * level.cols) / 2;
    final oy = (size.height - cs * level.rows) / 2;

    _drawGridShell(canvas, cs, ox, oy);
    _drawGridLines(canvas, cs, ox, oy);
    _drawCellGlows(canvas, cs, ox, oy);
    _drawPaths(canvas, cs, ox, oy);
    _drawEndpoints(canvas, cs, ox, oy);
  }

  // ── Grid shell ────────────────────────────────────────────────────────

  void _drawGridShell(Canvas canvas, double cs, double ox, double oy) {
    final w = cs * level.cols;
    final h = cs * level.rows;

    final shadowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox - 2, oy - 2, w + 4, h + 4),
        const Radius.circular(14),
      ),
      shadowPaint,
    );

    final bgPaint = Paint()..color = const Color(0xFF080C12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy, w, h),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    final cellBg = Paint();
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final scale = _cellScale(r, c);
        if (scale <= 0) continue;
        final pad = cs * (1 - scale) * 0.5;
        final brightness = ((r + c) % 2 == 0) ? 0xFF152238 : 0xFF0A1322;
        cellBg.color = Color(brightness);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              ox + c * cs + 1 + pad,
              oy + r * cs + 1 + pad,
              cs - 2 - pad * 2,
              cs - 2 - pad * 2,
            ),
            const Radius.circular(3),
          ),
          cellBg,
        );
      }
    }

    final frameAlpha =
        buildProgress == null ? 1.0 : (buildProgress! * 2).clamp(0.0, 1.0);
    final borderPaint = Paint()
      ..color = const Color(0xFF33507A).withValues(alpha: frameAlpha)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy, w, h),
        const Radius.circular(12),
      ),
      borderPaint,
    );
  }

  // ── Cell background glows ─────────────────────────────────────────────

  void _drawCellGlows(Canvas canvas, double cs, double ox, double oy) {
    if (dotsProgress != null && dotsProgress! < 1.0) return;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final cellScale = _cellScale(r, c);
        if (cellScale <= 0) continue;

        final pairId = grid[r][c];
        if (pairId < 0 || pairId >= level.pairs.length) continue;

        final pair = level.pairs[pairId];
        final color = pair.color;
        final isActive = pairId == activePairId;

        final isEndpoint = (r == pair.start.row && c == pair.start.col) ||
            (r == pair.end.row && c == pair.end.col);
        final path = paths[pairId];
        final hasPath = path != null && path.length >= 2;
        if (isEndpoint && !hasPath) continue;

        final isConnected = hasPath &&
            _isEndpointCell(path.first, pair) &&
            _isEndpointCell(path.last, pair);
        final alpha = isActive ? 0.32 : (isConnected ? 0.22 : 0.12);

        final cx = ox + c * cs + cs / 2;
        final cy = oy + r * cs + cs / 2;
        final glowRadius = cs * 0.60 * cellScale;

        final glowPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            glowRadius,
            [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          );
        canvas.drawRect(
          Rect.fromLTWH(ox + c * cs, oy + r * cs, cs, cs),
          glowPaint,
        );

        final tintAlpha = isActive ? 0.16 : (isConnected ? 0.11 : 0.06);
        final tintPaint = Paint()..color = color.withValues(alpha: tintAlpha);
        final tintPad = (1 - cellScale) * cs * 0.5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              ox + c * cs + 1 + tintPad,
              oy + r * cs + 1 + tintPad,
              cs - 2 - tintPad * 2,
              cs - 2 - tintPad * 2,
            ),
            const Radius.circular(2.5),
          ),
          tintPaint,
        );
      }
    }
  }

  // ── Grid lines ────────────────────────────────────────────────────────

  void _drawGridLines(Canvas canvas, double cs, double ox, double oy) {
    final lineAlpha =
        buildProgress == null ? 1.0 : (buildProgress! * 2.5).clamp(0.0, 1.0);
    final linePaint = Paint()
      ..color = const Color(0xFF2A4266).withValues(alpha: lineAlpha)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int r = 1; r < level.rows; r++) {
      canvas.drawLine(
        Offset(ox + 0.5, oy + r * cs),
        Offset(ox + level.cols * cs - 0.5, oy + r * cs),
        linePaint,
      );
    }
    for (int c = 1; c < level.cols; c++) {
      canvas.drawLine(
        Offset(ox + c * cs, oy + 0.5),
        Offset(ox + c * cs, oy + level.rows * cs - 0.5),
        linePaint,
      );
    }
  }

  // ── Paths (pipes) ─────────────────────────────────────────────────────

  void _drawPaths(Canvas canvas, double cs, double ox, double oy) {
    if (dotsProgress != null && dotsProgress! < 1.0) return;

    final dotRadius = cs * 0.22;

    for (final entry in paths.entries) {
      final pairId = entry.key;
      final path = entry.value;
      if (path.length < 2) continue;

      final color = level.pairs[pairId].color;
      final isActive = pairId == activePairId;
      final pathObj = _buildPath(path, cs, ox, oy, dotRadius);

      // outer glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: isActive ? 0.38 : 0.16)
        ..strokeWidth = cs * 0.30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(pathObj, glowPaint);

      // main pipe
      final mainPaint = Paint()
        ..shader = _pipeShader(path, color, cs, ox, oy, isActive)
        ..strokeWidth = cs * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pathObj, mainPaint);

      // highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: isActive ? 0.24 : 0.10)
        ..strokeWidth = cs * 0.04
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pathObj, highlightPaint);
    }
  }

  Shader _pipeShader(
    List<FlowCell> path,
    Color color,
    double cs,
    double ox,
    double oy,
    bool isActive,
  ) {
    if (path.isEmpty) {
      return ui.Gradient.linear(Offset.zero, const Offset(1, 1), [color, color]);
    }
    final first = Offset(
        ox + path.first.col * cs + cs / 2, oy + path.first.row * cs + cs / 2);
    final last = Offset(
        ox + path.last.col * cs + cs / 2, oy + path.last.row * cs + cs / 2);
    return ui.Gradient.linear(
      first,
      last,
      [
        color.withValues(alpha: isActive ? 1.0 : 0.85),
        color.withValues(alpha: isActive ? 0.92 : 0.78),
      ],
    );
  }

  Path _buildPath(
      List<FlowCell> path, double cs, double ox, double oy, double dotRadius) {
    final p = Path();
    final centers = path
        .map((c) => Offset(ox + c.col * cs + cs / 2, oy + c.row * cs + cs / 2))
        .toList();

    if (centers.length == 1) {
      p.moveTo(centers[0].dx, centers[0].dy);
      return p;
    }

    // Pipe ends at dot circumference (dot drawn on top covers overlap)
    final mergeOverlap = dotRadius;
    final start = _offsetToward(centers[0], centers[1], mergeOverlap);
    final end = _offsetToward(centers.last, centers[centers.length - 2], mergeOverlap);

    p.moveTo(start.dx, start.dy);

    if (centers.length == 2) {
      p.lineTo(end.dx, end.dy);
      return p;
    }

    final curveFactor = cs * 0.35;
    for (int i = 1; i < centers.length - 1; i++) {
      final prev = (i == 1) ? start : centers[i - 1];
      final curr = centers[i];
      final next = (i == centers.length - 2) ? end : centers[i + 1];

      final dxIn = curr.dx - prev.dx;
      final dyIn = curr.dy - prev.dy;
      final lenIn = sqrt(dxIn * dxIn + dyIn * dyIn);
      final dxOut = next.dx - curr.dx;
      final dyOut = next.dy - curr.dy;
      final lenOut = sqrt(dxOut * dxOut + dyOut * dyOut);

      if (lenIn < 0.001 || lenOut < 0.001) {
        p.lineTo(curr.dx, curr.dy);
        continue;
      }

      final cp1 = Offset(
        curr.dx - (dxIn / lenIn) * curveFactor,
        curr.dy - (dyIn / lenIn) * curveFactor,
      );

      final approach = Offset(
        curr.dx - (dxIn / lenIn) * curveFactor,
        curr.dy - (dyIn / lenIn) * curveFactor,
      );
      final depart = Offset(
        curr.dx + (dxOut / lenOut) * curveFactor,
        curr.dy + (dyOut / lenOut) * curveFactor,
      );

      p.quadraticBezierTo(cp1.dx, cp1.dy, approach.dx, approach.dy);
      p.quadraticBezierTo(curr.dx, curr.dy, depart.dx, depart.dy);
    }

    p.lineTo(end.dx, end.dy);
    return p;
  }

  Offset _offsetToward(Offset from, Offset to, double distance) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return from;
    return Offset(from.dx + (dx / len) * distance, from.dy + (dy / len) * distance);
  }

  // ── Endpoints ─────────────────────────────────────────────────────────

  void _drawEndpoints(Canvas canvas, double cs, double ox, double oy) {
    final count = level.pairs.length;
    for (int pi = 0; pi < count; pi++) {
      final pair = level.pairs[pi];

      double popScale = 1.0;
      if (dotsProgress != null) {
        final step = count > 1 ? 0.45 / (count - 1) : 0.0;
        final start = pi * step;
        if (dotsProgress! <= start) continue;
        final t = ((dotsProgress! - start) / 0.55).clamp(0.0, 1.0);
        popScale = Curves.easeOutBack.transform(t);
      }

      final isActive = pair.id == activePairId;
      final path = paths[pair.id];
      final isCompleted = path != null &&
          path.length >= 2 &&
          _isEndpointCell(path.first, pair) &&
          _isEndpointCell(path.last, pair);

      for (final cell in [pair.start, pair.end]) {
        final cx = ox + cell.col * cs + cs / 2;
        final cy = oy + cell.row * cs + cs / 2;
        final radius = cs * (isActive ? 0.24 : 0.20) * popScale;
        if (radius <= 0) continue;

        final dotPaint = Paint()
          ..color = pair.color.withValues(alpha: isCompleted ? 0.7 : 1.0);
        canvas.drawCircle(Offset(cx, cy), radius, dotPaint);

        final shinePaint = Paint()
          ..color = Colors.white.withValues(alpha: isActive ? 0.45 : 0.28);
        canvas.drawCircle(
          Offset(cx - radius * 0.2, cy - radius * 0.2),
          radius * 0.35,
          shinePaint,
        );

        final innerPaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
        canvas.drawCircle(Offset(cx, cy), radius * 0.2, innerPaint);
      }
    }
  }

  bool _isEndpointCell(FlowCell cell, FlowPair pair) {
    return (cell.row == pair.start.row && cell.col == pair.start.col) ||
        (cell.row == pair.end.row && cell.col == pair.end.col);
  }

  @override
  bool shouldRepaint(FlowFreePainter oldDelegate) {
    if (oldDelegate.hidden != hidden) return true;
    if (oldDelegate.activePairId != activePairId) return true;
    if (oldDelegate.paths.length != paths.length) return true;
    if (oldDelegate.grid != grid) return true;
    if (oldDelegate.buildProgress != buildProgress) return true;
    if (oldDelegate.dotsProgress != dotsProgress) return true;
    for (final key in paths.keys) {
      final oldPath = oldDelegate.paths[key];
      final newPath = paths[key];
      if (oldPath == null || newPath == null) return true;
      if (oldPath.length != newPath.length) return true;
      for (int i = 0; i < oldPath.length; i++) {
        if (oldPath[i] != newPath[i]) return true;
      }
    }
    return false;
  }
}

class FlowFreeCoverPainter extends CustomPainter {
  final List<Color> colors;

  FlowFreeCoverPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 5; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (colors.isNotEmpty) {
      final paint = Paint()
        ..color = colors[0].withValues(alpha: 0.6)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.3)
        ..quadraticBezierTo(size.width / 2, size.height * 0.1,
            size.width * 0.8, size.height * 0.5)
        ..quadraticBezierTo(size.width / 2, size.height * 0.9,
            size.width * 0.2, size.height * 0.7)
        ..close();

      canvas.drawPath(path, paint);
    }

    if (colors.isNotEmpty) {
      final dotPaint = Paint()..color = colors[0];
      canvas.drawCircle(
          Offset(size.width * 0.2, size.height * 0.3), 5, dotPaint);
      if (colors.length > 1) {
        canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 5,
            Paint()..color = colors[1]);
      }
    }
  }

  @override
  bool shouldRepaint(FlowFreeCoverPainter oldDelegate) => false;
}
