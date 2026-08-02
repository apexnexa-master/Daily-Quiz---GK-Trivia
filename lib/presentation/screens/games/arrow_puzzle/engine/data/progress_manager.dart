import 'achievement_config.dart';

class LevelProgress {
  final int levelId;
  final int stars;
  final int bestMoves;
  final bool perfectClear;
  final int hintsUsed;

  const LevelProgress({
    required this.levelId,
    required this.stars,
    required this.bestMoves,
    this.perfectClear = false,
    this.hintsUsed = 0,
  });
}

class DailyProgress {
  final String dateKey;
  final int stars;
  final int movesUsed;
  final bool perfectClear;
  final bool usedHint;
  final bool completed;
  final bool unlockedViaCoin;

  const DailyProgress({
    required this.dateKey,
    required this.stars,
    required this.movesUsed,
    this.perfectClear = false,
    this.usedHint = false,
    this.completed = true,
    this.unlockedViaCoin = false,
  });
}

int calculateStars(int moves, int targetMoves) {
  if (moves == targetMoves) return 3;
  if (moves <= targetMoves + 2) return 2;
  return 1;
}

class ProgressManager {
  static bool bypassLocks = false;
  int _currentLevelIndex = 1;
  int _walletBalance = 0;
  final Map<int, LevelProgress> _levelProgress = {};
  int _dailyStreak = 0;
  String _lastDailyDateKey = '';
  final Map<String, DailyProgress> _dailyCompletions = {};
  final Set<String> _unlockedAchievements = {};
  int _totalCoinsEarned = 0;
  int _noHintCompletions = 0;
  int _sessionCount = 0;
  String _firstSessionDate = '';
  String _lastSessionDate = '';
  int _totalPlayTimeSeconds = 0;

  ProgressManager();

  int get currentLevelIndex => _currentLevelIndex;
  int get walletBalance => _walletBalance;
  int get dailyStreak => _dailyStreak;
  String get lastDailyDateKey => _lastDailyDateKey;

  int get totalCoinsEarned => _totalCoinsEarned;
  int get noHintCompletions => _noHintCompletions;
  Set<String> get unlockedAchievements => Set.unmodifiable(_unlockedAchievements);
  int get sessionCount => _sessionCount;
  String get firstSessionDate => _firstSessionDate;
  String get lastSessionDate => _lastSessionDate;
  int get totalPlayTimeSeconds => _totalPlayTimeSeconds;

