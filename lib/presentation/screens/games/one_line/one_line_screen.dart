// lib/presentation/screens/games/one_line/one_line_screen.dart
//
// One-Line Drawing Puzzle — trace the whole figure with a single
// continuous stroke (Eulerian circuit). Grab the outline at the glowing
// start (or anywhere on tutorial levels) and drag all the way to the end
// without lifting, closing a loop early, or doubling back. A broken rule
// stamps a red cross and restarts the level from the beginning.
// Progress persists locally and in Firestore; solved levels stay
// replayable.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/scoring/game_performance.dart';
import '../../../../core/scoring/progression_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/daily_progress_service.dart';
import '../../../../core/services/game_sfx.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../games/widgets/countdown_overlay.dart';
import '../../../games/widgets/game_scaffold.dart';
import '../../../providers/app_providers.dart';
import 'one_line_engine.dart';
import 'one_line_generator.dart';
import 'one_line_models.dart';
import 'one_line_navigation.dart';
import 'one_line_painter.dart';

const String _bestScoreKey = 'one_line_best_v2';
const String _levelKey = 'one_line_level_v1';

enum _Phase { playing, finished, failed }

class _EdgeHit {
  final OneLineEdge edge;
  final double t;
  final double dist;
  const _EdgeHit(this.edge, this.t, this.dist);
}

class OneLineScreen extends ConsumerStatefulWidget {
  const OneLineScreen({super.key});

  @override
  ConsumerState<OneLineScreen> createState() => _OneLineScreenState();
}

