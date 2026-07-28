// lib/presentation/widgets/home_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_manager.dart';
import '../providers/app_providers.dart';

class HomeHeader extends ConsumerWidget {
  final String lang;
  final bool isDark;

  const HomeHeader({
    super.key,
    required this.lang,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // App Logo container with premium look
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/daily_gk_quiz_playstore_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // App Titles
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily GK',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                isBn
                    ? 'আপনার দৈনিক কুইজ'
                    : isHi
                        ? 'आज का क्विज़'
                        : 'Your Daily Quiz',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Leaderboard Button 🏆
          _LeaderboardButton(lang: lang),
          const SizedBox(width: 8),
          // Language selector button
          _LanguageButton(ref: ref, lang: lang),
          const SizedBox(width: 8),
          // Direct 1-tap Theme Toggle button (Sun / Moon)
          const _ThemeToggleButton(),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final newMode = isDark ? AppThemeMode.light : AppThemeMode.dark;
        ref.read(themeModeProvider.notifier).setThemeMode(newMode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.amber.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
          color: isDark ? Colors.amber : AppColors.primary,
          size: 19,
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final WidgetRef ref;
  final String lang;
  const _LanguageButton({required this.ref, required this.lang});

  void _showLanguageBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final title = isBn ? 'ভাষা নির্বাচন করুন' : isHi ? 'भाषा चुनें' : 'Select Language';

    final langs = [
      ('en', 'English'),
      ('hi', 'हिंदी'),
      ('bn', 'বাংলা'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ...langs.map((l) {
                final isSelected = lang == l.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(languageProvider.notifier).setLanguage(l.$1);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primary.withValues(alpha: 0.3) 
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l.$2,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected 
                                  ? AppColors.primary 
                                  : (isDark ? Colors.white : AppColors.textPrimaryLight),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _showLanguageBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Icon(
          Icons.translate_rounded,
          size: 18,
          color: isDark ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

class _LeaderboardButton extends StatelessWidget {
  final String lang;
  const _LeaderboardButton({required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/leaderboard');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: const Icon(
          Icons.emoji_events_rounded,
          size: 18,
          color: Colors.amber,
        ),
      ),
    );
  }
}
