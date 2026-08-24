// lib/presentation/screens/games/one_line/one_line_screen.dart
//
// One-Line Drawing Puzzle — trace the whole figure with a single
// continuous stroke (Eulerian circuit). Grab the outline ANYWHERE —
// mid-segment included — and drag along the lines. Dragging back onto
// the previous point undoes. Lifting the finger is never punished:
// progress simply waits to be picked up again at the pen tip.
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
import '../../../games/widgets/game_top_bar.dart';
import '../../../providers/app_providers.dart';
import 'one_line_engine.dart';
import 'one_line_generator.dart';
import 'one_line_models.dart';
import 'one_line_painter.dart';

const String _bestScoreKey = 'one_line_best_v2';
const String _levelKey = 'one_line_level_v1';

enum _Phase { playing, finished }

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
  bool _deadEndShown = false;

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
  int _elapsedSeconds = 0;

  Timer? _clockTimer;
  Timer? _autoStartTimer;
  late OneLineLevel _level = _generator.generateLevel(1);

  late final AnimationController _outlineIn; // intro: outline draws itself
  late final AnimationController _finishFlare; // success tick anim
  late final AnimationController _pulse; // marker breathing + win comet

  /// 0..1 — how much of the last edge is erased while the finger
  /// drags backwards along it (progressive undo).
  double _backtrackErase = 0;

  static const Color _accent = Color(0xFFE040FB);
  Color get _accentDeep => const Color(0xFFAA00FF);

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
    _outlineIn.dispose();
    _finishFlare.dispose();
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
    _deadEndShown = false;
    _grabbed = false;
    _backtrackErase = 0;
    _lastDragPoint = null;
    _pulse.stop();
    _finishFlare.reset();
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

  void _finishLevel() {
    if (_phase != _Phase.playing) return;
    _clockTimer?.cancel();
    // NOTE: _pulse keeps repeating — it now drives the victory comet
    // that rides the finished figure until the next level loads.

    // Stars: 3 for a flawless run (no undos, under par), 2 for a
    // tidy one, 1 for finishing at all. Mastery without punishment.
    final stars =
        (_engine.backtracks == 0 && _elapsedSeconds <= _level.parSeconds)
            ? 3
            : (_engine.backtracks <= 2 ? 2 : 1);
    _lastStars = stars;

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
    _persistProgress();

    final input = OneLinePerformanceInput(
      shapeComplexity: (_currentLevelIndex + 1).clamp(1, 10),
      edgeCount: _engine.totalEdges,
      completed: true,
      timeSeconds: _elapsedSeconds,
      backtracks: _engine.backtracks,
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
    return math.max(0, base + timeBonus + 30 - _engine.backtracks * 2);
  }

  void _nextLevel() => _restart(sameLevel: false);

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

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // ── Board geometry ───────────────────────────────────────────────────

  /// MUST mirror the painter's inset exactly — hit-testing against a
  /// differently-inset rect makes strokes snap in the wrong place.
  Rect _boardRect(Size size) {
    final inset = size.shortestSide * kOneLineBoardInset;
    return Rect.fromLTWH(
        inset, inset, size.width - inset * 2, size.height - inset * 2);
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

  Offset? _lastDragPoint;

  /// Where the current touch began — distinguishes taps from drags so
  /// a quick tap near the pen can extend the stroke too.
  Offset? _downPos;

  bool get _inputAllowed =>
      _phase == _Phase.playing && !_showCountdown && _boardReady;

  void _onPointerDown(PointerDownEvent event) {
    if (!_inputAllowed) return;
    final box = _boardBox;
    if (box == null) return;
    _downPos = event.localPosition;
    _lastDragPoint = null;

    // Once a stroke exists it can only be picked up again at the pen
    // tip (the head of the path). Touches elsewhere do nothing — never
    // punish, never disrupt.
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
    HapticFeedback.selectionClick();
    _updateDrag(event.localPosition);
    _repaint();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_inputAllowed || !_grabbed) return;
    final delta =
        _lastDragPoint == null ? null : event.localPosition - _lastDragPoint!;
    _lastDragPoint = event.localPosition;
    _updateDrag(event.localPosition, dragDelta: delta);
    _repaint();
  }

  /// Lifting the finger is NEVER a failure. The stroke simply pauses
  /// exactly where it is and waits to be picked up again at the pen
  /// tip — progress always persists (the pattern every top-rated
  /// one-line game ships with).
  void _onPointerUp(PointerUpEvent event) {
    if (!_inputAllowed) return;
    final movedFar =
        _downPos != null && (event.localPosition - _downPos!).distance > 14;
    _grabbed = false;
    _downPos = null;
    _backtrackErase = 0;
    _lastDragPoint = null;

    // A tap (not a drag) near a neighbouring point extends the stroke —
    // an accessible alternative for players who struggle with drags.
    if (!movedFar &&
        !_engine.isComplete &&
        _engine.started &&
        _phase == _Phase.playing) {
      _tapExtend(event.localPosition);
    }
    _engine.clearPreview();
    _repaint();
  }

  /// System-initiated cancellations (incoming call, navigation
  /// gesture) behave exactly like lifting: pause, keep everything.
  void _onPointerCancel(PointerCancelEvent event) {
    _grabbed = false;
    _downPos = null;
    _backtrackErase = 0;
    _lastDragPoint = null;
    _engine.clearPreview();
    _repaint();
  }

  /// Tap-to-extend: commit the untraced edge whose far end is closest
  /// to the tap, when that end sits within snapping distance.
  void _tapExtend(Offset p) {
    final box = _boardBox;
    if (box == null || !_engine.started || _engine.head == null) return;
    final pos = _pixelPositions(box.size);
    final snapR = _snapRadius(box.size);
    final headId = _engine.head!;
    int? farId;
    var bestDist = snapR * 0.95;
    for (final e in _engine.edges) {
      if (_engine.tracedEdgeIds.contains(e.id)) continue;
      if (!e.touches(headId)) continue;
      final fpos = pos[e.other(headId)];
      if (fpos == null) continue;
      final d = (p - fpos).distance;
      if (d < bestDist) {
        bestDist = d;
        farId = e.other(headId);
      }
    }
    if (farId != null) {
      final outcome = _applyMove(farId);
      if (outcome != null) return; // finished or advanced — done here
    }
  }

  /// Progressive gesture resolution — the pen follows the finger every
  /// frame:
  ///  * Not started → grabbing any untraced outline point begins the
  ///    stroke there (mid-segment included).
  ///  * Dragging along an untraced edge from head shows a live partial
  ///    stroke; crossing the commit fraction snaps the move so the
  ///    line flows through junctions without lifting the finger.
  ///  * Dragging back along the edge just drawn erases it gradually
  ///    and pops the previous move once crossed.
  ///  * Anything else (riding an old line, wandering off the outline)
  ///    is simply ignored — mistakes cost nothing, so experimenting
  ///    stays fun.
  void _updateDrag(Offset p, {Offset? dragDelta}) {
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

    bool progressed = true;
    bool committedThisEvent = false;
    int guard = 0;
    while (progressed && guard++ < 8) {
      progressed = false;

      // ── Drag-back undo ─────────────────────────────────────────
      final n = _engine.path.length;
      if (!committedThisEvent && n >= 2) {
        final prevPos = pos[_engine.path[n - 2]];
        final headPos = pos[_engine.head!];
        if (prevPos != null && headPos != null) {
          // t measured from head toward the previous vertex.
          final proj = _projectOnSegment(p, headPos, prevPos);
          final distToSeg = (p - proj.point).distance;
          final movingBack =
              dragDelta == null || _dot(dragDelta, prevPos - headPos) > 0;
          final nearPrev = (p - prevPos).distance <= snapR * 0.7;
          if (nearPrev ||
              (distToSeg <= snapR * 1.15 && proj.t >= 0.25 && movingBack)) {
            if (proj.t >= 0.82 || nearPrev) {
              final outcome = _engine.moveTo(_engine.path[n - 2]);
              if (outcome == 'backtracked') {
                HapticFeedback.selectionClick();
                _backtrackErase = 0;
                committedThisEvent = true;
                progressed = true;
                continue; // reversed — maybe draw onward elsewhere
              }
            } else {
              setState(() => _backtrackErase = proj.t.clamp(0.0, 1.0));
              return;
            }
          }
        }
      }
      if (_backtrackErase != 0) setState(() => _backtrackErase = 0);

      // ── Forward: follow the outline under the finger ───────────
      final headId = _engine.head!;
      final headPos = pos[headId];
      if (headPos == null) return;

      int? farId;
      double bestDist = double.infinity;
      double bestT = 0;
      for (final e in _engine.edges) {
        if (_engine.tracedEdgeIds.contains(e.id)) continue;
        if (!e.touches(headId)) continue;
        final fpos = pos[e.other(headId)];
        if (fpos == null) continue;
        // Orient head → far so t runs ahead of the pen.
        final proj = _projectOnSegment(p, headPos, fpos);
        final d = (p - proj.point).distance;
        if (d < bestDist) {
          bestDist = d;
          bestT = proj.t;
          farId = e.other(headId);
        }
      }

      // Nothing reachable under the finger — riding an old line or
      // drifting off the outline does nothing at all. The stroke just
      // waits; there is no fail state to fall into.
      if (farId == null || bestDist > snapR * 1.4) {
        _engine.clearPreview();
        return;
      }

      final farPos = pos[farId]!;
      if (bestT >= OneLineEngine.commitFraction ||
          (p - farPos).distance <= snapR * 0.85) {
        final outcome = _applyMove(farId);
        committedThisEvent = true;
        if (outcome != null) {
          progressed = true;
          continue; // keep flowing across junctions in one gesture
        }
        _engine.clearPreview();
        return;
      }
      final previewEdge = _edgeBetween(headId, farId);
      if (previewEdge == null) return; // never preview a bogus edge id
      _engine.setPreview(previewEdge.id, bestT);
      return;
    }
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  String? _applyMove(int vertexId) {
    final outcome = _engine.moveTo(vertexId);

    if (outcome == 'traced') {
      GameSfxService.instance.play(GameSfx.tap);
      HapticFeedback.selectionClick();
    }

    if (_engine.isComplete) {
      _repaint();
      _finishLevel();
      return outcome;
    }
    _checkDeadEnd();
    return outcome;
  }

  void _checkDeadEnd() {
    final dead = _engine.isDeadEnd;
    if (dead && !_deadEndShown) {
      _deadEndShown = true;
      GameSfxService.instance.play(GameSfx.wrong);
      HapticFeedback.vibrate();
      _setStateSafe(() {});
    } else if (!dead && _deadEndShown) {
      _deadEndShown = false;
      _setStateSafe(() {});
    }
  }

  void _undoMove() {
    if (_phase != _Phase.playing || !_engine.undo()) return;
    GameSfxService.instance.play(GameSfx.tap);
    _checkDeadEnd();
    _repaint();
  }

  void _clearStroke() {
    if (_phase != _Phase.playing || !_engine.started) return;
    GameSfxService.instance.play(GameSfx.tap);
    _engine.clearPath();
    _deadEndShown = false;
    _backtrackErase = 0;
    _lastDragPoint = null;
    _repaint();
  }

  void _repaint() => _setStateSafe(() {});

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GameScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              GameTopBar(
                title: _t('ONE LINE', 'ওয়ান লাইন', 'वन लाइन'),
                subtitle: _t(
                    'One stroke — never repeat a line.',
                    'এক টানে আঁকুন — রেখা দ্বিগুণ নয়।',
                    'एक ही रेखा में — रेखा दोहराएँ नहीं।'),
                trailing: _buildLevelChip(isDark),
              ),
              _buildProgressRow(isDark),
              Expanded(child: _buildBoardArea(isDark)),
              _buildDeadEndHint(isDark),
              _buildBottomControls(isDark),
              const SizedBox(height: 12),
            ],
          ),
          // Opaque backdrop while counting down — the board must not
          // peek through the transparent overlay.
          if (_showCountdown)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.homeBackdropDark
                      : AppColors.homeBackdropGradient,
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

  // ── HUD ──────────────────────────────────────────────────────────────

  Widget _buildLevelChip(bool isDark) {
    return GestureDetector(
      onTap: _showReplaySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.rRound),
          border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_rounded, size: 13, color: _accent),
            const SizedBox(width: 4),
            Text(
              '${_t('LVL', 'স্তর', 'स्तर')} ${_currentLevelIndex + 1}',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.emoji_events_rounded,
                size: 12, color: Color(0xFFFFC93C)),
            const SizedBox(width: 2),
            Text(
              '$_best',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(bool isDark) {
    final progress = _engine.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill(
                isDark,
                icon: Icons.category_rounded,
                label: '${_level.name} · ${_level.difficulty}',
              ),
              _pill(
                isDark,
                icon: Icons.timer_outlined,
                label: '$_elapsedSeconds${_t('s', 'সে', 'से')}',
              ),
              _pill(
                isDark,
                icon: Icons.linear_scale_rounded,
                label: '${_engine.tracedCount}/${_engine.totalEdges}',
                iconColor: _accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [_accent, _accentDeep]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(bool isDark,
      {required IconData icon, required String label, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: iconColor ??
                  (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadEndHint(bool isDark) {
    return AnimatedOpacity(
      opacity: _deadEndShown && !_engine.isComplete ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              _t('Stuck — drag back to undo', 'আটকে গেছেন — আনডু করুন',
                  'रास्ता बंद — वापस जाएँ'),
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardArea(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: AnimatedBuilder(
                animation: Listenable.merge([_outlineIn, _finishFlare, _pulse]),
                builder: (context, _) {
                  return Container(
                    key: _boardKey,
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: isDark
                            ? [
                                const Color(0xFF171126),
                                const Color(0xFF0C0913),
                              ]
                            : [Colors.white, const Color(0xFFF4EDFB)],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.rXl),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.18),
                        width: 1,
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
                          backtrackErase: _backtrackErase,
                          solution: _level.solution,
                          buildProgress: _runStarted && !_outlineIn.isCompleted
                              ? _outlineIn.value
                              : null,
                          deadEndPulse: _deadEndShown ? 1.0 : 0.0,
                          winGlow: _finishFlare.value,
                          pulsePhase: _pulse.isAnimating ? _pulse.value : 0,
                        ),
                        isDark: isDark,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
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
                color: const Color(0xFF2ECC71),
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
                      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]),
                  borderRadius: BorderRadius.circular(AppSpacing.rRound),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.35),
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
            icon: Icons.undo_rounded,
            label: _t('UNDO', 'আনডু', 'अनडू'),
            onTap: _undoMove,
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
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.rRound),
          border: Border.all(
            color: _accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
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
