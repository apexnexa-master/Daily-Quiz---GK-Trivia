class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;

  AnalyticsEvent(this.name, [this.properties = const {}]);
}

abstract class AnalyticsService {
  void trackLevelStart({
    required int levelId,
    required int chapterId,
    required int targetMoves,
    required int gridColumns,
    required int gridRows,
    required int arrowCount,
  });

  void trackMoveMade({
    required int levelId,
    required String arrowId,
    required int moveCount,
    required int remainingArrows,
  });

  void trackBlockedMove({
    required int levelId,
    required String arrowId,
    String? reason,
  });

  void trackLevelComplete({
    required int levelId,
    required int movesUsed,
    required int targetMoves,
    required int stars,
    required bool usedUndo,
    required bool usedHint,
    required bool isPerfectClear,
  });

  void trackDeadEnd({
    required int levelId,
    required int moveCount,
    required int arrowsRemaining,
  });

  void trackHintUsed({
    required int levelId,
    required int hintsUsed,
  });

  void trackUndoUsed({
    required int levelId,
    required bool isPaid,
    required int freeUndosRemaining,
  });

  void trackDailyChallengeStart({
    required int levelId,
    required int dailyStreak,
  });

  void trackDailyChallengeComplete({
    required int levelId,
    required int movesUsed,
    required int stars,
    required bool isPerfectClear,
  });

  void trackAchievementUnlocked({
    required String achievementId,
    required int tier,
    required String achievementName,
  });

  void trackSessionStart({
    required int sessionCount,
    required int totalLevelsCompleted,
    required int totalStars,
  });

  void trackSessionEnd({
    required int sessionDurationSeconds,
    required int levelsPlayedThisSession,
  });
}

class NullAnalyticsService implements AnalyticsService {
  @override
  void trackLevelStart({
    int levelId = 0,
    int chapterId = 0,
    int targetMoves = 0,
    int gridColumns = 0,
    int gridRows = 0,
    int arrowCount = 0,
  }) {}

  @override
  void trackMoveMade({
    int levelId = 0,
    String arrowId = '',
    int moveCount = 0,
    int remainingArrows = 0,
  }) {}

  @override
  void trackBlockedMove({
    int levelId = 0,
    String arrowId = '',
    String? reason,
  }) {}

  @override
  void trackLevelComplete({
    int levelId = 0,
    int movesUsed = 0,
    int targetMoves = 0,
    int stars = 0,
    bool usedUndo = false,
    bool usedHint = false,
    bool isPerfectClear = false,
  }) {}

  @override
  void trackDeadEnd({
    int levelId = 0,
    int moveCount = 0,
    int arrowsRemaining = 0,
  }) {}

  @override
  void trackHintUsed({
    int levelId = 0,
    int hintsUsed = 0,
  }) {}

  @override
  void trackUndoUsed({
    int levelId = 0,
    bool isPaid = false,
    int freeUndosRemaining = 0,
  }) {}

  @override
  void trackDailyChallengeStart({
    int levelId = 0,
    int dailyStreak = 0,
  }) {}

  @override
  void trackDailyChallengeComplete({
    int levelId = 0,
    int movesUsed = 0,
    int stars = 0,
    bool isPerfectClear = false,
  }) {}

  @override
  void trackAchievementUnlocked({
    String achievementId = '',
    int tier = 0,
    String achievementName = '',
  }) {}

  @override
  void trackSessionStart({
    int sessionCount = 0,
    int totalLevelsCompleted = 0,
    int totalStars = 0,
  }) {}

  @override
  void trackSessionEnd({
    int sessionDurationSeconds = 0,
    int levelsPlayedThisSession = 0,
  }) {}
}
