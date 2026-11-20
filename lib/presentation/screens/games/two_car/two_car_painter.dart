import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'two_car_models.dart';

class TwoCarPainter extends CustomPainter {
  final TwoCarSnapshot snapshot;
  final bool isDark;
  final int? blinkItemId;
  final int? blinkLane;
  final bool blinkOn;

  const TwoCarPainter({
    required this.snapshot,
    required this.isDark,
    this.blinkItemId,
    this.blinkLane,
    this.blinkOn = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..color = isDark ? const Color(0xFF0B101B) : const Color(0xFFEDF2FA),
    );

    final laneWidth = size.width / 2;
    for (var lane = 0; lane < 2; lane++) {
      final rect = Rect.fromLTWH(lane * laneWidth, 0, laneWidth, size.height);
      final inset = rect.deflate(1);
      canvas.save();
      canvas
          .clipRRect(RRect.fromRectAndRadius(inset, const Radius.circular(19)));

      canvas.drawRect(
        rect,
        Paint()
          ..color = isDark ? const Color(0xFF121928) : const Color(0xFFF8FAFF),
      );

      _drawRails(canvas, rect, lane);
      if (snapshot.activeLanes.contains(lane)) {
        _drawTouchHalo(canvas, rect, lane);
      }
      for (final item in snapshot.items.where((item) => item.lane == lane)) {
        _drawItem(
          canvas,
          rect,
          item,
          blinkOn && item.id == blinkItemId,
        );
      }
      _drawCar(
        canvas,
        rect,
        lane,
        blinkOn && lane == blinkLane,
      );

      canvas.restore();
    }

    _drawInnerBoundary(
      canvas,
      laneWidth * (1 - TwoCarLayout.laneEdgePadding),
      size.height,
      _laneColor(0),
    );
    _drawInnerBoundary(
      canvas,
      laneWidth * (1 + TwoCarLayout.laneEdgePadding),
      size.height,
      _laneColor(1),
    );
    canvas.drawLine(
      Offset(laneWidth, 0),
      Offset(laneWidth, size.height),
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08)
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
    );
  }

  void _drawRails(Canvas canvas, Rect rect, int lane) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.09)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 3;
    final x = lane == 0 ? rect.left + 3 : rect.right - 3;
    canvas.drawLine(
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      paint,
    );
  }

  void _drawInnerBoundary(
    Canvas canvas,
    double x,
    double height,
    Color color,
  ) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, height),
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.10 : 0.07)
        ..strokeWidth = 7,
    );
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, height),
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.48 : 0.38)
        ..strokeWidth = 2,
    );
  }

  void _drawTouchHalo(Canvas canvas, Rect rect, int lane) {
    final x = rect.left + snapshot.carX[lane] * rect.width;
    final y = rect.top + TwoCarLayout.carY * rect.height;
    canvas.drawCircle(
      Offset(x, y),
      rect.width * 0.17,
      Paint()..color = _laneColor(lane).withValues(alpha: isDark ? 0.16 : 0.12),
    );
  }

  void _drawItem(
    Canvas canvas,
    Rect rect,
    TwoCarItem item,
    bool blink,
  ) {
    final cx = rect.left + item.x * rect.width;
    final cy = rect.top + item.y * rect.height;
    if (item.kind == TwoCarItemKind.coin) {
      final radius = math.min(
            TwoCarLayout.coinWidth * rect.width,
            TwoCarLayout.coinHeight * rect.height,
          ) /
          2;
      final laneColor = _laneColor(item.lane);
      final lightColor = Color.lerp(laneColor, Colors.white, 0.45)!;
      final darkColor = Color.lerp(laneColor, Colors.black, 0.18)!;
      canvas.drawCircle(
        Offset(cx, cy + 3),
        radius,
        Paint()..color = laneColor.withValues(alpha: isDark ? 0.26 : 0.16),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = LinearGradient(
            colors: [lightColor, darkColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.8),
      );
      if (blink) {
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          radius + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: 0.95),
        );
      }
      return;
    }

    final side = math.min(
      TwoCarLayout.obstacleWidth * rect.width,
      TwoCarLayout.obstacleHeight * rect.height,
    );
    final corner = Radius.circular(side * 0.16);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: side, height: side),
      corner,
    );
    const squareColor = Color(0xFFD92D4F);
    final lightColor = Color.lerp(squareColor, Colors.white, 0.52)!;
    final darkColor = Color.lerp(squareColor, Colors.black, 0.24)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.outerRect.inflate(3), corner),
      Paint()..color = squareColor.withValues(alpha: isDark ? 0.10 : 0.08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.outerRect.shift(const Offset(0, 3)), corner),
      Paint()..color = Colors.black.withValues(alpha: isDark ? 0.30 : 0.14),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          colors: [lightColor, darkColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(box.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.outerRect.deflate(1.5),
        Radius.circular(corner.x * 0.8),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          box.outerRect.left + side * 0.18,
          box.outerRect.top + side * 0.16,
          side * 0.28,
          side * 0.10,
        ),
        Radius.circular(side * 0.05),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );
    if (blink) {
      canvas.drawRRect(
        box,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.outerRect.inflate(5), corner),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  void _drawCar(Canvas canvas, Rect rect, int lane, bool blink) {
    final color = _laneColor(lane);
    final cx = rect.left + snapshot.carX[lane] * rect.width;
    final cy = rect.top + TwoCarLayout.carY * rect.height;
    final width = TwoCarLayout.carWidth * rect.width;
    final height = TwoCarLayout.carHeight * rect.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 5), width: width, height: height),
        Radius.circular(height * 0.4),
      ),
      Paint()..color = Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
    );

    final wheelPaint = Paint()..color = const Color(0xFF111827);
    final wheelR = height * 0.22;
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * width * 0.3, cy + height * 0.36),
            width: width * 0.18,
            height: height * 0.34,
          ),
          Radius.circular(wheelR),
        ),
        wheelPaint,
      );
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: height),
      Radius.circular(height * 0.42),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 1), color.withValues(alpha: 0.62)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(body.outerRect),
    );

    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy - height * 0.12),
        width: width * 0.52,
        height: height * 0.36,
      ),
      Radius.circular(height * 0.18),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..color = isDark ? const Color(0xCC0B1220) : const Color(0xBFFFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + height * 0.29),
          width: width * 0.64,
          height: height * 0.12,
        ),
        Radius.circular(height * 0.06),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    if (blink) {
      canvas.drawRRect(
        body,
        Paint()..color = Colors.white.withValues(alpha: 0.32),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          body.outerRect.inflate(5),
          Radius.circular(height * 0.42),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  Color _laneColor(int lane) =>
      lane == 0 ? const Color(0xFF00E5FF) : const Color(0xFFB388FF);

  @override
  bool shouldRepaint(covariant TwoCarPainter oldDelegate) {
    if (oldDelegate.isDark != isDark ||
        oldDelegate.blinkItemId != blinkItemId ||
        oldDelegate.blinkLane != blinkLane ||
        oldDelegate.blinkOn != blinkOn ||
        oldDelegate.snapshot.phase != snapshot.phase ||
        oldDelegate.snapshot.score != snapshot.score ||
        oldDelegate.snapshot.coins != snapshot.coins ||
        oldDelegate.snapshot.elapsed != snapshot.elapsed ||
        oldDelegate.snapshot.carX.length != snapshot.carX.length ||
        oldDelegate.snapshot.activeLanes.length !=
            snapshot.activeLanes.length) {
      return true;
    }
    for (var i = 0; i < snapshot.carX.length; i++) {
      if (oldDelegate.snapshot.carX[i] != snapshot.carX[i]) return true;
    }
    for (final lane in snapshot.activeLanes) {
      if (!oldDelegate.snapshot.activeLanes.contains(lane)) return true;
    }
    if (oldDelegate.snapshot.items.length != snapshot.items.length) return true;
    for (var i = 0; i < snapshot.items.length; i++) {
      final a = oldDelegate.snapshot.items[i];
      final b = snapshot.items[i];
      if (a.id != b.id ||
          a.lane != b.lane ||
          a.x != b.x ||
          a.y != b.y ||
          a.kind != b.kind) {
        return true;
      }
    }
    return false;
  }
}
