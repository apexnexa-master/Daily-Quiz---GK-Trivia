// lib/presentation/screens/games/one_line/one_line_painter.dart
//
// CustomPainter for the One-Line board. Pure presentation: receives
// immutable snapshots of engine state plus animation values from the
// screen.
//
// Rendering notes (learned from polished one-stroke games):
//  * The untouched outline and the glow are stroked OPAQUE inside a
//    translucent `saveLayer`, so overlapping round caps blend exactly
//    once - junctions stay smooth with no node-like blobs where two or
//    more lines meet.
//  * The traced stroke is ONE continuous path through the committed
//    vertex sequence plus a live tip that follows the finger along the
//    outline in real time, drawn over a soft glow underlay with a
//    gradient core.
//  * A finished run keeps breathing: a light comet rides the completed
//    figure forever (the market-leading one-line games never freeze the
//    board after a win).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'one_line_models.dart';

class OneLineBoardState {
  final List<OneLineVertex> vertices;
  final List<OneLineEdge> edges;
  final List<int> path;
  final Set<int> tracedEdgeIds;

  /// Edge being drawn live from head + progress toward its far end.
  final int? previewEdgeId;
  final double previewT;

  /// 0..1 — fraction of the last edge erased while dragging backwards.
  final double backtrackErase;

  /// Solution vertex sequence — staggers the intro draw-on.
  final List<int> solution;

  /// 0..1 — outline draws itself in during the intro; null when done.
  final double? buildProgress;

  /// 0..1 — red flash intensity on a dead end.
  final double deadEndPulse;

  /// >0 once the level is completed (drives end-of-run rendering).
  final double winGlow;

  /// 0..1 looping phase driving subtle marker pulses and, after a
  /// win, the victory comet riding the finished figure.
  final double pulsePhase;

  const OneLineBoardState({
    required this.vertices,
    required this.edges,
    required this.path,
    required this.tracedEdgeIds,
    this.previewEdgeId,
    this.previewT = 0,
    this.backtrackErase = 0,
    this.solution = const [],
    this.buildProgress,
    this.deadEndPulse = 0,
    this.winGlow = 0,
    this.pulsePhase = 0,
  });

  /// A completed run plays its victory flare instead of live markers.
  bool get isFinished => winGlow > 0;
}

class OneLinePainter extends CustomPainter {
  final OneLineBoardState state;
  final bool isDark;
  final Color accent;

  static const _accent = Color(0xFFE040FB);
  static const _accentDeep = Color(0xFFAA00FF);

