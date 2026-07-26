// lib/presentation/widgets/home_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langs = [
      ('en', 'English'),
      ('hi', 'हिंदी'),
      ('bn', 'বাংলা'),
    ];
    
    return PopupMenuButton<String>(
      initialValue: lang,
      onSelected: (l) => ref.read(languageProvider.notifier).setLanguage(l),
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.secondary.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              lang.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => langs
          .map((l) => PopupMenuItem(
                value: l.$1,
                child: Row(
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
