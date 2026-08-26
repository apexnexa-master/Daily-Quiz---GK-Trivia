import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/scoring/game_performance.dart';
import '../../../../core/scoring/progression_service.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/daily_progress_service.dart';
import '../../../providers/app_providers.dart';
import '../../../workout/workout_models.dart';
import '../../../workout/workout_progress_banner.dart';
import 'arrow_maze_engine.dart';

const String _saveKey = 'arrow_maze_progress_v5';

class ArrowMazeGameScreen extends ConsumerStatefulWidget {
  const ArrowMazeGameScreen({super.key});

  @override
  ConsumerState<ArrowMazeGameScreen> createState() =>
      _ArrowMazeGameScreenState();
}

class _ArrowMazeGameScreenState extends ConsumerState<ArrowMazeGameScreen>
    with TickerProviderStateMixin {
  static const int _maxHearts = 3;
  static const int _maxHints = 3;

  final GlobalKey _helpButtonKey = GlobalKey();

  Timer? _timer;
  Timer? _hintTimer;
  AnimationController? _entryController;
  late Animation<double> _entryScale;

  ArrowMazeBoard? _board;
  List<MazeArrow> _initialArrows = const [];
  final List<MazeArrow> _undoStack = [];

  bool _loaded = false;
  bool _completed = false;
  int _currentLevelId = 1;
  int _hearts = _maxHearts;
  int _hintsLeft = _maxHints;
  int _hintsUsed = 0;
  int? _hintArrowId;
  int? _shakeArrowId;
  int _shakeToken = 0;
  int _elapsedSeconds = 0;
  bool _timerStarted = false;
  bool _isDailyChallenge = false;
  int _lastCompletionScore = 0;

  int _unlocked = 1;
  final Map<int, int> _stars = {};

  WorkoutStep? _workoutStep;
  int? _preparedLevelId;

  final List<_FlyOut> _flying = [];
  int _flyToken = 0;

  final Set<int> _visibleTrailCells = {};

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  String _t(String en, String bn, String hi) =>
      _isBn ? bn : (_isHi ? hi : en);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entryScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entryController!, curve: Curves.easeOut),
    );
    _loadProgressAndStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final step = args['workoutStep'];
    final prepared = args['preparedLevelId'];
    if (step is WorkoutStep && _workoutStep == null) {
      _workoutStep = step;
      _isDailyChallenge = false;
    }
    if (prepared is int && _preparedLevelId == null) {
      _preparedLevelId = prepared;
    }
    if (_workoutStep == null && args['isDailyChallenge'] == true) {
      _isDailyChallenge = true;
      if (_loaded) _startAt(_pickInitialLevelId());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _entryController?.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndStart() async {
    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
              {};
      final step = args['workoutStep'];
      if (step is WorkoutStep) {
        _workoutStep = step;
        _isDailyChallenge = false;
        final prepared = args['preparedLevelId'];
        if (prepared is int) _preparedLevelId = prepared;
      } else if (args['isDailyChallenge'] == true) {
        _isDailyChallenge = true;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _unlocked = (json['unlocked'] as int?) ?? 1;
        final rawStars = json['stars'];
        if (rawStars is Map) {
          rawStars.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id != null && v is int) _stars[id] = v;
          });
        }
      }
    } catch (_) {}

    if (!mounted) return;
    _startAt(_pickInitialLevelId());
    setState(() => _loaded = true);
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _saveKey,
        jsonEncode({
          'unlocked': _unlocked,
          'stars': _stars.map((k, v) => MapEntry('$k', v)),
        }),
      );
    } catch (_) {}
  }

  int _pickInitialLevelId() {
    if (_workoutStep != null) {
      return _preparedLevelId ??
          Random().nextInt(ArrowMazeGenerator.totalLevels) + 1;
    }
    if (_isDailyChallenge) return _harderDailyLevelId();
    return _unlocked.clamp(1, ArrowMazeGenerator.totalLevels);
  }

  int _harderDailyLevelId() {
    final now = DateTime.now();
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seed = int.tryParse(dateKey) ?? 0;
    return 70 + (seed % 25);
  }

  void _startAt(int levelId) {
    _loadLevel(levelId.clamp(1, ArrowMazeGenerator.totalLevels));
  }

  void _loadLevel(int levelId) {
    final level = ArrowMazeGenerator.generate(levelId);
    _currentLevelId = level.levelId;
    _initialArrows = level.arrows;
    _board = ArrowMazeBoard(level);
    _flying.clear();
    _undoStack.clear();
    _completed = false;
    _hearts = _maxHearts;
    _hintsLeft = _maxHints;
    _hintsUsed = 0;
    _hintArrowId = null;
    _shakeArrowId = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _timer?.cancel();
    _hintTimer?.cancel();
    _visibleTrailCells.clear();
    _entryController?.forward(from: 0);
    if (mounted) setState(() {});
    if (_isDailyChallenge) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRulesDialog();
      });
    }
  }

  void _restartLevel() {
    final level = _board!.level;
    _currentLevelId = level.levelId;
    _board = ArrowMazeBoard(level);
    _flying.clear();
    _undoStack.clear();
    _completed = false;
    _hearts = _maxHearts;
    _hintsLeft = _maxHints;
    _hintsUsed = 0;
    _hintArrowId = null;
    _shakeArrowId = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _timer?.cancel();
    _hintTimer?.cancel();
    _visibleTrailCells.clear();
    _entryController?.forward(from: 0);
    setState(() {});
  }

  void _startTimerIfNeeded() {
    if (_timerStarted) return;
    _timerStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _onArrowTap(MazeArrow arrow) {
    final board = _board;
    if (board == null || _completed || _hearts <= 0) return;
    _startTimerIfNeeded();

    if (board.escape(arrow)) {
      unawaited(HapticFeedback.lightImpact());
      if (_hintArrowId == arrow.id) {
        _hintTimer?.cancel();
        _hintArrowId = null;
      }
      _undoStack.add(arrow);
      _visibleTrailCells.addAll(board.removedCells);
      _flyToken++;
      _flying.add(_FlyOut(arrow: arrow, token: _flyToken));
      setState(() {});
      if (board.solved) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_completed) _onLevelWon();
        });
      }
    } else {
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _hearts--;
        _shakeArrowId = arrow.id;
        _shakeToken++;
      });
      if (_hearts <= 0) {
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _useHint() {
    final board = _board;
    if (board == null || _completed || _hintsLeft <= 0 || _hearts <= 0) return;
    final free = board.freePieces();
    if (free.isEmpty) return;
    final pick = free[Random().nextInt(free.length)];
    _hintsLeft--;
    _hintsUsed++;
    _hintTimer?.cancel();
    setState(() => _hintArrowId = pick.id);
    _hintTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() => _hintArrowId = null);
    });
  }

  void _undoMove() {
    final board = _board;
    if (board == null || _completed || _flying.isNotEmpty) return;
    if (_undoStack.isEmpty) return;
    final arrow = _undoStack.removeLast();
    board.restore(arrow);
    _visibleTrailCells.clear();
    _visibleTrailCells.addAll(board.removedCells);
    if (_hearts < _maxHearts) _hearts++;
    setState(() {});
  }

  void _onLevelWon() {
    final board = _board;
    if (board == null || !mounted) return;
    _completed = true;
    _timer?.cancel();

    final stars = _hearts.clamp(1, _maxHearts);
    final isCampaign = !_isDailyChallenge && _workoutStep == null;
    if (isCampaign) {
      if (_currentLevelId + 1 > _unlocked &&
          _unlocked < ArrowMazeGenerator.totalLevels) {
        _unlocked = _currentLevelId + 1;
      }
      final prev = _stars[_currentLevelId] ?? 0;
      if (stars > prev) _stars[_currentLevelId] = stars;
      _saveProgress();
    }

    final input = ArrowPerformanceInput(
      level: _currentLevelId,
      completed: true,
      timeSeconds: max(_elapsedSeconds, 1),
      movesUsed: board.moveCount,
      targetMoves: _initialArrows.length,
      hintsUsed: _hintsUsed > 0 ? 1 : 0,
    );
    final perf = GamePerformanceService.calculate(input);
    _lastCompletionScore = perf;

    final isOfficialChallenge = _isDailyChallenge && _workoutStep == null;
    if (isOfficialChallenge) {
      final auth = AuthService();
      final user = auth.currentUser;
      final playerName = user?.displayName ?? 'You';
      unawaited(
        ProgressionService.instance.recordSession(
          SessionRecord(
            gameId: 'arrow',
            mode: SessionMode.dailyChallenge,
            gameType: GameType.arrow,
            primaryPillar: BrainPillar.logic,
            performance: input,
            isDailyChallenge: true,
            challengeId: 'arrow_puzzle',
            playerName: playerName,
            durationSeconds: _elapsedSeconds,
          ),
        ),
      );
    } else {
      unawaited(
        ProgressionService.instance.recordSession(
          SessionRecord(
            gameId: 'arrow',
            mode: _workoutStep != null
                ? SessionMode.workoutGame
                : SessionMode.practice,
            gameType: GameType.arrow,
            primaryPillar: BrainPillar.logic,
            performance: input,
          ),
        ),
      );
    }
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    setState(() {});
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _board == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.black26),
        ),
      );
    }

    final board = _board!;
    final outOfHearts = _hearts <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_workoutStep != null)
                  WorkoutProgressBanner(step: _workoutStep!),
                _buildHeader(),
                Expanded(child: _buildBoardArea(board)),
                _buildBottomBar(board),
              ],
            ),
            if (_completed) _buildWinOverlay(board),
            if (outOfHearts) _buildFailedOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
            iconSize: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: (!_isDailyChallenge && _workoutStep == null)
                  ? _showLevelSelector
                  : null,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARROWS',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Colors.black26,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _isDailyChallenge
                                ? _t('Daily Challenge', 'ডেইলি চ্যালেঞ্জ',
                                    'डेली चैलेंज')
                                : _t(
                                    'Level $_currentLevelId',
                                    'লেভেল $_currentLevelId',
                                    'लेवल $_currentLevelId',
                                  ),
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          if (!_isDailyChallenge && _workoutStep == null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Colors.black38,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: List.generate(_maxHearts, (i) {
              final active = i < _hearts;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  active
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: active ? Colors.redAccent : Colors.black12,
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: _helpButtonKey,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.black38,
                  size: 22,
                ),
                if (_hintsLeft > 0 && !_completed)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_hintsLeft',
                        style: GoogleFonts.montserrat(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _useHint,
          ),
        ],
      ),
    );
  }

  Widget _buildBoardArea(ArrowMazeBoard board) {
    final level = board.level;
    final n = max(level.rows, level.cols);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tile = min(
            (constraints.maxWidth - 16) / level.cols,
            (constraints.maxHeight - 16) / level.rows,
          ).clamp(24.0, 60.0);
          final boardW = tile * level.cols;
          final boardH = tile * level.rows;

          final scaleX = constraints.maxWidth / boardW;
          final scaleY = constraints.maxHeight / boardH;
          final initialScale = min(min(scaleX, scaleY), 1.0);

          return Center(
            child: ScaleTransition(
              scale: _entryScale,
              child: InteractiveViewer(
                minScale: initialScale * 0.8,
                maxScale: 3.0,
                child: SizedBox(
                  width: boardW,
                  height: boardH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildGridDots(level, tile),
                      _buildRemovedCellTrail(board, tile),
                      ...board.pieces.map(
                        (a) => _buildArrowWidget(a, tile, n),
                      ),
                      ..._buildFlying(tile, n),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridDots(MazeLevel level, double tile) {
    return CustomPaint(
      size: Size(tile * level.cols, tile * level.rows),
      painter: _GridDotsPainter(
        rows: level.rows,
        cols: level.cols,
        tile: tile,
      ),
    );
  }

  Widget _buildRemovedCellTrail(ArrowMazeBoard board, double tile) {
    if (_visibleTrailCells.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      size: Size(tile * board.level.cols, tile * board.level.rows),
      painter: _RemovedCellTrailPainter(
        cells: _visibleTrailCells,
        cols: board.level.cols,
        tile: tile,
      ),
    );
  }

  Widget _buildArrowWidget(MazeArrow arrow, double tile, int n) {
    final isHinted = _hintArrowId == arrow.id;
    final shaking = _shakeArrowId == arrow.id;
    final canMove = _board?.isFree(arrow) ?? false;

    // Compute bounding box of the arrow path
    var minR = 999, maxR = -1, minC = 999, maxC = -1;
    for (final (r, c) in arrow.path) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }

    const pad = 0.5; // half-cell padding for arrowhead overshoot
    final left = (minC - pad) * tile;
    final top = (minR - pad) * tile;
    final width = (maxC - minC + 1 + pad * 2) * tile;
    final height = (maxR - minR + 1 + pad * 2) * tile;

    Widget arrowWidget = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        size: Size(width, height),
        painter: _ArrowPolylinePainter(
          arrow: arrow,
          tile: tile,
          hinted: isHinted,
          canMove: canMove,
          originCol: minC - pad,
          originRow: minR - pad,
        ),
      ),
    );

    if (shaking) {
      arrowWidget = TweenAnimationBuilder<double>(
        key: ValueKey('shake_$_shakeToken'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, v, child) {
          final dx = sin(v * pi * 5) * 5 * (1 - v);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: arrowWidget,
      );
    }

    // Wrap with gesture detector for tap handling.
    // Use a hit test that checks if the tap is within any path cell.
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => _onArrowTap(arrow),
        child: arrowWidget,
      ),
    );
  }

  List<Widget> _buildFlying(double tile, int n) {
    return _flying.map((fly) {
      final distance = n * tile * 1.5;

      // Bounding box for the flying arrow
      var minR = 999, maxR = -1, minC = 999, maxC = -1;
      for (final (r, c) in fly.arrow.path) {
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
      }
      const pad = 0.5;
      final left = (minC - pad) * tile;
      final top = (minR - pad) * tile;
      final width = (maxC - minC + 1 + pad * 2) * tile;
      final height = (maxR - minR + 1 + pad * 2) * tile;

      return Positioned(
        key: ValueKey('fly_${fly.token}'),
        left: left,
        top: top,
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInCubic,
          onEnd: () {
            _flying.removeWhere((f) => f.token == fly.token);
            if (mounted) setState(() {});
          },
          builder: (context, v, child) {
            final d = fly.arrow.fireDir;
            return Opacity(
              opacity: (1 - v * 1.5).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(d.dc * distance * v, d.dr * distance * v),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              size: Size(width, height),
              painter: _ArrowPolylinePainter(
                arrow: fly.arrow,
                tile: tile,
                hinted: false,
                canMove: true,
                originCol: minC - pad,
                originRow: minR - pad,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBottomBar(ArrowMazeBoard board) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isDailyChallenge) ...[
            _buildToolButton(
              icon: Icons.undo_rounded,
              enabled: board.moveCount > 0 &&
                  !_completed &&
                  _flying.isEmpty,
              onTap: _undoMove,
            ),
            const SizedBox(width: 16),
            _buildToolButton(
              icon: Icons.refresh_rounded,
              enabled: true,
              onTap: _restartLevel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled ? Colors.black.withValues(alpha: 0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.black54 : Colors.black12,
        ),
      ),
    );
  }

  Widget _buildWinOverlay(ArrowMazeBoard board) {
    final stars = _hearts.clamp(1, _maxHearts);
    final isPerfect = _hearts >= _maxHearts && _hintsUsed == 0;
    final isCampaign = !_isDailyChallenge && _workoutStep == null;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.black87,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'LEVEL CLEARED!',
                    'লেভেল সম্পন্ন!',
                    'लेवल पूरा!',
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_maxHearts, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: i < stars ? Colors.black87 : Colors.black12,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'Arrows: ${_initialArrows.length}   •   Time: ${_formatTime(_elapsedSeconds)}',
                    'তীর: ${_initialArrows.length}   •   সময়: ${_formatTime(_elapsedSeconds)}',
                    'तीर: ${_initialArrows.length}   •   समय: ${_formatTime(_elapsedSeconds)}',
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black45,
                  ),
                ),
                if (isPerfect) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _t('PERFECT!', 'নিখুঁত!', 'परफेक्ट!'),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_workoutStep != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _lastCompletionScore),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _t('CONTINUE', 'চালিয়ে যান', 'जारी रखें'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (isCampaign) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _restartLevel,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _t('Retry', 'আবার', 'फिर से'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (isCampaign &&
                                _currentLevelId <
                                    ArrowMazeGenerator.totalLevels) {
                              _startAt(_currentLevelId + 1);
                            } else {
                              Navigator.pop(context, _lastCompletionScore);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isCampaign &&
                                    _currentLevelId <
                                        ArrowMazeGenerator.totalLevels
                                ? _t('Next Level', 'পরবর্তী লেভেল',
                                    'अगला लेवल')
                                : _t('Exit', 'বের হন', 'बाहर निकलें'),
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

  Widget _buildFailedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.heart_broken_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _t('OUT OF LIVES', 'লাইভ শেষ', 'लाइव खत्म'),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'You ran out of lives. Revive to continue or exit.',
                    'লাইভ শেষ। চালিয়ে যেতে রিভাইভ করুন বা বেরিয়ে যান।',
                    'लाइव खत्म। जारी रखने के लिए रिवाइव करें या बाहर निकलें।',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          if (_isDailyChallenge) {
                            Navigator.pop(context, _lastCompletionScore);
                          } else {
                            if (!AdService.instance.isRewardedReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _t(
                                      'Ad is loading, please wait...',
                                      'অ্যাড লোড হচ্ছে, অপেক্ষা করুন...',
                                      'ऐड लोड हो रही है, प्रतीक्षा करें...',
                                    ),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              await AdService.instance.loadRewarded();
                              if (!AdService.instance.isRewardedReady) {
                                _revive();
                                return;
                              }
                            }
                            final earned =
                                await AdService.instance.showRewarded();
                            if (earned) _revive();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.black26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isDailyChallenge
                              ? _t('Exit', 'বের হন', 'बाहर निकलें')
                              : _t('Revive', 'রিভাইভ', 'रिवाइव'),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _restartLevel,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _t('Restart', 'রিস্টার্ট', 'रीस्टार्ट'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  void _revive() {
    setState(() {
      _hearts = _maxHearts;
    });
  }

  void _showRulesDialog({VoidCallback? onDismiss}) {
    Offset buttonCenter = const Offset(300, 80);
    final renderBox =
        _helpButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final buttonSize = renderBox.size;
      buttonCenter = Offset(
        buttonPosition.dx + buttonSize.width / 2,
        buttonPosition.dy + buttonSize.height / 2,
      );
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    _t('How to Play', 'কীভাবে খেলবেন', 'कैसे खेलें'),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ruleSection(
                      _t('GOAL:', 'লক্ষ্য:', 'लक्ष्य:'),
                      _t(
                        'Clear every arrow from the board. Tap an arrow and it slides off in the direction it points.',
                        'সব তীর বোর্ড থেকে সরান। তীরে ট্যাপ করলে সে তার দিকে সরে যায়।',
                        'हर तीर को बोर्ड से हटाएँ। तीर पर टैप करें और वह अपनी दिशा में चला जाएगा।',
                      ),
                      Colors.black87,
                    ),
                    const SizedBox(height: 14),
                    _ruleSection(
                      _t('MOVE:', 'চলুন:', 'चलें:'),
                      _t(
                        'Tap an arrow whose path ahead is completely clear. It slides off the board!',
                        'যে তীরের সামনের পথ সম্পূর্ণ ফাঁকা, সেটি ট্যাপ করুন। সে বোর্ড থেকে চলে যাবে!',
                        'जिस तीर के आगे का रास्ता पूरी तरह खाली है, उसे टैप करें। वह बोर्ड से बाहर चला जाएगा!',
                      ),
                      Colors.black54,
                    ),
                    const SizedBox(height: 14),
                    _ruleSection(
                      _t('BLOCKED:', 'আটকে আছে:', 'अवरुद्ध:'),
                      _t(
                        'If another arrow blocks the path, the tap fails and you lose a heart. Plan your moves!',
                        'পথে অন্য তীর থাকলে ট্যাপ ব্যর্থ হবে একটি হার্ট কমবে। পরিকল্পনা করুন!',
                        'रास्ते में कोई और तीर है तो टैप असफल होगा और एक हार्ट कटेगा। योजना बनाएँ!',
                      ),
                      Colors.redAccent,
                    ),
                    const SizedBox(height: 14),
                    _ruleSection(
                      _t('TIPS:', 'টিপস:', 'टिप्स:'),
                      _t(
                        '• Start with arrows near the edges.\n• Removing one arrow can unlock many others.\n• No timer — take your time to think!\n• Use hints or undo when stuck.',
                        '• প্রান্তের তীর দিয়ে শুরু করুন।\n• একটি তীর সরালে অনেক খুলে যেতে পারে।\n• কোনো টাইমার নেই — সময় নিন!\n• আটকে গেলে হিন্ট বা আনডু ব্যবহার করুন।',
                        '• किनारे के तीरों से शुरू करें।\n• एक तीर हटाने से कई खुल सकते हैं।\n• कोई टाइमर नहीं — सोचने के लिए समय लें!\n• फँसे तो हिंट या अनडू लें।',
                      ),
                      Colors.black38,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDismiss?.call();
                  },
                  child: Text(
                    _t('GOT IT', 'বুঝেছি', 'समझ गया'),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: curvedAnimation,
            builder: (context, childWidget) {
              final t = curvedAnimation.value;
              final screenSize = MediaQuery.of(context).size;
              final screenCenter =
                  Offset(screenSize.width / 2, screenSize.height / 2);
              final translation =
                  Offset.lerp(buttonCenter - screenCenter, Offset.zero, t)!;

              return Transform.translate(
                offset: translation,
                child: Transform.scale(
                  scale: t,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: childWidget,
                  ),
                ),
              );
            },
            child: child,
          );
        },
      ),
    );
  }

  Widget _ruleSection(String title, String body, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: color,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.35,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showLevelSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              void goTo(int levelId) {
                Navigator.pop(sheetContext);
                _startAt(levelId);
              }

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('SELECT LEVEL', 'লেভেল নির্বাচন', 'लेवल चुनें'),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: ArrowMazeGenerator.totalLevels,
                      itemBuilder: (context, idx) {
                        final levelId = idx + 1;
                        final isUnlocked = levelId <= _unlocked;
                        final stars = _stars[levelId] ?? 0;

                        return GestureDetector(
                          onTap: () {
                            if (isUnlocked) {
                              goTo(levelId);
                            } else {
                              ScaffoldMessenger.of(sheetContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(_t(
                                      'This level is locked.',
                                      'এই লেভেল লক করা।',
                                      'यह लेवल लॉक है।')),
                                ),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: stars > 0
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : (isUnlocked
                                      ? Colors.white
                                      : Colors.black.withValues(alpha: 0.02)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: stars > 0
                                    ? Colors.black45
                                    : (isUnlocked
                                        ? Colors.black12
                                        : Colors.black.withValues(alpha: 0.05)),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isUnlocked)
                                  Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Colors.black.withValues(alpha: 0.2),
                                  )
                                else
                                  Text(
                                    '$levelId',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: stars > 0
                                          ? Colors.black87
                                          : Colors.black54,
                                    ),
                                  ),
                                if (isUnlocked) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: List.generate(3, (i) {
                                      return Icon(
                                        i < stars
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 11,
                                        color: i < stars
                                            ? Colors.black87
                                            : Colors.black12,
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _FlyOut {
  final MazeArrow arrow;
  final int token;

  const _FlyOut({required this.arrow, required this.token});
}

// ─────────────────────────────────────────────────────────────────────────────
// Polyline Arrow Painter — thin black line connecting path cells + arrowhead
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowPolylinePainter extends CustomPainter {
  final MazeArrow arrow;
  final double tile;
  final bool hinted;
  final bool canMove;
  final double originCol;
  final double originRow;

  _ArrowPolylinePainter({
    required this.arrow,
    required this.tile,
    required this.hinted,
    required this.canMove,
    required this.originCol,
    required this.originRow,
  });

  Offset _cellCenter(int r, int c) {
    return Offset(
      (c - originCol + 0.5) * tile,
      (r - originRow + 0.5) * tile,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (arrow.path.isEmpty) return;

    final color = canMove ? Colors.black87 : Colors.black26;
    final strokeWidth = tile * 0.18;
    final headLen = tile * 0.42;
    final headHalf = tile * 0.28;

    // Draw body segments
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (arrow.path.length > 1) {
      final bodyPath = Path();
      final first = _cellCenter(arrow.path[0].$1, arrow.path[0].$2);
      bodyPath.moveTo(first.dx, first.dy);
      for (var i = 1; i < arrow.path.length; i++) {
        final p = _cellCenter(arrow.path[i].$1, arrow.path[i].$2);
        bodyPath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(bodyPath, bodyPaint);
    }

    // Draw arrowhead at the head cell
    final head = _cellCenter(arrow.head.$1, arrow.head.$2);
    final d = arrow.fireDir;
    final tip = Offset(head.dx + d.dc * headLen, head.dy + d.dr * headLen);

    // Perpendicular direction for the base of the triangle
    final perpDc = d.isHorizontal ? 0.0 : 1.0;
    final perpDr = d.isHorizontal ? 1.0 : 0.0;

    final baseCenter = Offset(
      head.dx - d.dc * headLen * 0.15,
      head.dy - d.dr * headLen * 0.15,
    );

    final baseLeft = Offset(
      baseCenter.dx + perpDc * headHalf,
      baseCenter.dy + perpDr * headHalf,
    );
    final baseRight = Offset(
      baseCenter.dx - perpDc * headHalf,
      baseCenter.dy - perpDr * headHalf,
    );

    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();
    canvas.drawPath(headPath, headPaint);

    // Hint glow
    if (hinted) {
      final glowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(headPath, glowPaint);

      if (arrow.path.length > 1) {
        final glowBody = Path();
        final f = _cellCenter(arrow.path[0].$1, arrow.path[0].$2);
        glowBody.moveTo(f.dx, f.dy);
        for (var i = 1; i < arrow.path.length; i++) {
          final p = _cellCenter(arrow.path[i].$1, arrow.path[i].$2);
          glowBody.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          glowBody,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08)
            ..strokeWidth = strokeWidth + 5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPolylinePainter oldDelegate) =>
      oldDelegate.hinted != hinted || oldDelegate.canMove != canMove;
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid Dots Painter
// ─────────────────────────────────────────────────────────────────────────────

class _GridDotsPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double tile;
  final Color color;

  _GridDotsPainter({
    required this.rows,
    required this.cols,
    required this.tile,
    Color? color,
  }) : color = color ?? const Color(0xFFD8D2C8);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final dotRadius = tile * 0.055;

    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(
          Offset(c * tile, r * tile),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridDotsPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Removed Cell Trail Painter
// ─────────────────────────────────────────────────────────────────────────────

class _RemovedCellTrailPainter extends CustomPainter {
  final Set<int> cells;
  final int cols;
  final double tile;

  _RemovedCellTrailPainter({
    required this.cells,
    required this.cols,
    required this.tile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE0DBD0);
    final dotRadius = tile * 0.055;
    final rng = Random(42);

    for (final key in cells) {
      final r = key ~/ cols;
      final c = key % cols;
      final cx = c * tile + tile / 2;
      final cy = r * tile + tile / 2;

      for (var i = 0; i < 3; i++) {
        final offsetX = (rng.nextDouble() - 0.5) * tile * 0.5;
        final offsetY = (rng.nextDouble() - 0.5) * tile * 0.5;
        canvas.drawCircle(
          Offset(cx + offsetX, cy + offsetY),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RemovedCellTrailPainter oldDelegate) =>
      oldDelegate.cells.length != cells.length;
}
