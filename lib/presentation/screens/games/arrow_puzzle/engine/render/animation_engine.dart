import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../logic/grid_matrix.dart';

enum AnimType { escape, bounce, undo }

class ArrowAnimationState {
  String arrowId;
  AnimType type;
  final List<Vector2> cells = [];
  final List<Vector2> route = [];
  Direction direction;
  ArrowColor color;
  ArrowShape shapeType;
  int layerId;
  double tailX;
  double tailY;
  double elapsed = 0;
  double duration;
  bool done = false;

  ArrowAnimationState({
    required this.arrowId,
    required this.type,
    List<Vector2>? cells,
    required this.direction,
    required this.color,
    this.shapeType = ArrowShape.straight,
    required this.layerId,
    required this.tailX,
    required this.tailY,
    required this.duration,
    this.elapsed = 0,
    this.done = false,
  }) {
    if (cells != null) this.cells.addAll(cells);
  }

  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  double slideDistance = 0;
  double opacityMultiplier = 1;
  double scaleMultiplier = 1;
  double redFlash = 0;
  double shakeIntensity = 0;

  void recompute() {
    final p = progress;
    switch (type) {
      case AnimType.escape:
        slideDistance = p * route.length;
        opacityMultiplier = p < 0.5 ? 1.0 : 1.0 - (p - 0.5) / 0.5;
        scaleMultiplier = 1.0 + 0.12 * (1 - p);
        break;
      case AnimType.bounce:
        if (p < 0.2) {
          slideDistance = (p / 0.2) * 0.20;
          redFlash = p / 0.2;
        } else {
          final bounce = _elasticOut((p - 0.2) / 0.8);
          slideDistance = 0.20 * (1 - bounce);
          redFlash = 1.0 - (p - 0.2) / 0.8;
        }
        redFlash = redFlash.clamp(0.0, 1.0);
        break;
      case AnimType.undo:
        slideDistance = (1.0 - _easeOutQuad(p)) * route.length;
        opacityMultiplier = p < 0.25 ? 0 : (p - 0.25) / 0.75;
        scaleMultiplier = 0.85 + 0.15 * p;
        break;
    }
  }

  Offset gridDirectionOffset(double tileW, double tileH) {
    switch (direction) {
      case Direction.right:
        return Offset(tileW / 2, tileH / 2);
      case Direction.down:
        return Offset(-tileW / 2, tileH / 2);
      case Direction.left:
        return Offset(-tileW / 2, -tileH / 2);
      case Direction.up:
        return Offset(tileW / 2, -tileH / 2);
    }
  }

  void update(double dt) {
    if (done) return;
    elapsed += dt;
    if (elapsed >= duration) {
      elapsed = duration;
      done = true;
    }
    recompute();
  }

  static double _easeOutQuad(double t) => t * (2 - t);

  static double _elasticOut(double t) {
    if (t == 0 || t == 1) return t;
    return pow(2, -10 * t) * sin((t * 10 - 0.75) * pi / 1.5) + 1;
  }
}

class FloatingText {
  String text;
  Offset position;
  double elapsed = 0;
  final double duration = 1.5;
  Color color;
  double fontSize;

  FloatingText({
    required this.text,
    required this.position,
    this.elapsed = 0,
    this.color = Colors.white,
    this.fontSize = 24,
  });

  bool get done => elapsed >= duration;
  double get opacity => (1 - elapsed / duration).clamp(0.0, 1.0);
  double get driftY => -elapsed * 40;

  void update(double dt) {
    elapsed += dt;
  }
}

class AnimationEngine {
  static const int _animPoolSize = 32;
  static const int _textPoolSize = 8;

  final List<ArrowAnimationState> _animations = [];
  final List<FloatingText> _floatingTexts = [];
  final List<ArrowAnimationState> _animPool = [];
  final List<FloatingText> _textPool = [];

  List<ArrowAnimationState> get activeAnimations =>
      List.unmodifiable(_animations);
  List<FloatingText> get activeFloatingTexts =>
      List.unmodifiable(_floatingTexts);
  double _shakeTimer = 0;
  double _shakeIntensity = 0;
  double _shakeDuration = 0;

  AnimationEngine() {
    for (int i = 0; i < _animPoolSize; i++) {
      _animPool.add(ArrowAnimationState(
        arrowId: '',
        type: AnimType.escape,
        cells: [],
        direction: Direction.right,
        color: ArrowColor.neutral,
        layerId: 0,
        tailX: 0,
        tailY: 0,
        duration: 0,
      ));
    }
    for (int i = 0; i < _textPoolSize; i++) {
      _textPool.add(FloatingText(
        text: '',
        position: Offset.zero,
      ));
    }
  }

  ArrowAnimationState _acquireAnimState() {
    if (_animPool.isNotEmpty) {
      return _animPool.removeLast();
    }
    return ArrowAnimationState(
      arrowId: '',
      type: AnimType.escape,
      cells: [],
      direction: Direction.right,
      color: ArrowColor.neutral,
      layerId: 0,
      tailX: 0,
      tailY: 0,
      duration: 0,
    );
  }

