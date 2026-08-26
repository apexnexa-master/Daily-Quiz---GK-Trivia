import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'silhouette_models.dart';
import 'silhouette_engine.dart';
import 'silhouette_levels.dart';
import 'silhouette_painter.dart';

class ArrowSilhouetteScreen extends StatefulWidget {
  const ArrowSilhouetteScreen({super.key});

  @override
  State<ArrowSilhouetteScreen> createState() => _ArrowSilhouetteScreenState();
}

class _ArrowSilhouetteScreenState extends State<ArrowSilhouetteScreen>
    with TickerProviderStateMixin {
  late SilhouetteEngine _engine;
  late SilhouetteLevel _level;
  int _currentLevelId = 1;
  bool _loaded = false;

  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _timerStarted = false;

  bool _showWinOverlay = false;
  int _hintsRemaining = 3;
  int _highestUnlocked = 1;
  final Map<int, int> _starsMap = {};

  late AnimationController _tickerController;
  final List<FlyOff> _flyOffs = [];
  final Map<String, double> _flyProgress = {};
  final List<AnimationController> _escapeControllers = [];

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _loadLevel(_currentLevelId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickerController.dispose();
    for (final c in _escapeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadLevel(int levelId) {
    final idx = levelId - 1;
    if (idx < 0 || idx >= silhouetteLevels.length) return;

    _level = silhouetteLevels[idx];
    _engine = SilhouetteEngine(_level);
    _currentLevelId = levelId;

    _timer?.cancel();
    _elapsedSeconds = 0;
    _timerStarted = false;
    _showWinOverlay = false;
    _hintsRemaining = 3;
    _flyOffs.clear();
    _flyProgress.clear();

    _loaded = true;
    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onTapDown(TapDownDetails details, Size canvasSize) {
    if (_showWinOverlay) return;

    final rows = _level.gridRows;
    final cols = _level.gridCols;
    final cellSize = min(canvasSize.width / cols, canvasSize.height / rows);
    final gridW = cols * cellSize;
    final gridH = rows * cellSize;
    final origin = Offset(
      (canvasSize.width - gridW) / 2,
      (canvasSize.height - gridH) / 2,
    );

    final arrow = _engine.hitTest(details.localPosition, origin, cellSize);
    if (arrow == null) {
      setState(() {
        _engine.highlightArrow(null);
      });
      return;
    }

    if (!_timerStarted) {
      _timerStarted = true;
      _startTimer();
    }

    if (_engine.canEscape(arrow)) {
      _performEscape(arrow, origin, cellSize);
    } else {
      _showBlocked(arrow.id);
    }
  }

  void _performEscape(ArrowPiece arrow, Offset origin, double cellSize) {
    HapticFeedback.lightImpact();
    _engine.escapeArrow(arrow);
    _engine.highlightArrow(null);

    final flyOff = FlyOff.forArrow(arrow, origin, cellSize);
    _flyOffs.add(flyOff);
    _flyProgress[arrow.id] = 0.0;

    setState(() {});

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _escapeControllers.add(controller);
    controller.addListener(() {
      _flyProgress[arrow.id] = flyOff.total * Curves.easeIn.transform(controller.value);
      setState(() {});
    });

    controller.forward().then((_) {
      _engine.completeEscape(arrow);
      _flyOffs.removeWhere((f) => f.arrow.id == arrow.id);
      _flyProgress.remove(arrow.id);
      _escapeControllers.remove(controller);
      controller.dispose();

      setState(() {
        if (_engine.allEscaped) {
          _onLevelComplete();
        }
      });
    });
  }

  Size get canvasSize => const Size(400, 600);

  void _showBlocked(String arrowId) {
    HapticFeedback.mediumImpact();
  }

  void _onLevelComplete() {
    _timer?.cancel();
    final result = _engine.result(Duration(seconds: _elapsedSeconds));
    _starsMap[_currentLevelId] = max(
      _starsMap[_currentLevelId] ?? 0,
      result.stars,
    );
    if (_currentLevelId >= _highestUnlocked) {
      _highestUnlocked = _currentLevelId + 1;
    }
    setState(() => _showWinOverlay = true);
  }

  void _undo() {
    if (_engine.undo()) setState(() {});
  }

  void _reset() => _loadLevel(_currentLevelId);

  void _useHint() {
    if (_hintsRemaining <= 0) return;
    final hint = _engine.showHint();
    if (hint == null) return;
    setState(() => _hintsRemaining--);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => hint.showHint = false);
    });
  }

  void _nextLevel() {
    if (_currentLevelId < silhouetteLevels.length) {
      _loadLevel(_currentLevelId + 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(child: _buildGameCanvas(isDark)),
                  _buildControls(isDark),
                ],
              ),
              if (_showWinOverlay) _buildWinOverlay(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARROW SILHOUETTE',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${_level.themeEmoji} ${_level.name} — Level $_currentLevelId',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          _buildStatChip(_formatTime(_elapsedSeconds), isDark),
          const SizedBox(width: 8),
          _buildStatChip('${_engine.moveCount}', isDark, highlight: true),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, bool isDark, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: highlight ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }

  Widget _buildGameCanvas(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        final canvasSize = Size(
          constraints.maxWidth - margin.horizontal,
          constraints.maxHeight - margin.vertical,
        );
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              onTapDown: (d) => _onTapDown(d, canvasSize),
              child: AnimatedBuilder(
                animation: _tickerController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SilhouettePainter(
                      engine: _engine,
                      animationValue: _tickerController.value,
                      flyOffs: _flyOffs,
                      flyProgress: _flyProgress,
                    ),
                    size: canvasSize,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          _buildControlButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: _engine.canUndo,
            isDark: isDark,
            onTap: _undo,
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint ($_hintsRemaining)',
            enabled: _hintsRemaining > 0,
            isDark: isDark,
            onTap: _useHint,
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            enabled: true,
            isDark: isDark,
            onTap: _reset,
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'REMAINING',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${_engine.activeCount}',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: enabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.87)
                      : Colors.black.withValues(alpha: 0.87))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.black.withValues(alpha: 0.24)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? (isDark ? Colors.white54 : Colors.black38)
                    : (isDark ? Colors.white24 : Colors.black12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinOverlay(bool isDark) {
    final result = _engine.result(Duration(seconds: _elapsedSeconds));
    final stars = result.stars;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'LEVEL COMPLETE!',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_level.themeEmoji} ${_level.name}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color:
                            i < stars ? const Color(0xFFFACC15) : Colors.white24,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Moves: ${_engine.moveCount} / ${_level.maxMoves}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white70
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'Time: ${_formatTime(_elapsedSeconds)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white70
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_currentLevelId > 1) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _loadLevel(_currentLevelId - 1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.24)
                                  : Colors.black.withValues(alpha: 0.24),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Prev',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _loadLevel(_currentLevelId),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.24)
                                : Colors.black.withValues(alpha: 0.24),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextLevel,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _currentLevelId < silhouetteLevels.length
                              ? 'Next'
                              : 'Exit',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
