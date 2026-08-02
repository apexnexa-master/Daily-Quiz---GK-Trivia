import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart';
import '../engine/logic/grid_matrix.dart';
import '../engine/logic/game_solver.dart';
import '../engine/logic/solver_cache.dart';
import '../engine/logic/undo_stack.dart';
import '../engine/data/level_schema.dart';
import '../engine/data/level_parser.dart';
import '../engine/data/economy_config.dart';
import '../engine/services/analytics_service.dart';

enum GameStatus { initial, playing, won, deadEnd, failed }

class LevelResult {
  final int levelId;
  final int movesUsed;
  final int targetMoves;
  final bool usedUndo;
  final bool usedHint;
  final int coinsEarned;

  LevelResult({
    required this.levelId,
    required this.movesUsed,
    required this.targetMoves,
    required this.usedUndo,
    required this.usedHint,
    required this.coinsEarned,
  });
}

class GameState {
  final GameStatus status;
  final ParsedLevel? parsedLevel;
  final int moveCount;
  final int combo;
  final int freeUndos;
  final int hintsUsed;
  final String? lastTappedArrowId;
  final bool lastMoveValid;
  final List<String> escapedArrowIds;
  final int lives;
  final int maxLives;

  GameState({
    this.status = GameStatus.initial,
    this.parsedLevel,
    this.moveCount = 0,
    this.combo = 0,
    this.freeUndos = 3,
    this.hintsUsed = 0,
    this.lastTappedArrowId,
    this.lastMoveValid = true,
    this.escapedArrowIds = const [],
    this.lives = 3,
    this.maxLives = 3,
  });

  GameState copyWith({
    GameStatus? status,
    ParsedLevel? parsedLevel,
    int? moveCount,
    int? combo,
    int? freeUndos,
    int? hintsUsed,
    String? lastTappedArrowId,
    bool? lastMoveValid,
    List<String>? escapedArrowIds,
    int? lives,
    int? maxLives,
  }) {
    return GameState(
      status: status ?? this.status,
      parsedLevel: parsedLevel ?? this.parsedLevel,
      moveCount: moveCount ?? this.moveCount,
      combo: combo ?? this.combo,
      freeUndos: freeUndos ?? this.freeUndos,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      lastTappedArrowId: lastTappedArrowId ?? this.lastTappedArrowId,
      lastMoveValid: lastMoveValid ?? this.lastMoveValid,
      escapedArrowIds: escapedArrowIds ?? this.escapedArrowIds,
      lives: lives ?? this.lives,
      maxLives: maxLives ?? this.maxLives,
    );
  }
}

abstract class GameEvent {}

class LoadLevelEvent extends GameEvent {
  final LevelData levelData;
  LoadLevelEvent(this.levelData);
}

class TapArrowEvent extends GameEvent {
  final String arrowId;
  TapArrowEvent(this.arrowId);
}

class UndoEvent extends GameEvent {
  final bool isPaid;
  UndoEvent({this.isPaid = false});
}

class UseHintEvent extends GameEvent {}

class ResetLevelEvent extends GameEvent {}

class FinishEscapeEvent extends GameEvent {
  final String arrowId;
  FinishEscapeEvent(this.arrowId);
}

class ReviveEvent extends GameEvent {}

class GameBloc extends Bloc<GameEvent, GameState> {
  final UndoStack _undoStack = UndoStack();
  final AnalyticsService _analytics;
  final SolverCache _solverCache = SolverCache();
  DateTime _lastValidTapTime = DateTime(2000);
  bool _hasUsedUndo = false;
  int _sessionLevelsPlayed = 0;
  DateTime? _sessionStartTime;

  GameBloc({AnalyticsService? analytics})
      : _analytics = analytics ?? NullAnalyticsService(),
        super(GameState()) {
    GameSolver.bindCache(_solverCache);
    on<LoadLevelEvent>(_onLoadLevel);
    on<TapArrowEvent>(_onTapArrow);
    on<UndoEvent>(_onUndo);
    on<UseHintEvent>(_onUseHint);
    on<ResetLevelEvent>(_onResetLevel);
    on<FinishEscapeEvent>(_onFinishEscape);
    on<ReviveEvent>(_onRevive);
  }

  bool get canUndo => _undoStack.canUndo;
  int get sessionLevelsPlayed => _sessionLevelsPlayed;
  DateTime? get sessionStartTime => _sessionStartTime;

  void _onLoadLevel(LoadLevelEvent event, Emitter<GameState> emit) {
    _undoStack.clear();
    _lastValidTapTime = DateTime(2000);
    _hasUsedUndo = false;
    _solverCache.onLevelLoad(event.levelData.metadata.levelId);
    final parsed = LevelParser.buildLogicalGrid(event.levelData);
    _sessionLevelsPlayed++;

    final md = event.levelData.metadata;
    _analytics.trackLevelStart(
      levelId: md.levelId,
      chapterId: md.chapterId,
      targetMoves: md.targetMoves,
      gridColumns: event.levelData.grid.columns,
      gridRows: event.levelData.grid.rows,
      arrowCount: parsed.arrowEntities.length,
    );

    emit(GameState(
      status: GameStatus.playing,
      parsedLevel: parsed,
      freeUndos: 3,
      lives: 3,
    ));
  }

