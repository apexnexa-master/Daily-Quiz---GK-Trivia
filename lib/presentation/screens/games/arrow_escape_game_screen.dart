import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'arrow_puzzle/bloc/game_bloc.dart';
import 'arrow_puzzle/engine/data/campaign_data.dart';
import 'arrow_puzzle/engine/data/progress_manager.dart';
import 'arrow_puzzle/engine/services/analytics_service.dart';
import 'arrow_puzzle/engine/render/game_canvas.dart';
import 'arrow_puzzle/engine/logic/game_solver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/local_stats_service.dart';
import '../../../../core/services/quiz_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/daily_progress_service.dart';
import '../../providers/app_providers.dart';
import '../../workout/workout_models.dart';
import '../../workout/workout_progress_banner.dart';

const String _saveKey = 'progress_save';

class ArrowEscapeGameScreen extends StatefulWidget {
  const ArrowEscapeGameScreen({super.key});

  @override
  State<ArrowEscapeGameScreen> createState() => _ArrowEscapeGameScreenState();
}

class _ArrowEscapeGameScreenState extends State<ArrowEscapeGameScreen> with TickerProviderStateMixin {
  late final GameCanvas _game;
  late final GameBloc _bloc;
  final AnalyticsService _analytics = NullAnalyticsService();
  late ProgressManager _progress;
  final CampaignCatalog _catalog = CampaignCatalog.createFullCatalog();

  AnimationController? _rulesBlinkController;
  late Animation<double> _rulesAnimation;
  final GlobalKey _helpButtonKey = GlobalKey();

  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _timerStarted = false;

  bool _loaded = false;
  int _currentLevelId = 1;
  bool _showWinOverlay = false;
  bool _showDeadEndOverlay = false;
  bool _showFailedOverlay = false;
  bool _isDailyChallenge = false;

  WorkoutStep? _workoutStep;
  int? _preparedLevelId;
  int _lastCompletionScore = 0;