  void recordSession() {
    _sessionCount++;
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_firstSessionDate.isEmpty) {
      _firstSessionDate = dateKey;
    }
    _lastSessionDate = dateKey;
  }

  void addPlayTime(int seconds) {
    _totalPlayTimeSeconds += seconds;
  }

  final Set<String> _ownedItems = {};

  Set<String> get ownedItems => Set.unmodifiable(_ownedItems);

  bool isItemOwned(String itemId) => _ownedItems.contains(itemId);

  void purchaseItem(String itemId) => _ownedItems.add(itemId);

  bool isAchievementUnlocked(String achievementId, int tier) {
    return _unlockedAchievements.contains('${achievementId}_$tier');
  }

  void unlockAchievement(String achievementId, int tier) {
    _unlockedAchievements.add('${achievementId}_$tier');
  }

  List<String> checkAchievements() {
    final newlyUnlocked = <String>[];
    for (final def in kAchievements) {
      final progress = _achievementProgress(def);
      for (int t = 0; t < def.tiers.length; t++) {
        final key = '${def.id}_$t';
        if (!_unlockedAchievements.contains(key) && progress >= def.tiers[t].threshold) {
          _unlockedAchievements.add(key);
          _walletBalance += def.tiers[t].coinReward;
          newlyUnlocked.add(key);
        }
      }
    }
    return newlyUnlocked;
  }

  int _achievementProgress(AchievementDef def) {
    switch (def.id) {
      case 'perfectionist':
        return countThreeStarMaps();
      case 'tactician':
        return _noHintCompletions;
      case 'daily_voyager':
        return _dailyStreak;
      case 'grid_explorer':
        return countLevelsCompleted();
      case 'coin_collector':
        return _totalCoinsEarned;
      default:
        return 0;
    }
  }

  int countThreeStarMaps() {
    int count = 0;
    for (final p in _levelProgress.values) {
      if (p.stars == 3) count++;
    }
    return count;
  }

  void addCoins(int amount) {
    _walletBalance += amount;
    _totalCoinsEarned += amount;
  }

  bool spendCoins(int amount) {
    if (_walletBalance < amount) return false;
    _walletBalance -= amount;
    return true;
  }

  bool isLevelUnlocked(int levelId) {
    if (bypassLocks) return true;
    if (levelId == 1) return true;
    return _levelProgress.containsKey(levelId - 1);
  }

  int? getStarRating(int levelId) {
    return _levelProgress[levelId]?.stars;
  }

  LevelProgress? getProgress(int levelId) {
    return _levelProgress[levelId];
  }

  bool hasPerfectClear(int levelId) {
    return _levelProgress[levelId]?.perfectClear ?? false;
  }

  int getHighestUnlockedLevel() {
    int highest = 1;
    for (final entry in _levelProgress.entries) {
      if (entry.key + 1 > highest) {
        highest = entry.key + 1;
      }
    }
    return highest.clamp(1, _currentLevelIndex);
  }

  void completeLevel({
    required int levelId,
    required int movesUsed,
    required int targetMoves,
    required bool usedUndo,
    required bool usedHint,
    required int coinsEarned,
  }) {
    final newStars = calculateStars(movesUsed, targetMoves);
    final isPerfect = !usedUndo && !usedHint;

    final existing = _levelProgress[levelId];
    final shouldUpdate = existing == null ||
        movesUsed < existing.bestMoves ||
        (isPerfect && !existing.perfectClear) ||
        newStars > existing.stars;

    if (shouldUpdate) {
      _levelProgress[levelId] = LevelProgress(
        levelId: levelId,
        stars: newStars,
        bestMoves: movesUsed,
        perfectClear: isPerfect || (existing?.perfectClear ?? false),
        hintsUsed: usedHint ? 1 : (existing?.hintsUsed ?? 0),
      );
    }

    addCoins(coinsEarned);
    if (!usedHint) {
      _noHintCompletions++;
    }
    if (levelId >= _currentLevelIndex) {
      _currentLevelIndex = levelId + 1;
      if (_currentLevelIndex > 200) _currentLevelIndex = 200;
    }
  }

  bool isDailyCompleted(String dateKey) {
    return _dailyCompletions.containsKey(dateKey);
  }

  DailyProgress? getDailyResult(String dateKey) {
    return _dailyCompletions[dateKey];
  }

  void completeDailyChallenge({
    required String dateKey,
    required int stars,
    required int movesUsed,
    required bool perfectClear,
    required bool usedHint,
    required int coinsEarned,
    bool unlockedViaCoin = false,
  }) {
    _dailyCompletions[dateKey] = DailyProgress(
      dateKey: dateKey,
      stars: stars,
      movesUsed: movesUsed,
      perfectClear: perfectClear,
      usedHint: usedHint,
      unlockedViaCoin: unlockedViaCoin,
    );
    addCoins(coinsEarned);
  }

  void updateDailyStreak(String dateKey, int streak) {
    _dailyStreak = streak;
    _lastDailyDateKey = dateKey;
  }

  void resetDailyStreak() {
    _dailyStreak = 0;
    _lastDailyDateKey = '';
  }

  int countDailyCompletions() {
    return _dailyCompletions.length;
  }

  int countTotalStars() {
    int total = 0;
    for (final p in _levelProgress.values) {
      total += p.stars;
    }
    return total;
  }

  int countPerfectClears() {
    int count = 0;
    for (final p in _levelProgress.values) {
      if (p.perfectClear) count++;
    }
    return count;
  }

  int countLevelsCompleted() {
    return _levelProgress.length;
  }

  void unlockAll() {
    for (int i = 1; i <= 200; i++) {
      if (_levelProgress[i] == null) {
        _levelProgress[i] = LevelProgress(
          levelId: i, stars: 0, bestMoves: 999, perfectClear: false, hintsUsed: 0,
        );
      }
    }
    _currentLevelIndex = 200;
  }

  void resetAll() {
    _currentLevelIndex = 1;
    _walletBalance = 0;
    _levelProgress.clear();
    _dailyStreak = 0;
    _lastDailyDateKey = '';
    _dailyCompletions.clear();
    _unlockedAchievements.clear();
    _totalCoinsEarned = 0;
    _noHintCompletions = 0;
    _sessionCount = 0;
    _firstSessionDate = '';
    _lastSessionDate = '';
    _totalPlayTimeSeconds = 0;
    _ownedItems.clear();
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLevelIndex': _currentLevelIndex,
      'walletBalance': _walletBalance,
      'levelProgress': _levelProgress.map((k, v) => MapEntry(
        k.toString(),
        {
          'stars': v.stars,
          'bestMoves': v.bestMoves,
          'perfectClear': v.perfectClear,
          'hintsUsed': v.hintsUsed,
        },
      )),
      'dailyStreak': _dailyStreak,
      'lastDailyDateKey': _lastDailyDateKey,
      'dailyCompletions': _dailyCompletions.map((k, v) => MapEntry(
        k,
        {
          'stars': v.stars,
          'movesUsed': v.movesUsed,
          'perfectClear': v.perfectClear,
          'usedHint': v.usedHint,
          'unlockedViaCoin': v.unlockedViaCoin,
        },
      )),
      'unlockedAchievements': _unlockedAchievements.toList(),
      'totalCoinsEarned': _totalCoinsEarned,
      'noHintCompletions': _noHintCompletions,
      'sessionCount': _sessionCount,
      'firstSessionDate': _firstSessionDate,
      'lastSessionDate': _lastSessionDate,
      'totalPlayTimeSeconds': _totalPlayTimeSeconds,
      'ownedItems': _ownedItems.toList(),
    };
  }

  factory ProgressManager.fromJson(Map<String, dynamic> json) {
    final mgr = ProgressManager();
    mgr._currentLevelIndex = json['currentLevelIndex'] as int? ?? 1;
    mgr._walletBalance = json['walletBalance'] as int? ?? 0;
    final progressJson = json['levelProgress'] as Map<String, dynamic>? ?? {};
    for (final entry in progressJson.entries) {
      final v = entry.value as Map<String, dynamic>;
      mgr._levelProgress[int.parse(entry.key)] = LevelProgress(
        levelId: int.parse(entry.key),
        stars: v['stars'] as int,
        bestMoves: v['bestMoves'] as int,
        perfectClear: v['perfectClear'] as bool? ?? false,
        hintsUsed: v['hintsUsed'] as int? ?? 0,
      );
    }
    mgr._dailyStreak = json['dailyStreak'] as int? ?? 0;
    mgr._lastDailyDateKey = json['lastDailyDateKey'] as String? ?? '';
    mgr._totalCoinsEarned = json['totalCoinsEarned'] as int? ?? 0;
    mgr._noHintCompletions = json['noHintCompletions'] as int? ?? 0;
    mgr._sessionCount = json['sessionCount'] as int? ?? 0;
    mgr._firstSessionDate = json['firstSessionDate'] as String? ?? '';
    mgr._lastSessionDate = json['lastSessionDate'] as String? ?? '';
    mgr._totalPlayTimeSeconds = json['totalPlayTimeSeconds'] as int? ?? 0;
    final achievements = json['unlockedAchievements'] as List<dynamic>? ?? [];
    for (final a in achievements) {
      mgr._unlockedAchievements.add(a as String);
    }
    final owned = json['ownedItems'] as List<dynamic>? ?? [];
    for (final item in owned) {
      mgr._ownedItems.add(item as String);
    }
    final dailyJson = json['dailyCompletions'] as Map<String, dynamic>? ?? {};
    for (final entry in dailyJson.entries) {
      final v = entry.value as Map<String, dynamic>;
      mgr._dailyCompletions[entry.key] = DailyProgress(
        dateKey: entry.key,
        stars: v['stars'] as int,
        movesUsed: v['movesUsed'] as int,
        perfectClear: v['perfectClear'] as bool? ?? false,
        usedHint: v['usedHint'] as bool? ?? false,
        unlockedViaCoin: v['unlockedViaCoin'] as bool? ?? false,
      );
    }
    return mgr;
  }
}
