// lib/presentation/widgets/profile/settings_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_manager.dart';
import '../../providers/app_providers.dart';

class SettingsSection extends ConsumerWidget {
  final String lang;
  final AppThemeMode themeMode;
  final bool isDark;

  const SettingsSection({
    super.key,
    required this.lang,
    required this.themeMode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final soundSettings = ref.watch(soundSettingsProvider);

    final title = isBn
        ? 'সেটিংস'
        : isHi
            ? 'सेटिंग्स'
            : 'Settings';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(title),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey)
                    .withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Sound Tile
              _buildSwitchTile(
                icon: Icons.volume_up_rounded,
                iconColor: AppColors.primary,
                label: isBn
                    ? 'শব্দ ও ফিডব্যাক'
                    : isHi
                        ? 'ध्वनि और फीडबैक'
                        : 'Sound & Feedback',
                value: soundSettings.soundEnabled,
                onChanged: (val) {
                  ref.read(soundSettingsProvider.notifier).setSoundEnabled(val);
                },
              ),
              _divider(),
              // Dark Mode Tile
              _buildThemeDropdownTile(ref),
              _divider(),
              // Language Tile
              _buildLanguageDropdownTile(ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Row(
      children: [
        const Icon(AppIcons.settings, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildThemeDropdownTile(WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.dark_mode_rounded, color: AppColors.secondary, size: 20),
      ),
      title: Text(
        isBn
            ? 'থিম'
            : isHi
                ? 'थीम'
                : 'Theme',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: DropdownButton<AppThemeMode>(
        value: themeMode,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        onChanged: (mode) {
          if (mode != null) {
            ref.read(themeModeProvider.notifier).setThemeMode(mode);
          }
        },
        items: [
          DropdownMenuItem(
            value: AppThemeMode.light,
            child: Text(isBn ? 'লাইট' : 'Light'),
          ),
          DropdownMenuItem(
            value: AppThemeMode.dark,
            child: Text(isBn ? 'ডার্ক' : 'Dark'),
          ),
          DropdownMenuItem(
            value: AppThemeMode.system,
            child: Text(isBn ? 'সিস্টেম' : 'System'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdownTile(WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.language_rounded, color: AppColors.accent, size: 20),
      ),
      title: Text(
        isBn
            ? 'ভাষা'
            : isHi
                ? 'भाषा'
                : 'Language',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: DropdownButton<String>(
        value: lang,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        onChanged: (val) {
          if (val != null) {
            ref.read(languageProvider.notifier).setLanguage(val);
          }
        },
        items: const [
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
          DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      height: 1,
      indent: 56,
    );
  }
}
