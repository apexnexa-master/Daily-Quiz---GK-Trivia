import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import 'silhouette_models.dart';
import 'silhouette_engine.dart';
import 'silhouette_levels.dart';
import 'silhouette_painter.dart';

/// Testing helper: when true every level is playable regardless of progress.
/// Flip back to `false` to restore the normal lock/unlock progression.
const bool kUnlockAllLevels = true;

/// Minimum arrow cell size, in logical pixels. Boards that would have to shrink
/// below this to fit the screen instead render larger and overflow the
/// viewport, where the player pans / zooms (InteractiveViewer) to reach the
/// whole picture. Small boards (which fit comfortably) keep their fit size.
const double _minCellSize = 20.0;

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
  bool _isLoading = false;

  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _timerStarted = false;

  bool _showWinOverlay = false;
  int _hintsRemaining = 3;
  int _highestUnlocked = kUnlockAllLevels ? silhouetteLevels.length : 1;
  final Map<int, int> _starsMap = {};
  Timer? _blockedFlashTimer;
  bool _argsRead = false;

  late AnimationController _tickerController;
  late AnimationController _introController;
  final List<FlyOff> _flyOffs = [];
  final Map<String, double> _flyProgress = {};
  final List<AnimationController> _escapeControllers = [];

  final TransformationController _transformController = TransformationController();
  int? _centeredForLevel;

  Map<int, int>? _maskDepths;
  List<double>? _arrowBuildOrder;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // Optionally start on a specific level, e.g. deep links or the debug
    // level picker can pass arguments: {'level': 12}.
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final startLevel = args?['level'];
    if (startLevel is int &&
        startLevel >= 1 &&
        startLevel <= silhouetteLevels.length) {
      _currentLevelId = startLevel;
    }
    _loadProgress();
    _loadLevel(_currentLevelId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blockedFlashTimer?.cancel();
    _tickerController.dispose();
    _introController.dispose();
    _transformController.dispose();
    for (final c in _escapeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadLevel(int levelId, {bool animate = true}) async {
    final idx = levelId - 1;
    if (idx < 0 || idx >= silhouetteLevels.length) return;

    _level = silhouetteLevels[idx];
    _currentLevelId = levelId;

    _timer?.cancel();
    _elapsedSeconds = 0;
    _timerStarted = false;
    _showWinOverlay = false;
    _hintsRemaining = 3;
    _blockedFlashTimer?.cancel();
    _tickerController.stop();
    _introController.stop();
    _flyOffs.clear();
    _flyProgress.clear();

    setState(() {
      _isLoading = true;
      _loaded = false;
    });

    // Yield to the event loop so the loading indicator can render,
    // then generate the puzzle off the main frame.
    await Future.delayed(Duration.zero);

    _engine = SilhouetteEngine(_level);

    // Precompute the intro reveal: a per-cell depth map and a per-arrow draw
    // order so the design "builds itself" from the middle outwards.
    _maskDepths = computeMaskDepths(_level.mask, _level.gridCols);
    _arrowBuildOrder =
        computeArrowBuildOrder(_engine.arrows, _maskDepths!, _level.gridCols);

    setState(() {
      _isLoading = false;
      _loaded = true;
    });

    if (animate) {
      _introController.forward(from: 0);
    } else {
      _introController.value = 1;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  static const _saveKey = 'arrow_silhouette_progress';

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_saveKey);
      if (jsonStr == null || jsonStr.isEmpty) return;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final highest = (data['highest'] as num?)?.toInt() ?? 1;
      if (highest >= 1) _highestUnlocked = highest;
      final stars = (data['stars'] as Map<String, dynamic>?) ?? {};
      stars.forEach((key, value) {
        final id = int.tryParse(key);
        final count = (value as num).toInt();
        if (id != null && count >= 1 && count <= 3) {
          _starsMap[id] = max(_starsMap[id] ?? 0, count);
        }
      });
    } catch (_) {}
    if (kUnlockAllLevels) _highestUnlocked = silhouetteLevels.length;
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _saveKey,
        jsonEncode({
          'highest': _highestUnlocked,
          'stars': _starsMap.map((k, v) => MapEntry('$k', v)),
        }),
      );
    } catch (_) {}
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onTapDown(TapDownDetails details, Size viewport) {
    if (_showWinOverlay) return;
    // Ignore taps until the design has finished drawing itself in.
    if (_introController.value < 1) return;

    final layout = _boardLayout(viewport);
    // The tap arrives in the board's own coordinate space (the CustomPaint is
    // the GestureDetector's child), so the origin is the board's top-left.
    final arrow = _engine.hitTest(
      details.localPosition,
      Offset.zero,
      layout.cell,
    );
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
      _performEscape(arrow, Offset.zero, layout.cell);
    } else {
      _showBlocked(arrow.id);
    }
  }

  void _performEscape(ArrowPiece arrow, Offset origin, double cellSize) {
    HapticFeedback.lightImpact();
    _engine.escapeArrow(arrow);
    _engine.highlightArrow(null);

    final flyOff = FlyOff.forArrow(arrow, origin, cellSize,
        gridRows: _engine.level.gridRows, gridCols: _engine.level.gridCols);
    _flyOffs.add(flyOff);
    _flyProgress[arrow.id] = 0.0;

    setState(() {});

    // Keep the train at a steady speed: longer arrows ride further, so their
    // animation is allowed proportionally more time.
    final rideCells = flyOff.total / cellSize;
    final rideMs = (rideCells * 80).clamp(600.0, 3200.0).round();
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: rideMs),
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

  void _showBlocked(String arrowId) {
    HapticFeedback.mediumImpact();
    final arrow = _engine.arrows.firstWhere((a) => a.id == arrowId);
    _blockedFlashTimer?.cancel();
    _tickerController.repeat();
    setState(() {
      _engine.flashBlocked(arrow); // charges a wasted move, retractable via undo
    });
    _blockedFlashTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(_engine.clearBlockedFlash);
      if (!_engine.arrows.any((a) => a.showHint)) {
        _tickerController.stop();
      }
    });
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
    _saveProgress();
    setState(() => _showWinOverlay = true);
  }

  void _undo() {
    _engine.clearBlockedFlash();
    if (_engine.undo()) setState(() {});
  }

  void _reset() => _loadLevel(_currentLevelId, animate: false);

  void _useHint() {
    if (_hintsRemaining <= 0) return;
    final hint = _engine.showHint();
    if (hint == null) return;
    _tickerController.repeat();
    setState(() => _hintsRemaining--);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => hint.showHint = false);
      if (_engine.blockedFlashId == null) {
        _tickerController.stop();
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_loaded && !_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Generating puzzle...',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'LEVEL $_currentLevelId',
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          _buildStatChip(_formatTime(_elapsedSeconds), isDark),
          const SizedBox(width: 8),
          _buildStatChip('${_engine.moveCount}', isDark, highlight: true),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Levels',
            icon: Icon(Icons.grid_view_rounded,
                color: isDark ? Colors.white70 : Colors.black54, size: 22),
            onPressed: _showLevelPicker,
          ),
        ],
      ),
    );
  }

  Widget _starDots(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final on = i < count;
        return Icon(
          on ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 10,
          color: on ? Colors.amber : Colors.white30,
        );
      }),
    );
  }

  void _showLevelPicker() {
    final current = _currentLevelId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final screenH = MediaQuery.of(sheetContext).size.height;
        return Container(
          height: screenH * 0.72,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVELS',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a puzzle to play',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a level to unlock the next one.',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    itemCount: silhouetteLevels.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 0.82,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (_, index) {
                      final level = silhouetteLevels[index];
                      final locked = level.id > _highestUnlocked;
                      final selected = level.id == current;
                      final stars = _starsMap[level.id] ?? 0;
                      return GestureDetector(
                        onTap: locked
                            ? () {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Finish level ${level.id - 1} to unlock ${level.themeEmoji} ${level.name}.',
                                    ),
                                    duration: const Duration(milliseconds: 1600),
                                  ),
                                );
                              }
                            : () {
                                Navigator.pop(sheetContext);
                                _loadLevel(level.id);
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: locked
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Opacity(
                                              opacity: 0.22,
                                              child: _MaskThumb(
                                                level: level,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.lock_rounded,
                                              color: Colors.white60,
                                              size: 18,
                                            ),
                                          ],
                                        )
                                      : _MaskThumb(
                                          level: level,
                                          color: selected
                                              ? AppColors.primary
                                              : Colors.white,
                                          opacity: selected ? 1.0 : 0.8,
                                        ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${level.id}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: locked
                                        ? Colors.white38
                                        : Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _starDots(stars),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  /// The board's layout for the current level: a cell size (never smaller than
  /// [_minCellSize]) and the resulting pixel size of the whole silhouette.
  ({Size size, double cell}) _boardLayout(Size viewport) {
    final cols = _level.gridCols;
    final rows = _level.gridRows;
    if (cols <= 0 || rows <= 0) {
      return (size: viewport, cell: _minCellSize);
    }
    final fit = min(viewport.width / cols, viewport.height / rows);
    final cell = max(fit, _minCellSize);
    return (size: Size(cols * cell, rows * cell), cell: cell);
  }

  Widget _buildGameCanvas(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = EdgeInsets.symmetric(horizontal: 4, vertical: 4);
        final viewport = Size(
          constraints.maxWidth - margin.horizontal,
          constraints.maxHeight - margin.vertical,
        );
        final layout = _boardLayout(viewport);

        // Centre the freshly-loaded picture on first layout: small boards are
        // placed by Align, oversized ones get a translation so the middle of
        // the design shows instead of its top-left corner.
        if (_centeredForLevel != _currentLevelId) {
          _centeredForLevel = _currentLevelId;
          final tx = layout.size.width > viewport.width
              ? (viewport.width - layout.size.width) / 2
              : 0.0;
          final ty = layout.size.height > viewport.height
              ? (viewport.height - layout.size.height) / 2
              : 0.0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _transformController.value = Matrix4.identity()
              ..setTranslationRaw(tx, ty, 0);
          });
        }

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
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              minScale: 0.3,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(32),
              child: SizedBox(
                width: max(viewport.width, layout.size.width),
                height: max(viewport.height, layout.size.height),
                child: Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTapDown: (d) => _onTapDown(d, viewport),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_tickerController, _introController]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: SilhouettePainter(
                          engine: _engine,
                          animationValue: _tickerController.value,
                          flyOffs: _flyOffs,
                          flyProgress: _flyProgress,
                          introductionValue: _introController.value,
                          maskDepths: _maskDepths,
                          arrowBuildOrder: _arrowBuildOrder,
                          isDark: isDark,
                        ),
                        size: layout.size,
                      );
                    },
                  ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(width: 6),
          _buildControlButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint ($_hintsRemaining)',
            enabled: _hintsRemaining > 0,
            isDark: isDark,
            onTap: _useHint,
          ),
          const SizedBox(width: 6),
          _buildControlButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            enabled: true,
            isDark: isDark,
            onTap: _reset,
          ),
          const Spacer(),
          _buildRemainingChip(isDark),
        ],
      ),
    );
  }

  Widget _buildRemainingChip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_engine.activeCount}',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LEFT',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: enabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.87)
                      : Colors.black.withValues(alpha: 0.87))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.black.withValues(alpha: 0.24)),
            ),
            const SizedBox(width: 4),
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
                  'Moves: ${result.moves} / ${result.maxMoves}  (ideal ${result.idealMoves})',
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

/// Paints a small preview of a level's silhouette mask so the level picker
/// shows the real shape instead of an emoji.
class _MaskThumb extends StatelessWidget {
  const _MaskThumb({
    required this.level,
    required this.color,
    this.opacity = 1.0,
  });

  final SilhouetteLevel level;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MaskThumbPainter(
        mask: level.mask,
        color: color.withValues(alpha: opacity),
      ),
      size: Size.infinite,
    );
  }
}

class _MaskThumbPainter extends CustomPainter {
  _MaskThumbPainter({required this.mask, required this.color});

  final List<List<bool>> mask;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (mask.isEmpty || size.isEmpty) return;
    final rows = mask.length;
    var cols = 0;
    for (final row in mask) {
      if (row.length > cols) cols = row.length;
    }
    if (cols == 0) return;
    final cell = min(size.width / cols, size.height / rows);
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;
    final paint = Paint()..color = color;
    final radius = Radius.circular(cell * 0.24);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < mask[row].length; col++) {
        if (!mask[row][col]) continue;
        final rect = Rect.fromLTWH(
          ox + col * cell,
          oy + row * cell,
          cell + 0.5,
          cell + 0.5,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MaskThumbPainter old) =>
      old.mask != mask || old.color != color;
}