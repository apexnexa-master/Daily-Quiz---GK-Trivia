// lib/presentation/widgets/leaderboard_preview.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/firestore_models.dart';

class LeaderboardPreview extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String lang;
  const LeaderboardPreview(
      {super.key, required this.entries, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final isBn = lang == 'bn';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const medals = ['🥇', '🥈', '🥉'];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Icon(Icons.leaderboard_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  isBn ? 'আজকের শীর্ষ ৩' : "Today's Top 3",
                  style: isBn
                      ? AppTheme.bengaliStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)
                      : Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                  child: Text(
                    isBn ? 'সব দেখুন →' : 'See all →',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Theme.of(context).dividerColor),
          // Entries
          ...entries.asMap().entries.map((e) {
            final entry = e.value;
            final rank = e.key;
            return _PreviewTile(
              entry: entry,
              medal: medals[rank],
              isLast: rank == entries.length - 1,
              lang: lang,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final String medal;
  final bool isLast;
  final String lang;
  final bool isDark;
  const _PreviewTile(
      {required this.entry,
      required this.medal,
      required this.isLast,
      required this.lang,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          entry.photoUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(entry.photoUrl!), radius: 16)
              : CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  )),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.displayName,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _scoreColor(entry.score).withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entry.score}/10',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _scoreColor(entry.score)),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 8) return AppTheme.successColor;
    if (score >= 5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
