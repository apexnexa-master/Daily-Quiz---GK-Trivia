import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/daily_progress_service.dart';
import '../../../../core/services/game_sfx.dart';
import '../../../../core/scoring/game_performance.dart';
import '../../../../core/scoring/progression_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../games/widgets/countdown_overlay.dart';
import '../../../games/widgets/game_results_panel.dart';
import '../../../games/widgets/game_scaffold.dart';
import '../../../games/widgets/game_top_bar.dart';
import '../../../providers/app_providers.dart';
import 'flow_free_models.dart';
import 'flow_free_generator.dart';
import 'flow_free_engine.dart';
import 'flow_free_painter.dart';

const String _bestScoreKey = 'flow_free_best_v2';
const String _levelKey = 'flow_free_level_v1';

enum _Phase { playing, finished }

class FlowFreeScreen extends ConsumerStatefulWidget {
  const FlowFreeScreen({super.key});

  @override
  ConsumerState<FlowFreeScreen> createState() => _FlowFreeScreenState();
}

class _FlowFreeScreenState extends ConsumerState<FlowFreeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _boardKey = GlobalKey();

  _Phase _phase = _Phase.playing;
  bool _showCountdown = false;
  bool _runStarted = false;
  bool _isNewBest = false;
  bool _boardReady = false;
  int _currentLevelIndex = 0;
  int _best = 0;
  int _elapsedSeconds = 0;
  bool _hasStartedDrawing = false;

  Timer? _clockTimer;
  Timer? _autoStartTimer;
  late FlowGameState _gameState;
  late FlowLevel _currentLevel;

  late final AnimationController _boardPop;
  late final AnimationController _boardReveal;
  late final AnimationController _dotsIn;
  late final AnimationController _boardFinish;
  late final AnimationController _warnPulse;

  bool _cellWarningActive = false;
  List<FlowCell> _warningCells = const [];
  Timer? _warningTimer;

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  String _t(String en, String bn, String hi) =>
      _isBn ? bn : _isHi ? hi : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boardPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _boardReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener(_onRevealStatus);
    _dotsIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addStatusListener(_onDotsStatus);
    _boardFinish = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _warnPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _loadBest();
    _loadLevel(0);
    _restoreProgress();
    // Skip the in-game intro screen entirely — the shared GameIntroScreen is
    // the single start screen. Kick off the countdown shortly after the route
    // fade-in completes.
    _autoStartTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showCountdown = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _warningTimer?.cancel();
    _autoStartTimer?.cancel();
    _boardPop.dispose();
    _boardReveal.dispose();
    _dotsIn.dispose();
    _boardFinish.dispose();
    _warnPulse.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestScoreKey) ?? 0);
  }

  /// Resume at the player's saved level: local save first (instant, works
  /// offline), then Firestore if it is further ahead. Skipped once a run has
  /// already begun so an in-flight fetch never disrupts active play.
  Future<void> _restoreProgress() async {
    final prefs = await SharedPreferences.getInstance();
    var startLevel = math.max(1, prefs.getInt(_levelKey) ?? 1);

    final cloudLevel = await CloudSyncService.instance.fetchFlowFreeLevel();
    if (cloudLevel != null && cloudLevel > startLevel) {
      startLevel = cloudLevel;
      unawaited(prefs.setInt(_levelKey, startLevel));
    }

    if (!mounted || _runStarted || _phase != _Phase.playing) return;
    final startIndex = startLevel - 1;
    if (startIndex == _currentLevelIndex) return;
    setState(() => _loadLevel(startIndex));
  }

  void _loadLevel(int index) {
    final generator = FlowPuzzleGenerator();
    _currentLevel = generator.generateLevel(index + 1);
    _currentLevelIndex = index;
    _gameState = FlowGameState(_currentLevel);
    _elapsedSeconds = 0;
    _hasStartedDrawing = false;
    _boardReady = false;
    _runStarted = false;
    _dismissCellWarning();
    final cells = _currentLevel.rows * _currentLevel.cols;
    _boardReveal.duration =
        Duration(milliseconds: math.min(1500, 550 + cells * 11));
  }

  // ── Board intro choreography ────────────────────────────────────────────

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    _dotsIn.forward(from: 0);
  }

  void _onDotsStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _phase != _Phase.playing) return;
    setState(() => _boardReady = true);
    _startClock();
  }

  // ── "All pipes connected but cells empty" snackbar ─────────────────────

  void _refreshCellWarning() {
    final shouldWarn = !_gameState.isComplete &&
        _gameState.paths.isNotEmpty &&
        _gameState.allPairsConnected &&
        _gameState.emptyCells.isNotEmpty;
    if (shouldWarn) {
      _showCellWarning();
    } else {
      _dismissCellWarning();
    }
  }

  void _showCellWarning() {
    if (_cellWarningActive) {
      _warningTimer?.cancel();
      _scheduleWarningDismiss();
      return;
    }
    setState(() {
      _warningCells = _gameState.emptyCells;
      _cellWarningActive = true;
    });
    _warnPulse.repeat();
    GameSfxService.instance.play(GameSfx.wrong);
    HapticFeedback.mediumImpact();
    _scheduleWarningDismiss();
  }

  void _scheduleWarningDismiss() {
    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _dismissCellWarning();
    });
  }

  void _dismissCellWarning() {
    _warningTimer?.cancel();
    _warningTimer = null;
    if (!_cellWarningActive) return;
    _cellWarningActive = false;
    _warningCells = const [];
    if (_warnPulse.isAnimating) _warnPulse.stop();
    if (mounted) setState(() {});
  }

  // ── Flow control ──────────────────────────────────────────────────────

  void _beginRun() {
    if (_runStarted) return;
    _clockTimer?.cancel();
    setState(() {
      _showCountdown = false;
      _runStarted = true;
      _phase = _Phase.playing;
      _elapsedSeconds = 0;
      _hasStartedDrawing = false;
      _boardReady = false;
    });
    _boardPop.forward(from: 0);
    _dotsIn.reset();
    _boardReveal.forward(from: 0);
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _finishLevel() {
    if (_phase != _Phase.playing) return;
    _clockTimer?.cancel();

    final score = _calculateScore();
    final isNewBest = score > _best;
    if (isNewBest) {
      _best = score;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_bestScoreKey, score);
      });
    }

    GameSfxService.instance.play(GameSfx.levelUp);

    _persistProgress();

    final input = FlowFreePerformanceInput(
      gridSize: _currentLevel.rows * _currentLevel.cols,
      colorsCount: _currentLevel.pairCount,
      completed: true,
      timeSeconds: _elapsedSeconds,
    );
    unawaited(
      ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'flowFree',
          mode: SessionMode.practice,
          gameType: GameType.flowFree,
          primaryPillar: BrainPillar.logic,
          performance: input,
        ),
      ),
    );
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    setState(() {
      _phase = _Phase.finished;
      _isNewBest = isNewBest;
    });
    _boardFinish.forward(from: 0);
  }

  /// Store the level to start from next session: the one after the level just
  /// cleared. Never regresses (replays of earlier levels keep the max), and
  /// mirrors to Firestore for signed-in players.
  Future<void> _persistProgress() async {
    final nextStartLevel = _currentLevelIndex + 2;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_levelKey) ?? 1;
    final target = math.max(stored, nextStartLevel);
    if (target == stored) return;
    await prefs.setInt(_levelKey, target);
    await CloudSyncService.instance.saveFlowFreeLevel(target);
  }

  // Compact scale: level 1 full clear lands around 60-90 pts instead of ~600.
  int _calculateScore() {
    final base = _currentLevelIndex * 20 + 10;
    final timeBonus = math.max(0, 60 - _elapsedSeconds);
    final completionBonus = _gameState.isComplete ? 30 : 0;
    return math.max(0, base + timeBonus + completionBonus);
  }

  /// 1-3 stars for a completed level based on clear speed vs grid size.
  /// Null while the level is not complete.
  int? _computeStars() {
    if (!_gameState.isComplete) return null;
    final par = _currentLevel.rows * _currentLevel.cols;
    if (_elapsedSeconds <= par) return 3;
    if (_elapsedSeconds <= par * 2) return 2;
    return 1;
  }

  void _playAgain() {
    GameSfxService.instance.play(GameSfx.tap);
    _loadLevel(_currentLevelIndex);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.playing;
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  void _nextLevel() {
    GameSfxService.instance.play(GameSfx.tap);
    _loadLevel(_currentLevelIndex + 1);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.playing;
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  void _exitGame() {
    Navigator.pop(context);
  }

  // ── Gesture handling ──────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    if (_phase != _Phase.playing || !_boardReady) return;
    final cell = _getGridCell(event.localPosition);
    if (cell == null) return;

    final row = cell.dx.toInt();
    final col = cell.dy.toInt();

    // Can start drawing from ANY non-empty cell (endpoint or path cell)
    final pairId = _gameState.getPairIdAt(row, col);
    if (pairId != null || _isEndpointCell(row, col)) {
      if (!_hasStartedDrawing) _hasStartedDrawing = true;
      _dismissCellWarning();
      _gameState.startDrawing(FlowCell(row, col));
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  bool _isEndpointCell(int row, int col) {
    for (final pair in _currentLevel.pairs) {
      if ((pair.start.row == row && pair.start.col == col) ||
          (pair.end.row == row && pair.end.col == col)) {
        return true;
      }
    }
    return false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_phase != _Phase.playing || !_hasStartedDrawing) return;
    if (_gameState.activePairId == null) return;

    final cell = _getGridCell(event.localPosition);
    if (cell == null) return;

    final row = cell.dx.toInt();
    final col = cell.dy.toInt();
    final path = _gameState.paths[_gameState.activePairId];
    if (path != null && path.isNotEmpty) {
      final last = path.last;
      if (row == last.row && col == last.col) return;
    }

    _gameState.extendPath(FlowCell(row, col));
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_phase != _Phase.playing || !_hasStartedDrawing) return;
    _gameState.finishDrawing();
    if (_gameState.isComplete) {
      _dismissCellWarning();
      setState(() => _finishLevel());
      return;
    }
    _refreshCellWarning();
    setState(() {});
  }

  Offset? _getGridCell(Offset localPos) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;

    final cellW = size.width / _currentLevel.cols;
    final cellH = size.height / _currentLevel.rows;
    final cellSize = cellW < cellH ? cellW : cellH;
    final offsetX = (size.width - cellSize * _currentLevel.cols) / 2;
    final offsetY = (size.height - cellSize * _currentLevel.rows) / 2;

    final x = localPos.dx - offsetX;
    final y = localPos.dy - offsetY;

    if (x < 0 || y < 0) return null;

    final col = (x / cellSize).floor();
    final row = (y / cellSize).floor();

    if (row >= 0 && row < _currentLevel.rows &&
        col >= 0 && col < _currentLevel.cols) {
      return Offset(row.toDouble(), col.toDouble());
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GameScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              GameTopBar(
                title: _t('FLOW FREE', 'ফ্লো ফ্রি', 'फ्लो फ्री'),
                subtitle: _t(
                  'Connect matching colors with pipes.',
                  'মিলিম রং পাইপ দিয়ে সংযুক্ত করুন।',
                  'मिलते रंगों को पाइप से जोड़ें।',
                ),
                trailing: _buildLevelChip(isDark),
              ),
              const SizedBox(height: 4),
              Expanded(child: _buildBoardArea(isDark)),
              _buildUndoButtonBottom(isDark),
              const SizedBox(height: 20),
            ],
          ),
          if (_boardFinish.isAnimating || _boardFinish.isCompleted)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _boardFinish,
                builder: (context, _) => IgnorePointer(
                  child: Container(
                    color: const Color(0xFF00E5FF).withValues(
                      alpha: (1 - _boardFinish.value) * 0.3,
                    ),
                  ),
                ),
              ),
            ),
          if (_phase == _Phase.finished) _buildResults(isDark),
          if (_showCountdown)
            CountdownOverlay(
              onFinished: _beginRun,
              goLabel: _t('GO!', 'শুরু!', 'शुरू!'),
            ),
        ],
      ),
    );
  }

  // ── HUD ───────────────────────────────────────────────────────────────

  Widget _buildLevelChip(bool isDark) {
    return GestureDetector(
      onTap: _showLevelPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.rRound),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_rounded,
                size: 13, color: Color(0xFF00E5FF)),
            const SizedBox(width: 4),
            Text(
              '${_t('LVL', 'স্তর', 'स्तर')} ${_currentLevelIndex + 1}',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
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

  /// Replay sheet: lists only the levels the player has already solved
  /// (progress key stores the NEXT level to start from, so solved = 1..n-1).
  Future<void> _showLevelPicker() async {
    GameSfxService.instance.play(GameSfx.tap);
    final prefs = await SharedPreferences.getInstance();
    final solvedMax = math.max(0, (prefs.getInt(_levelKey) ?? 1) - 1);
    if (!mounted) return;

    const accent = Color(0xFF00E5FF);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF141A26),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.replay_rounded, size: 16, color: accent),
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
                          fontSize: 12,
                          color: Colors.white54,
                        ),
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
                            _buildReplayLevelDot(n, sheetCtx, accent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplayLevelDot(int levelNumber, BuildContext sheetCtx, Color accent) {
    final isCurrent = levelNumber == _currentLevelIndex + 1;
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        if (!isCurrent) _jumpToLevel(levelNumber - 1);
      },
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent ? accent : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: accent.withValues(alpha: isCurrent ? 1 : 0.3),
            width: 1.2,
          ),
        ),
        child: Text(
          '$levelNumber',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isCurrent ? const Color(0xFF062033) : Colors.white70,
          ),
        ),
      ),
    );
  }

  void _jumpToLevel(int index) {
    _loadLevel(index);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.playing;
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  Widget _buildUndoButtonBottom(bool isDark) {
    final enabled =
        _gameState.canUndo && _phase == _Phase.playing && _boardReady;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: enabled ? _undoLastMove : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFFFF9100).withValues(alpha: 0.12)
                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            shape: BoxShape.circle,
            border: enabled
                ? Border.all(
                    color: const Color(0xFFFF9100).withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: Icon(
            Icons.undo_rounded,
            size: 20,
            color: enabled
                ? const Color(0xFFFF9100)
                : (isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight),
          ),
        ),
      ),
    );
  }

  void _undoLastMove() {
    if (_gameState.undo()) {
      HapticFeedback.selectionClick();
      _refreshCellWarning();
      setState(() {});
    }
  }

  Widget _buildBoardArea(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: AnimatedBuilder(
              animation: _boardPop,
              builder: (context, child) {
                final scale = Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(parent: _boardPop, curve: Curves.easeOutBack),
                );
                return ScaleTransition(scale: scale, child: child);
              },
              child: Container(
                key: _boardKey,
                width: maxSize,
                height: maxSize,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppSpacing.rXl),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rXl),
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_boardReveal, _dotsIn, _warnPulse]),
                          builder: (context, _) {
                            // Nothing is painted until the countdown kicks
                            // off the run (intro screen was removed — the
                            // shared GameIntroScreen handles onboarding).
                            final hidden = !_runStarted || _showCountdown;
                            final building = !hidden &&
                                (_boardReveal.isAnimating ||
                                    _boardReveal.value < 1.0);

                            // Dots stay hidden (progress 0) until the grid
                            // build finishes, then pop in via _dotsIn, then
                            // rest at null (= fully shown).
                            final double? dotsProgress;
                            if (!hidden && _dotsIn.isAnimating) {
                              dotsProgress = _dotsIn.value;
                            } else if (!hidden && !_dotsIn.isCompleted) {
                              dotsProgress = 0.0;
                            } else {
                              dotsProgress = null;
                            }

                            return CustomPaint(
                              painter: FlowFreePainter(
                                level: _currentLevel,
                                paths: _gameState.paths,
                                grid: _gameState.grid,
                                activePairId: _gameState.activePairId,
                                hidden: hidden,
                                buildProgress:
                                    building ? _boardReveal.value : null,
                                dotsProgress: dotsProgress,
                                blinkingCells: _cellWarningActive
                                    ? _warningCells
                                    : const [],
                                blinkPulse: _warnPulse.value,
                              ),
                              size: Size(maxSize, maxSize),
                            );
                          },
                        ),
                        if (_phase == _Phase.playing)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: 10,
                            child: IgnorePointer(
                              child: _buildCellWarningBar(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────

  /// Slim snackbar pinned to the top edge of the board. Slides in when the
  /// warning activates and slides out when it auto-dismisses. Purely visual
  /// (IgnorePointer) so the user can keep drawing underneath at any moment.
  Widget _buildCellWarningBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _cellWarningActive
          ? Container(
              key: const ValueKey('cell-warning'),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF101826).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(AppSpacing.rRound),
                border: Border.all(
                  color: const Color(0xFFFFC947).withValues(alpha: 0.55),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFFFFB300).withValues(alpha: 0.28),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.grid_on_rounded,
                    size: 15,
                    color: Color(0xFFFFC947),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t(
                        'Fill every cell to complete!',
                        'সম্পূর্ণ করতে প্রতিটি ঘর পূরণ করুন!',
                        'पूरा करने के लिए हर खाना भरें!',
                      ),
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('cell-warning-off')),
    );
  }


  Widget _buildResults(bool isDark) {
    final score = _calculateScore();
    final completed = _gameState.isComplete;
    return GameResultsPanel(
      title: completed
          ? _t('LEVEL COMPLETE!', 'লেভেল সম্পন্ন!', 'स्तर पूरा!')
          : _t('GREAT START!', 'দারুণ শুরু!', 'शानदार शुरुआत!'),
      subtitle: completed
          ? _t(
              'Grid ${_currentLevel.rows}×${_currentLevel.cols} cleared!',
              '${_currentLevel.rows}×${_currentLevel.cols} গ্রিড সম্পূর্ণ!',
              '${_currentLevel.rows}×${_currentLevel.cols} ग्रिड पूरा!',
            )
          : _t(
              'Fill every cell to clear the grid.',
              'গ্রিড সম্পূর্ণ করতে প্রতিটি ঘর পূরণ করুন।',
              'ग्रिड पूरा करने के लिए हर खाना भरें।',
            ),
      score: score,
      isNewBest: _isNewBest,
      stars: _computeStars(),
      stats: [
        GameResultStat(
          label: _t('TIME', 'সময়', 'समय'),
          value: '${_elapsedSeconds}s',
          icon: Icons.timer_outlined,
          color: const Color(0xFF00E5FF),
        ),
        GameResultStat(
          label: _t('FILLED', 'পূরণ', 'भरा हुआ'),
          value:
              '${(_gameState.filledCells * 100 / _gameState.totalCells).round()}%',
          icon: Icons.grid_on_rounded,
          color: const Color(0xFF76FF03),
        ),
        GameResultStat(
          label: _t('BEST', 'সেরা', 'सर्वश्रेष्ठ'),
          value: '$_best',
          icon: Icons.emoji_events_outlined,
          color: AppColors.coin,
        ),
      ],
      playAgainLabel: _t('NEXT LEVEL', 'পরের স্তর', 'अगला स्तर'),
      shareLabel: _t('REPLAY', 'আবার খেলুন', 'फिर से खेलें'),
      exitLabel: _t('EXIT', 'বাহির', 'बाहर'),
      footerHint: _t(
        'Level ${_currentLevelIndex + 1} • ${_currentLevel.difficulty}',
        'স্তর ${_currentLevelIndex + 1} • ${_currentLevel.difficulty}',
        'स्तर ${_currentLevelIndex + 1} • ${_currentLevel.difficulty}',
      ),
      onPlayAgain: completed ? _nextLevel : _playAgain,
      onShare: _playAgain,
      onExit: _exitGame,
    );
  }
}
