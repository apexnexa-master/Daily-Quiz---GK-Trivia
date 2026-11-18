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

  /// True while a finger is actively drawing the stroke.
  final bool drawing;

  /// Edge highlighted by the hint system, if any.
  final int? hintEdgeId;

  /// 0..1 — red cross stamp shown when a run fails.
  final double failGlow;

  /// Vertex where the run failed (used for the impact glow).
  final int? failPointId;

  /// Solution vertex sequence — staggers the intro draw-on.
  final List<int> solution;

  /// 0..1 — outline draws itself in during the intro; null when done.
  final double? buildProgress;

  /// >0 once the level is completed (drives end-of-run rendering).
  final double winGlow;

  /// 0..1 looping phase driving subtle marker pulses and, after a
  /// win, the victory comet riding the finished figure.
  final double pulsePhase;

  /// 0..1 one-shot intro sweep; 0 or 1 means no shimmer.
  final double introSweepPhase;

  /// 0..1 celebration timeline; 0 means no confetti.
  final double confettiPhase;

  const OneLineBoardState({
    required this.vertices,
    required this.edges,
    required this.path,
    required this.tracedEdgeIds,
    this.previewEdgeId,
    this.previewT = 0,
    this.drawing = false,
    this.hintEdgeId,
    this.failGlow = 0,
    this.failPointId,
    this.solution = const [],
    this.buildProgress,
    this.winGlow = 0,
    this.pulsePhase = 0,
    this.introSweepPhase = 0,
    this.confettiPhase = 0,
  });

  /// A completed run plays its victory flare instead of live markers.
  bool get isFinished => winGlow > 0;
}

class OneLinePainter extends CustomPainter {
  final OneLineBoardState state;
  final bool isDark;
  final Color accent;

  static const _accent = Color(0xFFFFD54F);
  static const _accentDeep = Color(0xFFFF9F1C);
  static const _outline = Color(0xFF93A6C4);

