// lib/presentation/utils/account_linker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

class AccountLinker {
  AccountLinker._();

  static Future<void> linkAccount(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) {
        dialogContext = loadingContext;
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      },
    );

    UpgradeResult? result;
    try {
      result = await ref.read(authServiceProvider).upgradeAnonymousAccount();
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.pop(dialogContext!);
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
      }
    });

    if (result != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBn
                  ? 'অ্যাকাউন্ট সফলভাবে যুক্ত করা হয়েছে!'
                  : isHi
                      ? 'खाता सफलतापूर्वक लिंक किया गया!'
                      : 'Account linked successfully!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      ref.invalidate(authStateProvider);

      if (result.needsOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
          }
        });
      }
    }
  }
}
