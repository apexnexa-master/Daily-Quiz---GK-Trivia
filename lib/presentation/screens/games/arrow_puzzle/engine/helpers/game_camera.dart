import 'dart:math';
import 'package:flutter/material.dart';

class GameCamera {
  double scale;
  Offset pan;
  double tileSize;
  int gridColumns;
  int gridRows;

  bool allowOverflow;

  GameCamera({
    this.scale = 1.0,
    this.pan = Offset.zero,
    this.tileSize = 52,
    this.gridColumns = 6,
    this.gridRows = 6,
    this.allowOverflow = false,
  });

  Offset gridToScreen(int x, int y) {
    return Offset(x * tileSize * scale, y * tileSize * scale) + pan;
  }

  Size get gridExtent {
    final w = gridColumns * tileSize * scale;
    final h = gridRows * tileSize * scale;
    return Size(w, h);
  }

  void autoScale(Size viewport) {
    if (gridColumns <= 0 || gridRows <= 0 || tileSize <= 0) return;
    const double boardMargin = 8.0;
    final extentW = gridColumns * tileSize.toDouble() + boardMargin * 2;
    final extentH = gridRows * tileSize.toDouble() + boardMargin * 2;
    if (extentW <= 0 || extentH <= 0) return;

    const double margin = 8.0;
    final availableW = viewport.width - margin * 2;
    final availableH = viewport.height - margin * 2;
    if (availableW <= 0 || availableH <= 0) return;

    final scaleX = availableW / extentW;
    final scaleY = availableH / extentH;
    final double calculatedScale = min(scaleX, scaleY);

    if (allowOverflow) {
      const double minScaleLimit = 1.0;
      scale = max(calculatedScale, minScaleLimit);
    } else {
      scale = calculatedScale;
    }

    final gridPixelW = gridColumns * tileSize * scale;
    final gridPixelH = gridRows * tileSize * scale;
    pan = Offset(
      (viewport.width - gridPixelW) / 2,
      (viewport.height - gridPixelH) / 2,
    );
  }

  Offset screenToGrid(Offset screen) {
    final gx = (screen.dx - pan.dx) / (tileSize * scale);
    final gy = (screen.dy - pan.dy) / (tileSize * scale);
    return Offset(gx, gy);
  }
}
