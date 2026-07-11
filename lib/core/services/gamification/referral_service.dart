// lib/core/services/gamification/referral_service.dart
import 'package:uuid/uuid.dart';
import 'user_stats_service.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  Future<void> init() async {}

  String generateReferralCode() {
    final uuid = const Uuid();
    final random = uuid.v4().replaceAll('-', '').toUpperCase();
    return 'GKQ${random.substring(0, 6)}';
  }

  Future<bool> applyReferralCode(String code) async {
    if (code.isEmpty || code.length < 4) return false;

    final statsService = UserStatsService.instance;
    final stats = await statsService.getUserStats();
    final updated = stats.copyWith(
      referralCount: stats.referralCount + 1,
      coins: stats.coins + 50,
      xp: stats.xp + 100,
    );
    await statsService.saveUserStats(updated);
    return true;
  }
}