  double _initialScale = 1.0;
  Offset _initialPan = Offset.zero;
  Offset _focalPoint = Offset.zero;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final state = _bloc.state;
      if (state.status == GameStatus.playing) {
        setState(() {
          _elapsedSeconds++;
        });
      } else if (state.status == GameStatus.won || state.status == GameStatus.failed) {
        _timer?.cancel();
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _bloc = GameBloc(analytics: _analytics);
    _game = GameCanvas()..bindBloc(_bloc);
    _game.gameCamera.allowOverflow = true;
    _progress = ProgressManager();

    _rulesBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rulesAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _rulesBlinkController!, curve: Curves.easeInOut),
    );

    _bloc.stream.listen((state) {
      if (!mounted) return;

      if (state.lastTappedArrowId != null && !_timerStarted) {
        _timerStarted = true;
        _startTimer();
      }

      if (state.status == GameStatus.won) {
        setState(() => _showWinOverlay = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _onLevelWon();
        });
      } else if (state.status == GameStatus.deadEnd) {
        if (_isDailyChallenge) {
          setState(() => _showFailedOverlay = true);
        } else {
          setState(() => _showDeadEndOverlay = true);
        }
      } else if (state.status == GameStatus.failed) {
        setState(() => _showFailedOverlay = true);
      } else {
        if (_showDeadEndOverlay) {
          setState(() => _showDeadEndOverlay = false);
        }
        if (_showFailedOverlay) {
          setState(() => _showFailedOverlay = false);
        }
        if (state.lastTappedArrowId != null && !state.lastMoveValid) {
          // Trigger the rules button blinking!
          _rulesBlinkController?.forward().then((_) {
            _rulesBlinkController?.reverse().then((_) {
              _rulesBlinkController?.forward().then((_) {
                _rulesBlinkController?.reverse();
              });
            });
          });

          final parsed = state.parsedLevel;
          if (parsed != null) {
            try {
              final arrow = parsed.arrowEntities.firstWhere((a) => a.id == state.lastTappedArrowId);
              if (GameSolver.isCoveredByHigherLayer(parsed.logicalGrid, arrow)) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Blocked: This arrow is covered by an arrow above it!'),
                    duration: Duration(milliseconds: 1500),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Blocked: Clear the path in front of this arrow first!'),
                    duration: Duration(milliseconds: 1500),
                  ),
                );
              }
            } catch (_) {}
          }
        }
      }
    });

    _loadProgressAndStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final isDaily = args['isDailyChallenge'] == true;
    final step = args['workoutStep'];
    final prepared = args['preparedLevelId'];
    if (step is WorkoutStep && _workoutStep == null) {
      _workoutStep = step;
      _isDailyChallenge = false;
    }
    if (prepared is int && _preparedLevelId == null) {
      _preparedLevelId = prepared;
    }
    // The workout route also passes `isDailyChallenge: true`, but a workout is
    // never a daily challenge — don't let it flip the mode once it is set.
    if (_workoutStep == null && isDaily != _isDailyChallenge) {
      _isDailyChallenge = isDaily;
      if (_loaded) {
        _loadInitialChallenge();
      }
    }
  }

  void _loadInitialChallenge() {
    _currentLevelId = _pickInitialLevelId();
    _prepareLevel(_currentLevelId);
  }

  int _pickInitialLevelId() {
    if (_workoutStep != null) {
      return _preparedLevelId ?? Random().nextInt(_catalog.totalLevels) + 1;
    }
    if (_isDailyChallenge) {
      return getHarderDailyLevelId();
    }
    final unlocked = _progress.getHighestUnlockedLevel();
    return unlocked > 100 ? 1 : unlocked;
  }

  /// Generates the level on a background isolate (never blocks the UI thread)
  /// and loads it into the game once ready.
  Future<void> _prepareLevel(int levelId) async {
    final levelDef = await CampaignCatalog.generateInBackground(levelId);
    if (!mounted || levelDef == null) return;
    _loadLevel(levelDef.levelId);
  }

  void _showRulesDialog({VoidCallback? onDismiss}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Offset buttonCenter = const Offset(300, 80);
    final renderBox = _helpButtonKey.currentContext?.findRenderObject() as RenderBox?;
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
        barrierColor: Colors.black.withValues(alpha: 0.7),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              title: Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'How to Play',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOAL:',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Swipe or tap arrows to slide them off the grid. Arrows can only move in the direction they are pointing.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CAN BE MOVED:',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.green,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            'Arrows with an empty, clear path in front of them.',
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            'Arrows at the top layer (brighter lines, casting longer shadows).',
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CANNOT BE MOVED (BLOCKED):',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.redAccent,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✗ ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            'Path Blocked: Another arrow is sitting directly on the path in front of it.',
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✗ ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            'Covered (3D Stacking): Another arrow on a higher layer is crossing directly over its body. You must clear the top, brighter arrow first!',
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TIPS:',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.amber,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Look at shadows & brightness: Clear the brightest, topmost layer first.\n'
                      '• Use the Reset button if you get stuck.\n'
                      '• Tap a blocked arrow to see a helpful message explaining what is blocking it.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
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
                    'GOT IT',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
              final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
              final translation = Offset.lerp(buttonCenter - screenCenter, Offset.zero, t)!;

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

  int getHarderDailyLevelId() {
    final now = DateTime.now();
    final dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seed = int.tryParse(dateKey) ?? 0;
    // Map the seed to a hard level between level 70 and 95 (25 levels range)
    return 70 + (seed % 25);
  }

  Future<void> _loadProgressAndStart() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
      final isDaily = args['isDailyChallenge'] == true;
      final step = args['workoutStep'];
      final prepared = args['preparedLevelId'];
      if (step is WorkoutStep) {
        _workoutStep = step;
        _isDailyChallenge = false;
        if (prepared is int) _preparedLevelId = prepared;
      } else if (isDaily) {
        _isDailyChallenge = true;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_saveKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _progress = ProgressManager.fromJson(json);
      } catch (_) {
        _progress = ProgressManager();
      }
    }
    _progress.recordSession();
    _bloc.startSession();

    _currentLevelId = _pickInitialLevelId();
    await _prepareLevel(_currentLevelId);
    if (!mounted) return;
    _loaded = true;
    setState(() {});
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(_progress.toJson()));
  }

  void _loadLevel(int levelId) {
    final levelDef = _catalog.getLevel(levelId);
    if (levelDef != null) {
      _currentLevelId = levelId;
      _bloc.loadLevel(levelDef.levelData);
      setState(() {
        _showWinOverlay = false;
        _showDeadEndOverlay = false;
        _showFailedOverlay = false;
      });

      _timer?.cancel();
      _elapsedSeconds = 0;
      _timerStarted = false;
      if (_isDailyChallenge) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showRulesDialog();
        });
      }
    }
  }

  void _onLevelWon() {
    final result = _bloc.getLevelResult();
    if (result == null || !mounted) return;

    _progress.completeLevel(
      levelId: result.levelId,
      movesUsed: result.movesUsed,
      targetMoves: result.targetMoves,
      usedUndo: result.usedUndo,
      usedHint: result.usedHint,
      coinsEarned: result.coinsEarned,
    );
    _saveProgress();

    final basePoints = 100;
    final extraMoves = result.movesUsed > result.targetMoves ? (result.movesUsed - result.targetMoves) : 0;
    final movesPenalty = extraMoves * 2;
    final baseScore = (basePoints - movesPenalty).clamp(20, 100);
    final speedBonus = _elapsedSeconds < 180 ? ((180 - _elapsedSeconds) * 50 ~/ 180) : 0;
    final totalPoints = baseScore + speedBonus;
    _lastCompletionScore = baseScore;

    if (_isDailyChallenge) {
      final auth = AuthService();
      final user = auth.currentUser;
      final playerName = user?.displayName ?? 'You';

      LocalStatsService.instance.addScoreToLeaderboard(playerName, totalPoints, _elapsedSeconds, 'arrow_puzzle');

      if (user != null) {
        QuizService().submitScoreToLeaderboard(
          playerName: playerName,
          score: totalPoints,
          timeTaken: _elapsedSeconds,
          challengeId: 'arrow_puzzle',
        );
      }
    }

    // Track daily goal, streak & brain score (Logic pillar)
    DailyProgressService.instance.recordGameCompletion(
      pillar: BrainPillar.logic,
      scorePct: totalPoints,
      gameType: GameType.arrow,
    );
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    // Show completion popup on overlay instead of replacing route
    setState(() {
      _showWinOverlay = true;
    });
  }

  void _requestUndo() {
    final state = _bloc.state;
    if (state.status == GameStatus.won) return;
    if (!_bloc.canUndo) return;
    _bloc.add(UndoEvent());
  }

  void _requestHint() {
    final state = _bloc.state;
    if (state.status == GameStatus.won) return;
    _bloc.add(UseHintEvent());
  }

  void _showInsufficientCoins() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not enough coins! Solve more levels to earn coins.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rulesBlinkController?.dispose();
    _saveProgress();
    _bloc.endSession();
    _bloc.close();
    super.dispose();
  }

  void _showLevelSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT CHALLENGE',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: 100,
                  itemBuilder: (context, idx) {
                    final levelId = idx + 1;
                    final isUnlocked = levelId <= _progress.getHighestUnlockedLevel() || ProgressManager.bypassLocks;
                    final isCompleted = _progress.getProgress(levelId) != null;

                    return GestureDetector(
                      onTap: () {
                        if (isUnlocked) {
                          Navigator.pop(context);
                          _loadLevel(levelId);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This level is locked.')),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (isUnlocked
                                  ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
                                  : (isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01))),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : (isUnlocked
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : (isDark ? Colors.white10 : Colors.black12)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!isUnlocked)
                                Icon(Icons.lock, size: 16, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3))
                              else
                                Text(
                                  '$levelId',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isCompleted
                                        ? const Color(0xFF10B981)
                                        : (isDark ? Colors.white : Colors.black.withValues(alpha: 0.87)),
                                  ),
                                ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
                  if (_workoutStep != null)
                    WorkoutProgressBanner(step: _workoutStep!),
                  // Glassmorphic Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isDailyChallenge ? null : _showLevelSelector,
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isDailyChallenge ? 'DAILY CHALLENGE' : 'ARROW ESCAPE',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _isDailyChallenge
                                              ? 'Arrow Puzzle 3D'
                                              : 'Challenge $_currentLevelId',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        if (!_isDailyChallenge) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _rulesAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _rulesAnimation.value,
                              child: child,
                            );
                          },
                          child: IconButton(
                            key: _helpButtonKey,
                            icon: Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 20),
                            onPressed: () => _showRulesDialog(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Flame Render Widget
                  Expanded(
                    child: StreamBuilder<GameState>(
                      initialData: _bloc.state,
                      stream: _bloc.stream,
                      builder: (context, snapshot) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: GestureDetector(
                              onTapUp: (details) => _game.handleTap(details.localPosition),
                              onScaleStart: (details) {
                                _initialScale = _game.gameCamera.scale;
                                _initialPan = _game.gameCamera.pan;
                                _focalPoint = details.localFocalPoint;
                              },
                              onScaleUpdate: (details) {
                                final double minScale = 0.2;
                                final double maxScale = 8.0;
                                final double newScale = (_initialScale * details.scale).clamp(minScale, maxScale);

                                final double gx = (_focalPoint.dx - _initialPan.dx) / (_game.gameCamera.tileSize * _initialScale);
                                final double gy = (_focalPoint.dy - _initialPan.dy) / (_game.gameCamera.tileSize * _initialScale);

                                _game.gameCamera.scale = newScale;
                                _game.gameCamera.pan = details.localFocalPoint - Offset(
                                  gx * _game.gameCamera.tileSize * newScale,
                                  gy * _game.gameCamera.tileSize * newScale,
                                );
                              },
                              child: GameWidget(game: _game),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Controls Capsule Panel
                  StreamBuilder<GameState>(
                    initialData: _bloc.state,
                    stream: _bloc.stream,
                    builder: (context, snapshot) {
                      final s = snapshot.data!;
                      final canUndo = _bloc.canUndo;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MOVES',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${s.moveCount}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LIVES',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(3, (idx) {
                                    final active = idx < s.lives;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 3.0),
                                      child: Icon(
                                        active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: active ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black26),
                                        size: 16,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TIME',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _formatTime(_elapsedSeconds),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            if (!_isDailyChallenge) ...[
                              const Spacer(),
                              // Undo
                              _buildActionButton(
                                icon: Icons.undo_rounded,
                                label: 'Undo',
                                enabled: canUndo,
                                isDark: isDark,
                                onTap: _requestUndo,
                              ),
                              const SizedBox(width: 16),
                              // Reset
                              _buildActionButton(
                                icon: Icons.refresh_rounded,
                                label: 'Reset',
                                enabled: true,
                                isDark: isDark,
                                onTap: () {
                                  _bloc.add(ResetLevelEvent());
                                  _timer?.cancel();
                                  setState(() {
                                    _elapsedSeconds = 0;
                                    _timerStarted = false;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Game Win Celebrations Custom Overlay widget
              if (_showWinOverlay) _buildWinCelebrationOverlay(isDark),

              // Dead End Alert Banner
              if (_showDeadEndOverlay) _buildDeadEndBanner(isDark),

              // Failed Out of Lives Panel
              if (_showFailedOverlay) _buildFailedOverlayPanel(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return AnimatedScaleButton(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? (isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black.withValues(alpha: 0.87))
              : (isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.24)),
        ),
      ),
    );
  }

  Widget _buildWinCelebrationOverlay(bool isDark) {
    final result = _bloc.getLevelResult();
    if (result == null) return const SizedBox.shrink();

    final isPerfect = !result.usedUndo && !result.usedHint;

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
                  'CHALLENGE CLEARED!',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Moves Used: ${result.movesUsed} (Target: ${result.targetMoves})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Time Taken: ${_formatTime(_elapsedSeconds)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                if (isPerfect) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F1FE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PERFECT ESCAPE!',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00F1FE),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_workoutStep != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _lastCompletionScore),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (!_isDailyChallenge) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _loadLevel(_currentLevelId);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.24)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (!_isDailyChallenge && _currentLevelId < _catalog.totalLevels) {
                              _loadLevel(_currentLevelId + 1);
                            } else {
                              Navigator.pop(context, _lastCompletionScore);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            (!_isDailyChallenge && _currentLevelId < _catalog.totalLevels) ? 'Next Level' : 'Exit',
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

  Widget _buildDeadEndBanner(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  'DEAD END',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No valid moves remain.\nUndo or reset to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _requestUndo();
                          setState(() {
                            _showDeadEndOverlay = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Undo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                           _bloc.add(ResetLevelEvent());
                           _timer?.cancel();
                           setState(() {
                             _showDeadEndOverlay = false;
                             _elapsedSeconds = 0;
                             _timerStarted = false;
                           });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reset', style: TextStyle(color: Colors.white)),
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

  Widget _buildFailedOverlayPanel(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.heart_broken_rounded, color: Colors.redAccent, size: 52),
                const SizedBox(height: 12),
                Text(
                  'OUT OF LIVES',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDailyChallenge
                      ? 'You ran out of lives. Revive to continue or exit.'
                      : 'You ran out of lives. Revive to continue or restart.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          if (_isDailyChallenge) {
                            Navigator.pop(context, _lastCompletionScore); // Exit
                          } else {
                            if (!AdService.instance.isRewardedReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ad is loading, please wait...'), duration: Duration(seconds: 1)),
                              );
                              await AdService.instance.loadRewarded();
                              if (!AdService.instance.isRewardedReady) {
                                _bloc.add(ReviveEvent());
                                setState(() {
                                  _showFailedOverlay = false;
                                });
                                return;
                              }
                            }
                            final earned = await AdService.instance.showRewarded();
                            if (earned) {
                              _bloc.add(ReviveEvent());
                              setState(() {
                                _showFailedOverlay = false;
                              });
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_isDailyChallenge ? 'Exit' : 'Revive', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_isDailyChallenge) {
                            if (!AdService.instance.isRewardedReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ad is loading, please wait...'), duration: Duration(seconds: 1)),
                              );
                              await AdService.instance.loadRewarded();
                              if (!AdService.instance.isRewardedReady) {
                                _bloc.add(ReviveEvent());
                                setState(() {
                                  _showFailedOverlay = false;
                                });
                                return;
                              }
                            }
                            final earned = await AdService.instance.showRewarded();
                            if (earned) {
                              _bloc.add(ReviveEvent());
                              setState(() {
                                _showFailedOverlay = false;
                              });
                            }
                          } else {
                            _bloc.add(ResetLevelEvent());
                            _timer?.cancel();
                            setState(() {
                              _showFailedOverlay = false;
                              _elapsedSeconds = 0;
                              _timerStarted = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_isDailyChallenge ? 'Revive' : 'Restart', style: const TextStyle(color: Colors.white)),
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
