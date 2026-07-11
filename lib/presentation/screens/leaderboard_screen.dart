// lib/presentation/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/local_stats_service.dart';
import '../providers/app_providers.dart';

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
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, lang, isDark, isBn, isHi),
            Expanded(
              child: leaderboardAsync.when(
                data: (entries) => entries.isEmpty
                    ? _buildEmptyState(isDark, isBn, isHi)
                    : _buildLeaderboardList(entries, isDark, isBn, isHi),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black))),
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
        gradient:
            isDark ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
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
                isBn
                    ? 'লিডারবোর্ড'
                    : isHi
                        ? 'लीडरबोर्ड'
                        : 'Leaderboard',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(_getTodayDate(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined,
                size: 52, color: AppTheme.primaryColor),
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
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            isBn
                ? 'কুইজ দিয়ে প্রথম হন!'
                : isHi
                    ? 'क्विज़ देकर पहले बनें!'
                    : 'Be the first to attempt!',
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(
      List<LeaderboardEntryLocal> entries, bool isDark, bool isBn, bool isHi) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final rank = i + 1;
        final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
        final isTopThree = rank <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: rank == 1
                ? LinearGradient(colors: [
                    Colors.amber.withValues(alpha: 0.2),
                    Colors.orange.withValues(alpha: 0.1)
                  ])
                : null,
            color: rank == 1
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isTopThree
                  ? _getScoreColor(entry.score).withValues(alpha: 0.4)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.1)),
            ),
            boxShadow: rank == 1
                ? [
                    BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: isTopThree
                    ? Text(medals[rank]!,
                        style: const TextStyle(fontSize: 26),
                        textAlign: TextAlign.center)
                    : Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('#$rank',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.grey)),
                      ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    _getScoreColor(entry.score).withValues(alpha: 0.15),
                child: Text(
                  entry.playerName.isNotEmpty
                      ? entry.playerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: _getScoreColor(entry.score),
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.playerName,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.timeTaken}s',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _getScoreColor(entry.score).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          _getScoreColor(entry.score).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${entry.score}/10',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _getScoreColor(entry.score)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return AppTheme.successColor;
    if (score >= 5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
