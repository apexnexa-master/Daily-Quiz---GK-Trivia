import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/scoring/daily_challenge_service.dart';
import '../../../../core/scoring/game_performance.dart';
import '../../../../core/scoring/progression_service.dart';
import '../../../../core/services/daily_progress_service.dart';
import '../../../../core/services/game_sfx.dart';
import '../../../games/widgets/game_results_panel.dart';
import '../../../games/widgets/game_scaffold.dart';
import '../../../games/widgets/game_top_bar.dart';
import '../../../providers/app_providers.dart';
import 'two_car_engine.dart';
import 'two_car_models.dart';
import 'two_car_painter.dart';

const String _twoCarBestKey = 'two_car_drive_best';

class TwoCarScreen extends ConsumerStatefulWidget {
  final bool isDailyChallenge;
  final int? seed;

  const TwoCarScreen({
    super.key,
    this.isDailyChallenge = false,
    this.seed,
  });

  @override
  ConsumerState<TwoCarScreen> createState() => _TwoCarScreenState();
}

class _TwoCarScreenState extends ConsumerState<TwoCarScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TwoCarEngine _engine;
  final Map<int, int> _pointerLanes = <int, int>{};

  Ticker? _ticker;
  Duration? _lastTick;
  int _best = 0;
  bool _isNewBest = false;
  bool _crashHandled = false;
  bool _blinkHandled = false;
  bool _blinkActive = false;
  bool _blinkOn = false;
  int? _blinkItemId;
  int? _blinkLane;
  TwoCarFailure _blinkFailure = TwoCarFailure.none;

  @override
  void initState() {
    super.initState();
    final dailySeed =
        widget.seed ?? int.tryParse(DailyChallengeService.dateKey());
    _engine = TwoCarEngine(
      seed: widget.isDailyChallenge ? dailySeed : null,
    );
    WidgetsBinding.instance.addObserver(this);
    _loadBest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_ticker?.isActive ?? false) _ticker!.stop();
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _engine.phase == TwoCarPhase.running &&
        !(_ticker?.isActive ?? false)) {
      _lastTick = null;
      _ticker?.start();
    }
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_twoCarBestKey) ?? 0);
  }

  void _start() {
    _pointerLanes.clear();
    _engine.start();
    _lastTick = null;
    _isNewBest = false;
    _crashHandled = false;
    _blinkHandled = false;
    _blinkActive = false;
    _blinkOn = false;
    _blinkItemId = null;
    _blinkLane = null;
    _blinkFailure = TwoCarFailure.none;
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) _ticker!.start();
    GameSfxService.instance.play(GameSfx.tap);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final last = _lastTick;
    _lastTick = elapsed;
    if (_engine.phase != TwoCarPhase.running) return;

    final delta =
        last == null ? 0.0 : (elapsed - last).inMicroseconds / 1000000.0;
    final result = _engine.update(delta);
    if (result.collected) {
      GameSfxService.instance.play(GameSfx.correct);
      HapticFeedback.selectionClick();
    }
    if (result.crashed) {
      _startBlink(
        result.itemId,
        result.lane,
        GameSfx.gameOver,
        TwoCarFailure.obstacle,
      );
    }
    if (result.missed) {
      _startBlink(
        result.itemId,
        result.lane,
        GameSfx.wrong,
        TwoCarFailure.missedCoin,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _startBlink(
    int? itemId,
    int? lane,
    GameSfx sfx,
    TwoCarFailure failure,
  ) async {
    if (_blinkHandled) return;
    _blinkHandled = true;
    _blinkActive = true;
    _blinkItemId = itemId;
    _blinkLane = lane;
    _blinkFailure = failure;
    if (_ticker?.isActive ?? false) _ticker!.stop();
    GameSfxService.instance.play(sfx);
    HapticFeedback.heavyImpact();

    try {
      for (var blink = 0; blink < 2; blink++) {
        if (mounted) setState(() => _blinkOn = true);
        await Future<void>.delayed(const Duration(milliseconds: 130));
        if (mounted) setState(() => _blinkOn = false);
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
    } finally {
      if (mounted) {
        setState(() {
          _blinkActive = false;
          _blinkOn = false;
        });
      }
      await _finish(skipOutcomeFeedback: true);
    }
  }

  Future<void> _finish({bool skipOutcomeFeedback = false}) async {
    if (_crashHandled) return;
    _crashHandled = true;
    if (_ticker?.isActive ?? false) _ticker!.stop();
    if (!skipOutcomeFeedback) {
      GameSfxService.instance.play(GameSfx.gameOver);
      HapticFeedback.heavyImpact();
    }

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getInt(_twoCarBestKey) ?? 0;
    final isNewBest = _engine.score > previous;
    if (isNewBest) {
      await prefs.setInt(_twoCarBestKey, _engine.score);
    }
    if (!mounted) return;
    setState(() {
      _best = isNewBest ? _engine.score : previous;
      _isNewBest = isNewBest;
    });

    if (widget.isDailyChallenge) {
      final input = DualDrivePerformanceInput(
        coins: _engine.coins,
        timeSeconds: _engine.elapsedSeconds,
        missedCoin: _engine.failure == TwoCarFailure.missedCoin,
      );
      unawaited(
        ProgressionService.instance.recordSession(
          SessionRecord(
            gameId: 'dualDrive',
            mode: SessionMode.dailyChallenge,
            gameType: GameType.dualDrive,
            primaryPillar: BrainPillar.reaction,
            performance: input,
            isDailyChallenge: true,
            challengeId:
                DailyChallengeService.challengeIdForGame('dualDrive'),
            durationSeconds: _engine.elapsedSeconds,
          ),
        ),
      );
      try {
        ProviderScope.containerOf(context, listen: false)
            .invalidate(dailyProgressProvider);
      } catch (_) {}
    }
  }

  void _onPointerDown(PointerDownEvent event, double boardWidth) {
    if (_engine.phase != TwoCarPhase.running) return;
    final lane = TwoCarInput.laneForDx(event.localPosition.dx, boardWidth);
    _pointerLanes[event.pointer] = lane;
    _engine.setCarX(
      lane,
      TwoCarInput.laneXForDx(event.localPosition.dx, lane, boardWidth),
    );
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event, double boardWidth) {
    final lane = _pointerLanes[event.pointer];
    if (lane == null || _engine.phase != TwoCarPhase.running) return;
    _engine.setCarX(
      lane,
      TwoCarInput.laneXForDx(event.localPosition.dx, lane, boardWidth),
    );
    setState(() {});
  }

  void _onPointerEnd(int pointer) {
    if (_pointerLanes.remove(pointer) != null && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    String t(String en, String bn, String hi) => lang == 'bn'
        ? bn
        : lang == 'hi'
            ? hi
            : en;

    return GameScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              GameTopBar(
                title: t('DUAL DRIVE', 'ডুয়াল ড্রাইভ', 'डुअल ड्राइव'),
                subtitle: t(
                  'TWO HANDS · ONE ROAD',
                  'দুই হাত · এক রাস্তা',
                  'दो हाथ · एक सड़क',
                ),
                trailing: _buildScoreChip(isDark),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardWidth = constraints.maxWidth > 560.0
                        ? 560.0
                        : constraints.maxWidth;
                    final boardHeight = constraints.maxHeight;
                    final activeLanes = _pointerLanes.values.toSet();
                    final board = Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: TwoCarPainter(
                              snapshot: _engine.snapshot(activeLanes),
                              isDark: isDark,
                              blinkItemId: _blinkItemId,
                              blinkLane: _blinkLane,
                              blinkOn: _blinkOn,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) =>
                                _onPointerDown(event, boardWidth),
                            onPointerMove: (event) =>
                                _onPointerMove(event, boardWidth),
                            onPointerUp: (event) =>
                                _onPointerEnd(event.pointer),
                            onPointerCancel: (event) =>
                                _onPointerEnd(event.pointer),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        if (_blinkActive) _buildBlinkMessage(isDark, t),
                        if (_engine.phase == TwoCarPhase.ready)
                          _buildStartOverlay(isDark, t),
                      ],
                    );

                    return Center(
                      child: SizedBox(
                        width: boardWidth,
                        height: boardHeight,
                        child: board,
                      ),
                    );
                  },
                ),
              ),
              _buildFooter(isDark, t),
            ],
          ),
          if (_engine.phase == TwoCarPhase.gameOver && !_blinkActive)
            _buildResultsPanel(isDark, t),
        ],
      ),
    );
  }

  Widget _buildScoreChip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 5),
          Text(
            '${_engine.score}',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1B2340),
            ),
          ),
        ],
      ),
    );
  }

  String _failureMessage(
    String Function(String, String, String) t,
    TwoCarFailure failure,
  ) {
    if (failure == TwoCarFailure.missedCoin) {
      return t("DON'T MISS THE CIRCLE!", 'বৃত্তটি নিন!', 'वृत्त लें!');
    }
    return t('DODGE THE SQUARE!', 'বর্গ এড়ান!', 'वर्ग से बचें!');
  }

  Widget _buildBlinkMessage(
    bool isDark,
    String Function(String, String, String) t,
  ) {
    final missed = _blinkFailure == TwoCarFailure.missedCoin;
    final message = _failureMessage(t, _blinkFailure);
    return Positioned(
      top: 46,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xCC111827) : const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: missed
                    ? Colors.amber.withValues(alpha: 0.7)
                    : const Color(0xFFD92D4F).withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark ? Colors.white : const Color(0xFF1B2340),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartOverlay(
    bool isDark,
    String Function(String, String, String) t,
  ) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xD90B101B) : const Color(0xDEF8FAFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      size: 38, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 18),
                Text(
                  t('DUAL DRIVE', 'ডুয়াল ড্রাইভ', 'डुअल ड्राइव'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1B2340),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    'Steer both cars at once — one finger for each side.',
                    'একসাথে দুটি গাড়ি চালান — প্রতি পাশের জন্য একটি আঙুল।',
                    'एक साथ दोनों कार चलाएँ — हर तरफ के लिए एक उँगली।',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t('START', 'শুরু', 'शुरू')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF07111D),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    textStyle: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  t(
                    'Collect every circle. Dodge red squares.',
                    'প্রতিটি বৃত্ত সংগ্রহ করুন। লাল বর্গক্ষেত্র এড়িয়ে চলুন।',
                    'हर वृत्त इकट्ठा करें। लाल वर्गों से बचें।',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    bool isDark,
    String Function(String, String, String) t,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded,
              size: 14, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t('Drag in each half', 'প্রতি ভাগে টেনে আনুন',
                  'हर हिस्से में खींचें'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Text(
            '${t('BEST', 'সেরা', 'बेस्ट')} $_best',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel(
    bool isDark,
    String Function(String, String, String) t,
  ) {
    final missedCoin = _engine.failure == TwoCarFailure.missedCoin;
    return GameResultsPanel(
      title: missedCoin
          ? t('MISSED!', 'মিস!', 'चूक गए!')
          : t('CRASH!', 'ধাক্কা!', 'टक्कर!'),
      subtitle: _failureMessage(t, _engine.failure),
      subtitleColor: missedCoin
          ? (isDark ? Colors.amber : const Color(0xFFB45309))
          : (isDark ? const Color(0xFFFF6B81) : const Color(0xFFC62846)),
      pulseSubtitle: true,
      score: _engine.score,
      isNewBest: _isNewBest,
      stars: _engine.stars,
      stats: [
        GameResultStat(
          label: t('COINS', 'কয়েন', 'सिक्के'),
          value: '${_engine.coins}',
          icon: Icons.monetization_on_rounded,
          color: Colors.amber,
        ),
        GameResultStat(
          label: t('TIME', 'সময়', 'समय'),
          value: '${_engine.elapsedSeconds}s',
          icon: Icons.timer_rounded,
          color: const Color(0xFF00E5FF),
        ),
        GameResultStat(
          label: t('BEST', 'সেরা', 'बेस्ट'),
          value: '$_best',
          icon: Icons.emoji_events_rounded,
          color: Colors.amber,
        ),
      ],
      playAgainLabel: t('PLAY AGAIN', 'আবার খেলুন', 'फिर खेलें'),
      exitLabel: t('EXIT', 'প্রস্থান', 'बाहर'),
      onPlayAgain: _start,
      onExit: () => Navigator.of(context).pop(),
    );
  }
}
