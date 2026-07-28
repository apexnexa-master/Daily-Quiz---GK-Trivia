// lib/presentation/screens/play_zone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../providers/app_providers.dart';

class PlayZoneScreen extends ConsumerWidget {
  const PlayZoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final screenTitle = isBn ? 'প্লে জোন' : isHi ? 'प्ले ज़ोन' : 'Play Zone';
    final screenSubtitle = isBn
        ? 'বিভিন্ন আকর্ষণীয় গেম মোডে অংশ নিন'
        : isHi
            ? 'विभिन्न रोमांचक गेम मोड में भाग लें'
            : 'Explore exciting quiz formats & challenges!';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Block
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      screenTitle,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      screenSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Game Modes Grid
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    // Mode 1: Math Puzzle (Coming Soon)
                    StaggeredListItem(
                      index: 0,
                      child: _buildPlayZoneCard(
                        context,
                        title: isBn ? 'গণিত পাজল' : isHi ? 'गणित पहेलियाँ' : 'Math Puzzles',
                        description: isBn
                            ? 'মজার অঙ্ক ধাঁধার সমাধান করে আপনার বুদ্ধিমত্তা এবং গণিত দক্ষতা উন্নত করুন।'
                            : isHi
                                ? 'मज़ेदार गणित पहेलियों को हल करके अपनी बुद्धि और गणित कौशल में सुधार करें।'
                                : 'Sharpen your analytical mind and speed solving interactive math puzzles.',
                        icon: Icons.calculate_rounded,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E1E2F), const Color(0xFF3F3F5F)]
                              : [Colors.grey.shade50, Colors.grey.shade200],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        btnLabel: isBn ? 'শীঘ্রই আসছে' : isHi ? 'जल्द ही आ रहा है' : 'Coming Soon',
                        isLocked: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode 2: Programming Quiz (Coming Soon)
                    StaggeredListItem(
                      index: 1,
                      child: _buildPlayZoneCard(
                        context,
                        title: isBn ? 'প্রোগ্রামিং কুইজ' : isHi ? 'प्रोग्रामिंग क्विज़' : 'Programming Trivia',
                        description: isBn
                            ? 'জাভাস্ক্রিপ্ট, পাইথন এবং ডার্ট কোডিং চ্যালেঞ্জ দিয়ে আপনার প্রযুক্তি জ্ঞান যাচাই করুন।'
                            : isHi
                                ? 'जावास्क्रिप्ट, पायथन और डार्ट कोडिंग चुनौतियों के साथ अपने तकनीकी ज्ञान का परीक्षण करें।'
                                : 'Test your software skills in Python, JavaScript, Dart, and system architecture.',
                        icon: Icons.code_rounded,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E1E2F), const Color(0xFF3F3F5F)]
                              : [Colors.grey.shade50, Colors.grey.shade200],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        btnLabel: isBn ? 'শীঘ্রই আসছে' : isHi ? 'जल्द ही आ रहा है' : 'Coming Soon',
                        isLocked: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayZoneCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Gradient gradient,
    required String btnLabel,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
              : Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLocked
                ? Colors.transparent
                : const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (!isLocked)
              Positioned(
                right: -25,
                bottom: -25,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: isDark ? 0.08 : 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isLocked
                                        ? (isDark ? Colors.white54 : Colors.grey.shade600)
                                        : (isDark ? Colors.white : AppColors.textPrimaryLight),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (isLocked) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white38 : Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: isLocked
                                      ? (isDark ? Colors.white30 : Colors.grey.shade400)
                                      : (isDark ? Colors.white60 : AppColors.textSecondaryLight),
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.1))
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.success.withValues(alpha: 0.08)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: isLocked
                              ? (isDark ? Colors.white30 : Colors.grey.shade400)
                              : AppColors.success,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedScaleButton(
                    onTap: isLocked ? () {} : onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade300)
                            : const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isLocked
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isLocked) ...[
                            const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            btnLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isLocked
                                  ? (isDark ? Colors.white30 : Colors.grey.shade500)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
