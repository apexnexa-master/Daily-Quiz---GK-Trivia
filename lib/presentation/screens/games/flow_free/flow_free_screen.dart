import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const String _bestScoreKey = 'flow_free_best';

enum _Phase { intro, playing, finished }

class FlowFreeScreen extends ConsumerStatefulWidget {
  const FlowFreeScreen({super.key});

  @override
  ConsumerState<FlowFreeScreen> createState() => _FlowFreeScreenState();
}

class _FlowFreeScreenState extends ConsumerState<FlowFreeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _boardKey = GlobalKey();

  _Phase _phase = _Phase.intro;
  bool _showCountdown = false;
  bool _isNewBest = false;
  bool _boardReady = false;
  int _currentLevelIndex = 0;
  int _best = 0;
  int _elapsedSeconds = 0;
  bool _hasStartedDrawing = false;

  Timer? _clockTimer;
  late FlowGameState _gameState;
  late FlowLevel _currentLevel;

  late final AnimationController _introSpin;
  late final AnimationController _boardPop;
  late final AnimationController _boardReveal;
  late final AnimationController _dotsIn;
  late final AnimationController _boardFinish;

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  String _t(String en, String bn, String hi) =>
      _isBn ? bn : _isHi ? hi : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _introSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
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
    _loadBest();
    _loadLevel(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _introSpin.dispose();
    _boardPop.dispose();
    _boardReveal.dispose();
    _dotsIn.dispose();
    _boardFinish.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestScoreKey) ?? 0);
  }

  void _loadLevel(int index) {
    final generator = FlowPuzzleGenerator();
    _currentLevel = generator.generateLevel(index + 1);
    _currentLevelIndex = index;
    _gameState = FlowGameState(_currentLevel);
    _elapsedSeconds = 0;
    _hasStartedDrawing = false;
    _boardReady = false;
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

  // ── Flow control ──────────────────────────────────────────────────────

  void _startPressed() {
    GameSfxService.instance.play(GameSfx.tap);
    setState(() => _showCountdown = true);
  }

  void _beginRun() {
    if (_phase == _Phase.playing) return;
    _clockTimer?.cancel();
    setState(() {
      _showCountdown = false;
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

  int _calculateScore() {
    final base = _currentLevelIndex * 100 + 50;
    final timeBonus = math.max(0, 300 - _elapsedSeconds * 2);
    final completionBonus = _gameState.isComplete ? 300 : 0;
    return math.max(0, base + timeBonus + completionBonus);
  }

  void _playAgain() {
    GameSfxService.instance.play(GameSfx.tap);
    _loadLevel(_currentLevelIndex);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.intro;
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  void _nextLevel() {
    GameSfxService.instance.play(GameSfx.tap);
    _loadLevel(_currentLevelIndex + 1);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.intro;
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
    setState(() {
      if (_gameState.isComplete) {
        _finishLevel();
      }
    });
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
          if (_phase == _Phase.intro && !_showCountdown) _buildIntro(isDark),
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
      onTap: kDebugMode ? () => _showLevelPicker() : null,
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
            if (kDebugMode) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 10, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }

  void _showLevelPicker() {
    final controller = TextEditingController(text: '${_currentLevelIndex + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Jump to Level', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Level number (1-999)',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (val) {
            final num = int.tryParse(val);
            if (num != null && num >= 1) {
              Navigator.pop(ctx);
              _jumpToLevel(num - 1);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final num = int.tryParse(controller.text);
              if (num != null && num >= 1) {
                Navigator.pop(ctx);
                _jumpToLevel(num - 1);
              }
            },
            child: const Text('GO', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }

  void _jumpToLevel(int index) {
    _loadLevel(index);
    _clockTimer?.cancel();
    setState(() {
      _phase = _Phase.intro;
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
                  color: _phase == _Phase.intro
                      ? Colors.transparent
                      : (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppSpacing.rXl),
                  border: _phase == _Phase.intro
                      ? null
                      : Border.all(
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
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_boardReveal, _dotsIn]),
                      builder: (context, _) {
                        final hidden =
                            _phase == _Phase.intro || _showCountdown;
                        final building = !hidden &&
                            (_boardReveal.isAnimating ||
                                _boardReveal.value < 1.0);

                        // Dots stay hidden (progress 0) until the grid build
                        // finishes, then pop in via _dotsIn, then rest at null
                        // (= fully shown, no per-frame dot math).
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
                          ),
                          size: Size(maxSize, maxSize),
                        );
                      },
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

  Widget _buildIntro(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: (isDark ? const Color(0xFF05080E) : Colors.white)
            .withValues(alpha: isDark ? 0.95 : 0.97),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroOrb(isDark),
                  AppSpacing.vXxl,
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00E5FF), Color(0xFF76FF03)],
                    ).createShader(bounds),
                    child: Text(
                      _t('FLOW FREE', 'ফ্লো ফ্রি', 'फ्लो फ्री'),
                      style: GoogleFonts.montserrat(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x5500E5FF), blurRadius: 26),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    _t(
                      'Connect matching colors without crossing pipes.',
                      'পাইপ ছাড়ার বিনা মিলিম রং সংযুক্ত করুন।',
                      'पाइप को पार किए बिना मिलते रंगों को जोड़ें।',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  AppSpacing.vXxl,
                  _buildRuleRow(
                    icon: Icons.touch_app_rounded,
                    color: const Color(0xFF00E5FF),
                    text: _t(
                      'Drag from a colored dot to draw a path.',
                      'পাথ আঁকতে একটি রঙিন বিন্দু থেকে টেনে আনুন।',
                      'पाथ बनाने के लिए रंगीन बिंदु से खींचें।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.block_rounded,
                    color: AppColors.error,
                    text: _t(
                      'Paths cannot cross each other.',
                      'পাথ একে অপরকে পার করতে পারে না।',
                      'पाथ एक दूसरे को पार नहीं कर सकते।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.grid_on_rounded,
                    color: const Color(0xFF76FF03),
                    text: _t(
                      'Fill every cell on the grid to complete the level.',
                      'লেভেল সম্পূর্ণ করতে গ্রিডের প্রতিটি কোষ পূরণ করুন।',
                      'स्तर पूरा करने के लिए ग्रिड की हर सेल भरें।',
                    ),
                    isDark: isDark,
                  ),
                  if (_best > 0) ...[
                    AppSpacing.vXl,
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: _glass(isDark, AppColors.coin),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 14, color: AppColors.coin),
                          const SizedBox(width: 6),
                          Text(
                            _t(
                                'Best: $_best', 'সেরা: $_best', 'सर्वश्रेष्ठ: $_best'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  AppSpacing.vXxl,
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF76FF03)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.rLg),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _startPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.rLg),
                          ),
                        ),
                        child: Text(
                          _t('START', 'শুরু করুন', 'शुरू करें'),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.vMd,
                  TextButton(
                    onPressed: _exitGame,
                    child: Text(
                      _t('BACK', 'ফিরে যান', 'वापस जाएं'),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroOrb(bool isDark) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF76FF03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                  blurRadius: 34,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          AnimatedBuilder(
            animation: _introSpin,
            builder: (context, _) {
              final angle = _introSpin.value * 2 * math.pi;
              return Transform.rotate(
                angle: angle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitDot(const Offset(64, 0), const Color(0xFF00E5FF)),
                    _orbitDot(const Offset(-64, 0), const Color(0xFFFF6D00)),
                    _orbitDot(const Offset(0, 64), const Color(0xFFE040FB)),
                    _orbitDot(const Offset(0, -64), const Color(0xFFFFEB3B)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _orbitDot(Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border:
              Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final score = _calculateScore();
    final completed = _gameState.isComplete;
    return GameResultsPanel(
      title: completed
          ? _t('LEVEL COMPLETE!', 'লেভেল সম্পন্ন!', 'स्तर पूरा!')
          : _t('GREAT START!', 'দারুণ শুরু!', 'शानदार शुरुआत!'),
      subtitle: _t(
        '${_currentLevel.rows}x${_currentLevel.cols} — ${_currentLevel.pairCount} colors',
        '${_currentLevel.rows}x${_currentLevel.cols} — ${_currentLevel.pairCount} রং',
        '${_currentLevel.rows}x${_currentLevel.cols} — ${_currentLevel.pairCount} रंग',
      ),
      score: score,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
          label: _t('TIME', 'সময়', 'समय'),
          value: '${_elapsedSeconds}s',
          icon: Icons.timer_outlined,
          color: const Color(0xFF00E5FF),
        ),
        GameResultStat(
          label: _t('FILLED', 'পূরণ', 'भरा हुआ'),
          value: '${_gameState.filledCells}/${_gameState.totalCells}',
          icon: Icons.grid_on_rounded,
          color: const Color(0xFF76FF03),
        ),
        GameResultStat(
          label: _t('PAIRS', 'জোড়া', 'जोड़े'),
          value: '${_currentLevel.pairCount}',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFFE040FB),
        ),
      ],
      playAgainLabel: _t('NEXT LEVEL', 'পরের স্তর', 'अगला स्तर'),
      shareLabel: _t('REPLAY', 'আবার খেলুন', 'फिर से खेलें'),
      exitLabel: _t('EXIT', 'বাহির', 'बाहर'),
      footerHint: _t('Best: $_best', 'সেরা: $_best', 'सर्वश्रेष्ठ: $_best'),
      onPlayAgain: completed ? _nextLevel : _playAgain,
      onShare: _playAgain,
      onExit: _exitGame,
    );
  }

  BoxDecoration _glass(bool isDark, Color accent) => BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      );
}
