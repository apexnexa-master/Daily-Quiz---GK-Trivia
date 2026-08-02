import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../logic/grid_matrix.dart';
import '../helpers/game_camera.dart';
import '../../bloc/game_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'animation_engine.dart';
import 'dart:math' as math;
class GameCanvas extends FlameGame {
  GameCamera gameCamera = GameCamera();
  GameBloc? _bloc;
  bool _needsAutoScale = false;
  int _lastGridCols = 0;
  int _lastGridRows = 0;
  final AnimationEngine _animEngine = AnimationEngine();
  Set<String> _prevEscapedIds = {};
  final Set<String> _startedEscapeIds = {};
  String? _handledInvalidMoveId;
  int _lastHandledCombo = 0;
  double _tapFlashTimer = 0;
  String? _tapFlashArrowId;
  static const double _tapFlashDuration = 0.15;
  String? _blockedPathArrowId;
  double _blockedPathTimer = 0.0;
  final Paint _tileFillPaint = Paint();
  final Paint _tileStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  final Paint _arrowFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _arrowStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final Paint _modBgPaint = Paint()..style = PaintingStyle.fill;
  final Paint _modStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _portalPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _portalInnerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _gatePaint = Paint()..strokeWidth = 2.0;
  final Paint _lockPaint = Paint()..style = PaintingStyle.fill;
  final Paint _patternFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _patternStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  void bindBloc(GameBloc bloc) {
    _bloc = bloc;
    _prevEscapedIds = Set.from(bloc.state.escapedArrowIds);
    _startedEscapeIds.clear();
    _blockedPathArrowId = null;
    _blockedPathTimer = 0.0;
  }

