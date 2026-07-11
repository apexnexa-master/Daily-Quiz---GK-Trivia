// lib/presentation/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/local_stats_service.dart';
import '../providers/app_providers.dart';
import '../widgets/shimmer_loading.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final leaderboardAsync = ref.watch(localLeaderboardProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, lang, isDark, isBn, isHi),
            Expanded(
              child: leaderboardAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return _buildEmptyState(isDark, isBn, isHi);
                  }
                  return _buildContent(entries, isDark, isBn, isHi);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: LeaderboardShimmer(),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, String lang, bool isDark, bool isBn, bool isHi) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text(
                isBn ? 'লিডারবোর্ড' : isHi ? 'लीडरबोर्ड' : 'Leaderboard',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _getTodayDate(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTodayDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]}';
  }

  Widget _buildEmptyState(bool isDark, bool isBn, bool isHi) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_outlined, size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            isBn
                ? 'কোনো র‍্যাংকিং নেই'
                : isHi
                    ? 'अभी तक कोई रैंकिंग नहीं'
                    : 'No rankings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isBn
                ? 'কুইজ দিয়ে প্রথম হন!'
                : isHi
                    ? 'क्विज़ देकर पहले बनें!'
                    : 'Be the first to attempt!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<LeaderboardEntryLocal> entries, bool isDark, bool isBn, bool isHi) {
    final podiumEntries = entries.take(3).toList();
    final listEntries = entries.skip(3).toList();

    return CustomScrollView(
      slivers: [
        // 3D Podium visually
        if (podiumEntries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: _buildPodium(podiumEntries, isDark, isBn, isHi),
            ),
          ),
        // List entries
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = listEntries[index];
                final rank = index + 4;
                return StaggeredListItem(
                  index: index,
                  child: _buildListEntry(entry, rank, isDark),
                );
              },
              childCount: listEntries.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(
      List<LeaderboardEntryLocal> podium, bool isDark, bool isBn, bool isHi) {
    // Re-order podium for left-middle-right display: Rank 2, Rank 1, Rank 3
    LeaderboardEntryLocal? rank1 = podium.isNotEmpty ? podium[0] : null;
    LeaderboardEntryLocal? rank2 = podium.length > 1 ? podium[1] : null;
    LeaderboardEntryLocal? rank3 = podium.length > 2 ? podium[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rank 2 Column
        if (rank2 != null)
          Expanded(
            child: _buildPodiumColumn(
              entry: rank2,
              rank: 2,
              height: 110,
              color: const Color(0xFF94A3B8), // Slate
              avatarSize: 56,
              isDark: isDark,
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        
        // Rank 1 Column
        if (rank1 != null)
          Expanded(
            child: _buildPodiumColumn(
              entry: rank1,
              rank: 1,
              height: 140,
              color: const Color(0xFFFBBF24), // Amber/Gold
              avatarSize: 72,
              isDark: isDark,
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),

        // Rank 3 Column
        if (rank3 != null)
          Expanded(
            child: _buildPodiumColumn(
              entry: rank3,
              rank: 3,
              height: 90,
              color: const Color(0xFFCD7F32), // Bronze
              avatarSize: 52,
              isDark: isDark,
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required LeaderboardEntryLocal entry,
    required int rank,
    required double height,
    required Color color,
    required double avatarSize,
    required bool isDark,
  }) {
    final initials = entry.playerName.isNotEmpty ? entry.playerName[0].toUpperCase() : 'U';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trophy/Crown Icon
        if (rank == 1)
          const PulseWidget(
            child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 28),
          )
        else
          Icon(
            rank == 2 ? Icons.military_tech_rounded : Icons.star_rounded,
            color: color,
            size: 20,
          ),
        const SizedBox(height: 4),
        
        // Avatar
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: avatarSize * 0.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // Name
        Text(
          entry.playerName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Score
        Text(
          '${entry.score}/10',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 8),

        // 3D Podium Block
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListEntry(LeaderboardEntryLocal entry, int rank, bool isDark) {
    final initials = entry.playerName.isNotEmpty ? entry.playerName[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.timeTaken}s',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Score Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getScoreColor(entry.score).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getScoreColor(entry.score).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${entry.score}/10',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _getScoreColor(entry.score),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return AppColors.success;
    if (score >= 5) return AppColors.warning;
    return AppColors.error;
  }
}