  void _releaseAnimState(ArrowAnimationState state) {
    if (_animPool.length < _animPoolSize) {
      state.done = false;
      state.elapsed = 0;
      state.slideDistance = 0;
      state.opacityMultiplier = 1;
      state.scaleMultiplier = 1;
      state.redFlash = 0;
      state.shakeIntensity = 0;
      state.route.clear();
      _animPool.add(state);
    }
  }

  FloatingText _acquireText() {
    if (_textPool.isNotEmpty) {
      return _textPool.removeLast();
    }
    return FloatingText(text: '', position: Offset.zero);
  }

  void _releaseText(FloatingText text) {
    if (_textPool.length < _textPoolSize) {
      text.elapsed = 0;
      _textPool.add(text);
    }
  }

  void startEscape(ArrowEntity arrow, LogicalGrid grid) {
    _animations.removeWhere((a) =>
        a.arrowId == arrow.id && a.type == AnimType.escape);
    final state = _acquireAnimState();
    state.arrowId = arrow.id;
    state.type = AnimType.escape;
    state.cells
      ..clear()
      ..addAll(arrow.getOccupiedCells());
    state.direction = arrow.getTipDirection();
    state.color = arrow.color;
    state.shapeType = arrow.shapeType;
    state.layerId = arrow.layerId;
    state.tailX = arrow.tailPosition.x;
    state.tailY = arrow.tailPosition.y;
    state.route
      ..clear()
      ..addAll(grid.getExitRoute(arrow));
    state.duration = state.route.length * 0.08;
    state.elapsed = 0;
    state.done = false;
    _animations.add(state);
  }

  void startBounce(String arrowId, ArrowEntity arrow, LogicalGrid grid) {
    _animations.removeWhere((a) =>
        a.arrowId == arrowId && a.type == AnimType.bounce);
    final state = _acquireAnimState();
    state.arrowId = arrowId;
    state.type = AnimType.bounce;
    state.cells
      ..clear()
      ..addAll(arrow.getOccupiedCells());
    state.direction = arrow.getTipDirection();
    state.color = arrow.color;
    state.shapeType = arrow.shapeType;
    state.layerId = arrow.layerId;
    state.tailX = arrow.tailPosition.x;
    state.tailY = arrow.tailPosition.y;
    state.route
      ..clear()
      ..addAll(grid.getExitRoute(arrow));
    state.duration = 0.3;
    state.elapsed = 0;
    state.done = false;
    _animations.add(state);
  }

  void startUndo(String arrowId, ArrowEntity arrow, LogicalGrid grid) {
    _animations.removeWhere((a) =>
        a.arrowId == arrowId && a.type == AnimType.undo);
    final state = _acquireAnimState();
    state.arrowId = arrowId;
    state.type = AnimType.undo;
    state.cells
      ..clear()
      ..addAll(arrow.getOccupiedCells());
    state.direction = arrow.getTipDirection();
    state.color = arrow.color;
    state.shapeType = arrow.shapeType;
    state.layerId = arrow.layerId;
    state.tailX = arrow.tailPosition.x;
    state.tailY = arrow.tailPosition.y;
    state.route
      ..clear()
      ..addAll(grid.getExitRoute(arrow));
    state.duration = state.route.length * 0.06;
    state.elapsed = 0;
    state.done = false;
    _animations.add(state);
  }

  void triggerComboEffect(int combo) {
    if (combo >= 5) {
      _shakeDuration = 0.2 + (combo - 5) * 0.05;
      _shakeTimer = _shakeDuration;
      _shakeIntensity = 2.0 + (combo - 5) * 0.5;
    }
    if (combo >= 3) {
      final ft = _acquireText();
      ft.text = 'x$combo';
      ft.position = const Offset(200, 80);
      ft.color = combo >= 5 ? Colors.yellow : Colors.white;
      ft.fontSize = combo >= 5 ? 36 : 24;
      ft.elapsed = 0;
      _floatingTexts.add(ft);
    }
  }

  bool hasAnimFor(String arrowId, AnimType type) {
    return _animations.any((a) => a.arrowId == arrowId && a.type == type);
  }

  ArrowAnimationState? find(String arrowId, AnimType type) {
    for (final a in _animations) {
      if (a.arrowId == arrowId && a.type == type && !a.done) return a;
    }
    return null;
  }

  void clear() {
    _animations.clear();
    _floatingTexts.clear();
    _shakeTimer = 0;
    _shakeIntensity = 0;
  }

  Offset get shakeOffset {
    if (_shakeTimer <= 0) return Offset.zero;
    return Offset(
      (Random().nextDouble() - 0.5) * _shakeIntensity,
      (Random().nextDouble() - 0.5) * _shakeIntensity,
    );
  }

  List<String> update(double dt) {
    final completedEscapeIds = <String>[];
    for (final a in _animations) {
      a.update(dt);
      if (a.done && a.type == AnimType.escape) {
        completedEscapeIds.add(a.arrowId);
      }
    }
    _animations.removeWhere((a) {
      if (a.done) {
        _releaseAnimState(a);
        return true;
      }
      return false;
    });

    for (final t in _floatingTexts) {
      t.update(dt);
    }
    _floatingTexts.removeWhere((t) {
      if (t.done) {
        _releaseText(t);
        return true;
      }
      return false;
    });

    if (_shakeTimer > 0) _shakeTimer -= dt;
    return completedEscapeIds;
  }
}
