import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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
import 'one_line_engine.dart';
import 'one_line_models.dart';
import 'one_line_painter.dart';
import 'one_line_shapes.dart';

const String _bestScoreKey = 'one_line_best';

enum _Phase { intro, playing, finished }

class OneLineScreen extends ConsumerStatefulWidget {
  const OneLineScreen({super.key});

  @override
  ConsumerState<OneLineScreen> createState() => _OneLineScreenState();
}

class _OneLineScreenState extends ConsumerState<OneLineScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final OneLineEngine _engine = OneLineEngine();
  final GlobalKey _boardKey = GlobalKey();

  _Phase _phase = _Phase.intro;
  bool _showCountdown = false;
  bool _isNewBest = false;
  int _runId = 0;
  int _currentLevelIndex = 0;
  int _best = 0;
  int _workoutScore = 0;
  int _elapsedSeconds = 0;
  int _backtracks = 0;
  bool _hasStartedDrawing = false;

  Timer? _clockTimer;
  Stopwatch _stopwatch = Stopwatch();

  late final AnimationController _introSpin;
  late final AnimationController _boardPop;

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _introSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _boardPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadBest();
    _loadLevel(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _stopwatch.stop();
    _introSpin.dispose();
    _boardPop.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestScoreKey) ?? 0);
  }

  void _loadLevel(int index) {
    final levels = OneLineShapes.levels;
    if (index >= levels.length) index = 0;
    _currentLevelIndex = index;
    _engine.reset(levels[index]);
    _elapsedSeconds = 0;
    _backtracks = 0;
    _hasStartedDrawing = false;
  }

  String _t(String en, String bn, String hi) =>
      _isBn ? bn : _isHi ? hi : en;

  // ── Flow control ──────────────────────────────────────────────────────

  void _startPressed() {
    GameSfxService.instance.play(GameSfx.tap);
    setState(() => _showCountdown = true);
  }

  void _beginRun() {
    if (_phase == _Phase.playing) return;
    _runId++;
    setState(() {
      _showCountdown = false;
      _phase = _Phase.playing;
      _elapsedSeconds = 0;
      _backtracks = 0;
      _hasStartedDrawing = false;
    });
    _stopwatch = Stopwatch()..start();
    _startClock();
    _boardPop.forward(from: 0);
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
    _stopwatch.stop();

    final score = _calculateScore();
    final isNewBest = score > _best;
    if (isNewBest) {
      _best = score;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_bestScoreKey, score);
      });
    }

    GameSfxService.instance.play(GameSfx.gameOver);
    final input = OneLinePerformanceInput(
      shapeComplexity: _currentLevelIndex + 1,
      edgeCount: _engine.totalEdges,
      completed: true,
      timeSeconds: _elapsedSeconds,
      backtracks: _backtracks,
    );
    _workoutScore = GamePerformanceService.calculate(input);
    unawaited(
      ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'oneLine',
          mode: SessionMode.practice,
          gameType: GameType.oneLine,
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
  }

  int _calculateScore() {
    final base = _currentLevelIndex * 100 + 50;
    final timeBonus = math.max(0, 300 - _elapsedSeconds * 2);
    final backtrackPenalty = _backtracks * 20;
    final completionBonus = _engine.isComplete() ? 200 : 0;
    return math.max(0, base + timeBonus + completionBonus - backtrackPenalty);
  }

  void _playAgain() {
    GameSfxService.instance.play(GameSfx.tap);
    _runId++;
    _loadLevel(_currentLevelIndex);
    _clockTimer?.cancel();
    _stopwatch.stop();
    setState(() {
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  void _nextLevel() {
    GameSfxService.instance.play(GameSfx.tap);
    _runId++;
    _loadLevel(_currentLevelIndex + 1);
    _clockTimer?.cancel();
    _stopwatch.stop();
    setState(() {
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  Future<void> _shareScore() async {
    final text = '''
🧠 **One Line Drawing**

🔥 Level ${_currentLevelIndex + 1}: ${_engine.shape.name}
⏱ Time: ${_elapsedSeconds}s | Edges: ${_engine.traversedCount}/${_engine.totalEdges}
⚡ Score: ${_calculateScore()}

Can you beat me? 🚀
''';
    try {
      await Share.share(text, subject: 'My One Line Score!');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('Sharing is not available right now.',
                'এখন শেয়ার করা যাচ্ছে না।', 'अभी साझा करना संभव नहीं है।'))),
      );
    }
  }

  void _exitGame() {
    Navigator.pop(context);
  }

  // ── Gesture handling ──────────────────────────────────────────────────

  void _onTapUp(TapUpDetails details) {
    if (_phase != _Phase.playing) return;

    final vertex = _getVertexFromPosition(details.localPosition);
    if (vertex == null) return;

    if (!_hasStartedDrawing) {
      // Start path from this vertex
      if (_engine.startPath(vertex.id)) {
        setState(() {
          _hasStartedDrawing = true;
        });
        HapticFeedback.selectionClick();
        GameSfxService.instance.play(GameSfx.tap);
      }
    } else {
      // Try to move to this vertex
      final success = _engine.moveToVertex(vertex.id);
      if (success) {
        HapticFeedback.selectionClick();
        GameSfxService.instance.play(GameSfx.tap);

        if (_engine.isComplete()) {
          _finishLevel();
        }
      } else if (_engine.currentVertex == vertex.id) {
        // Tapped current vertex - undo last move (backtrack)
        if (_engine.currentPath.length > 1) {
          _backtracks++;
          // Simple undo: remove last vertex and un-traverse last edge
          final lastVertex = _engine.currentPath.last;
          final prevVertex =
              _engine.currentPath[_engine.currentPath.length - 2];
          // Find the edge between prev and last
          for (final edge in _engine.shape.edges) {
            if (_engine.traversedEdgeIds.contains(edge.id) &&
                ((edge.startVertexId == prevVertex &&
                    edge.endVertexId == lastVertex) ||
                    (edge.startVertexId == lastVertex &&
                        edge.endVertexId == prevVertex))) {
              _engine.traversedEdgeIds.remove(edge.id);
              edge.traversed = false;
              break;
            }
          }
          _engine.currentPath.removeLast();
          setState(() {});
        }
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _Phase.playing) return;

    final vertex = _getVertexFromPosition(details.localPosition);
    if (vertex == null) return;

    if (!_hasStartedDrawing) {
      if (_engine.startPath(vertex.id)) {
        setState(() {
          _hasStartedDrawing = true;
        });
        HapticFeedback.selectionClick();
      }
    } else {
      _engine.moveToVertex(vertex.id);
      HapticFeedback.selectionClick();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != _Phase.playing || !_hasStartedDrawing) return;

    final vertex = _getVertexFromPosition(details.localPosition);
    if (vertex == null) return;

    if (vertex.id != _engine.currentVertex) {
      final success = _engine.moveToVertex(vertex.id);
      if (success) {
        HapticFeedback.selectionClick();
        if (_engine.isComplete()) {
          _finishLevel();
        }
      }
    }
  }

  OneLineVertex? _getVertexFromPosition(Offset position) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final size = box.size;
    final padding = size.width * 0.08;
    final drawSize = Size(size.width - padding * 2, size.height - padding * 2);
    final vertexRadius = size.width * 0.06;

    for (final vertex in _engine.shape.vertices) {
      final pixelPos = Offset(
        padding + vertex.position.dx * drawSize.width,
        padding + vertex.position.dy * drawSize.height,
      );
      final distance = (position - pixelPos).distance;
      if (distance < vertexRadius * 2) {
        return vertex;
      }
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
                title: _t('ONE LINE', 'ওয়ান লাইন', 'वन लाइन'),
                subtitle: _t('Draw the impossible shape.',
                    'অসম্ভব আকৃতি আঁকুন।', 'असंभव आकृति बनाएँ।'),
                trailing: _buildLevelChip(isDark),
              ),
              _buildProgressRow(isDark),
              Expanded(child: _buildBoardArea(isDark)),
              const SizedBox(height: 20),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        border: Border.all(
          color: const Color(0xFFE040FB).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.draw_rounded,
              size: 13, color: Color(0xFFE040FB)),
          const SizedBox(width: 4),
          Text(
            '${_t('LVL', 'স্তর', 'स्तर')} ${_currentLevelIndex + 1}',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(bool isDark) {
    final progress = _engine.progress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shape name
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.rRound),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shape_line_rounded,
                        size: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                    const SizedBox(width: 4),
                    Text(
                      _engine.shape.name,
                      style: GoogleFonts.montserrat(
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
              // Timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.rRound),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${_elapsedSeconds}s',
                      style: GoogleFonts.montserrat(
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
              // Edges completed
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.rRound),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.linear_scale_rounded,
                        size: 13, color: Color(0xFFE040FB)),
                    const SizedBox(width: 4),
                    Text(
                      '${_engine.traversedCount}/${_engine.totalEdges}',
                      style: GoogleFonts.montserrat(
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
          ),
          const SizedBox(height: 8),
          // Progress bar
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE040FB), Color(0xFFAA00FF)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE040FB)
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
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

  Widget _buildBoardArea(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: GestureDetector(
              onTapUp: _onTapUp,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: AnimatedBuilder(
                animation: _boardPop,
                builder: (context, child) {
                  final scale = Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(
                        parent: _boardPop, curve: Curves.easeOutBack),
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
                    child: CustomPaint(
                      painter: OneLinePainter(
                        engine: _engine,
                        isDark: isDark,
                      ),
                      size: Size(maxSize, maxSize),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroOrb(isDark),
                  AppSpacing.vXxl,
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE040FB), Color(0xFFAA00FF)],
                    ).createShader(bounds),
                    child: Text(
                      _t('ONE LINE', 'ওয়ান লাইন', 'वन लाइन'),
                      style: GoogleFonts.montserrat(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x55E040FB), blurRadius: 26),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    _t(
                      'Draw the impossible shape.',
                      'অসম্ভব আকৃতি আঁকুন।',
                      'असंभव आकृति बनाएँ।',
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
                    icon: Icons.draw_rounded,
                    color: const Color(0xFFE040FB),
                    text: _t(
                      'Tap vertices to trace the shape with a single stroke.',
                      'একটি ধারাবাহিক স্ট্রোকে আকৃতি ট্রেস করুন।',
                      'एक निरंतर स्ट्रोक में आकृति ट्रेस करें।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.block_rounded,
                    color: AppColors.error,
                    text: _t(
                      'Every edge must be traversed exactly once.',
                      'প্রতিটি প্রান্ত ঠিক একবার পার হতে হবে।',
                      'हर किनारा ठीक एक बार पार किया जाना चाहिए।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.touch_app_rounded,
                    color: const Color(0xFF76FF03),
                    text: _t(
                      'Tap the current vertex to undo a move.',
                      'মুভ আনডু করতে বর্তমান শীর্ষবিন্দুতে ট্যাপ করুন।',
                      'चाल अनडू करने के लिए वर्तमान शीर्ष बिंदु पर टैप करें।',
                    ),
                    isDark: isDark,
                  ),
                  if (_best > 0) ...[
                    AppSpacing.vXl,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: _glass(isDark, AppColors.coin),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 14, color: AppColors.coin),
                          const SizedBox(width: 6),
                          Text(
                            _t('Best: $_best', 'সেরা: $_best',
                                'सर्वश्रेष्ठ: $_best'),
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
                          colors: [Color(0xFFE040FB), Color(0xFFAA00FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.rLg),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE040FB)
                                .withValues(alpha: 0.4),
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
                            borderRadius:
                                BorderRadius.circular(AppSpacing.rLg),
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
                colors: [Color(0xFFE040FB), Color(0xFFAA00FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.45),
                  blurRadius: 34,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.draw_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          AnimatedBuilder(
            animation: _introSpin,
            builder: (context, _) {
              final angle = _introSpin.value * 2 * pi;
              return Transform.rotate(
                angle: angle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitDot(
                        const Offset(64, 0), const Color(0xFF00E5FF)),
                    _orbitDot(
                        const Offset(-64, 0), const Color(0xFF76FF03)),
                    _orbitDot(
                        const Offset(0, 64), const Color(0xFFFFEB3B)),
                    _orbitDot(
                        const Offset(0, -64), const Color(0xFFFF5252)),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 1,
        ),
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
                color:
                    isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final score = _calculateScore();
    final completed = _engine.isComplete();
    return GameResultsPanel(
      title: completed
          ? _t("SHAPE COMPLETE!", "আকৃতি সম্পন্ন!", "आकृति पूर्ण!")
          : _t("TIME'S UP!", "সময় শেষ!", "समय समाप्त!"),
      subtitle: _t(
        '${_engine.shape.name} — ${_engine.traversedCount}/${_engine.totalEdges} edges',
        '${_engine.shape.name} — ${_engine.traversedCount}/${_engine.totalEdges} প্রান্ত',
        '${_engine.shape.name} — ${_engine.traversedCount}/${_engine.totalEdges} किनारे',
      ),
      score: score,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
          label: _t('TIME', 'সময়', 'समय'),
          value: '${_elapsedSeconds}s',
          icon: Icons.timer_outlined,
          color: const Color(0xFFE040FB),
        ),
        GameResultStat(
          label: _t('EDGES', 'প্রান্ত', 'किनारे'),
          value: '${_engine.traversedCount}/${_engine.totalEdges}',
          icon: Icons.linear_scale_rounded,
          color: const Color(0xFF00E5FF),
        ),
        GameResultStat(
          label: _t('BACKTRACKS', 'আনডু', 'अनडू'),
          value: '$_backtracks',
          icon: Icons.undo_rounded,
          color: AppColors.warning,
        ),
      ],
      playAgainLabel: _t('PLAY AGAIN', 'আবার খেলুন', 'फिर से खेलें'),
      shareLabel: _t('SHARE SCORE', 'স্কোর শেয়ার করুন', 'स्कोर साझा करें'),
      exitLabel: _t('EXIT', 'বাহির', 'बाहर'),
      footerHint: _t('Best: $_best', 'সেরা: $_best', 'सर्वश्रेष्ठ: $_best'),
      onPlayAgain: _playAgain,
      onShare: _shareScore,
      onExit: _exitGame,
    );
  }

  BoxDecoration _glass(bool isDark, Color accent) => BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
          width: 1,
        ),
      );
}