  void _onUseHint(UseHintEvent event, Emitter<GameState> emit) {
    final s = state;
    if (s.status != GameStatus.playing) return;
    _analytics.trackHintUsed(
      levelId: s.parsedLevel?.levelData.metadata.levelId ?? 0,
      hintsUsed: s.hintsUsed + 1,
    );
    emit(s.copyWith(hintsUsed: s.hintsUsed + 1));
  }

  void _onTapArrow(TapArrowEvent event, Emitter<GameState> emit) {
    final state = this.state;
    if (state.status != GameStatus.playing && state.status != GameStatus.deadEnd) return;
    if (state.escapedArrowIds.contains(event.arrowId)) return;

    final parsed = state.parsedLevel;
    if (parsed == null) return;

    ArrowEntity? targetArrow;
    for (final arrow in parsed.arrowEntities) {
      if (arrow.id == event.arrowId) {
        targetArrow = arrow;
        break;
      }
    }

    if (targetArrow == null) return;
    if (targetArrow.state != ArrowState.active) return;

    if (GameSolver.isCoveredByHigherLayer(parsed.logicalGrid, targetArrow)) {
      _analytics.trackBlockedMove(
        levelId: parsed.levelData.metadata.levelId,
        arrowId: event.arrowId,
        reason: 'covered_by_higher_layer',
      );
      emit(state.copyWith(
        lastTappedArrowId: event.arrowId,
        lastMoveValid: false,
        combo: 0,
      ));
      return;
    }

    final arrowMod = parsed.logicalGrid.arrowModifiers[event.arrowId];
    if (arrowMod != null && !arrowMod.canPlayerTap(targetArrow)) {
      _analytics.trackBlockedMove(
        levelId: parsed.levelData.metadata.levelId,
        arrowId: event.arrowId,
        reason: 'modifier_blocked',
      );
      emit(state.copyWith(
        lastTappedArrowId: event.arrowId,
        lastMoveValid: false,
        combo: 0,
      ));
      return;
    }

    final isValid = parsed.logicalGrid.checkExitPath(targetArrow);

    if (isValid) {
      final record = UndoRecord(
        arrowId: targetArrow.id,
        tailX: targetArrow.tailPosition.x,
        tailY: targetArrow.tailPosition.y,
        direction: targetArrow.direction,
      );
      _undoStack.push(record);

      parsed.logicalGrid.clearArrowFromMatrix(targetArrow);
      targetArrow.state = ArrowState.escaping;
      targetArrow.escapeStartTime = DateTime.now();
      parsed.logicalGrid.escapingArrows.add(targetArrow);

      final now = DateTime.now();
      final isCombo = now.difference(_lastValidTapTime).inMilliseconds < 800;
      final newCombo = isCombo ? (state.combo + 1).clamp(0, 10) : 1;
      _lastValidTapTime = now;

      final newEscaped = List<String>.from(state.escapedArrowIds)..add(event.arrowId);

      final levelId = parsed.levelData.metadata.levelId;
      final activeCount = _countActiveArrows(parsed.arrowEntities);

      _analytics.trackMoveMade(
        levelId: levelId,
        arrowId: event.arrowId,
        moveCount: state.moveCount + 1,
        remainingArrows: activeCount,
      );

      GameStatus newStatus = state.status;
      if (activeCount == 0) {
        newStatus = GameStatus.won;
        _analytics.trackLevelComplete(
          levelId: levelId,
          movesUsed: state.moveCount + 1,
          targetMoves: parsed.levelData.metadata.targetMoves,
          stars: _calculateStars(state.moveCount + 1, parsed.levelData.metadata.targetMoves),
          usedUndo: _hasUsedUndo,
          usedHint: state.hintsUsed > 0,
          isPerfectClear: !_hasUsedUndo && state.hintsUsed == 0,
        );
      } else {
        final validMoves = GameSolver.getValidMoves(parsed.logicalGrid);
        if (validMoves.isEmpty) {
          newStatus = GameStatus.deadEnd;
          _analytics.trackDeadEnd(
            levelId: levelId,
            moveCount: state.moveCount + 1,
            arrowsRemaining: activeCount,
          );
        }
      }

      emit(state.copyWith(
        status: newStatus,
        moveCount: state.moveCount + 1,
        combo: newCombo,
        lastTappedArrowId: event.arrowId,
        lastMoveValid: true,
        escapedArrowIds: newEscaped,
      ));
    } else {
      _analytics.trackBlockedMove(
        levelId: parsed.levelData.metadata.levelId,
        arrowId: event.arrowId,
        reason: 'path_blocked',
      );
      emit(state.copyWith(
        lastTappedArrowId: event.arrowId,
        lastMoveValid: false,
        combo: 0,
      ));
    }
  }

