import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/local_stats_service.dart';
import '../../data/models/firestore_models.dart';
import '../../data/models/gamification_models.dart';
import 'stats_providers.dart';
import 'quiz_providers.dart';
import 'auth_providers.dart';

final localLeaderboardProvider = FutureProvider<List<LeaderboardEntryLocal>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  
  if (user != null) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colLeaderboard)
          .orderBy('score', descending: true)
          .limit(200)
          .get();
          
      if (snap.docs.isNotEmpty) {
        final entries = snap.docs.map((doc) {
          final d = doc.data();
          return LeaderboardEntryLocal(
            playerName: d['display_name'] ?? 'Player',
            score: d['score'] ?? 0,
            timeTaken: d['time_taken'] ?? 0,
            date: d['quiz_date'] ?? '',
          );
        }).toList();
        
        final localEntries = await ref.watch(localStatsServiceProvider).getLocalLeaderboard();
        final combined = [...entries];
        for (final local in localEntries) {
          final exists = combined.any((e) => e.playerName == local.playerName && e.date == local.date);
          if (!exists) {
            combined.add(local);
          }
        }
        return combined;
      }
    } catch (_) {
      // Silently fall back to Hive local/mock cache on error (e.g. offline)
    }
  }
  
  return ref.watch(localStatsServiceProvider).getLocalLeaderboard();
});

final battleSessionProvider = StateProvider<BattleSessionModel?>((ref) => null);

final isInBattleProvider = Provider<bool>((ref) {
  final session = ref.watch(battleSessionProvider);
  return session != null && session.isInProgress;
});