  Vector2? _lastSize;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_lastSize == null || _lastSize!.x != size.x || _lastSize!.y != size.y) {
      _lastSize = Vector2(size.x, size.y);
      _needsAutoScale = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final completedEscapeIds = _animEngine.update(dt);
    for (final id in completedEscapeIds) {
      _bloc?.add(FinishEscapeEvent(id));
    }
    if (_tapFlashTimer > 0) {
      _tapFlashTimer -= dt;
      if (_tapFlashTimer <= 0) _tapFlashArrowId = null;
    }
    if (_blockedPathTimer > 0) {
      _blockedPathTimer -= dt;
      if (_blockedPathTimer <= 0) _blockedPathArrowId = null;
    }
    _checkForNewAnimations();
  }

  ArrowEntity? _findArrow(String id) {
    final level = _bloc?.state.parsedLevel;
    if (level == null) return null;
    for (final a in level.arrowEntities) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _checkForNewAnimations() {
    final state = _bloc?.state;
    if (state == null || state.parsedLevel == null) return;
    final grid = state.parsedLevel!.logicalGrid;

    for (final arrow in state.parsedLevel!.arrowEntities) {
      if (arrow.state == ArrowState.escaping &&
          !_animEngine.hasAnimFor(arrow.id, AnimType.escape) &&
          !_startedEscapeIds.contains(arrow.id)) {
        _animEngine.startEscape(arrow, grid);
        _startedEscapeIds.add(arrow.id);
      }
    }

    if (!state.lastMoveValid &&
        state.lastTappedArrowId != null &&
        state.lastTappedArrowId != _handledInvalidMoveId) {
      final arrow = _findArrow(state.lastTappedArrowId!);
      if (arrow != null) {
        _animEngine.startBounce(state.lastTappedArrowId!, arrow, grid);
        _blockedPathArrowId = state.lastTappedArrowId;
        _blockedPathTimer = 0.8;
      }
      _handledInvalidMoveId = state.lastTappedArrowId;
    }

    final currentEscaped = Set<String>.from(state.escapedArrowIds);
    for (final id in _prevEscapedIds) {
      if (!currentEscaped.contains(id)) {
        final arrow = _findArrow(id);
        if (arrow != null &&
            !_animEngine.hasAnimFor(id, AnimType.undo)) {
          _animEngine.startUndo(id, arrow, grid);
          _startedEscapeIds.remove(id);
        }
      }
    }
    _prevEscapedIds = currentEscaped;

    if (state.combo >= 3 && state.combo != _lastHandledCombo) {
      _animEngine.triggerComboEffect(state.combo);
      _lastHandledCombo = state.combo;
    }
  }

  void handleTap(Offset screenPos) {
    final bloc = _bloc;
    if (bloc == null) return;
    final state = bloc.state;
    if (state.status != GameStatus.playing) return;
    final grid = state.parsedLevel?.logicalGrid;
    if (grid == null) return;

    final gridPos = gameCamera.screenToGrid(screenPos);
    final gx = gridPos.dx.floor();
    final gy = gridPos.dy.floor();

    if (gx < 0 || gx >= gameCamera.gridColumns || gy < 0 || gy >= gameCamera.gridRows) return;

    for (int l = 2; l >= 0; l--) {
      final occupant = grid.matrix[gx][gy][l];
      if (occupant != null && occupant.state == ArrowState.active) {
        _tapFlashArrowId = occupant.id;
        _tapFlashTimer = _tapFlashDuration;
        bloc.add(TapArrowEvent(occupant.id));
        return;
      }
    }
  }

  static const _arrowColors = {
    ArrowColor.neutral: Color(0xFF8E9AA6),
    ArrowColor.red: Color(0xFFFD5564),
    ArrowColor.blue: Color(0xFF2FA6FF),
    ArrowColor.green: Color(0xFF3CD070),
    ArrowColor.yellow: Color(0xFFFFC03D),
  };

  static const _modifierColors = {
    SpecialTileType.ice: Color(0xFF80DEEA),
    SpecialTileType.portalEntrance: Color(0xFFAB47BC),
    SpecialTileType.portalExit: Color(0xFF8E24AA),
    SpecialTileType.colorLock: Color(0xFFFFF176),
    SpecialTileType.oneWayGate: Color(0xFFFF7043),
    SpecialTileType.breakableWall: Color(0xFF546E7A),
  };

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bloc = _bloc;
    final state = bloc?.state;
    final level = state?.parsedLevel;

    if (level != null) {
      final cols = level.levelData.grid.columns;
      final rows = level.levelData.grid.rows;
      if (_lastGridCols != cols || _lastGridRows != rows) {
        gameCamera.gridColumns = cols;
        gameCamera.gridRows = rows;
        _lastGridCols = cols;
        _lastGridRows = rows;
        _needsAutoScale = true;
        _startedEscapeIds.clear();
      }
    }

    if (_needsAutoScale) {
      gameCamera.autoScale(Size(size.x, size.y));
      _needsAutoScale = false;
    }

    final shake = _animEngine.shakeOffset;
    if (shake != Offset.zero) canvas.save();
    if (shake != Offset.zero) canvas.translate(shake.dx, shake.dy);

    final bgGradientPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF141829),
          Color(0xFF070913),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      bgGradientPaint,
    );

    if (level == null) {
      if (shake != Offset.zero) canvas.restore();
      return;
    }

    // Render unified board container card behind tiles
    final ts = gameCamera.tileSize * gameCamera.scale;
    final margin = 8.0 * gameCamera.scale;
    final boardRect = Rect.fromLTRB(
      gameCamera.gridToScreen(0, 0).dx - margin,
      gameCamera.gridToScreen(0, 0).dy - margin,
      gameCamera.gridToScreen(gameCamera.gridColumns - 1, gameCamera.gridRows - 1).dx + ts + margin,
      gameCamera.gridToScreen(gameCamera.gridColumns - 1, gameCamera.gridRows - 1).dy + ts + margin,
    );
    final boardRRect = RRect.fromRectAndRadius(boardRect, Radius.circular(16 * gameCamera.scale));
    final boardCardPaint = Paint()..color = const Color(0xFF0f1124);
    canvas.drawRRect(boardRRect, boardCardPaint);

    final boardBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * gameCamera.scale
      ..color = const Color(0xFF1f2442);
    canvas.drawRRect(boardRRect, boardBorderPaint);

    _renderGrid(canvas);
    _renderModifiers(canvas, level.logicalGrid);

    for (int l = 0; l < 3; l++) {
      _renderArrowsOnLayer(canvas, level.arrowEntities, l);
      _renderAnimatingArrowsOnLayer(canvas, l);
    }

    _renderBlockedTrajectory(canvas, level);

    _renderFloatingTexts(canvas);
    _renderGameStatus(canvas, state!);

    if (shake != Offset.zero) canvas.restore();
  }

  void _renderGameStatus(Canvas canvas, GameState state) {
    if (state.status == GameStatus.playing) return;

    final text = switch (state.status) {
      GameStatus.won => 'LEVEL CLEARED!',
      GameStatus.deadEnd => 'DEAD END',
      _ => '',
    };

    if (text.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: state.status == GameStatus.won
              ? const Color(0xFF4CAF50)
              : const Color(0xFFE53935),
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.x / 2 - textPainter.width / 2, size.y / 2 - textPainter.height / 2),
    );
  }

  void _renderGrid(Canvas canvas) {
    final ts = gameCamera.tileSize * gameCamera.scale;

    for (int x = 0; x < gameCamera.gridColumns; x++) {
      for (int y = 0; y < gameCamera.gridRows; y++) {
        final pos = gameCamera.gridToScreen(x, y);

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx, pos.dy, ts, ts),
          Radius.circular(6 * gameCamera.scale),
        );
        // Subtle tile fill to match casing background (matches board background exactly)
        _tileFillPaint.color = const Color(0xFF0f1124);
        canvas.drawRRect(rrect, _tileFillPaint);
        // Extremely faint border stroke for grid hints
        _tileStrokePaint.color = const Color(0xFF1c234a).withValues(alpha: 0.12);
        canvas.drawRRect(rrect, _tileStrokePaint);
      }
    }
  }

  void _renderModifiers(Canvas canvas, LogicalGrid grid) {
    final ts = gameCamera.tileSize * gameCamera.scale;
    for (final modifier in grid.tileModifiers.values) {
      final pos = modifier.position;
      final center = gameCamera.gridToScreen(pos.x.toInt(), pos.y.toInt()) + Offset(ts / 2, ts / 2);

      final color = _modifierColors[modifier.type];
      if (color != null) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: ts - 4, height: ts - 4),
          Radius.circular(4),
        );
        _modBgPaint.color = color.withValues(alpha: 0.2);
        canvas.drawRRect(rrect, _modBgPaint);
        _modStrokePaint.color = color.withValues(alpha: 0.5);
        canvas.drawRRect(rrect, _modStrokePaint);
      }

      _renderModifierIcon(canvas, center, modifier);
    }
  }

  void _renderModifierIcon(Canvas canvas, Offset center, TileModifier modifier) {
    final s = gameCamera.scale;
    switch (modifier.type) {
      case SpecialTileType.portalEntrance:
      case SpecialTileType.portalExit:
        _drawPortalRing(canvas, center, s);
        break;
      case SpecialTileType.oneWayGate:
        _drawGateArrow(canvas, center, modifier.exitDirection, s);
        break;
      case SpecialTileType.colorLock:
        _drawLockIcon(canvas, center, modifier.requiredColor, s);
        break;
      case SpecialTileType.breakableWall:
        _drawBreakableIcon(canvas, center, modifier.hitPoints, s);
        break;
      case SpecialTileType.ice:
      case SpecialTileType.none:
        break;
    }
  }

  void _renderArrowsOnLayer(Canvas canvas, List<ArrowEntity> arrows, int layerId) {
    for (final arrow in arrows) {
      if (arrow.layerId != layerId) continue;
      if (arrow.state != ArrowState.active) continue;
      if (_animEngine.hasAnimFor(arrow.id, AnimType.escape)) continue;
      if (_animEngine.hasAnimFor(arrow.id, AnimType.bounce)) continue;
      if (_animEngine.hasAnimFor(arrow.id, AnimType.undo)) continue;
      _renderSingleArrow(canvas, arrow, null);
    }
  }

  void _renderAnimatingArrowsOnLayer(Canvas canvas, int layerId) {
    for (final anim in _animEngine.activeAnimations) {
      if (anim.layerId != layerId) continue;
      _renderSingleArrow(canvas, null, anim);
    }
  }

  void _renderFloatingTexts(Canvas canvas) {
    for (final ft in _animEngine.activeFloatingTexts) {
      final tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: ft.opacity),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(ft.position.dx - tp.width / 2, ft.position.dy + ft.driftY),
      );
    }
  }

  Offset getRouteScreenPos(List<v64.Vector2> route, double x, double tileSize) {
    if (route.isEmpty) return Offset.zero;
    if (x <= 0) {
      return gameCamera.gridToScreen(route.first.x.toInt(), route.first.y.toInt()) + Offset(tileSize / 2, tileSize / 2);
    }
    if (x >= route.length - 1) {
      final last = route.last;
      return gameCamera.gridToScreen(last.x.toInt(), last.y.toInt()) + Offset(tileSize / 2, tileSize / 2);
    }

    final index = x.floor();
    final t = x - index;
    final p0 = route[index];
    final p1 = route[index + 1];

    if ((p0 - p1).length > 1.5) {
      final cell = t < 0.5 ? p0 : p1;
      return gameCamera.gridToScreen(cell.x.toInt(), cell.y.toInt()) + Offset(tileSize / 2, tileSize / 2);
    }

    final s0 = gameCamera.gridToScreen(p0.x.toInt(), p0.y.toInt()) + Offset(tileSize / 2, tileSize / 2);
    final s1 = gameCamera.gridToScreen(p1.x.toInt(), p1.y.toInt()) + Offset(tileSize / 2, tileSize / 2);
    return Offset(
      s0.dx + (s1.dx - s0.dx) * t,
      s0.dy + (s1.dy - s0.dy) * t,
    );
  }

  List<List<Offset>> getSubPaths(List<Offset> segmentPoints, List<double> segmentIndices, List<v64.Vector2> route) {
    final List<List<Offset>> subPaths = [];
    if (segmentPoints.isEmpty) return subPaths;
    List<Offset> current = [segmentPoints.first];

    for (int i = 0; i < segmentPoints.length - 1; i++) {
      final idx0 = segmentIndices[i];
      final idx1 = segmentIndices[i + 1];
      
      bool hasJump = false;
      final startInt = idx0.floor();
      final endInt = idx1.floor();
      for (int j = startInt; j <= endInt; j++) {
        if (j >= 0 && j < route.length - 1) {
          if ((route[j] - route[j + 1]).length > 1.5) {
            hasJump = true;
            break;
          }
        }
      }

      if (hasJump) {
        subPaths.add(current);
        current = [segmentPoints[i + 1]];
      } else {
        current.add(segmentPoints[i + 1]);
      }
    }
    subPaths.add(current);
    return subPaths;
  }

  Direction getRouteDirectionAt(List<v64.Vector2> route, double x, Direction defaultDir) {
    if (route.isEmpty) return defaultDir;
    if (x <= 0) {
      if (route.length < 2) return defaultDir;
      final p0 = route[0];
      final p1 = route[1];
      final dx = (p1.x - p0.x).toInt();
      final dy = (p1.y - p0.y).toInt();
      if (dx == 1) return Direction.right;
      if (dx == -1) return Direction.left;
      if (dy == 1) return Direction.down;
      if (dy == -1) return Direction.up;
      return defaultDir;
    }
    final index = x.floor();
    if (index >= route.length - 1) {
      if (route.length < 2) return defaultDir;
      final p0 = route[route.length - 2];
      final p1 = route.last;
      final dx = (p1.x - p0.x).toInt();
      final dy = (p1.y - p0.y).toInt();
      if (dx == 1) return Direction.right;
      if (dx == -1) return Direction.left;
      if (dy == 1) return Direction.down;
      if (dy == -1) return Direction.up;
      return defaultDir;
    }
    final p0 = route[index];
    final p1 = route[index + 1];
    final dx = (p1.x - p0.x).toInt();
    final dy = (p1.y - p0.y).toInt();
    if (dx == 1) return Direction.right;
    if (dx == -1) return Direction.left;
    if (dy == 1) return Direction.down;
    if (dy == -1) return Direction.up;
    return defaultDir;
  }

  void _renderSingleArrow(Canvas canvas, ArrowEntity? arrow, ArrowAnimationState? anim) {
    final level = _bloc?.state.parsedLevel;
    if (level == null) return;
    final grid = level.logicalGrid;

    final layerId = anim?.layerId ?? arrow!.layerId;
    final layerOpacity = _layerOpacity(layerId);
    final arrowColor = anim?.color ?? arrow!.color;
    final baseColor = _arrowColors[arrowColor] ?? _arrowColors[ArrowColor.neutral]!;

    final opacityMul = anim?.opacityMultiplier ?? 1.0;
    final scaleMul = anim?.scaleMultiplier ?? 1.0;
    final redFlash = anim?.redFlash ?? 0.0;

    Color arrowFill = baseColor;
    if (redFlash > 0) {
      arrowFill = Color.lerp(baseColor, Colors.red, redFlash)!;
    }
    if (layerId == 0) {
      arrowFill = Color.lerp(arrowFill, const Color(0xFF607D8B), 0.25)!;
    } else if (layerId == 1) {
      arrowFill = Color.lerp(arrowFill, const Color(0xFF78909C), 0.10)!;
    }

    final ts = gameCamera.tileSize * gameCamera.scale * scaleMul;
    final alpha = (layerOpacity * opacityMul).clamp(0.0, 1.0);

    final List<v64.Vector2> route = anim != null
        ? anim.route
        : grid.getExitRoute(arrow!);
    final double slideDistance = anim?.slideDistance ?? 0.0;
    final int arrowLength = anim != null ? anim.cells.length : arrow!.length;
    final Direction initialDir = anim?.direction ?? arrow!.getTipDirection();

    final centers = <Offset>[];
    final segmentIndices = <double>[];
    for (int i = 0; i < arrowLength; i++) {
      final double idx = i.toDouble() + slideDistance;
      centers.add(getRouteScreenPos(route, idx, ts));
      segmentIndices.add(idx);
    }

    final double tipIdx = (arrowLength - 1).toDouble() + slideDistance;
    final dir = getRouteDirectionAt(route, tipIdx, initialDir);

    final isTapFlash = _tapFlashArrowId != null &&
        arrow != null &&
        arrow.id == _tapFlashArrowId &&
        _tapFlashTimer > 0;
    final flashIntensity = isTapFlash ? (_tapFlashTimer / _tapFlashDuration) : 0.0;

    Color useFill = arrowFill;
    if (flashIntensity > 0) {
      useFill = Color.lerp(arrowFill, Colors.white, flashIntensity * 0.4)!;
    }

    final subPaths = getSubPaths(centers, segmentIndices, route);

    // Draw drop shadow for higher layers
    if (layerId > 0 && alpha > 0.0) {
      canvas.save();
      final shadowOffset = Offset(ts * 0.035 * layerId, ts * 0.045 * layerId);
      canvas.translate(shadowOffset.dx, shadowOffset.dy);
      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.58
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: alpha * 0.35);
      for (int i = 0; i < subPaths.length; i++) {
        final isLastSubPath = (i == subPaths.length - 1);
        _drawShapeArrowShadow(canvas, subPaths[i], dir, ts, alpha, isLastSubPath, shadowPaint);
      }
      canvas.restore();
    }

    for (int i = 0; i < subPaths.length; i++) {
      final isLastSubPath = (i == subPaths.length - 1);
      _drawShapeArrowCasing(canvas, subPaths[i], dir, ts, alpha, isLastSubPath);
    }
    for (int i = 0; i < subPaths.length; i++) {
      final isLastSubPath = (i == subPaths.length - 1);
      _drawShapeArrowFill(canvas, subPaths[i], dir, useFill, ts, alpha, isLastSubPath);
    }

    _drawColorblindPatternOnCenters(canvas, centers, arrowColor, alpha, ts);
  }

  Path buildRoundedPath(List<Offset> points, double radius) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];

      final v0 = p0 - p1;
      final v2 = p2 - p1;

      final d0 = v0.distance;
      final d2 = v2.distance;

      final r = radius.clamp(0.0, d0 / 2).clamp(0.0, d2 / 2);

      final p0Active = p1 + _normalize(v0) * r;
      final p2Active = p1 + _normalize(v2) * r;

      path.lineTo(p0Active.dx, p0Active.dy);
      path.quadraticBezierTo(p1.dx, p1.dy, p2Active.dx, p2Active.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  Offset _normalize(Offset offset) {
    final d = offset.distance;
    return d == 0 ? Offset.zero : Offset(offset.dx / d, offset.dy / d);
  }

  void _drawShapeArrowCasing(Canvas canvas, List<Offset> centers, Direction dir, double ts, double alpha, bool drawHead) {
    if (centers.isEmpty) return;

    final casingWidth = ts * 0.58;

    final List<Offset> bodyPoints = [];
    if (centers.length > 1) {
      final tailDir = centers[1] - centers[0];
      final tailLen = tailDir.distance;
      if (tailLen > 0) {
        final tailDirNorm = Offset(tailDir.dx / tailLen, tailDir.dy / tailLen);
        bodyPoints.add(centers[0] - tailDirNorm * ts * 0.45);
      } else {
        bodyPoints.add(centers[0]);
      }
      bodyPoints.addAll(centers);
    } else {
      final center = centers.last;
      final step = _gridDirectionOffset(dir);
      bodyPoints.add(center - step * ts * 0.45);
      bodyPoints.add(center);
    }

    final radius = ts * 0.40;
    final path = buildRoundedPath(bodyPoints, radius);

    final casingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = casingWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF0f1124);
    canvas.drawPath(path, casingPaint);

    if (drawHead) {
      final last = centers.last;
      final headHalf = ts * 0.38;
      final headDepth = ts * 0.40;
      final casingHeadHalf = headHalf + ts * 0.08;
      final casingHeadDepth = headDepth + ts * 0.08;

      _drawArrowHead(canvas, last, dir, casingHeadHalf, casingHeadDepth, const Color(0xFF0f1124), 1.0);
    }
  }

  void _drawShapeArrowFill(Canvas canvas, List<Offset> centers, Direction dir, Color fillColor, double ts, double alpha, bool drawHead) {
    if (centers.isEmpty) return;

    final bodyWidth = ts * 0.42;

    final List<Offset> bodyPoints = [];
    if (centers.length > 1) {
      final tailDir = centers[1] - centers[0];
      final tailLen = tailDir.distance;
      if (tailLen > 0) {
        final tailDirNorm = Offset(tailDir.dx / tailLen, tailDir.dy / tailLen);
        bodyPoints.add(centers[0] - tailDirNorm * ts * 0.45);
      } else {
        bodyPoints.add(centers[0]);
      }
      bodyPoints.addAll(centers);
    } else {
      final center = centers.last;
      final step = _gridDirectionOffset(dir);
      bodyPoints.add(center - step * ts * 0.45);
      bodyPoints.add(center);
    }

    final radius = ts * 0.40;
    final path = buildRoundedPath(bodyPoints, radius);

    final bodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = bodyWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = fillColor.withValues(alpha: alpha);
    canvas.drawPath(path, bodyPaint);

    if (drawHead) {
      final last = centers.last;
      final headHalf = ts * 0.38;
      final headDepth = ts * 0.40;

      _drawArrowHead(canvas, last, dir, headHalf, headDepth, fillColor, alpha, drawStroke: true);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset center, Direction dir, double headHalf, double headDepth, Color fillColor, double alpha, {bool drawStroke = false}) {
    final path = Path();
    switch (dir) {
      case Direction.right:
        path.moveTo(center.dx + headDepth * 0.8, center.dy);
        path.lineTo(center.dx - headDepth * 0.4, center.dy - headHalf);
        path.lineTo(center.dx - headDepth * 0.4, center.dy + headHalf);
        path.close();
        break;
      case Direction.left:
        path.moveTo(center.dx - headDepth * 0.8, center.dy);
        path.lineTo(center.dx + headDepth * 0.4, center.dy - headHalf);
        path.lineTo(center.dx + headDepth * 0.4, center.dy + headHalf);
        path.close();
        break;
      case Direction.down:
        path.moveTo(center.dx, center.dy + headDepth * 0.8);
        path.lineTo(center.dx - headHalf, center.dy - headDepth * 0.4);
        path.lineTo(center.dx + headHalf, center.dy - headDepth * 0.4);
        path.close();
        break;
      case Direction.up:
        path.moveTo(center.dx, center.dy - headDepth * 0.8);
        path.lineTo(center.dx - headHalf, center.dy + headDepth * 0.4);
        path.lineTo(center.dx + headHalf, center.dy + headDepth * 0.4);
        path.close();
        break;
    }

    _arrowFillPaint.color = fillColor.withValues(alpha: alpha);
    canvas.drawPath(path, _arrowFillPaint);

    if (drawStroke) {
      _arrowStrokePaint.color = fillColor.withValues(alpha: alpha * 0.8);
      _arrowStrokePaint.strokeWidth = 1.0;
      canvas.drawPath(path, _arrowStrokePaint);
    }
  }

  Offset _gridDirectionOffset(Direction dir) {
    switch (dir) {
      case Direction.right:
        return Offset(1, 0);
      case Direction.left:
        return Offset(-1, 0);
      case Direction.down:
        return Offset(0, 1);
      case Direction.up:
        return Offset(0, -1);
    }
  }

  void _drawPortalRing(Canvas canvas, Offset center, double scale) {
    final radius = 6.0 * scale;
    _portalPaint.color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(center, radius, _portalPaint);
    _portalInnerPaint.color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius - 2.0 * scale, _portalInnerPaint);
  }

  void _drawGateArrow(Canvas canvas, Offset center, Direction? dir, double scale) {
    if (dir == null) return;
    final len = 8.0 * scale;
    Offset tip;
    switch (dir) {
      case Direction.right:
        tip = Offset(center.dx + len, center.dy);
        break;
      case Direction.left:
        tip = Offset(center.dx - len, center.dy);
        break;
      case Direction.down:
        tip = Offset(center.dx, center.dy + len);
        break;
      case Direction.up:
        tip = Offset(center.dx, center.dy - len);
        break;
    }
    _gatePaint.color = Colors.white.withValues(alpha: 0.9);
    _gatePaint.strokeWidth = 2.0 * scale;
    canvas.drawLine(center, tip, _gatePaint);
  }

  void _drawLockIcon(Canvas canvas, Offset center, ArrowColor? color, double scale) {
    final size = 5.0 * scale;
    final lockColor = color != null
        ? (_arrowColors[color] ?? Colors.white)
        : Colors.white;
    _lockPaint.color = lockColor.withValues(alpha: 0.8);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size * 2, height: size * 1.5),
      _lockPaint,
    );
  }

  void _drawBreakableIcon(Canvas canvas, Offset center, int hitPoints, double scale) {
    final text = '$hitPoints';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawColorblindPatternOnCenters(
      Canvas canvas, List<Offset> centers, ArrowColor color, double alpha, double ts) {
    if (color == ArrowColor.neutral) return;

    _patternFillPaint.color = Colors.white.withValues(alpha: alpha * 0.55);
    _patternStrokePaint.color = Colors.white.withValues(alpha: alpha * 0.55);

    for (final center in centers) {
      final cx = center.dx;
      final cy = center.dy;
      final s = ts * 0.15;

      switch (color) {
        case ArrowColor.red:
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy), width: s, height: s * 0.4),
            _patternFillPaint,
          );
          break;
        case ArrowColor.blue:
          canvas.drawCircle(Offset(cx, cy), s * 0.35, _patternFillPaint);
          break;
        case ArrowColor.green:
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy), width: s * 0.4, height: s),
            _patternFillPaint,
          );
          break;
        case ArrowColor.yellow:
          canvas.drawCircle(Offset(cx, cy), s * 0.4, _patternStrokePaint);
          break;
        case ArrowColor.neutral:
          break;
      }
    }
  }

  void _drawShapeArrowShadow(Canvas canvas, List<Offset> centers, Direction dir, double ts, double alpha, bool drawHead, Paint shadowPaint) {
    if (centers.isEmpty) return;

    final List<Offset> bodyPoints = [];
    if (centers.length > 1) {
      final tailDir = centers[1] - centers[0];
      final tailLen = tailDir.distance;
      if (tailLen > 0) {
        final tailDirNorm = Offset(tailDir.dx / tailLen, tailDir.dy / tailLen);
        bodyPoints.add(centers[0] - tailDirNorm * ts * 0.45);
      } else {
        bodyPoints.add(centers[0]);
      }
      bodyPoints.addAll(centers);
    } else {
      final center = centers.last;
      final step = _gridDirectionOffset(dir);
      bodyPoints.add(center - step * ts * 0.45);
      bodyPoints.add(center);
    }

    final radius = ts * 0.40;
    final path = buildRoundedPath(bodyPoints, radius);
    canvas.drawPath(path, shadowPaint);

    if (drawHead) {
      final last = centers.last;
      final headHalf = ts * 0.38;
      final headDepth = ts * 0.40;
      final casingHeadHalf = headHalf + ts * 0.08;
      final casingHeadDepth = headDepth + ts * 0.08;

      _drawArrowHead(canvas, last, dir, casingHeadHalf, casingHeadDepth, shadowPaint.color, alpha);
    }
  }

  void _renderBlockedTrajectory(Canvas canvas, dynamic level) {
    if (_blockedPathArrowId == null || _blockedPathTimer <= 0) return;

    final arrow = _findArrow(_blockedPathArrowId!);
    if (arrow == null) return;

    final blockedRoute = level.logicalGrid.getBlockedExitRoute(arrow);
    if (blockedRoute.isEmpty) return;

    final ts = gameCamera.tileSize * gameCamera.scale;
    final List<Offset> points = [];
    for (final cell in blockedRoute) {
      points.add(gameCamera.gridToScreen(cell.x.toInt(), cell.y.toInt()) + Offset(ts / 2, ts / 2));
    }

    // Build path with rounded corners
    final path = buildRoundedPath(points, ts * 0.28);
    final opacity = (_blockedPathTimer / 0.8).clamp(0.0, 1.0);

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ts * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.red.withValues(alpha: opacity * 0.45);
    canvas.drawPath(path, pathPaint);

    // Render a small pulsing red indicator at the blocker coordinate
    if (points.isNotEmpty) {
      final lastPoint = points.last;
      final sizePulse = ts * 0.85 + math.sin(_blockedPathTimer * 15) * ts * 0.05;
      final blockerRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: lastPoint, width: sizePulse, height: sizePulse),
        Radius.circular(6 * gameCamera.scale),
      );
      final blockerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.red.withValues(alpha: opacity * 0.25);
      canvas.drawRRect(blockerRRect, blockerPaint);

      final blockerBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * gameCamera.scale
        ..color = Colors.red.withValues(alpha: opacity * 0.85);
      canvas.drawRRect(blockerRRect, blockerBorder);
    }
  }

  static double _layerOpacity(int layerId) {
    switch (layerId) {
      case 0:
        return 0.70;
      case 1:
        return 0.85;
      case 2:
        return 1.00;
      default:
        return 1.00;
    }
  }
}
