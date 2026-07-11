// lib/core/services/gamification/achievements_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/gamification_models.dart';
import 'user_stats_service.dart';
import '../cloud_sync_service.dart';

class AchievementsService {
  AchievementsService._();
  static final AchievementsService instance = AchievementsService._();

  late Box _achievementsBox;

  Future<void> init() async {
    _achievementsBox = await Hive.openBox('achievements');
  }

  static const Map<AchievementType, AchievementModel> achievementDefinitions = {
    AchievementType.firstQuiz: AchievementModel(
      type: AchievementType.firstQuiz,
      titleKey: 'First Quiz',
      descriptionKey: 'Complete your first quiz',
      icon: '🎯',
      xpReward: 50,
      coinReward: 25,
      requiredCount: 1,
    ),
    AchievementType.streak7Days: AchievementModel(
      type: AchievementType.streak7Days,
      titleKey: '7 Day Streak',
      descriptionKey: 'Complete quizzes for 7 consecutive days',
      icon: '🔥',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 7,
    ),
    AchievementType.streak30Days: AchievementModel(
      type: AchievementType.streak30Days,
      titleKey: '30 Day Streak',
      descriptionKey: 'Complete quizzes for 30 consecutive days',
      icon: '⚡',
      xpReward: 500,
      coinReward: 250,
      requiredCount: 30,
    ),
    AchievementType.perfectScore: AchievementModel(
      type: AchievementType.perfectScore,
      titleKey: 'Perfect Score',
      descriptionKey: 'Get 100% on any quiz',
      icon: '💯',
      xpReward: 150,
      coinReward: 75,
      requiredCount: 1,
    ),
    AchievementType.quizMaster: AchievementModel(
      type: AchievementType.quizMaster,
      titleKey: 'Quiz Master',
      descriptionKey: 'Complete 50 quizzes',
      icon: '🏆',
      xpReward: 300,
      coinReward: 150,
      requiredCount: 50,
    ),
    AchievementType.speedDemon: AchievementModel(
      type: AchievementType.speedDemon,
      titleKey: 'Speed Demon',
      descriptionKey: 'Complete a quiz in under 60 seconds',
      icon: '⏱️',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 1,
    ),
    AchievementType.earlyBird: AchievementModel(
      type: AchievementType.earlyBird,
      titleKey: 'Early Bird',
      descriptionKey: 'Take a quiz before 8 AM',
      icon: '🌅',
      xpReward: 75,
      coinReward: 35,
      requiredCount: 1,
    ),
    AchievementType.socialButterfly: AchievementModel(
      type: AchievementType.socialButterfly,
      titleKey: 'Social Butterfly',
      descriptionKey: 'Share your score 5 times',
      icon: '🦋',
      xpReward: 100,
      coinReward: 50,
      requiredCount: 5,
    ),
    AchievementType.referralChampion: AchievementModel(
      type: AchievementType.referralChampion,
      titleKey: 'Referral Champion',
      descriptionKey: 'Refer 5 friends',
      icon: '👥',
      xpReward: 250,
      coinReward: 125,
      requiredCount: 5,
    ),
    AchievementType.explorer: AchievementModel(
      type: AchievementType.explorer,
      titleKey: 'Explorer',
      descriptionKey: 'Try all exam modes',
      icon: '🧭',
      xpReward: 150,
      coinReward: 75,
      requiredCount: 5,
    ),
    AchievementType.level10: AchievementModel(
      type: AchievementType.level10,
      titleKey: 'Rising Star',
      descriptionKey: 'Reach Level 10',
      icon: '⭐',
      xpReward: 200,
      coinReward: 100,
      requiredCount: 10,
    ),
    AchievementType.level25: AchievementModel(
      type: AchievementType.level25,
      titleKey: 'Quiz Pro',
      descriptionKey: 'Reach Level 25',
      icon: '🌟',
      xpReward: 500,
      coinReward: 250,
      requiredCount: 25,
    ),
    AchievementType.level50: AchievementModel(
      type: AchievementType.level50,
      titleKey: 'Quiz Legend',
      descriptionKey: 'Reach Level 50',
      icon: '👑',
      xpReward: 1000,
      coinReward: 500,
      requiredCount: 50,
    ),
  };

  List<AchievementModel> getAllAchievements() {
    final unlocked = _achievementsBox.get('unlocked', defaultValue: <String>[]);
    final progress = _achievementsBox.get('progress', defaultValue: <String, int>{});

    return achievementDefinitions.values.map((def) {
      final isUnlocked = unlocked.contains(def.type.name);
      final current = progress[def.type.name] ?? 0;

      return def.copyWith(
        isUnlocked: isUnlocked,
        currentCount: current,
        unlockedAt: isUnlocked ? DateTime.now() : null,
      );
    }).toList();
  }

  Future<AchievementModel?> unlockAchievement(AchievementType type) async {
    final unlocked = _achievementsBox.get('unlocked', defaultValue: <String>[]);
    if (unlocked.contains(type.name)) return null;

    final def = achievementDefinitions[type];
    if (def == null) return null;

    unlocked.add(type.name);
    await _achievementsBox.put('unlocked', unlocked);

    await UserStatsService.instance.addXP(def.xpReward);
    await UserStatsService.instance.addCoins(def.coinReward);

    await CloudSyncService.instance.onAchievementUnlock(type.name);
    return def.copyWith(isUnlocked: true, unlockedAt: DateTime.now());
  }

  Future<void> updateAchievementProgress(AchievementType type, int count) async {
    final progress = _achievementsBox.get('progress', defaultValue: <String, int>{});
    progress[type.name] = count;
    await _achievementsBox.put('progress', progress);

    final def = achievementDefinitions[type];
    if (def != null && count >= def.requiredCount) {
      await unlockAchievement(type);
    }
  }
}
