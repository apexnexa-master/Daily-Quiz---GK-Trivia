// lib/presentation/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/local_stats_service.dart';
import '../../core/scoring/leaderboard_service.dart';
import '../providers/app_providers.dart';
import '../widgets/shimmer_loading.dart';
import 'package:google_fonts/google_fonts.dart';

final leaderboardTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class LeaderboardScreen extends ConsumerWidget {
  final bool isTab;
  const LeaderboardScreen({super.key, this.isTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final leaderboardAsync = ref.watch(localLeaderboardProvider);
    final selectedTab = ref.watch(leaderboardTabProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, lang, isDark, isBn, isHi),
            Expanded(
              child: leaderboardAsync.when(
                data: (entries) {
                  // Filter and aggregate entries based on the selected tab
                  List<LeaderboardEntryLocal> filteredEntries = [];
                  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

                  if (selectedTab == 0) {
                    filteredEntries = entries.where((e) => e.date == todayStr).toList();
                  } else if (selectedTab == 1) {
                    // Weekly board = best 5 daily scores per player (§19), not
                    // a sum of every play. The engine handles the window.
                    filteredEntries = LeaderboardService
                        .aggregateWeekly(entries)
                        .map((a) => LeaderboardEntryLocal(
                              playerName: a.playerName,
                              score: a.score,
                              timeTaken: a.timeTaken,
                              date: todayStr,
                            ))
                        .toList();
                  } else {
                    // All-time board uses the same best-5 rule to avoid
                    // lifetime accumulation (§21).
                    filteredEntries = LeaderboardService
                        .aggregateAllTime(entries)
                        .map((a) => LeaderboardEntryLocal(
                              playerName: a.playerName,
                              score: a.score,
                              timeTaken: a.timeTaken,
                              date: todayStr,
                            ))
                        .toList();
                  }

                  if (filteredEntries.isEmpty) {
                    return _buildEmptyState(ref, isDark, isBn, isHi);
                  }
                  return _buildContent(ref, filteredEntries, isDark, isBn, isHi, selectedTab != 0);
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
      BuildContext context, WidgetRef ref, String lang, bool isDark, bool isBn, bool isHi) {
    final selectedTab = ref.watch(leaderboardTabProvider);
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
              if (isTab != true) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
              ],
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
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
                onPressed: () => _showLeaderboardRulesDialog(context, isDark, isBn, isHi),
                tooltip: 'Leaderboard Rules',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTab(ref, 0, isBn ? 'আজ' : isHi ? 'आज' : 'Today'),
                _buildTab(ref, 1, isBn ? 'এই সপ্তাহ' : isHi ? 'इस सप्ताह' : 'This Week'),
                _buildTab(ref, 2, isBn ? 'সর্বকালের' : isHi ? 'ऑल टाइम' : 'All Time'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getBoardSubtitle(selectedTab, isBn, isHi),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  String _getBoardSubtitle(int tab, bool isBn, bool isHi) {
    switch (tab) {
      case 0:
        return isBn
            ? 'শুধুমাত্র আজকের অফিসিয়াল ডেইলি চ্যালেঞ্জ পয়েন্ট দেখানো হয়েছে'
            : isHi
                ? 'केवल आज के आधिकारिक डेली चैलेंज पॉइंट दिखाए गए हैं'
                : "Only today's official Daily Challenge points are shown";
      case 1:
        return isBn
            ? 'সাপ্তাহিক = সেরা ৫টি ডেইলি চ্যালেঞ্জ স্কোর'
            : isHi
                ? 'साप्ताहिक = शीर्ष 5 डेली चैलेंज स्कोर'
                : 'Weekly = best 5 Daily Challenge scores';
      default:
        return isBn
            ? 'সর্বকালের = সেরা ৫টি ডেইলি চ্যালেঞ্জ স্কোর'
            : isHi
                ? 'ऑल टाइम = शीर्ष 5 डेली चैलेंज स्कोर'
                : 'All-time = best 5 Daily Challenge scores';
    }
  }

  Widget _buildTab(WidgetRef ref, int index, String text) {
    final selectedTab = ref.watch(leaderboardTabProvider);
    final isSelected = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(leaderboardTabProvider.notifier).state = index,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
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

  Widget _buildEmptyState(WidgetRef ref, bool isDark, bool isBn, bool isHi) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(localLeaderboardProvider);
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400,
          alignment: Alignment.center,
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
        ),
      ),
    );
  }

  Widget _buildContent(WidgetRef ref, List<LeaderboardEntryLocal> entries, bool isDark, bool isBn, bool isHi, bool isCumulative) {
    final podiumEntries = entries.take(3).toList();
    final listEntries = entries.skip(3).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(localLeaderboardProvider);
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 3D Podium visually
          if (podiumEntries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: _buildPodium(podiumEntries, isDark, isBn, isHi, isCumulative),
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
                    child: _buildListEntry(entry, rank, isDark, isCumulative),
                  );
                },
                childCount: listEntries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(
      List<LeaderboardEntryLocal> podium, bool isDark, bool isBn, bool isHi, bool isCumulative) {
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
              isCumulative: isCumulative,
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
              isCumulative: isCumulative,
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
              isCumulative: isCumulative,
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
    required bool isCumulative,
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
                color: isDark ? color : (color == const Color(0xFFFBBF24) ? const Color(0xFFD97706) : color),
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
          '${entry.score} pts',
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

  Widget _buildListEntry(LeaderboardEntryLocal entry, int rank, bool isDark, bool isCumulative) {
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
            backgroundColor: (isDark ? AppColors.primary : AppColors.primaryDark).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              entry.playerName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              '${entry.score} pts',
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
    if (score >= 150) return AppColors.success;
    if (score >= 80) return AppColors.warning;
    return AppColors.error;
  }

  void _showLeaderboardRulesDialog(BuildContext context, bool isDark, bool isBn, bool isHi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24)),
            const SizedBox(width: 8),
            Text(
              isBn ? 'র‍্যাঙ্কিং নিয়মাবলী' : isHi ? 'रैंकिंग नियम' : 'Leaderboard Rules',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. RATED CHALLENGES ONLY:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Only official Daily Challenge submissions (GK Live Challenge and Arrow Puzzle 3D Daily Challenge) award leaderboard points. Practice modes and campaign levels never count. Each challenge grants one official attempt per day — retries can improve your personal best but never award extra points.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '2. WEEKLY BEST 5:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.green,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Your top 5 Daily Challenge scores of the week are added together for the weekly board (grinding easy games won't help). The all-time board uses the same best-5 rule over your history, so older accounts don't automatically win. Every row shows only the points that actually count — never practice or XP.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '3. HOW POINTS WORK:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.amber,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each official challenge is scored as performance 0–100 (accuracy, speed, difficulty, efficiency) and then scaled ×10 into 0–1000 leaderboard points. The points shown on the board are exactly these scaled challenge points.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '4. SCORING MATRIX (per game):',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.purple,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• GK Quiz & Battle: Accuracy 60% + Difficulty 25% + Speed 15% (30s per question budget).\n'
                '• Arrow Puzzle 3D: Difficulty 40% + Time 30% + Moves 20% + Quality 10%.\n'
                '• Stroop Test: Accuracy 50% + Reaction 30% + Difficulty 20%.\n'
                '• Synapse Recall: Sequence 50% + Accuracy 30% + Difficulty 20%.\n'
                '• Math Speed: Accuracy 50% + Speed 30% + Difficulty 20% (6s per problem budget).',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '5. XP IS NOT INCLUDED:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.blueAccent,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'XP (practice 10, daily challenge 25, workout 30, battle 10, capped at 150 per day) is earned separately and NEVER affects leaderboard ranking or the points shown on this board.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '6. RANKING & TIES:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.redAccent,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Players are ranked by competition rules: your rank is 1 + the number of players with a strictly higher score, so equal scores share the same rank. If scores are tied, the player with the lowest overall time taken is ranked higher.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