  void _onUndo(UndoEvent event, Emitter<GameState> emit) {
    final state = this.state;
    if (state.status == GameStatus.won) return;
    if (!_undoStack.canUndo) return;

    if (event.isPaid) {
      if (_undoStack.hasFreeUndo) return;
    } else {
      if (!_undoStack.hasFreeUndo) return;
      _undoStack.useFreeUndo();
    }
    _hasUsedUndo = true;

    final levelId = state.parsedLevel?.levelData.metadata.levelId ?? 0;
    _analytics.trackUndoUsed(
      levelId: levelId,
      isPaid: event.isPaid,
      freeUndosRemaining: state.freeUndos - (event.isPaid ? 0 : 1),
    );

    final record = _undoStack.pop();
    if (record == null) return;

    final parsed = state.parsedLevel;
    if (parsed == null) return;

    ArrowEntity? targetArrow;
    for (final arrow in parsed.arrowEntities) {
      if (arrow.id == record.arrowId) {
        targetArrow = arrow;
        break;
      }
    }

    if (targetArrow == null) return;

    targetArrow.tailPosition = Vector2(record.tailX, record.tailY);
    targetArrow.direction = record.direction;
    targetArrow.state = ArrowState.active;
    targetArrow.isEscaped = false;
    targetArrow.cachedExitRoute = null;

    parsed.logicalGrid.registerArrow(targetArrow);
    parsed.logicalGrid.escapingArrows.removeWhere((a) => a.id == targetArrow!.id);

    final newEscaped = List<String>.from(state.escapedArrowIds)
      ..remove(record.arrowId);

    final newFreeUndos = event.isPaid ? state.freeUndos : state.freeUndos - 1;

    emit(state.copyWith(
      status: GameStatus.playing,
      moveCount: state.moveCount - 1,
      combo: 0,
      freeUndos: newFreeUndos,
      escapedArrowIds: newEscaped,
    ));
  }

  void _onFinishEscape(FinishEscapeEvent event, Emitter<GameState> emit) {
    final state = this.state;
    final parsed = state.parsedLevel;
    if (parsed == null) return;

    for (final arrow in parsed.arrowEntities) {
      if (arrow.id == event.arrowId) {
        arrow.state = ArrowState.escaped;
        arrow.isEscaped = true;
        parsed.logicalGrid.escapingArrows.removeWhere((a) => a.id == arrow.id);
        break;
      }
    }
    emit(state.copyWith(
      escapedArrowIds: List<String>.from(state.escapedArrowIds),
    ));
  }

  void _onRevive(ReviveEvent event, Emitter<GameState> emit) {
    final state = this.state;
    if (state.status != GameStatus.failed) return;
    emit(state.copyWith(
      status: GameStatus.playing,
      lives: 3,
    ));
  }

  void _onResetLevel(ResetLevelEvent event, Emitter<GameState> emit) {
    final parsed = state.parsedLevel;
    if (parsed == null) return;
    loadLevel(parsed.levelData);
  }

  void loadLevel(LevelData levelData) {
    add(LoadLevelEvent(levelData));
  }

  void startSession() {
    _sessionStartTime = DateTime.now();
  }

  void endSession() {
    if (_sessionStartTime == null) return;
    final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;
    _analytics.trackSessionEnd(
      sessionDurationSeconds: duration,
      levelsPlayedThisSession: _sessionLevelsPlayed,
    );
    _sessionLevelsPlayed = 0;
    _sessionStartTime = null;
  }

  int _calculateStars(int moves, int targetMoves) {
    if (moves == targetMoves) return 3;
    if (moves <= targetMoves + 2) return 2;
    return 1;
  }

  LevelResult? getLevelResult() {
    final s = state;
    if (s.status != GameStatus.won || s.parsedLevel == null) return null;
    final target = s.parsedLevel!.levelData.metadata.targetMoves;
    final coinsEarned = EconomyConfig.levelClearCoins + (s.hintsUsed == 0 ? EconomyConfig.perfectClearBonus : 0);
    return LevelResult(
      levelId: s.parsedLevel!.levelData.metadata.levelId,
      movesUsed: s.moveCount,
      targetMoves: target,
      usedUndo: _hasUsedUndo,
      usedHint: s.hintsUsed > 0,
      coinsEarned: coinsEarned,
    );
  }

  int _countActiveArrows(List<ArrowEntity> arrows) {
    int count = 0;
    for (final a in arrows) {
      if (a.state == ArrowState.active) count++;
    }
    return count;
  }
}
