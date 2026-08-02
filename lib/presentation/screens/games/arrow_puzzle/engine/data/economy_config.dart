class EconomyConfig {
  EconomyConfig._();

  static const int levelClearCoins = 10;
  static const int perfectClearBonus = 25;
  static const int dailyChallengeCoins = 100;
  static const int dailyChallengePerfectBonus = 50;
  static const int dailyChallengePerfectBadge = 150;

  static const int hintCostFirst = 50;
  static const int hintCostSecond = 100;
  static const int hintCostSubsequent = 200;

  static const int emergencyUndoCost = 20;
  static const int undoAdRefillUndos = 3;

  static const int premiumThemeCost = 500;
  static const int customSkinBundleCost = 1200;
  static const int dailyChallengeUnlockCost = 30;

  static const int coinBoosterAmount = 1000;
  static const double coinBoosterPrice = 0.49;
  static const int coinVaultAmount = 3000;
  static const double coinVaultPrice = 1.49;
  static const double adRemovalPrice = 0.99;

  static const int interstitialAdInterval = 4;
  static const int interstitialAdMinLevel = 51;
  static const int interstitialAdMinTimeSeconds = 15;
  static const int interstitialAdPushbackLevels = 2;

  static int hintCost(int hintsUsedInLevel) {
    if (hintsUsedInLevel == 0) return hintCostFirst;
    if (hintsUsedInLevel == 1) return hintCostSecond;
    return hintCostSubsequent;
  }
}

class IapProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final int? coinAmount;
  final bool removesAds;

  const IapProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.coinAmount,
    this.removesAds = false,
  });
}

const List<IapProduct> kIapProducts = [
  IapProduct(
    id: 'remove_ads',
    name: 'Remove Ads',
    description: 'Permanently remove all interstitial ads',
    price: 0.99,
    removesAds: true,
  ),
  IapProduct(
    id: 'coin_booster',
    name: '1,000 Coin Booster',
    description: 'Get 1,000 coins instantly',
    price: 0.49,
    coinAmount: 1000,
  ),
  IapProduct(
    id: 'coin_vault',
    name: '3,000 Coin Vault',
    description: 'Get 3,000 coins instantly',
    price: 1.49,
    coinAmount: 3000,
  ),
];

class AdReward {
  final String label;
  final int? coinAmount;
  final int? undoRefill;
  final bool dailyChallengeUnlock;

  const AdReward({
    required this.label,
    this.coinAmount,
    this.undoRefill,
    this.dailyChallengeUnlock = false,
  });
}

const Map<String, AdReward> kAdRewards = {
  'coins': AdReward(label: '+150 Coins', coinAmount: 150),
  'hint': AdReward(label: 'Free Hint'),
  'undo_refill': AdReward(label: '+3 Free Undos', undoRefill: 3),
  'daily_challenge': AdReward(label: 'Unlock Daily Challenge', dailyChallengeUnlock: true),
};