  OneLinePainter({
    required this.state,
    required this.isDark,
    this.accent = _accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The canvas is full-bleed, but the figure keeps its square
    // proportions: vertices are mapped into the largest centred square,
    // so a tall screen never stretches the puzzle out of shape.
    final side = size.shortestSide;
    final inset = side * kOneLineBoardInset;
    final board = Rect.fromLTWH(
      (size.width - side) / 2 + inset,
      (size.height - side) / 2 + inset,
      side - inset * 2,
      side - inset * 2,
    );
    Offset px(Offset norm) => Offset(
        board.left + norm.dx * board.width, board.top + norm.dy * board.height);

    final positions = <int, Offset>{
      for (final v in state.vertices) v.id: px(v.position),
    };
    final baseW = size.shortestSide * 0.025;
    final traceW = baseW * 1.12;
    final layerBounds = Offset.zero & size;
    final baseColor = isDark ? _outline : const Color(0xFF2B2140);

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

    // ── Background texture: sparse dot grid for depth ────────────────
    _paintDotGrid(canvas, size, baseColor);

    // ── Untouched outline ────────────────────────────────────────────
    // Opaque strokes composited through one translucent layer: overlaps
    // at junctions blend once, keeping every meeting point smooth.
    canvas.saveLayer(
      layerBounds,
      Paint()
        ..color = baseColor.withValues(alpha: state.isFinished ? 0.08 : 0.18),
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

    if (!state.isFinished &&
        state.failGlow <= 0 &&
        state.path.isEmpty &&
        state.introSweepPhase > 0 &&
        state.introSweepPhase < 1) {
      _paintIdleShimmer(canvas, positions, baseW);
    }

    if (state.path.length > 2 && !state.isFinished && state.failGlow <= 0) {
      for (var i = 1; i < state.path.length - 1; i++) {
        final jp = positions[state.path[i]];
        if (jp == null) continue;
        canvas.drawCircle(
            jp,
            baseW * 0.95,
            Paint()
              ..color = accent.withValues(alpha: 0.16)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(
            jp, baseW * 0.5, Paint()..color = accent.withValues(alpha: 0.72));
      }
    }

    final solved = state.isFinished;
    final failing = state.failGlow > 0;
    final traceColor = failing ? failRed : (solved ? successGreen : accent);
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
      if (solved || failing) {
        corePaint.color = traceColor;
      } else {
        corePaint.shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [accent, _accentDeep],
        );
      }
      canvas.drawPath(tracedPath, corePaint);

      if (solved) {
        _paintComet(canvas, positions, traceW);
      }
    }

    if (!solved && !failing && state.hintEdgeId != null) {
      _paintHint(canvas, positions, traceW);
    }
    if (state.drawing && !solved && !failing) {
      _paintSparks(canvas, positions, headId, tipPx, traceW);
    }

    if (!solved && !failing) {
      final pulse = math.sin(state.pulsePhase * 2 * math.pi);
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
      final marker = tipPx ?? positions[headId];
      if (marker != null) {
        canvas.drawCircle(marker, traceW * 0.70, Paint()..color = traceColor);
      }
    }

    if (state.isFinished) {
      _paintSuccessTick(canvas, size, state.winGlow);
      _paintConfetti(canvas, size, state.confettiPhase);
    }
    if (failing) {
      final fp =
          state.failPointId == null ? null : positions[state.failPointId];
      if (fp != null) {
        canvas.drawCircle(
            fp,
            traceW * 2.8,
            Paint()
              ..color = failRed.withValues(alpha: 0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      _paintFailCross(canvas, size, state.failGlow);
    }
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

  static const successGreen = Color(0xFF34D399);
  static const failRed = Color(0xFFFF5A5F);

  /// Solid badge behind the result stamps so a green tick never melts
  /// into green lines (nor the red cross into red ones).
  void _paintBadgeBacking(
      Canvas canvas, Offset c, double radius, double t, Color ringColor) {
    final backing = isDark ? const Color(0xF00B1222) : const Color(0xFAFFFFFF);
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

  Offset? _pointAlong(List<Offset> points, double t) {
    if (points.isEmpty) return null;
    if (points.length == 1) return points.first;
    final lens = <double>[];
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final l = (points[i] - points[i - 1]).distance;
      lens.add(l);
      total += l;
    }
    if (total <= 0) return points.first;
    var target = (t.clamp(0.0, 1.0)) * total;
    for (var i = 0; i < lens.length; i++) {
      if (target <= lens[i]) {
        return Offset.lerp(points[i], points[i + 1], target / lens[i]);
      }
      target -= lens[i];
    }
    return points.last;
  }

  /// Before the first touch, a gentle light glides around the figure so
  /// the board reads as interactive without needing written instructions.
  void _paintIdleShimmer(Canvas canvas, Map<int, Offset> positions, double w) {
    final route = <Offset>[
      for (final id in state.solution)
        if (positions[id] != null) positions[id]!,
    ];
    if (route.length < 2) return;
    final travel = state.introSweepPhase.clamp(0.0, 1.0);
    final spot = _pointAlong(route, travel);
    if (spot == null) return;
    canvas.drawCircle(
        spot,
        w * 2.6,
        Paint()
          ..color = accent.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(
        spot, w * 0.42, Paint()..color = Colors.white.withValues(alpha: 0.55));
  }

  static const _confettiColors = <Color>[
    Color(0xFFFFD54F),
    Color(0xFFFF9F1C),
    Color(0xFF34D399),
    Color(0xFF38BDF8),
    Colors.white,
    Color(0xFFFF5A5F),
  ];

  static double _noise(num seed) {
    final v = math.sin(seed * 127.1 + 311.7) * 43758.5453;
    return v - v.floor();
  }

  /// One-shot burst of rotating confetti around the victory badge.
  void _paintConfetti(Canvas canvas, Size size, double phase) {
    if (phase <= 0 || phase >= 1) return;
    final t = phase.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final side = size.shortestSide;
    const count = 64;

    for (var i = 0; i < count; i++) {
      final angle = _noise(i + 1) * math.pi * 2;
      final speed = side * (0.20 + 0.34 * _noise(i + 40));
      final lift = side * (0.10 + 0.16 * _noise(i + 80));
      final fall = side * (0.40 + 0.30 * _noise(i + 120));
      final x = center.dx + math.cos(angle) * speed * t;
      final y =
          center.dy + math.sin(angle) * speed * t + (fall * t * t) - (lift * t);
      final alpha =
          math.pow(1 - t, 1.35).toDouble() * (0.65 + 0.35 * _noise(i + 160));
      final color = _confettiColors[i % _confettiColors.length];
      final w = side * (0.008 + 0.006 * _noise(i + 200));
      final h = w * (i % 3 == 0 ? 1.0 : 2.1);
      final spin =
          _noise(i + 240) * math.pi * 2 + t * (5 + 9 * _noise(i + 280));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin);
      canvas.drawRect(
        Offset(-w / 2, -h / 2) & Size(w, h),
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
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

    // One lap every pulse cycle; ease so it lingers at the ends.
    final c = _pointAlong(
      points,
      Curves.easeInOut.transform((state.pulsePhase % 1.0).clamp(0.0, 1.0)),
    );
    if (c == null) return;

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
      final end = positions[state.path[i]];
      if (end == null) continue;
      p.lineTo(end.dx, end.dy);
    }
    if (tip != null) p.lineTo(tip.dx, tip.dy);
    return p;
  }

  static const _hintCyan = Color(0xFF38BDF8);

  void _paintHint(Canvas canvas, Map<int, Offset> positions, double traceW) {
    final eid = state.hintEdgeId;
    if (eid == null) return;
    for (final e in state.edges) {
      if (e.id != eid) continue;
      final a = positions[e.a];
      final b = positions[e.b];
      if (a == null || b == null) return;
      final pulse = 0.5 + 0.5 * math.sin(state.pulsePhase * 2 * math.pi);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = _hintCyan.withValues(alpha: 0.16 + 0.14 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = traceW * 3.0
            ..strokeCap = StrokeCap.round);
      final dash = Paint()
        ..color = _hintCyan.withValues(alpha: 0.75 + 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = traceW * 0.85
        ..strokeCap = StrokeCap.round;
      const segments = 10;
      for (var i = 0; i < segments; i += 2) {
        canvas.drawLine(Offset.lerp(a, b, i / segments)!,
            Offset.lerp(a, b, (i + 1) / segments)!, dash);
      }
      canvas.drawCircle(b, traceW * (1.0 + 0.25 * pulse),
          Paint()..color = _hintCyan.withValues(alpha: 0.22 + 0.18 * pulse));
      canvas.drawCircle(b, traceW * 0.45,
          Paint()..color = Colors.white.withValues(alpha: 0.9));
      return;
    }
  }

  void _paintSparks(Canvas canvas, Map<int, Offset> positions, int? headId,
      Offset? tip, double traceW) {
    final pen = tip ?? (headId == null ? null : positions[headId]);
    if (pen == null) return;

    canvas.drawCircle(
        pen,
        traceW * 2.8,
        Paint()
          ..color = accent.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawCircle(
        pen,
        traceW * 1.35,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    const count = 12;
    for (var i = 0; i < count; i++) {
      final life = (state.pulsePhase * 1.9 + i / count) % 1.0;
      final angle = (i / count) * math.pi * 2 +
          math.sin(state.pulsePhase * math.pi * 4 + i) * 0.28;
      final radius = traceW * (1.0 + life * 3.4);
      final spot =
          pen + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(
          spot,
          traceW * (0.30 - 0.19 * life),
          Paint()
            ..color = (i.isEven ? Colors.white : accent)
                .withValues(alpha: (1 - life) * 0.9));
    }
    _paintSparkTrail(canvas, positions, tip, traceW);
  }

  void _paintSparkTrail(
      Canvas canvas, Map<int, Offset> positions, Offset? tip, double traceW) {
    final pts = <Offset>[
      for (final id in state.path)
        if (positions[id] != null) positions[id]!,
    ];
    if (tip != null) pts.add(tip);
    if (pts.length < 2) return;
    final tail = pts.sublist(math.max(0, pts.length - 4));
    final lens = <double>[];
    var total = 0.0;
    for (var i = 1; i < tail.length; i++) {
      final l = (tail[i] - tail[i - 1]).distance;
      lens.add(l);
      total += l;
    }
    if (total <= 0) return;
    const count = 14;
    for (var i = 0; i < count; i++) {
      var target =
          ((i / count) * total + state.pulsePhase * total * 0.4) % total;
      var spot = tail.first;
      for (var s = 0; s < lens.length; s++) {
        if (lens[s] > 0 && target <= lens[s]) {
          spot = Offset.lerp(tail[s], tail[s + 1], target / lens[s])!;
          break;
        }
        target -= lens[s];
      }
      final twinkle =
          0.5 + 0.5 * math.sin(state.pulsePhase * math.pi * 6 + i * 1.9);
      canvas.drawCircle(
          spot,
          traceW * (0.09 + 0.13 * twinkle),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.20 + 0.55 * twinkle));
    }
  }

  void _paintFailCross(Canvas canvas, Size size, double t) {
    if (t <= 0) return;
    final s = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.085 * s;
    final w = size.shortestSide * 0.024;

    canvas.drawCircle(
        c, r * 1.8, Paint()..color = failRed.withValues(alpha: 0.18 * t));
    _paintBadgeBacking(canvas, c, r * 1.42, t, failRed);

    final paint = Paint()
      ..color = failRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - r * 0.75, c.dy - r * 0.75),
        Offset(c.dx + r * 0.75, c.dy + r * 0.75), paint);
    canvas.drawLine(Offset(c.dx + r * 0.75, c.dy - r * 0.75),
        Offset(c.dx - r * 0.75, c.dy + r * 0.75), paint);
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
