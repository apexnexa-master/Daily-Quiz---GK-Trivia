// lib/presentation/widgets/profile/settings_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_manager.dart';
import '../../providers/app_providers.dart';
import '../../screens/bookmarks_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
              // Dark Mode Tile
              _buildThemeDropdownTile(ref),
              _divider(),
              // Language Tile
              _buildLanguageDropdownTile(ref),
              _divider(),
              // Saved Questions Tile
              _buildSavedQuestionsTile(context, ref),
              _divider(),
              // Achievements Option Tile
              _buildAchievementsTile(context),
              _divider(),
              // Rate This App Tile
              _buildRateAppTile(context),
              _divider(),
              // Feedback & Suggestions Tile
              _buildFeedbackTile(context),
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

  Widget _buildSavedQuestionsTile(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 20),
      ),
      title: Text(
        isBn
            ? 'সংরক্ষিত প্রশ্ন'
            : isHi
                ? 'सहेजे गए प्रश्न'
                : 'Saved Questions',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.white30 : Colors.grey.shade400,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookmarksScreen()),
        );
      },
    );
  }

  Widget _buildAchievementsTile(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.xp.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.emoji_events_rounded, color: AppColors.xp, size: 20),
      ),
      title: Text(
        isBn
            ? 'অর্জনসমূহ'
            : isHi
                ? 'उपलब्धियां'
                : 'Achievements',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.white30 : Colors.grey.shade400,
      ),
      onTap: () {
        Navigator.pushNamed(context, '/achievements');
      },
    );
  }

  Widget _buildRateAppTile(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final title = isBn ? 'অ্যাপটি মূল্যায়ন করুন' : isHi ? 'ऐप को रेट करें' : 'Rate This App';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.white30 : Colors.grey.shade400,
      ),
      onTap: () async {
        final url = Uri.parse('https://play.google.com/store/apps/details?id=com.nexasoft.dailyquiz');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final title = isBn ? 'মতামত ও পরামর্শ' : isHi ? 'प्रतिक्रिया और सुझाव' : 'Feedback & Suggestions';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.feedback_rounded, color: isDark ? AppColors.primary : AppColors.primaryDark, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.white30 : Colors.grey.shade400,
      ),
      onTap: () {
        Navigator.pushNamed(context, '/feedback');
      },
    );
  }
}
