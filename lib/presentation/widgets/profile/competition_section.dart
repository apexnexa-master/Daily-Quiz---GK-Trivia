// lib/presentation/widgets/profile/competition_section.dart
// Weekly-leaderboard standing for the profile (spec §28): this week's best-5
// score, rank, points needed to overtake the player above, and the personal
// records (best weekly rank / best daily score).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/scoring_providers.dart';
import '../shimmer_loading.dart';

class CompetitionSection extends ConsumerWidget {
  final String lang;
  final bool isDark;
  const CompetitionSection({super.key, required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final statsAsync = ref.watch(brainStatsProvider);
    final rankAsync = ref.watch(myWeeklyRankProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.warning),
            ),
            const SizedBox(width: 10),
            Text(
              isBn ? 'প্রতিযোগিতা' : isHi ? 'प्रतियोगिता' : 'Competition',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        statsAsync.when(
          data: (bundle) {
            final rank = rankAsync.value;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: isDark ? 0.18 : 0.08),
                    AppColors.warning.withValues(alpha: isDark ? 0.08 : 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        value: bundle.weeklyChallengeCount == 0
                            ? '—'
                            : '${bundle.weeklyScore}',
                        label: isBn
                            ? 'সপ্তাহের স্কোর'
                            : isHi
                                ? 'सप्ताह स्कोर'
                                : 'Weekly Score',
                        isDark: isDark,
                      ),
                      _StatColumn(
                        value: rank?.rank != null && rank!.rank > 0
                            ? '#${rank.rank}'
                            : '—',
                        label: isBn
                            ? 'র‍্যাংক'
                            : isHi
                                ? 'रैंक'
                                : 'Rank',
                        isDark: isDark,
                      ),
                      _StatColumn(
                        value: rank?.pointsToNext != null && rank!.pointsToNext > 0
                            ? '+${rank.pointsToNext}'
                            : bundle.weeklyChallengeCount == 0
                                ? '—'
                                : '0',
                        label: isBn
                            ? 'পরের দিকে'
                            : isHi
                                ? 'अगले तक'
                                : 'To Next',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RecordChip(
                          icon: Icons.stars_rounded,
                          value: bundle.bestWeeklyRank > 0
                              ? '#${bundle.bestWeeklyRank}'
                              : '—',
                          label: isBn
                              ? 'সেরা র‍্যাংক'
                              : isHi
                                  ? 'सर्वश्रेष्ठ रैंक'
                                  : 'Best Rank',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RecordChip(
                          icon: Icons.bolt_rounded,
                          value: bundle.bestDailyScore > 0
                              ? '${bundle.bestDailyScore}'
                              : '—',
                          label: isBn
                              ? 'সেরা দৈনিক স্কোর'
                              : isHi
                                  ? 'सर्वश्रेष्ठ दैनिक स्कोर'
                                  : 'Best Daily Score',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (_) => Column(
                children: [
                  const ShimmerCircle(size: 32),
                  const SizedBox(height: 8),
                  ShimmerBox(width: 40, height: 14, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  ShimmerBox(width: 60, height: 10, borderRadius: BorderRadius.circular(4)),
                ],
              )),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;
  const _StatColumn({
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _RecordChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  const _RecordChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
