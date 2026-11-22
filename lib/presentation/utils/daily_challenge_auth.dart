// lib/presentation/utils/daily_challenge_auth.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';

class DailyChallengeAuth {
  DailyChallengeAuth._();

  /// Returns true when the user may start a daily challenge.
  ///
  /// Play-first guests (Firebase anonymous sessions) are allowed to play so
  /// the core daily loop is never gated behind a login wall. They can link an
  /// account later from the dashboard to back up their progress.
  static bool canStart(WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    return auth.isLoggedIn;
  }

  /// Shows a "login required for daily challenges" dialog.
  /// Navigates to the login screen when the user confirms.
  static Future<void> requireLogin(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBn ? 'লগইন প্রয়োজন' : isHi ? 'लॉगिन आवश्यक' : 'Sign In Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isBn
              ? 'আপনি অতিথি হিসেবে খেলতে পারবেন, তবে স্কোর লিডারবোর্ডে জমা দিতে অ্যাকাউন্ট লিংক করতে হবে।'
              : isHi
                  ? 'आप अतिथि के रूप में खेल सकते हैं, लेकिन स्कोर लीडरबोर्ड में जमा करने के लिए खाता लिंक करना होगा।'
                  : "You can play as a guest, but you'll need to sign in to submit your score to the leaderboard.",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              isBn ? 'বন্ধ করুন' : isHi ? 'बंद करें' : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isBn ? 'লগইন করুন' : isHi ? 'लॉगिन करें' : 'Sign In Now',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogin == true && context.mounted) {
      Navigator.pushNamed(context, '/login');
    }
  }
}
