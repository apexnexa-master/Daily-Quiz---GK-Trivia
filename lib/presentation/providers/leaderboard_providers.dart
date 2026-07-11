import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/firestore_models.dart';
import '../../data/models/gamification_models.dart';
import '../../core/services/local_stats_service.dart';
import 'stats_providers.dart';

final localLeaderboardProvider = FutureProvider<List<LeaderboardEntryLocal>>((ref) async {
  return ref.watch(localStatsServiceProvider).getLocalLeaderboard();
});

final battleSessionProvider = StateProvider<BattleSessionModel?>((ref) => null);

final isInBattleProvider = Provider<bool>((ref) {
  final session = ref.watch(battleSessionProvider);
  return session != null && session.isInProgress;
});
