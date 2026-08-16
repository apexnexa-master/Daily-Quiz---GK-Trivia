// lib/presentation/screens/stats_screen.dart
// "View All" stats page reached from the Home screen. Hosts the Brain & Skills
// and Competition sections (previously rendered inside the Profile screen).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/app_providers.dart';
import '../providers/scoring_providers.dart';
import '../widgets/profile/brain_and_skills_section.dart';
import '../widgets/profile/competition_section.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isBn, isHi, isDark),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(brainStatsProvider);
                  ref.invalidate(myWeeklyRankProvider);
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: AppSpacing.paddingScreen,
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          BrainAndSkillsSection(lang: lang, isDark: isDark),
                          const SizedBox(height: 24),
                          CompetitionSection(lang: lang, isDark: isDark),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isBn, bool isHi, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.primaryGradientDark
            : AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            isBn ? 'মস্তিষ্ক ও দক্ষতা' : isHi ? 'मस्तिष्क और कौशल' : 'Brain Skills',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
