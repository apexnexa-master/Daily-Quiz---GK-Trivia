// lib/core/scoring/brain_score.dart
// Brain Score: the user's overall demonstrated cognitive performance.
//
// It is the weighted average of the cognitive skill ratings. It moves slowly
// (the skill ratings themselves are gradual), it is only "established" once
// enough sessions across enough skills exist, and weekly/historical data is
// tracked so the app can show trends ("+4 this week") without recomputing
// old values when formulas change.

import 'dart:convert';

import 'package:intl/intl.dart';

import 'scoring_config.dart';
import 'scoring_store.dart';
import 'skill_ratings.dart';

enum BrainScoreStatus { building, established }

/// A single dated snapshot used for history graphs.
class BrainScoreSnapshot {
  final String date; // 'yyyy-MM-dd'
  final int score;

  const BrainScoreSnapshot({required this.date, required this.score});

  Map<String, dynamic> toJson() => {'date': date, 'score': score};

  factory BrainScoreSnapshot.fromJson(Map<String, dynamic> json) =>
      BrainScoreSnapshot(
        date: json['date']?.toString() ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}

class BrainScoreState {
  final int totalSessions;
  final String weekStartDate;
  final int weekStartScore;
  final List<BrainScoreSnapshot> history;
  final int bestChallengeScore;
  final String? bestChallengeDate;
  final String lastSnapshotDate;

  const BrainScoreState({
    this.totalSessions = 0,
    this.weekStartDate = '',
    this.weekStartScore = 0,
    this.history = const [],
    this.bestChallengeScore = 0,
    this.bestChallengeDate,
    this.lastSnapshotDate = '',
  });

  Map<String, dynamic> toJson() => {
        'totalSessions': totalSessions,
        'weekStartDate': weekStartDate,
        'weekStartScore': weekStartScore,
        'history': history.map((h) => h.toJson()).toList(),
        'bestChallengeScore': bestChallengeScore,
        'bestChallengeDate': bestChallengeDate,
        'lastSnapshotDate': lastSnapshotDate,
      };

  factory BrainScoreState.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    return BrainScoreState(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      weekStartDate: json['weekStartDate']?.toString() ?? '',
      weekStartScore: (json['weekStartScore'] as num?)?.toInt() ?? 0,
      history: rawHistory is List
          ? rawHistory
              .whereType<Map>()
              .map((e) => BrainScoreSnapshot.fromJson(
                  e.cast<String, dynamic>()))
              .toList()
          : const [],
      bestChallengeScore: (json['bestChallengeScore'] as num?)?.toInt() ?? 0,
      bestChallengeDate: json['bestChallengeDate'] as String?,
      lastSnapshotDate: json['lastSnapshotDate']?.toString() ?? '',
    );
  }
}

/// Result surfaced to the UI after a session updates the brain score.
class BrainScoreUpdate {
  final BrainScoreState state;
  final SkillRatings ratings;
  final int score;
  final BrainScoreStatus status;
  final int weeklyChange;

  const BrainScoreUpdate({
    required this.state,
    required this.ratings,
    required this.score,
    required this.status,
    required this.weeklyChange,
  });
}

class BrainScoreService {
  BrainScoreService._();
  static final BrainScoreService instance = BrainScoreService._();

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
  static String _weekStartDate() {
    final now = DateTime.now();
    final daysSinceMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysSinceMonday));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  BrainScoreState _state = const BrainScoreState();
  SkillRatings _ratings = const SkillRatings();

  Future<void> _load() async {
    _state = BrainScoreState.fromJson(
      ScoringStore.instance.readJson(ScoringStore.keyBrainState),
    );
    _ratings = SkillRatings.fromJson(
      ScoringStore.instance.readJson(ScoringStore.keySkillRatings),
    );
  }

  /// Weighted average over every skill that has at least one session, with
  /// the configured weights renormalized among represented skills. 0 when
  /// nothing has been rated yet.
  int scoreFrom(SkillRatings ratings) {
    final represented = ScoringConfig.allSkills.where(ratings.hasData).toList();
    if (represented.isEmpty) return 0;
    final weightSum =
        represented.fold<double>(0, (s, k) => s + ScoringConfig.skillWeight(k));
    final weighted = represented.fold<double>(
        0, (s, k) => s + ratings.rating(k) * ScoringConfig.skillWeight(k));
    return (weighted / weightSum).round();
  }

  BrainScoreStatus statusFrom(SkillRatings ratings) {
    if (ratings.totalSessions < ScoringConfig.minSessionsForEstablished) {
      return BrainScoreStatus.building;
    }
    if (ratings.representedSkillCount < ScoringConfig.minSkillsForEstablished) {
      return BrainScoreStatus.building;
    }
    return BrainScoreStatus.established;
  }

  Future<BrainScoreUpdate> recordSession() async {
    await _load();

    final today = _today();
    final weekStart = _weekStartDate();

    // Roll the weekly baseline over when the week changes so the weekly
    // change reflects only this week's movement.
    var weekStartScore = _state.weekStartScore;
    if (_state.weekStartDate != weekStart) {
      weekStartScore = scoreFrom(_ratings);
    }

    var history = List<BrainScoreSnapshot>.from(_state.history);
    final score = scoreFrom(_ratings);
    if (_state.lastSnapshotDate != today) {
      history.add(BrainScoreSnapshot(date: today, score: score));
      if (history.length > ScoringConfig.historySize) {
        history.removeRange(0, history.length - ScoringConfig.historySize);
      }
    }

    final newState = BrainScoreState(
      totalSessions: _state.totalSessions + 1,
      weekStartDate: weekStart,
      weekStartScore: weekStartScore,
      history: history,
      bestChallengeScore: _state.bestChallengeScore,
      bestChallengeDate: _state.bestChallengeDate,
      lastSnapshotDate: today,
    );

    _state = newState;
    await ScoringStore.instance.writeJson(
      ScoringStore.keyBrainState,
      newState.toJson(),
    );

    return BrainScoreUpdate(
      state: newState,
      ratings: _ratings,
      score: score,
      status: statusFrom(_ratings),
      weeklyChange: score - weekStartScore,
    );
  }

  /// Records the best official Daily Challenge score (0-1000). Returns true
  /// when it is a new personal best.
  Future<bool> recordChallengeScore(int score) async {
    await _load();
    if (score <= _state.bestChallengeScore) return false;
    final newState = BrainScoreState(
      totalSessions: _state.totalSessions,
      weekStartDate: _state.weekStartDate,
      weekStartScore: _state.weekStartScore,
      history: _state.history,
      bestChallengeScore: score,
      bestChallengeDate: _today(),
      lastSnapshotDate: _state.lastSnapshotDate,
    );
    _state = newState;
    await ScoringStore.instance.writeJson(
      ScoringStore.keyBrainState,
      newState.toJson(),
    );
    return true;
  }

  Future<BrainScoreUpdate> current() async {
    await _load();
    final score = scoreFrom(_ratings);
    return BrainScoreUpdate(
      state: _state,
      ratings: _ratings,
      score: score,
      status: statusFrom(_ratings),
      weeklyChange: score - _state.weekStartScore,
    );
  }
}

/// JSON helpers used when persisting brain-score history snapshots.
String encodeSnapshots(List<BrainScoreSnapshot> snapshots) =>
    jsonEncode(snapshots.map((s) => s.toJson()).toList());

List<BrainScoreSnapshot> decodeSnapshots(String raw) {
  try {
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map>()
        .map((e) => BrainScoreSnapshot.fromJson(e.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    return const [];
  }
}
