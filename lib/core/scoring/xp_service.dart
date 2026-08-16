// lib/core/scoring/xp_service.dart
// XP (engagement) is completely separate from Brain Score (performance).
// XP never decreases, it is awarded from a single central configuration and
// it is protected from farming by (a) diminishing returns for repeated
// practice sessions and (b) a hard daily cap.

import 'dart:math' as math;

import '../services/gamification_service.dart';
import 'scoring_config.dart';
import 'scoring_store.dart';

/// Where a session happens. Determines the base XP a session is worth.
enum SessionMode {
  practice,
  dailyChallenge,
  workoutGame,
  battle,
}

class XpAward {
  final int requested;
  final int granted;
  final bool capped;

  const XpAward({
    required this.requested,
    required this.granted,
    this.capped = false,
  });

  bool get fullyGranted => requested == granted;
}

class XpState {
  final String date; // 'yyyy-MM-dd'
  final int xpToday;
  final Map<String, int> modeCounts;

  const XpState({
    this.date = '',
    this.xpToday = 0,
    this.modeCounts = const {},
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'xpToday': xpToday,
        'modeCounts': modeCounts,
      };

  factory XpState.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['modeCounts'];
    return XpState(
      date: json['date']?.toString() ?? '',
      xpToday: (json['xpToday'] as num?)?.toInt() ?? 0,
      modeCounts: rawCounts is Map
          ? {
              for (final e in rawCounts.entries)
                e.key.toString(): (e.value as num?)?.toInt() ?? 0,
            }
          : const {},
    );
  }
}

class XPService {
  XPService._();
  static final XPService instance = XPService._();

  XpState _cache = const XpState();
  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<XpState> _load() async {
    _cache = XpState.fromJson(
      ScoringStore.instance.readJson(ScoringStore.keyXpState),
    );
    if (_cache.date != _today()) {
      _cache = XpState(date: _today());
      await _save();
    }
    return _cache;
  }

  Future<void> _save() async {
    await ScoringStore.instance.writeJson(
      ScoringStore.keyXpState,
      _cache.toJson(),
    );
  }

  /// Base XP for a mode before multipliers and the cap.
  int xpForMode(SessionMode mode) {
    switch (mode) {
      case SessionMode.practice:
        return ScoringConfig.practiceXp;
      case SessionMode.dailyChallenge:
        return ScoringConfig.dailyChallengeXp;
      case SessionMode.battle:
        return ScoringConfig.battleXp;
      case SessionMode.workoutGame:
        return 0;
    }
  }

  /// Anti-farming multiplier for repeated practice sessions.
  double _practiceMultiplier(int count) {
    if (count < ScoringConfig.practiceFullXpCount) return 1.0;
    if (count <
        ScoringConfig.practiceFullXpCount + ScoringConfig.practiceHalfXpCount) {
      return 0.5;
    }
    return ScoringConfig.practiceDiminishedMultiplier;
  }

  /// XP earned today so far (before any reset).
  Future<int> xpToday() async {
    final state = await _load();
    return state.xpToday;
  }

  /// Remaining daily XP budget.
  Future<int> remainingToday() async {
    final state = await _load();
    return math.max(0, ScoringConfig.dailyXpCap - state.xpToday);
  }

  /// Grants the mode's XP respecting diminishing returns and the daily cap.
  Future<XpAward> award(SessionMode mode) async {
    final base = xpForMode(mode);
    if (base <= 0) return const XpAward(requested: 0, granted: 0);
    final state = await _load();
    final count = state.modeCounts[mode.name] ?? 0;
    final multiplier =
        mode == SessionMode.practice ? _practiceMultiplier(count) : 1.0;
    final computed = (base * multiplier).round();
    return _grant(computed, mode: mode.name);
  }

  /// Awards the completion XP for the daily goal (a separate, meaningful
  /// activity reward that also respects the cap).
  Future<XpAward> awardDailyGoal() async {
    return _grant(ScoringConfig.dailyGoalXp, mode: 'daily_goal');
  }

  /// Awards a finished workout: base + a small performance component + a
  /// perfect-session bonus, all metered through the daily cap.
  Future<XpAward> awardWorkout({
    required int overallScore,
    required int completedCount,
    required int plannedCount,
  }) async {
    var computed = ScoringConfig.workoutXp +
        (overallScore * ScoringConfig.workoutPerformanceXpMultiplier).round();
    if (plannedCount > 0 && completedCount == plannedCount) {
      computed += ScoringConfig.perfectBonusXp;
    }
    return _grant(computed, mode: 'workout');
  }

  Future<XpAward> _grant(int computed, {String? mode}) async {
    final state = await _load();
    final remaining = math.max(0, ScoringConfig.dailyXpCap - state.xpToday);
    if (remaining <= 0) {
      return XpAward(requested: computed, granted: 0, capped: true);
    }
    final granted = math.min(computed, remaining);

    final counts = Map<String, int>.from(state.modeCounts);
    if (mode != null) {
      counts[mode] = (counts[mode] ?? 0) + 1;
    }
    _cache = XpState(
      date: state.date,
      xpToday: state.xpToday + granted,
      modeCounts: counts,
    );
    await _save();

    if (granted > 0) {
      try {
        await GamificationService.instance.addXP(granted);
      } catch (_) {
        // XP bookkeeping already persisted; do not fail the session flow.
      }
    }
    return XpAward(
      requested: computed,
      granted: granted,
      capped: granted < computed,
    );
  }

  /// For tests / debugging: reset the daily state.
  Future<void> resetDaily() async {
    _cache = XpState(date: _today());
    await _save();
  }
}
