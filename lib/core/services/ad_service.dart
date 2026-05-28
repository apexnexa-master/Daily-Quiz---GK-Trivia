// lib/core/services/ad_service.dart
// PHASE 4: AD INTEGRATION [CRITICAL — Primary Revenue Source]
//
// Ad Strategy:
//  - Banner:       Home screen + Leaderboard (persistent, non-intrusive)
//  - Interstitial: ONCE after result screen (max 3/session)
//  - Rewarded:     "Watch ad to unlock explanation" for free users
//  - Pro users:    Skip ALL ads (is_pro = true)
//
// AdMob best practices:
//  1. Preload interstitial before quiz starts (not after)
//  2. Never show ads during active quiz — hurts UX and retention
//  3. Rewarded video = highest CPM (~₹40-80/1000 views in India)

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _interstitialCountThisSession = 0;
  bool _isPro = false;

  // Call from main.dart after Firebase init
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Preload first interstitial immediately
    await loadInterstitial();
    await loadRewarded();
  }

  void setProStatus(bool isPro) {
    _isPro = isPro;
  }

  // ── Banner Ad ─────────────────────────────────────────────
  // Returns null for pro users — caller must check and hide widget.
  BannerAd? createBanner() {
    if (_isPro) return null;
    return BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  // ── Interstitial Ad ───────────────────────────────────────
  Future<void> loadInterstitial() async {
    if (_isPro) return;
    await InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  // Show interstitial — enforces session frequency cap
  Future<bool> showInterstitial() async {
    if (_isPro) return false;
    if (_interstitialCountThisSession >= AppConstants.maxInterstitialsPerSession) {
      return false;
    }
    if (_interstitialAd == null) {
      await loadInterstitial(); // Try reload
      return false; // Don't wait — show next time
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial(); // Preload next
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
      },
    );

    await _interstitialAd!.show();
    _interstitialCountThisSession++;
    return true;
  }

  // ── Rewarded Ad ───────────────────────────────────────────
  Future<void> loadRewarded() async {
    if (_isPro) return;
    await RewardedAd.load(
      adUnitId: AppConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  // Show rewarded ad — returns true if user earned reward (watched full ad)
  Future<bool> showRewarded() async {
    if (_isPro) return true; // Pro users always get reward without watching ad
    if (_rewardedAd == null) {
      await loadRewarded();
      return false;
    }

    bool rewarded = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (_, __) => rewarded = true,
    );
    return rewarded;
  }

  bool get isRewardedReady => _rewardedAd != null;
  bool get isInterstitialReady => _interstitialAd != null;

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

// ── Banner Widget ─────────────────────────────────────────────
// Drop this anywhere in your widget tree — it handles null safely.
// Usage: BannerAdWidget()
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _bannerAd = AdService.instance.createBanner();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
