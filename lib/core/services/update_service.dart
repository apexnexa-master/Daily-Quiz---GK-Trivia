// lib/core/services/update_service.dart
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  /// Checks for available updates from Google Play Store on app start
  Future<void> checkForUpdates() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Handled silently for debug / sideloaded builds where Play Store API is unavailable.
    }
  }

  /// Shows an update dialog prompting the user to update from Play Store
  static void showUpdateDialog(BuildContext context, {String? updateUrl}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Colors.teal, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Update Available!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'A new version of MindSprint is available on the Play Store. Update now to enjoy new features, games, and improvements!',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse(
                updateUrl ?? 'https://play.google.com/store/apps/details?id=${AppConstants.appPackage}',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
