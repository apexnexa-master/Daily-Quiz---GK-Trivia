// lib/presentation/widgets/profile/brain_and_skills_section.dart
// Profile sections powered by the scoring engine (spec §23/§26): the Brain
// Score + cognitive skill bars and the Activity counters. Reads the read-side
// [brainStatsProvider] bundle; safe to show for any logged-in user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scoring/brain_score.dart';
import '../../../core/services/daily_progress_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/scoring_providers.dart';
import '../shimmer_loading.dart';

class BrainAndSkillsSection extends ConsumerWidget {
  final String lang;
  final bool isDark;
  const BrainAndSkillsSection({super.key, required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final statsAsync = ref.watch(brainStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology_rounded, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              isBn ? 'মস্তিষ্ক ও দক্ষতা' : isHi ? 'मस्तिष्क और कौशल' : 'Brain & Skills',
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
          data: (bundle) => Column(
            children: [
              _BrainScoreCard(bundle: bundle, isDark: isDark, isBn: isBn, isHi: isHi),
              const SizedBox(height: 12),
              _ActivityCard(bundle: bundle, isDark: isDark, isBn: isBn, isHi: isHi),
            ],
          ),
          loading: () => _ProfileCardPlaceholder(isDark: isDark),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ProfileCardPlaceholder extends StatelessWidget {
  final bool isDark;
  const _ProfileCardPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              const ShimmerCircle(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 18, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 8),
                    ShimmerBox(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ShimmerBox(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                const SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(height: 8, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                ShimmerBox(width: 30, height: 12, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _BrainScoreCard extends StatelessWidget {
  final BrainStatsBundle bundle;
  final bool isDark;
  final bool isBn;
  final bool isHi;

  const _BrainScoreCard({
    required this.bundle,
    required this.isDark,
    required this.isBn,
    required this.isHi,
  });

  static const List<(String, String, String, String)> _pillars = [
    (BrainPillar.knowledge, 'Knowledge', 'জ্ঞান', 'ज्ञान'),
    (BrainPillar.logic, 'Logic', 'যুক্তি', 'तर्क'),
    (BrainPillar.speed, 'Speed', 'গতি', 'गति'),
    (BrainPillar.memory, 'Memory', 'স্মৃতি', 'स्मृति'),
    (BrainPillar.reaction, 'Reaction', 'প্রতিক্রিয়া', 'प्रतिक्रिया'),
  ];

  @override
  Widget build(BuildContext context) {
    final brain = bundle.brain;
    final established = brain.status == BrainScoreStatus.established;
    final change = brain.weeklyChange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.neonCyan.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBn ? 'মস্তিষ্ক স্কোর' : isHi ? 'मस्तिष्क स्कोर' : 'Brain Score',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${brain.score}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: established
                    ? (isBn ? 'স্থির' : isHi ? 'स्थिर' : 'Established')
                    : (isBn ? 'নির্মাণাধীন' : isHi ? 'विकासशील' : 'Building'),
                color: established ? AppColors.success : AppColors.warning,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (change >= 0 ? AppColors.success : AppColors.error)
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: change >= 0 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${change >= 0 ? '+' : ''}$change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: change >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._pillars.map((p) {
            final (key, en, bn, hi) = p;
            final hasData = brain.ratings.hasData(key);
            final value = hasData ? brain.ratings.rating(key) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      isBn ? bn : isHi ? hi : en,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hasData ? value / 100 : 0,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      hasData ? value.round().toString() : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: hasData
                            ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                            : (isDark ? Colors.white24 : Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  const _StatusPill({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final BrainStatsBundle bundle;
  final bool isDark;
  final bool isBn;
  final bool isHi;
  const _ActivityCard({
    required this.bundle,
    required this.isDark,
    required this.isBn,
    required this.isHi,
  });

  @override
  Widget build(BuildContext context) {
    final a = bundle.activity;
    final minutes = (a.trainingSeconds / 60).round();
    final trainingLabel = minutes < 1
        ? (isBn ? '<১ মিনিট' : isHi ? '<1 मिनट' : '<1 min')
        : '$minutes ${isBn ? 'মিনিট' : isHi ? 'मिनट' : 'min'}';

    final items = [
      (Icons.videogame_asset_rounded, '${a.gamesPlayed}',
          isBn ? 'খেলা' : isHi ? 'गेम' : 'Games'),
      (Icons.emoji_events_rounded, '${a.dailyChallengesCompleted}',
          isBn ? 'চ্যালেঞ্জ' : isHi ? 'चुनौतियाँ' : 'Challenges'),
      (Icons.fitness_center_rounded, '${a.workoutsCompleted}',
          isBn ? 'ওয়ার্কআউট' : isHi ? 'वर्कआउट' : 'Workouts'),
      (Icons.timer_rounded, trainingLabel,
          isBn ? 'সময়' : isHi ? 'समय' : 'Training'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBn ? 'কার্যকলাপ' : isHi ? 'गतिविधि' : 'Activity',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: items.map((it) {
              final (icon, value, label) = it;
              return Expanded(
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