class _OneLineScreenState extends ConsumerState<OneLineScreen>
    with TickerProviderStateMixin {
  final OneLineGenerator _generator = OneLineGenerator();
  final OneLineEngine _engine = OneLineEngine();
  final GlobalKey _boardKey = GlobalKey();

  _Phase _phase = _Phase.playing;
  bool _showCountdown = false;
  bool _runStarted = false;
  bool _boardReady = false;
  bool _isDrawing = false;
  bool _strokeMoved = false;
  int _hintsUsed = 0;
  int? _hintEdgeId;
  int _attemptsThisLevel = 0;
  int? _failVertexId;

  static const int _maxHints = 3;

  /// True once a touch has been accepted as "holding the pen" — moves
  /// outside the board are ignored while false so stray taps never
  /// disturb an in-progress stroke.
  bool _grabbed = false;
  int _currentLevelIndex = 0;
  int _best = 0;
  int _lastScore = 0;

  /// 3 / 2 / 1 stars earned by the last completed run — 3 for a
  /// perfect run (no undos within par time).
  int _lastStars = 0;
  String? _resultWord;
  int _elapsedSeconds = 0;

  Timer? _clockTimer;
  Timer? _autoStartTimer;
  Timer? _hintTimer;
  Timer? _failTimer;
  late OneLineLevel _level = _generator.generateLevel(1);

  late final AnimationController _outlineIn; // intro: outline draws itself
  late final AnimationController _finishFlare; // success tick anim
  late final AnimationController _confetti; // one-shot victory burst
  late final AnimationController _introSweep; // one-shot start hint
  late final AnimationController _failFlare; // red cross stamp
  late final AnimationController _pulse; // marker breathing + win comet

  static const Color _accent = Color(0xFFFFD54F);
  static const Color _success = Color(0xFF34D399);
  static const Color _hintBlue = Color(0xFF38BDF8);

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.watch(languageProvider);
  String _t(String en, String bn, String hi) => _isBn
      ? bn
      : _isHi
          ? hi
          : en;

  @override
  void initState() {
    super.initState();
    _outlineIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _outlineIn.addStatusListener(_onOutlineStatus);
    _finishFlare = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _confetti = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _introSweep = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _failFlare = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _loadBest();
    _loadLevel(0);
    _restoreProgress();
    _autoStartTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showCountdown = true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _autoStartTimer?.cancel();
    _hintTimer?.cancel();
    _failTimer?.cancel();
    _outlineIn.dispose();
    _finishFlare.dispose();
    _confetti.dispose();
    _introSweep.dispose();
    _failFlare.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestScoreKey) ?? 0);
  }

  /// Resume at the saved level (local first, Firestore when ahead).
  /// Skipped once a run has begun so a late response never disrupts play.
  Future<void> _restoreProgress() async {
    final prefs = await SharedPreferences.getInstance();
    var startLevel = math.max(1, prefs.getInt(_levelKey) ?? 1);

    final cloudLevel = await CloudSyncService.instance.fetchOneLineLevel();
    if (cloudLevel != null && cloudLevel > startLevel) {
      startLevel = cloudLevel;
      unawaited(prefs.setInt(_levelKey, startLevel));
    }

    if (!mounted || _runStarted || _phase != _Phase.playing) return;
    final startIndex = startLevel - 1;
    if (startIndex == _currentLevelIndex) return;
    setState(() => _loadLevel(startIndex));
  }

  /// Resets every piece of per-run state for [index]. Callers own the
  /// setState — this method only mutates fields.
  void _loadLevel(int index) {
    _level = _generator.generateLevel(index + 1);
    _currentLevelIndex = index;
    _engine.reset(_level);
    _elapsedSeconds = 0;
    _boardReady = false;
    _runStarted = false;
    _grabbed = false;
    _isDrawing = false;
    _strokeMoved = false;
    _hintsUsed = 0;
    _hintEdgeId = null;
    _hintTimer?.cancel();
    _failTimer?.cancel();
    _failVertexId = null;
    _pulse.stop();
    _finishFlare.reset();
    _confetti.reset();
    _introSweep.reset();
    _failFlare.reset();
    _resultWord = null;
    _outlineIn.duration =
        Duration(milliseconds: math.min(1600, 450 + _level.edges.length * 70));
  }

  // ── Run lifecycle ────────────────────────────────────────────────────

  void _beginRun() {
    if (_runStarted || _phase != _Phase.playing) return;
    setState(() {
      _showCountdown = false;
      _runStarted = true;
      _elapsedSeconds = 0;
    });
    _outlineIn.forward(from: 0);
    _introSweep.forward(from: 0);
    _pulse.repeat();
    _startClock();
  }

  void _onOutlineStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _phase != _Phase.playing) return;
    setState(() => _boardReady = true);
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _elapsedSeconds++);
    });
  }

  /// A wider vocabulary of praise, picked by how clean and quick the run
  /// was and rotated by level so repeat wins still feel fresh.
  String _resultWordFor(int stars) {
    final clean = _attemptsThisLevel == 0 && _hintsUsed == 0;
    final quick = _elapsedSeconds <= (_level.parSeconds / 2).ceil();
    final List<String> options;
    if (stars == 3 && clean && quick) {
      options = [
        _t('LEGENDARY!', 'কিংবদন্তি!', 'अद्भुत!'),
        _t('FLAWLESS!', 'নিখুঁত!', 'निर्दोष!'),
        _t('INCREDIBLE!', 'অবিশ্বাস্য!', 'अविश्वसनीय!'),
      ];
    } else if (stars == 3) {
      options = [
        _t('PERFECT!', 'পারফেক্ট!', 'बिलकुल सही!'),
        _t('AWESOME!', 'অসাধারণ!', 'शानदार!'),
        _t('BRILLIANT!', 'উজ্জ্বল!', 'प्रतिभाशाली!'),
      ];
    } else if (stars == 2) {
      options = [
        _t('GREAT!', 'সুন্দর!', 'बढ़िया!'),
        _t('SUPERB!', 'অতি উত্তম!', 'उत्तम!'),
        _t('SMOOTH!', 'মসৃণ!', 'सरल!'),
      ];
    } else {
      options = [
        _t('NICE!', 'ভালো!', 'अच्छा!'),
        _t('WELL DONE!', 'ভালো করেছেন!', 'शाबाश!'),
        _t('KEEP GOING!', 'চালিয়ে যান!', 'आगे बढ़ें!'),
      ];
    }
    return options[_currentLevelIndex % options.length];
  }

  void _finishLevel() {
    if (_phase != _Phase.playing) return;
    _clockTimer?.cancel();
    // NOTE: _pulse keeps repeating — it now drives the victory comet
    // that rides the finished figure until the next level loads.

    // Stars: 3 for a flawless run (no undos, under par), 2 for a
    // tidy one, 1 for finishing at all. Mastery without punishment.
    var stars =
        (_attemptsThisLevel == 0 && _elapsedSeconds <= _level.parSeconds)
            ? 3
            : (_attemptsThisLevel <= 2 ? 2 : 1);
    if (_attemptsThisLevel >= 2) stars = 1;
    _lastStars = stars;
    _resultWord = _resultWordFor(stars);

    final score = _calculateScore();
    _lastScore = score;
    if (score > _best) {
      _best = score;
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_bestScoreKey, score));
    }

    GameSfxService.instance.play(GameSfx.levelUp);
    HapticFeedback.mediumImpact();
    _finishFlare.forward(from: 0);
    _confetti.forward(from: 0);
    _persistProgress();

    final input = OneLinePerformanceInput(
      shapeComplexity: (_currentLevelIndex + 1).clamp(1, 10),
      edgeCount: _engine.totalEdges,
      completed: true,
      timeSeconds: _elapsedSeconds,
      backtracks: _attemptsThisLevel,
      hintsUsed: _hintsUsed,
    );
    unawaited(ProgressionService.instance.recordSession(SessionRecord(
      gameId: 'oneLine',
      mode: SessionMode.practice,
      gameType: GameType.oneLine,
      primaryPillar: BrainPillar.logic,
      performance: input,
    )));
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    // No success screen: the board itself celebrates — strokes turn
    // green and a tick stamps in — while the bottom bar offers the
    // single green NEXT LEVEL action.
    _setStateSafe(() => _phase = _Phase.finished);
  }

  /// Next session starts after the level just cleared; never regresses.
  Future<void> _persistProgress() async {
    final nextStartLevel = _currentLevelIndex + 2;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_levelKey) ?? 1;
    final target = math.max(stored, nextStartLevel);
    if (target == stored) return;
    await prefs.setInt(_levelKey, target);
    await CloudSyncService.instance.saveOneLineLevel(target);
  }

  int _calculateScore() {
    final base = _currentLevelIndex * 20 + 10;
    final timeBonus = math.max(0, _level.parSeconds * 2 - _elapsedSeconds);
    return math.max(
      0,
      base + timeBonus + 30 - _attemptsThisLevel * 5 - _hintsUsed * 3,
    );
  }

  void _nextLevel() {
    _attemptsThisLevel = 0;
    _restart(sameLevel: false);
  }

  /// Restarts go straight back into play — the countdown is an opening
  /// ceremony, not a tax on retries.
  void _restart({required bool sameLevel}) {
    GameSfxService.instance.play(GameSfx.tap);
    _clockTimer?.cancel();
    _setStateSafe(() {
      _loadLevel(sameLevel ? _currentLevelIndex : _currentLevelIndex + 1);
      _phase = _Phase.playing;
      _showCountdown = false;
    });
    _beginRun();
  }

  void _failGame({int? vertexId}) {
    if (_phase != _Phase.playing) return;
    _phase = _Phase.failed;
    _grabbed = false;
    _isDrawing = false;
    _strokeMoved = false;
    _failVertexId = vertexId ?? _engine.head;
    _attemptsThisLevel++;
    _hideHint();
    _engine.clearPreview();
    _clockTimer?.cancel();
    GameSfxService.instance.play(GameSfx.wrong);
    HapticFeedback.heavyImpact();
    _failFlare.forward(from: 0);
    _setStateSafe(() {});
    _failTimer?.cancel();
    _failTimer = Timer(const Duration(milliseconds: 1250), _retryAfterFail);
  }

  void _retryAfterFail() {
    _failTimer?.cancel();
    _clockTimer?.cancel();
    _setStateSafe(() {
      _loadLevel(_currentLevelIndex);
      _phase = _Phase.playing;
      _showCountdown = false;
    });
    _beginRun();
  }

  void _hideHint() {
    _hintTimer?.cancel();
    _hintEdgeId = null;
  }

  int? _startingHintEdge() {
    final solution = _level.solution;
    if (solution.length < 2) return null;
    return _edgeBetween(solution[0], solution[1])?.id;
  }

  void _showHint() {
    if (_phase != _Phase.playing || _engine.isComplete) return;
    if (_hintsUsed >= _maxHints) return;
    final edgeId =
        _engine.started ? _engine.suggestNextEdge() : _startingHintEdge();
    if (edgeId == null) return;
    GameSfxService.instance.play(GameSfx.tap);
    HapticFeedback.selectionClick();
    _setStateSafe(() {
      _hintsUsed++;
      _hintEdgeId = edgeId;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2400), () {
      _hideHint();
      _repaint();
    });
  }

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // ── Board geometry ───────────────────────────────────────────────────

  /// MUST mirror the painter's inset exactly — hit-testing against a
  /// differently-inset rect makes strokes snap in the wrong place.
  ///
  /// The board is full-bleed, so the figure is mapped into the largest
  /// centred square inside [size] (matching the painter) to keep the
  /// puzzle's proportions intact.
  Rect _boardRect(Size size) {
    final side = size.shortestSide;
    final inset = side * kOneLineBoardInset;
    return Rect.fromLTWH(
      (size.width - side) / 2 + inset,
      (size.height - side) / 2 + inset,
      side - inset * 2,
      side - inset * 2,
    );
  }

  Map<int, Offset> _pixelPositions(Size size) {
    final b = _boardRect(size);
    return {
      for (final v in _engine.vertices)
        v.id: Offset(
            b.left + v.position.dx * b.width, b.top + v.position.dy * b.height),
    };
  }

  ({Offset point, double t}) _projectOnSegment(Offset p, Offset a, Offset b) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final len2 = abx * abx + aby * aby;
    var t = 0.0;
    if (len2 > 0) {
      t = ((p.dx - a.dx) * abx + (p.dy - a.dy) * aby) / len2;
      t = t.clamp(0.0, 1.0);
    }
    return (point: Offset(a.dx + abx * t, a.dy + aby * t), t: t);
  }

  _EdgeHit? _nearestUntracedEdge(Offset p, Map<int, Offset> pos) {
    _EdgeHit? best;
    for (final e in _engine.edges) {
      if (_engine.tracedEdgeIds.contains(e.id)) continue;
      final a = pos[e.a];
      final b = pos[e.b];
      if (a == null || b == null) continue;
      final proj = _projectOnSegment(p, a, b);
      final d = (p - proj.point).distance;
      if (best == null || d < best.dist) {
        best = _EdgeHit(e, proj.t, d);
      }
    }
    return best;
  }

  double _snapRadius(Size size) =>
      (size.shortestSide * 0.085).clamp(24.0, 46.0).toDouble();

  OneLineEdge? _edgeBetween(int a, int b) {
    for (final e in _engine.edges) {
      if ((e.a == a && e.b == b) || (e.a == b && e.b == a)) return e;
    }
    return null;
  }

  // ── Input ────────────────────────────────────────────────────────────

  RenderBox? get _boardBox =>
      _boardKey.currentContext?.findRenderObject() as RenderBox?;

  /// Where the current touch began — used to tell a real drag from a
  /// stray tap so accidental touches never break a stroke.
  Offset? _downPos;

  bool get _inputAllowed =>
      _phase == _Phase.playing && !_showCountdown && _boardReady;

  void _onPointerDown(PointerDownEvent event) {
    if (!_inputAllowed) return;
    final box = _boardBox;
    if (box == null) return;
    _downPos = event.localPosition;
    _strokeMoved = false;

    if (_engine.started) {
      final pos = _pixelPositions(box.size);
      final headPos = pos[_engine.head!];
      final snapR = _snapRadius(box.size);
      if (headPos == null ||
          (event.localPosition - headPos).distance > snapR * 1.6) {
        return;
      }
    }
    _grabbed = true;
    _isDrawing = true;
    HapticFeedback.selectionClick();
    _updateDrag(event.localPosition);
    _repaint();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_inputAllowed || !_grabbed) return;
    if (_downPos != null && (event.localPosition - _downPos!).distance > 6) {
      _strokeMoved = true;
    }
    _isDrawing = true;
    _updateDrag(event.localPosition);
    _repaint();
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasGrabbed = _grabbed;
    final moved = _strokeMoved;
    _grabbed = false;
    _isDrawing = false;
    _downPos = null;
    _engine.clearPreview();
    _commitFinishingEdgeOnRelease(event.localPosition);
    _ensureCompletion();
    if (!_inputAllowed) {
      _repaint();
      return;
    }
    final hadProgress = _engine.started && (_engine.tracedCount > 0 || moved);
    if (wasGrabbed && hadProgress && !_engine.isComplete) {
      _failGame();
      return;
    }
    if (_engine.started && !hadProgress) {
      _engine.clearPath();
      _hideHint();
    }
    _strokeMoved = false;
    _repaint();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final wasGrabbed = _grabbed;
    final moved = _strokeMoved;
    _grabbed = false;
    _isDrawing = false;
    _downPos = null;
    _engine.clearPreview();
    _ensureCompletion();
    if (wasGrabbed &&
        _phase == _Phase.playing &&
        _engine.started &&
        (_engine.tracedCount > 0 || moved) &&
        !_engine.isComplete) {
      _failGame();
      return;
    }
    _strokeMoved = false;
    _repaint();
  }

  void _updateDrag(Offset p) {
    final box = _boardBox;
    if (box == null) return;
    final pos = _pixelPositions(box.size);
    final snapR = _snapRadius(box.size);

    if (!_engine.started) {
      final hit = _nearestUntracedEdge(p, pos);
      if (hit != null && hit.dist <= snapR) {
        if (_engine.startOnEdge(hit.edge.id, hit.t)) {
          GameSfxService.instance.play(GameSfx.tap);
          HapticFeedback.selectionClick();
        }
      }
      return;
    }

    int guard = 0;
    while (guard++ < 8 && _phase == _Phase.playing) {
      final headId = _engine.head!;
      final headPos = pos[headId];
      if (headPos == null) return;

      final choice = OneLineNavigation.choose(
        pointer: p,
        headId: headId,
        head: headPos,
        edges: _engine.edges,
        tracedEdgeIds: _engine.tracedEdgeIds,
        positions: pos,
        snapRadius: snapR,
      );
      if (choice == null) {
        _engine.clearPreview();
        return;
      }

      if (OneLineNavigation.shouldCommit(
        t: choice.t,
        pointer: p,
        far: pos[choice.farId]!,
        snapRadius: snapR,
      )) {
        final outcome = _applyMove(choice.farId);
        if (outcome == 'traced' && _phase == _Phase.playing) continue;
        _engine.clearPreview();
        return;
      }
      _engine.setPreview(choice.edgeId, choice.t);
      return;
    }
  }

  /// Guarantees a solved graph always flips the UI to the finished state,
  /// even if the last edge was committed from an unusual pointer path.
  void _ensureCompletion() {
    if (mounted && _phase == _Phase.playing && _engine.isComplete) {
      _finishLevel();
    }
  }

  /// A release right on the final vertex counts as drawing the last edge —
  /// no more "visually done but still playing" near-misses.
  void _commitFinishingEdgeOnRelease(Offset p) {
    if (_phase != _Phase.playing ||
        !_engine.started ||
        _engine.isComplete ||
        _engine.tracedCount + 1 != _engine.totalEdges) {
      return;
    }
    final box = _boardBox;
    final head = _engine.head;
    if (box == null || head == null) return;
    final pos = _pixelPositions(box.size);
    final snapR = _snapRadius(box.size);
    final traced = _engine.tracedEdgeIds;
    for (final edge in _engine.edges) {
      if (traced.contains(edge.id) || !edge.touches(head)) continue;
      final farId = edge.other(head);
      final far = pos[farId];
      if (far != null && (p - far).distance <= snapR) {
        _applyMove(farId);
        return;
      }
    }
  }

  String? _applyMove(int vertexId) {
    final path = _engine.path;
    if (path.length >= 2 && vertexId == path[path.length - 2]) return null;
    final outcome = _engine.moveTo(vertexId);

    if (outcome == 'traced') {
      GameSfxService.instance.play(GameSfx.tap);
      HapticFeedback.selectionClick();
      _hideHint();
    }

    if (_engine.isComplete) {
      _repaint();
      _finishLevel();
      return outcome;
    }
    if (outcome == 'traced' && _engine.isDeadEnd) {
      _failGame(vertexId: vertexId);
    }
    return outcome;
  }

  void _clearStroke() {
    if (_phase != _Phase.playing || !_engine.started) return;
    GameSfxService.instance.play(GameSfx.tap);
    _engine.clearPath();
    _hideHint();
    _strokeMoved = false;
    _isDrawing = false;
    _repaint();
  }

  void _repaint() {
    _ensureCompletion();
    _setStateSafe(() {});
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return GameScaffold(
      safeArea: false,
      child: Stack(
        children: [
          // Full-bleed board: the figure stays square and centred while
          // the background fills the entire screen.
          Positioned.fill(child: _buildBoardArea(isDark)),
          if (_phase == _Phase.failed)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                    color: OneLinePainter.failRed.withValues(alpha: 0.06)),
              ),
            ),
          // Minimal HUD — level and time only (plus a subtle back).
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: _buildTopHud(isDark),
            ),
          ),
          // Hint + controls hugging the bottom edge, over the board.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBottomControls(isDark),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _buildResultBanner(),
          // Opaque backdrop while counting down — the board must not
          // peek through the transparent overlay.
          if (_showCountdown)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A1020), Color(0xFF05070E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          if (_showCountdown)
            CountdownOverlay(
              onFinished: _beginRun,
              goLabel: _t('GO!', 'শুরু!', 'শুরু!'),
            ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    if (_phase != _Phase.finished || _resultWord == null) {
      return const SizedBox.shrink();
    }
    final tint = _lastStars >= 3 ? _accent : _success;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _finishFlare,
          builder: (context, _) {
            final raw = _finishFlare.value.clamp(0.0, 1.0);
            final scale = 0.65 + 0.35 * Curves.easeOutBack.transform(raw);
            return Align(
              alignment: const Alignment(0, -0.30),
              child: Opacity(
                opacity: (raw * 1.8).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xE6080F1C),
                      borderRadius: BorderRadius.circular(AppSpacing.rRound),
                      border: Border.all(color: tint.withValues(alpha: 0.65)),
                      boxShadow: [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      _resultWord!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                        color: tint,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── HUD ──────────────────────────────────────────────────────────────

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Top HUD kept deliberately spare: a back affordance plus the two
  /// things a player actually needs — the current level and the clock.
  Widget _buildTopHud(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                ),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              _hudChip(
                isDark,
                icon: Icons.grid_view_rounded,
                label:
                    '${_t('LEVEL', 'স্তর', 'स्तर')} ${_currentLevelIndex + 1}',
                onTap: _showReplaySheet,
                chevron: true,
              ),
              const SizedBox(width: 8),
              _hudChip(
                isDark,
                icon: Icons.timeline_rounded,
                label: '${_engine.tracedCount}/${_engine.totalEdges}',
                accent: OneLinePainter.successGreen,
              ),
              const SizedBox(width: 8),
              _hudChip(
                isDark,
                icon: Icons.timer_outlined,
                label: _formatTime(_elapsedSeconds),
                accent: _accent,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _engine.progress,
              minHeight: 4,
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              color: _phase == _Phase.failed
                  ? OneLinePainter.failRed
                  : (_engine.isComplete
                      ? OneLinePainter.successGreen
                      : _accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hudChip(
    bool isDark, {
    required IconData icon,
    required String label,
    Color? accent,
    VoidCallback? onTap,
    bool chevron = false,
  }) {
    final tint = accent ?? _accent;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }

  Widget _buildBoardArea(bool isDark) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _outlineIn,
          _finishFlare,
          _confetti,
          _introSweep,
          _failFlare,
          _pulse,
        ]),
        builder: (context, _) {
          return Container(
            key: _boardKey,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [Color(0xFF111B30), Color(0xFF05070E)],
              ),
            ),
            child: CustomPaint(
              painter: OneLinePainter(
                state: OneLineBoardState(
                  vertices: _engine.vertices,
                  edges: _engine.edges,
                  path: _engine.path,
                  tracedEdgeIds: _engine.tracedEdgeIds,
                  previewEdgeId: _engine.previewEdgeId,
                  previewT: _engine.previewT,
                  drawing: _isDrawing && _phase == _Phase.playing,
                  hintEdgeId: _hintEdgeId,
                  failGlow: _phase == _Phase.failed ? _failFlare.value : 0,
                  failPointId: _failVertexId,
                  solution: _level.solution,
                  buildProgress: _runStarted && !_outlineIn.isCompleted
                      ? _outlineIn.value
                      : null,
                  winGlow: _finishFlare.value,
                  pulsePhase: _pulse.isAnimating ? _pulse.value : 0,
                  introSweepPhase: _introSweep.value,
                  confettiPhase: _confetti.value,
                ),
                isDark: isDark,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    if (_phase == _Phase.failed) return const SizedBox.shrink();
    if (_phase == _Phase.finished) {
      // Win state: a single green action — straight to the next level.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★' * _lastStars + '☆' * (3 - _lastStars),
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: _lastStars >= 3
                    ? const Color(0xFFFFC93C)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                  'SCORE $_lastScore   ·   BEST $_best',
                  'SCORE $_lastScore · BEST $_best',
                  'SCORE $_lastScore · BEST $_best'),
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: _success,
              ),
            ),
            const SizedBox(height: 6),
            if (_attemptsThisLevel > 0 || _hintsUsed > 0)
              Text(
                _t(
                    'RETRIES $_attemptsThisLevel   ·   HINTS $_hintsUsed',
                    'RETRIES $_attemptsThisLevel · HINTS $_hintsUsed',
                    'RETRIES $_attemptsThisLevel · HINTS $_hintsUsed'),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                ),
              ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _nextLevel,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF0FA97A)]),
                  borderRadius: BorderRadius.circular(AppSpacing.rRound),
                  boxShadow: [
                    BoxShadow(
                      color: _success.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('NEXT LEVEL', 'পরবর্তী স্তর', 'अगला स्तर'),
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 17, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _controlButton(
            isDark,
            icon: Icons.lightbulb_outline_rounded,
            label: '${_t('HINT', 'ইঙ্গিত', 'संकेत')} ${_maxHints - _hintsUsed}',
            onTap: _showHint,
            tint: _hintBlue,
            enabled: _hintsUsed < _maxHints && !_engine.isComplete,
          ),
          _controlButton(
            isDark,
            icon: Icons.restart_alt_rounded,
            label: _t('RESTART', 'রিস্টার্ট', 'फिर से'),
            onTap: _clearStroke,
          ),
        ],
      ),
    );
  }

  Widget _controlButton(bool isDark,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? tint,
      bool enabled = true}) {
    final color = tint ?? _accent;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: enabled ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(AppSpacing.rRound),
          border: Border.all(
            color: color.withValues(alpha: enabled ? 0.35 : 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: color.withValues(alpha: enabled ? 1 : 0.35)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: (isDark ? Colors.white70 : Colors.black87)
                      .withValues(alpha: enabled ? 1 : 0.4),
                )),
          ],
        ),
      ),
    );
  }

  /// Replay sheet listing only already-solved levels.
  Future<void> _showReplaySheet() async {
    GameSfxService.instance.play(GameSfx.tap);
    final prefs = await SharedPreferences.getInstance();
    final solvedMax = math.max(0, (prefs.getInt(_levelKey) ?? 1) - 1);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.6),
        decoration: BoxDecoration(
          color: const Color(0xFF14101F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.replay_rounded, size: 16, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t('Replay Solved Levels', 'সমাধান করা স্তর',
                          'हल किए गए स्तर'),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (solvedMax < 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      _t(
                        'Complete a level to unlock replays!',
                        'রিপ্লে আনলক করতে একটি স্তর সম্পূর্ণ করুন!',
                        'रीप्ले अनलॉक करने के लिए एक स्तर पूरा करें!',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                          fontSize: 12, color: Colors.white54),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (int n = 1; n <= solvedMax; n++)
                          _replayDot(n, sheetCtx),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replayDot(int levelNumber, BuildContext sheetCtx) {
    final isCurrent = levelNumber == _currentLevelIndex + 1;
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        if (!isCurrent) {
          GameSfxService.instance.play(GameSfx.tap);
          _clockTimer?.cancel();
          _setStateSafe(() {
            _attemptsThisLevel = 0;
            _loadLevel(levelNumber - 1);
            _phase = _Phase.playing;
            _showCountdown = false;
          });
          _beginRun();
        }
      },
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent ? _accent : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: _accent.withValues(alpha: isCurrent ? 1 : 0.3),
            width: 1.2,
          ),
        ),
        child: Text('$levelNumber',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isCurrent ? const Color(0xFF26062E) : Colors.white70,
            )),
      ),
    );
  }
}
