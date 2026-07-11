// lib/presentation/providers/stats_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/local_stats_service.dart';
import '../../core/services/question_tracking_service.dart';
import '../../data/models/firestore_models.dart';
import '../../data/models/gamification_models.dart';
import 'quiz_providers.dart';

final localStatsServiceProvider = Provider<LocalStatsService>((ref) => LocalStatsService.instance);
final questionTrackingProvider = Provider<QuestionTrackingService>((ref) => QuestionTrackingService.instance);

final localStreakProvider = FutureProvider<LocalStreakData>((ref) async {
  return ref.watch(localStatsServiceProvider).getStreak();
});

final localPersonalBestProvider = FutureProvider<PersonalBestData>((ref) async {
  return ref.watch(localStatsServiceProvider).getPersonalBest();
});

final totalQuizzesProvider = FutureProvider<int>((ref) async {
  return ref.watch(localStatsServiceProvider).getTotalQuizzes();
});

final totalScoreProvider = FutureProvider<int>((ref) async {
  return ref.watch(localStatsServiceProvider).getTotalScore();
});

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  return ref.watch(questionTrackingProvider).getAchievements();
});

final modeStatsProvider = FutureProvider<Map<String, ModeStats>>((ref) async {
  return ref.watch(questionTrackingProvider).getAllModeStats();
});

final currentModeStatsProvider = FutureProvider<ModeStats>((ref) async {
  final mode = ref.watch(examModeProvider);
  return ref.watch(questionTrackingProvider).getModeStats(mode);
});
