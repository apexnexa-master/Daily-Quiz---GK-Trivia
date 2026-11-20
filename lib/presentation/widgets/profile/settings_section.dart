// lib/presentation/widgets/profile/settings_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_manager.dart';
import '../../providers/app_providers.dart';
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
              _buildThemeTile(context, ref),
              _divider(),
              // Language Tile
              _buildLanguageTile(context, ref),
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

  Widget _buildThemeTile(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final title = isBn
        ? 'থিম'
        : isHi
            ? 'थीम'
            : 'Theme';
    final value = themeMode == AppThemeMode.light
        ? (isBn ? 'লাইট' : 'Light')
        : themeMode == AppThemeMode.dark
            ? (isBn ? 'ডার্ক' : 'Dark')
            : (isBn ? 'সিস্টেম' : 'System');

    return _buildChoiceTile(
      icon: Icons.dark_mode_rounded,
      color: AppColors.secondary,
      title: title,
      value: value,
      onTap: () => _showThemeSheet(context, ref),
    );
  }

  Widget _buildLanguageTile(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final title = isBn
        ? 'ভাষা'
        : isHi
            ? 'भाषा'
            : 'Language';
    final value = lang == 'bn'
        ? 'বাংলা'
        : lang == 'hi'
            ? 'हिंदी'
            : 'English';

    return _buildChoiceTile(
      icon: Icons.language_rounded,
      color: AppColors.accent,
      title: title,
      value: value,
      onTap: () => _showLanguageSheet(context, ref),
    );
  }

  Widget _buildChoiceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    _showChoiceSheet<AppThemeMode>(
      context,
      title: isBn
          ? 'থিম নির্বাচন করুন'
          : isHi
              ? 'थीम चुनें'
              : 'Select Theme',
      values: const [
        AppThemeMode.light,
        AppThemeMode.dark,
        AppThemeMode.system,
      ],
      labels: [
        isBn
            ? 'লাইট'
            : isHi
                ? 'हल्का'
                : 'Light',
        isBn
            ? 'ডার্ক'
            : isHi
                ? 'गहरा'
                : 'Dark',
        isBn
            ? 'সিস্টেম'
            : isHi
                ? 'सिस्टम'
                : 'System',
      ],
      icons: const [
        Icons.light_mode_rounded,
        Icons.dark_mode_rounded,
        Icons.brightness_auto_rounded,
      ],
      selected: themeMode,
      onSelected: (mode) {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    _showChoiceSheet<String>(
      context,
      title: isBn
          ? 'ভাষা নির্বাচন করুন'
          : isHi
              ? 'भाषा चुनें'
              : 'Select Language',
      values: const ['en', 'hi', 'bn'],
      labels: const ['English', 'हिंदी', 'বাংলা'],
      icons: const [
        Icons.language_rounded,
        Icons.language_rounded,
        Icons.language_rounded,
      ],
      selected: lang,
      onSelected: (value) {
        ref.read(languageProvider.notifier).setLanguage(value);
      },
    );
  }

  void _showChoiceSheet<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required List<String> labels,
    required List<IconData> icons,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: sheetDark ? const Color(0xFF1E1E2F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (sheetDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color:
                        sheetDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(values.length, (index) {
                  final isSelected = values[index] == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        onSelected(values[index]);
                        Navigator.pop(sheetContext);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                                  .withValues(alpha: sheetDark ? 0.16 : 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : (sheetDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.withValues(alpha: 0.15)),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icons[index],
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : (sheetDark
                                      ? Colors.white70
                                      : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                labels[index],
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (sheetDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _divider() {
    return Divider(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      height: 1,
      indent: 56,
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
        child: const Icon(Icons.emoji_events_rounded,
            color: AppColors.xp, size: 20),
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
    final title = isBn
        ? 'অ্যাপটি মূল্যায়ন করুন'
        : isHi
            ? 'ऐप को रेट करें'
            : 'Rate This App';

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
        final url = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.nexasoft.dailyquiz');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final title = isBn
        ? 'মতামত ও পরামর্শ'
        : isHi
            ? 'प्रतिक्रिया और सुझाव'
            : 'Feedback & Suggestions';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.feedback_rounded,
            color: isDark ? AppColors.primary : AppColors.primaryDark,
            size: 18),
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
