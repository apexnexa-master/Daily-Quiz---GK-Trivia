// lib/presentation/screens/games/synapse_recall/synapse_art.dart
// Premium vector "synapse network" illustration used on the game intro screen
// and as the Synapse Recall game tile cover. Pure CustomPainter — no image
// assets, no embedded text, no fake UI. Follows the BRAINX dark premium visual
// language (deep navy, neon lime / cyan / purple accents, soft glows).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SynapseNetworkPainter extends CustomPainter {
  final double progress;

  SynapseNetworkPainter({this.progress = 1.0});

  static const List<Color> _accents = [
    Color(0xFFD4FF50),
    Color(0xFF00F1FE),
    Color(0xFFB388FF),
    Color(0xFFFF5FA2),
    Color(0xFF43E29A),
  ];

  Offset _node(Size size, int i, double spread) {
    // Deterministic positions derived from the index (no flicker across frames).
    final angle = (i * 2.399963).remainder(math.pi * 2);
    final r = spread * (0.35 + 0.25 * (math.sin(i * 1.7) * 0.5 + 0.5));
    final center = Offset(size.width / 2, size.height * 0.52);
    return center + Offset(math.cos(angle) * r, math.sin(angle) * r * 0.82);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ambient glow blooms.
    final blooms = <(Offset, double, Color)>[
      (Offset(w * 0.18, h * 0.12), w * 0.55, AppColors.primary),
      (Offset(w * 0.85, h * 0.28), w * 0.5, const Color(0xFFB388FF)),
      (Offset(w * 0.5, h * 0.9), w * 0.6, const Color(0xFF00F1FE)),
    ];
    for (final (center, radius, color) in blooms) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Sparse background node dots.
    final dots = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < 40; i++) {
      final dx = ((i * 37) % 101) / 100 * w;
      final dy = ((i * 61) % 103) / 100 * h;
      canvas.drawCircle(Offset(dx, dy), (i % 5) == 0 ? 1.6 : 1.0, dots);
    }

    // Connected node network.
    const count = 16;
    final nodes = <Offset>[];
    final colors = <Color>[];
    for (var i = 0; i < count; i++) {
      nodes.add(_node(size, i, 0.88));
      colors.add(_accents[i % _accents.length]);
    }

    // Links between nearby nodes.
    for (var i = 0; i < count; i++) {
      for (var j = i + 1; j < count; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < w * 0.30) {
          final line = Paint()
            ..isAntiAlias = true
            ..strokeWidth = 1.2
            ..color = colors[i].withValues(alpha: 0.28 * progress);
          canvas.drawLine(nodes[i], nodes[j], line);
        }
      }
    }

    // Nodes.
    for (var i = 0; i < count; i++) {
      final center = nodes[i];
      final radius = 3.5 + 3.5 * ((i % 3) + 1) * 0.35;
      final color = colors[i];

      final glow = Paint()
        ..color = color.withValues(alpha: 0.20 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius * 2.0, glow);

      final fill = Paint()
        ..color = color.withValues(alpha: 0.85 * progress);
      canvas.drawCircle(center, radius, fill);

      if (i % 5 == 0) {
        // A few nodes become geometric diamonds for character.
        final diamond = Path();
        final r2 = radius * 1.4;
        diamond
          ..moveTo(center.dx, center.dy - r2)
          ..lineTo(center.dx + r2, center.dy)
          ..lineTo(center.dx, center.dy + r2)
          ..lineTo(center.dx - r2, center.dy)
          ..close();
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.75 * progress);
        canvas.drawPath(diamond, ring);
      } else {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.55 * progress);
        canvas.drawCircle(center, radius * 1.6, ring);
      }
    }
  }

  @override
  bool shouldRepaint(SynapseNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Full-bleed illustration used on the intro screen.
class SynapseNetworkArt extends StatelessWidget {
  final double progress;
  const SynapseNetworkArt({super.key, this.progress = 1.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SynapseNetworkPainter(progress: progress),
      size: const Size.square(180),
    );
  }
}

/// Reusable cover for the Synapse Recall game tile (matches GameCard cover slot).
class SynapseRecallCover extends StatelessWidget {
  const SynapseRecallCover({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1117), Color(0xFF101A24), Color(0xFF16213A)],
        ),
      ),
      child: CustomPaint(
        painter: SynapseNetworkPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