  OneLinePainter({
    required this.state,
    required this.isDark,
    this.accent = _accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * kOneLineBoardInset;
    final board = Rect.fromLTWH(
        inset, inset, size.width - inset * 2, size.height - inset * 2);
    Offset px(Offset norm) => Offset(
        board.left + norm.dx * board.width, board.top + norm.dy * board.height);

    final positions = <int, Offset>{
      for (final v in state.vertices) v.id: px(v.position),
    };
    final baseW = size.shortestSide * 0.024;
    final traceW = baseW; // drawn line matches the outline exactly
    final layerBounds = Offset.zero & size;
    final baseColor = isDark ? Colors.white : const Color(0xFF2B2140);

    final headId = state.path.isEmpty ? null : state.path.last;

    // ── Live tip position (pen follows the finger) ──────────────────
    Offset? tipPx;
    if (state.previewEdgeId != null && headId != null) {
      for (final e in state.edges) {
        if (e.id != state.previewEdgeId) continue;
        final pa = positions[e.a];
        final pb = positions[e.b];
        if (pa == null || pb == null) break;
        tipPx = e.a == headId
            ? Offset.lerp(pa, pb, state.previewT)
            : Offset.lerp(pb, pa, state.previewT);
        break;
      }
    }

    // While dragging back, the pen sits on the erased end of the last
    // segment instead.
    Offset? erasePx;
    if (!state.isFinished &&
        state.backtrackErase > 0 &&
        state.path.length >= 2) {
      final prev = positions[state.path[state.path.length - 2]];
      final head = positions[headId];
      if (prev != null && head != null) {
        erasePx =
            Offset.lerp(prev, head, (1 - state.backtrackErase).clamp(0, 1));
      }
    }

    // ── Background texture: sparse dot grid for depth ────────────────
    _paintDotGrid(canvas, size, baseColor);

    // ── Untouched outline ────────────────────────────────────────────
    // Opaque strokes composited through one translucent layer: overlaps
    // at junctions blend once, keeping every meeting point smooth.
    canvas.saveLayer(
      layerBounds,
      Paint()
        ..color = baseColor.withValues(alpha: state.isFinished ? 0.08 : 0.15),
    );
    final outlinePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final revealOrder = _revealOrderByEdge();
    for (final edge in state.edges) {
      if (state.tracedEdgeIds.contains(edge.id)) continue;
      var reveal = 1.0;
      if (state.buildProgress != null) {
        final order = revealOrder[edge.key] ?? revealOrder.length;
        final span = math.max(3, revealOrder.length);
        reveal =
            ((state.buildProgress! * (span + 4) - order) / 4).clamp(0.0, 1.0);
        if (reveal <= 0) continue;
      }
      final start = positions[edge.a];
      final end = positions[edge.b];
      if (start == null || end == null) continue;
      final eased = Curves.easeOut.transform(reveal);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(Offset.lerp(start, end, eased)!.dx,
              Offset.lerp(start, end, eased)!.dy),
        outlinePaint,
      );
    }
    canvas.restore();

    // ── Traced stroke: glow underlay + gradient core + live tip ──────
    final solved = state.isFinished;
    final traceColor = solved ? successGreen : accent;
    final tracedPath = _buildTracedPath(positions, tipPx);
    if (tracedPath != null) {
      // Soft halo behind the line makes the stroke pop off the board.
      canvas.drawPath(
        tracedPath,
        Paint()
          ..color = traceColor.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = traceW * 2.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = traceW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (solved) {
        corePaint.color = traceColor;
      } else {
        corePaint.shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [accent, _accentDeep],
        );
      }
      canvas.drawPath(tracedPath, corePaint);

      // ── Victory comet: light riding the finished figure forever ────
      if (solved) {
        _paintComet(canvas, positions, traceW);
      }
    }

    // ── Markers ──────────────────────────────────────────────────────
    if (state.path.isEmpty || !state.isFinished) {
      final dead = state.deadEndPulse;
      final pulse = math.sin(state.pulsePhase * 2 * math.pi);

      // Start-of-stroke marker: hollow ring that breathes gently so
      // players can always find where the stroke began.
      final tailC = state.path.isEmpty ? null : positions[state.path.first];
      if (tailC != null) {
        canvas.drawCircle(
            tailC,
            baseW * (0.95 + 0.12 * pulse),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = baseW * 0.45
              ..color =
                  accent.withValues(alpha: (0.75 + 0.20 * pulse).clamp(0, 1)));
      }

      // Pen tip at the live position — flat dot in the stroke colour.
      final marker = erasePx ?? tipPx ?? positions[headId];
      if (marker != null) {
        final tipColor =
            dead > 0.05 ? Color.lerp(traceColor, failRed, dead)! : traceColor;
        canvas.drawCircle(marker, traceW * 0.70,
            Paint()..color = dead > 0.3 ? failRed : tipColor);
      }
    }

    // ── Result overlay: green tick on win ────────────────────────────
    if (state.isFinished) _paintSuccessTick(canvas, size, state.winGlow);
  }

