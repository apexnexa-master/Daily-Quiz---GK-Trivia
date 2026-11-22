import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/scoring/daily_challenge_service.dart';
import '../../core/services/local_stats_service.dart';
import '../../data/models/gamification_models.dart';
import 'auth_providers.dart';
import 'stats_providers.dart';

int _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value) => value?.toString() ?? '';

class _SampleLeaderboardPlayer {
  final String id;
  final String name;
  final int todayScore;
  final int todayTime;
  final int legacyScore;

  const _SampleLeaderboardPlayer({
    required this.id,
    required this.name,
    required this.todayScore,
    required this.todayTime,
    required this.legacyScore,
  });
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int _boundedSampleScore(int value) => value < 260 ? 260 : (value > 1000 ? 1000 : value);

List<LeaderboardEntryLocal> _sortedLeaderboardEntries(
    List<LeaderboardEntryLocal> entries) {
  final sorted = entries.toList();
  sorted.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.timeTaken.compareTo(b.timeTaken);
  });
  return sorted;
}

List<LeaderboardEntryLocal> _sampleLeaderboardEntries() {
  final today = DailyChallengeService.todayDateString();
  final now = DateTime.now();
  final weekDates = <String>{today};
  for (var offset = 0; offset < now.weekday; offset++) {
    weekDates.add(_dateKey(DateTime(now.year, now.month, now.day - offset)));
  }
  final orderedWeekDates = weekDates.toList()..sort();
  final olderDates = <String>[
    for (var offset = 7; offset <= 28; offset += 7)
      _dateKey(DateTime(now.year, now.month, now.day - offset)),
  ];

  const players = <_SampleLeaderboardPlayer>[
    _SampleLeaderboardPlayer(id: 'demo_aarav', name: 'Aarav S.', todayScore: 920, todayTime: 54, legacyScore: 875),
    _SampleLeaderboardPlayer(id: 'demo_diya', name: 'Diya R.', todayScore: 885, todayTime: 61, legacyScore: 860),
    _SampleLeaderboardPlayer(id: 'demo_rohan', name: 'Rohan M.', todayScore: 850, todayTime: 68, legacyScore: 830),
    _SampleLeaderboardPlayer(id: 'demo_ishita', name: 'Ishita P.', todayScore: 815, todayTime: 74, legacyScore: 810),
    _SampleLeaderboardPlayer(id: 'demo_kabir', name: 'Kabir J.', todayScore: 780, todayTime: 81, legacyScore: 790),
    _SampleLeaderboardPlayer(id: 'demo_meera', name: 'Meera N.', todayScore: 745, todayTime: 88, legacyScore: 765),
    _SampleLeaderboardPlayer(id: 'demo_arjun', name: 'Arjun T.', todayScore: 710, todayTime: 95, legacyScore: 735),
    _SampleLeaderboardPlayer(id: 'demo_sneha', name: 'Sneha K.', todayScore: 680, todayTime: 102, legacyScore: 705),
  ];

  final entries = <LeaderboardEntryLocal>[];
  for (var playerIndex = 0; playerIndex < players.length; playerIndex++) {
    final player = players[playerIndex];
    entries.add(LeaderboardEntryLocal(
      playerId: player.id,
      playerName: player.name,
      score: player.todayScore,
      timeTaken: player.todayTime,
      date: today,
      completedChallenges: const ['demo_daily'],
    ));

    final weekEntryCount = orderedWeekDates.length < 5 ? orderedWeekDates.length : 5;
    for (var dayIndex = 0; dayIndex < weekEntryCount; dayIndex++) {
      final date = orderedWeekDates[dayIndex];
      if (date == today) continue;
      entries.add(LeaderboardEntryLocal(
        playerId: player.id,
        playerName: player.name,
        score: _boundedSampleScore(
          player.todayScore - 45 - ((dayIndex * 37 + playerIndex * 19) % 130),
        ),
        timeTaken: player.todayTime + 6 + ((dayIndex * 11 + playerIndex * 7) % 34),
        date: date,
        completedChallenges: const ['demo_daily'],
      ));
    }

    for (var olderIndex = 0; olderIndex < olderDates.length; olderIndex++) {
      entries.add(LeaderboardEntryLocal(
        playerId: player.id,
        playerName: player.name,
        score: _boundedSampleScore(
          player.legacyScore - ((olderIndex * 29 + playerIndex * 23) % 95),
        ),
        timeTaken: player.todayTime + 12 + ((olderIndex * 13 + playerIndex * 5) % 40),
        date: olderDates[olderIndex],
        completedChallenges: const ['demo_daily'],
      ));
    }
  }
  return entries;
}

final localLeaderboardProvider =
    FutureProvider<List<LeaderboardEntryLocal>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final localEntries =
      await ref.watch(localStatsServiceProvider).getLocalLeaderboard();

  if (user == null) return _sortedLeaderboardEntries(localEntries);

  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colLeaderboard)
        .orderBy('score', descending: true)
        .limit(200)
        .get();

    final entries = snap.docs.map((doc) {
      final data = dataAsMap(doc);
      return LeaderboardEntryLocal(
        playerId: _asString(data['uid']).isNotEmpty
            ? _asString(data['uid'])
            : doc.id,
        playerName: _asString(data['display_name']).isNotEmpty
            ? _asString(data['display_name'])
            : 'Player',
        score: _asInt(data['score']),
        timeTaken: _asInt(data['time_taken']),
        date: _asString(data['quiz_date']),
        completedChallenges: (data['completed_challenges'] is List)
            ? List<String>.from(
                (data['completed_challenges'] as List).map(_asString),
              )
            : const [],
      );
    }).toList();

    final seen = <String>{};
    for (final entry in entries) {
      seen.add('${entry.playerId}|${entry.date}');
    }
    for (final local in localEntries) {
      final key = '${local.playerId}|${local.date}';
      if (!seen.contains(key)) {
        entries.add(local);
        seen.add(key);
      }
    }

    return _sortedLeaderboardEntries(entries);
  } catch (_) {
    return _sortedLeaderboardEntries(localEntries);
  }
});

Map<String, dynamic> dataAsMap(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  if (data == null) return {};
  return Map<String, dynamic>.from(data);
}

final displayLeaderboardProvider =
    FutureProvider<List<LeaderboardEntryLocal>>((ref) async {
  final realEntries = await ref.watch(localLeaderboardProvider.future);
  final entries = <LeaderboardEntryLocal>[
    ..._sampleLeaderboardEntries(),
    ...realEntries,
  ];
  return _sortedLeaderboardEntries(entries);
});

final battleSessionProvider = StateProvider<BattleSessionModel?>((ref) => null);

final isInBattleProvider = Provider<bool>((ref) {
  final session = ref.watch(battleSessionProvider);
  return session != null && session.isInProgress;
});
