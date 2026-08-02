enum RewardedAdPurpose { hint, undoRefill, coins, dailyChallenge }

abstract class AdService {
  bool get isInterstitialAvailable;
  bool get isRewardedAvailable;

  bool shouldShowInterstitial({
    required int completedLevelCount,
    required int highestLevelCompleted,
    required int lastLevelTimeSeconds,
    required bool adsRemoved,
    required int consecutivePushedBack,
  });

  Future<bool> showInterstitialAd();

  Future<bool> showRewardedAd(RewardedAdPurpose purpose);
}

class NullAdService implements AdService {
  @override
  bool get isInterstitialAvailable => false;

  @override
  bool get isRewardedAvailable => false;

  @override
  bool shouldShowInterstitial({
    int completedLevelCount = 0,
    int highestLevelCompleted = 0,
    int lastLevelTimeSeconds = 0,
    bool adsRemoved = false,
    int consecutivePushedBack = 0,
  }) => false;

  @override
  Future<bool> showInterstitialAd() async => false;

  @override
  Future<bool> showRewardedAd(RewardedAdPurpose purpose) async => false;
}