  void _paintDotGrid(Canvas canvas, Size size, Color baseColor) {
    final step = size.shortestSide * 0.085;
    final paint = Paint()
      ..color = baseColor.withValues(alpha: isDark ? 0.05 : 0.06)
      ..style = PaintingStyle.fill;
    final rows = (size.height / step).ceil();
    final cols = (size.width / step).ceil();
    final ox = (size.width - cols * step) / 2;
    final oy = (size.height - rows * step) / 2;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(Offset(ox + c * step, oy + r * step), 1.1, paint);
      }
    }
  }

  static const successGreen = Color(0xFF2ECC71);
  static const failRed = Color(0xFFE53935);

  /// Solid badge behind the result stamps so a green tick never melts
  /// into green lines (nor the red cross into red ones).
  void _paintBadgeBacking(
      Canvas canvas, Offset c, double radius, double t, Color ringColor) {
    final backing = isDark ? const Color(0xF0100B1C) : const Color(0xFAFFFFFF);
    canvas.drawCircle(c, radius, Paint()..color = backing);
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.055
          ..color = ringColor.withValues(alpha: 0.85 * t));
  }

  /// Big green tick stamped over the finished figure; scales in with
  /// [t] (0..1).
  void _paintSuccessTick(Canvas canvas, Size size, double t) {
    if (t <= 0) return;
    final s = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.085 * s;
    final w = size.shortestSide * 0.024;

    canvas.drawCircle(
        c, r * 1.75, Paint()..color = successGreen.withValues(alpha: 0.16 * t));
    _paintBadgeBacking(canvas, c, r * 1.42, t, successGreen);

    final check = Path()
      ..moveTo(c.dx - r * 0.85, c.dy + r * 0.05)
      ..lineTo(c.dx - r * 0.2, c.dy + r * 0.65)
      ..lineTo(c.dx + r * 0.9, c.dy - r * 0.6);
    canvas.drawPath(
      check,
      Paint()
        ..color = successGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 1.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// A soft light that travels along the completed stroke, looping
  /// forever — the finished figure keeps feeling alive after a win.
  void _paintComet(Canvas canvas, Map<int, Offset> positions, double traceW) {
    if (state.path.length < 2) return;
    final points = <Offset>[
      for (final id in state.path)
        if (positions[id] != null) positions[id]!,
    ];
    if (points.length < 2) return;

    var total = 0.0;
    final lens = <double>[];
    for (var i = 1; i < points.length; i++) {
      final l = (points[i] - points[i - 1]).distance;
      lens.add(l);
      total += l;
    }
    if (total <= 0) return;

    // One lap every pulse cycle; ease so it lingers at the ends.
    final t =
        Curves.easeInOut.transform((state.pulsePhase % 1.0).clamp(0.0, 1.0));
    var target = t * total;
    Offset c = points.last;
    for (var i = 0; i < lens.length; i++) {
      if (target <= lens[i]) {
        c = Offset.lerp(points[i], points[i + 1], target / lens[i])!;
        break;
      }
      target -= lens[i];
    }

    canvas.drawCircle(
        c,
        traceW * 1.7,
        Paint()
          ..color = Colors.white
              .withValues(alpha: 0.28 * state.winGlow.clamp(0.4, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        c, traceW * 0.75, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  /// The committed stroke as one continuous polyline, trimmed while
  /// erasing backwards and extended to the live drag tip.
  Path? _buildTracedPath(Map<int, Offset> positions, Offset? tip) {
    if (state.path.isEmpty) return null;
    final p = Path();
    final first = positions[state.path.first];
    if (first == null) return null;
    p.moveTo(first.dx, first.dy);

    for (int i = 1; i < state.path.length; i++) {
      var end = positions[state.path[i]];
      final start = positions[state.path[i - 1]];
      if (end == null || start == null) continue;
      if (i == state.path.length - 1 && state.backtrackErase > 0) {
        final keep = (1 - state.backtrackErase).clamp(0.0, 1.0);
        end = Offset.lerp(start, end, keep)!;
      }
      p.lineTo(end.dx, end.dy);
    }
    if (tip != null) p.lineTo(tip.dx, tip.dy);
    return p;
  }

  /// Maps each edge to its position within the solution walk so the
  /// intro can draw the figure stroke-by-stroke.
  Map<String, int> _revealOrderByEdge() {
    final order = <String, int>{};
    for (int i = 0; i + 1 < state.solution.length; i++) {
      final a = state.solution[i];
      final b = state.solution[i + 1];
      order.putIfAbsent(a < b ? '$a-$b' : '$b-$a', () => i);
    }
    return order;
  }

  @override
  bool shouldRepaint(covariant OneLinePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.isDark != isDark ||
      oldDelegate.accent != accent;
}

extension _EdgeKey on OneLineEdge {
  String get key => a < b ? '$a-$b' : '$b-$a';
}
