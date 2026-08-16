// lib/core/scoring/activity_service.dart
// Lightweight activity counters for the profile "Activity" section (spec §26).
//
// Kept deliberately small — these are engagement/usage numbers, never used for
// the Brain Score, XP or the leaderboard. Training time is a monotonic counter
// of completed session seconds, not wall-clock app usage.

import 'scoring_store.dart';

class ActivityStats {
  final int gamesPlayed;
  final int workoutsCompleted;
  final int dailyChallengesCompleted;
  final int trainingSeconds;

  const ActivityStats({
    this.gamesPlayed = 0,
    this.workoutsCompleted = 0,
    this.dailyChallengesCompleted = 0,
    this.trainingSeconds = 0,
  });

  String get trainingMinutesLabel {
    final minutes = (trainingSeconds / 60).round();
    if (minutes < 1) return '<1 min';
    return '$minutes min';
  }

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'workoutsCompleted': workoutsCompleted,
        'dailyChallengesCompleted': dailyChallengesCompleted,
        'trainingSeconds': trainingSeconds,
      };

  factory ActivityStats.fromJson(Map<String, dynamic> json) => ActivityStats(
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        workoutsCompleted: (json['workoutsCompleted'] as num?)?.toInt() ?? 0,
        dailyChallengesCompleted:
            (json['dailyChallengesCompleted'] as num?)?.toInt() ?? 0,
        trainingSeconds: (json['trainingSeconds'] as num?)?.toInt() ?? 0,
      );
}

class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  static const String _key = ScoringStore.keyActivityStats;

  Future<ActivityStats> current() async {
    final json = ScoringStore.instance.readJson(_key);
    return ActivityStats.fromJson(json);
  }

  Future<ActivityStats> _update(ActivityStats Function(ActivityStats) mutate) async {
    final stats = await current();
    final next = mutate(stats);
    await ScoringStore.instance.writeJson(_key, next.toJson());
    return next;
  }

  /// One completed (non-workout-component) game session.
  Future<ActivityStats> recordGame({int trainingSeconds = 0}) => _update(
        (s) => ActivityStats(
          gamesPlayed: s.gamesPlayed + 1,
          workoutsCompleted: s.workoutsCompleted,
          dailyChallengesCompleted: s.dailyChallengesCompleted,
          trainingSeconds: s.trainingSeconds + trainingSeconds,
        ),
      );

  /// One official daily challenge completion (first attempt only).
  Future<ActivityStats> recordDailyChallenge({int trainingSeconds = 0}) =>
      _update(
        (s) => ActivityStats(
          gamesPlayed: s.gamesPlayed + 1,
          workoutsCompleted: s.workoutsCompleted,
          dailyChallengesCompleted: s.dailyChallengesCompleted + 1,
          trainingSeconds: s.trainingSeconds + trainingSeconds,
        ),
      );

  /// One finished workout session (not its component games).
  Future<ActivityStats> recordWorkout({int trainingSeconds = 0}) => _update(
        (s) => ActivityStats(
          gamesPlayed: s.gamesPlayed,
          workoutsCompleted: s.workoutsCompleted + 1,
          dailyChallengesCompleted: s.dailyChallengesCompleted,
          trainingSeconds: s.trainingSeconds + trainingSeconds,
        ),
      );
}
