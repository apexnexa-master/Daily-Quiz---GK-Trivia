// lib/presentation/screens/games/arrow_escape_game_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'arrow_puzzle/bloc/game_bloc.dart';
import 'arrow_puzzle/engine/data/campaign_data.dart';
import 'arrow_puzzle/engine/data/daily_challenge_manager.dart';
import 'arrow_puzzle/engine/data/economy_config.dart';
import 'arrow_puzzle/engine/data/progress_manager.dart';
import 'arrow_puzzle/engine/services/analytics_service.dart';
import 'arrow_puzzle/engine/render/game_canvas.dart';
import 'arrow_puzzle/engine/logic/grid_matrix.dart';
import 'arrow_puzzle/engine/logic/game_solver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../../core/services/ad_service.dart';

const String _saveKey = 'progress_save';

class ArrowEscapeGameScreen extends StatefulWidget {
  const ArrowEscapeGameScreen({super.key});

  @override
  State<ArrowEscapeGameScreen> createState() => _ArrowEscapeGameScreenState();
}

class _ArrowEscapeGameScreenState extends State<ArrowEscapeGameScreen> {
  late final GameCanvas _game;
  late final GameBloc _bloc;
  final AnalyticsService _analytics = NullAnalyticsService();
  late ProgressManager _progress;
  final CampaignCatalog _catalog = CampaignCatalog.createFullCatalog();

  bool _loaded = false;
  int _currentLevelId = 1;
  bool _showWinOverlay = false;
  bool _showDeadEndOverlay = false;
  bool _showFailedOverlay = false;
  bool _isDailyChallenge = false;

  double _initialScale = 1.0;
  Offset _initialPan = Offset.zero;
  Offset _focalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _bloc = GameBloc(analytics: _analytics);
    _game = GameCanvas()..bindBloc(_bloc);
    _game.gameCamera.allowOverflow = true;
    _progress = ProgressManager();

    _bloc.stream.listen((state) {
      if (!mounted) return;
      if (state.status == GameStatus.won) {
        setState(() => _showWinOverlay = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _onLevelWon();
        });
      } else if (state.status == GameStatus.deadEnd) {
        setState(() => _showDeadEndOverlay = true);
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
    if (isDaily != _isDailyChallenge) {
      _isDailyChallenge = isDaily;
      if (_loaded) {
        _loadInitialChallenge();
      }
    }
  }

  void _loadInitialChallenge() {
    if (_isDailyChallenge) {
      _currentLevelId = getHarderDailyLevelId();
    } else {
      _currentLevelId = _progress.getHighestUnlockedLevel();
      if (_currentLevelId > 100) _currentLevelId = 1;
    }
    _loadLevel(_currentLevelId);
  }

  int getHarderDailyLevelId() {
    final now = DateTime.now().toUtc();
    final dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seed = int.tryParse(dateKey) ?? 0;
    // Map the seed to a hard level between level 70 and 95 (25 levels range)
    return 70 + (seed % 25);
  }

  Future<void> _loadProgressAndStart() async {
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
    ProgressManager.bypassLocks = true; // Make navigation flexible for training
    _progress.recordSession();
    _bloc.startSession();
    _loaded = true;
    _loadInitialChallenge();
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
    final levelDef = _catalog.getLevel(_currentLevelId);
    final totalLevels = _catalog.totalLevels;

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
                  // Glassmorphic Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
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
                                              ? 'Daily Hard Mode'
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
                        StreamBuilder<GameState>(
                          initialData: _bloc.state,
                          stream: _bloc.stream,
                          builder: (context, snapshot) {
                            final s = snapshot.data!;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(3, (idx) {
                                final active = idx < s.lives;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Icon(
                                    active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: active ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black26),
                                    size: 20,
                                  ),
                                );
                              }),
                            );
                          },
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
                            const Spacer(),

                            // Undo
                            _buildActionButton(
                              icon: Icons.undo_rounded,
                              label: 'Undo',
                              enabled: canUndo,
                              isDark: isDark,
                              onTap: _requestUndo,
                            ),
                            const SizedBox(width: 10),

                            // Hint
                            _buildActionButton(
                              icon: Icons.lightbulb_outline_rounded,
                              label: 'Hint',
                              enabled: true,
                              isDark: isDark,
                              onTap: _requestHint,
                            ),
                            const SizedBox(width: 10),

                            // Reset
                            _buildActionButton(
                              icon: Icons.refresh_rounded,
                              label: 'Reset',
                              enabled: true,
                              isDark: isDark,
                              onTap: () {
                                _bloc.add(ResetLevelEvent());
                              },
                            ),
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
                Row(
                  children: [
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
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentLevelId < _catalog.totalLevels) {
                            _loadLevel(_currentLevelId + 1);
                          } else {
                            Navigator.pop(context);
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
                          _currentLevelId < _catalog.totalLevels ? 'Next Level' : 'Exit',
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
                          setState(() {
                            _showDeadEndOverlay = false;
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
                  'You ran out of lives. Revive to continue or restart.',
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
                          if (!AdService.instance.isRewardedReady) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ad is loading, please wait...'), duration: Duration(seconds: 1)),
                            );
                            await AdService.instance.loadRewarded();
                            if (!AdService.instance.isRewardedReady) {
                              // Fallback if ad cannot load (e.g. offline)
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
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Revive', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _bloc.add(ResetLevelEvent());
                          setState(() {
                            _showFailedOverlay = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Restart', style: TextStyle(color: Colors.white)),
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
