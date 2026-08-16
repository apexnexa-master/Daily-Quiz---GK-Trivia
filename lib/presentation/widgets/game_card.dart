// lib/presentation/widgets/game_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_colors.dart';

/// Reusable premium game card used across every game listing in the app.
///
/// Visual hierarchy: Illustration cover -> Title -> Subtitle -> Metadata + action.
/// All game tiles (daily challenge, play zone, battle, category grids) share
/// this single design system so every tile looks consistent.
class GameCard extends StatelessWidget {
  /// Asset image rendered as the illustration area at the top of the card.
  final String? imagePath;

  /// Custom cover widget (e.g. gradient + icon block for category tiles).
  final Widget? cover;

  /// Game / category title.
  final String? title;

  /// Short supporting description shown under the title.
  final String? subtitle;

  /// Small category label rendered as a pill on the cover (e.g. "LOGIC").
  final String? badge;

  /// Small metadata string (duration, question count, ...) shown as a pill.
  final String? meta;

  /// Optional icon next to [meta].
  final IconData? metaIcon;

  /// Small footer hint text shown above the action button.
  final String? footer;

  /// Accent color driving border, badge, glow and action button.
  final Color? accent;

  /// Locked state: dimmed cover, lock badge and disabled tap.
  final bool isLocked;

  /// Live state: pulsing red dot inside the badge.
  final bool isLive;

  /// Coming soon state: frosted blur overlay on the cover.
  final bool isComingSoon;

  /// Localized label for the coming soon overlay.
  final String comingSoonLabel;

  /// Tap target. Disabled automatically when locked / coming soon.
  final VoidCallback? onTap;

  /// Fixed card width. Omit to fill the available width.
  final double? width;

  /// Height of the cover area when [coverAspectRatio] is not set.
  final double coverHeight;

  /// When set, the cover height scales with the card width
  /// (`width / aspectRatio`) keeping consistent proportions.
  final double? coverAspectRatio;

  /// Whether the card should stretch to fill its parent height and pin the
  /// footer row to the bottom (used inside fixed-height grids).
  final bool fillHeight;

  /// Compact rendering: smaller paddings, fonts and controls so the card stays
  /// short in dense grids (category tiles). Cover is expected to be a slim
  /// accent band when combined with [coverAspectRatio] / [coverHeight].
  final bool compact;

  const GameCard({
    super.key,
    this.imagePath,
    this.cover,
    this.title,
    this.subtitle,
    this.badge,
    this.meta,
    this.metaIcon,
    this.footer,
    this.accent,
    this.isLocked = false,
    this.isLive = false,
    this.isComingSoon = false,
    this.comingSoonLabel = 'COMING SOON',
    this.onTap,
    this.width,
    this.coverHeight = 130,
    this.coverAspectRatio,
    this.fillHeight = false,
    this.compact = false,
  }) : assert(cover == null || imagePath == null,
            'Provide either [cover] or [imagePath], not both');

  /// Shared corner radius for every game card in the app.
  static const double radius = 24;

  /// Returns a readable version of [accent] for text on tinted backgrounds.
  static Color accentForeground(Color accent, bool isDark) {
    if (isDark) return accent;
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness > 0.45) {
      return hsl.withLightness(0.32).toColor();
    }
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF151D1E) : Colors.white;
    final effectiveAccent = accent ?? AppColors.primary;
    final isMuted = isLocked || isComingSoon;

    final card = Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfaceColor,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1B2628), const Color(0xFF151D1E)]
              : [Colors.white, const Color(0xFFFAFAFA)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          if (!isMuted)
            BoxShadow(
              color: effectiveAccent.withValues(alpha: isDark ? 0.22 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(isDark, effectiveAccent, surfaceColor, compact),
          if (fillHeight)
            Expanded(
              child: _buildInfoSection(isDark, effectiveAccent, isMuted,
                  fillInfo: true, compact: compact),
            )
          else
            _buildInfoSection(isDark, effectiveAccent, isMuted,
                compact: compact),
        ],
      ),
    );

    return AnimatedScaleButton(
      onTap: isMuted ? null : onTap,
      child: card,
    );
  }

  // ── Cover (illustration area) ─────────────────────────────────────────

  Widget _buildCover(bool isDark, Color accent, Color surfaceColor, bool compact) {
    final Widget coverContent;
    if (cover != null) {
      coverContent = cover!;
    } else if (imagePath != null) {
      coverContent = Image.asset(
        imagePath!,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else {
      coverContent = _buildIconCover(isDark, accent);
    }

    final Widget coverBox;
    if (coverAspectRatio != null) {
      coverBox = AspectRatio(
        aspectRatio: coverAspectRatio!,
        child: coverContent,
      );
    } else {
      coverBox = SizedBox(
        height: coverHeight,
        width: double.infinity,
        child: coverContent,
      );
    }

    return Stack(
      children: [
        coverBox,
        // Bottom scrim blends the illustration into the info section.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: compact ? 14 : 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  surfaceColor,
                  surfaceColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: compact ? 4 : 10,
            left: compact ? 6 : 10,
            child: _buildBadge(isDark, accent, compact),
          ),
        if (meta != null)
          Positioned(
            top: compact ? 4 : 10,
            right: compact ? 6 : 10,
            child: _buildMetaPill(isDark, compact),
          ),
        if (isLocked) Positioned.fill(child: _buildLockedOverlay(isDark)),
        if (isComingSoon) Positioned.fill(child: _buildComingSoonOverlay()),
      ],
    );
  }

  Widget _buildIconCover(bool isDark, Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.30 : 0.24),
            accent.withValues(alpha: isDark ? 0.12 : 0.08),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.sports_esports_rounded,
            color: accentForeground(accent, isDark),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(bool isDark, Color accent, bool compact) {
    final isMuted = isLocked || isComingSoon;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isMuted
            ? (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200)
            : accent.withValues(alpha: isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMuted
              ? Colors.transparent
              : accent.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            PulseWidget(
              child: Container(
                width: compact ? 5 : 6,
                height: compact ? 5 : 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: compact ? 4 : 5),
          ],
          Text(
            badge!,
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? 0.5 : 0.7,
              color: isMuted
                  ? (isDark ? Colors.white38 : Colors.grey.shade500)
                  : accentForeground(accent, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(bool isDark, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metaIcon != null) ...[
            Icon(
              metaIcon,
              size: compact ? 10 : 11,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            meta!,
            style: TextStyle(
              fontSize: compact ? 9 : 9.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay(bool isDark) {
    return Container(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.35),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.lock_rounded,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black45,
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  comingSoonLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────────────

  Widget _buildInfoSection(
      bool isDark, Color accent, bool isMuted,
      {bool fillInfo = false, bool compact = false}) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: isMuted
                    ? (isDark ? Colors.white38 : Colors.grey.shade400)
                    : (isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
            ),
            if (fillInfo) const Spacer() else const SizedBox(height: 2),
            Row(
              children: [
                if (footer != null && footer!.isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      footer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isMuted
                            ? (isDark ? Colors.white24 : Colors.grey.shade400)
                            : (isDark
                                ? AppColors.textSecondaryDark
                                    .withValues(alpha: 0.75)
                                : AppColors.textSecondaryLight
                                    .withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else
                  const Spacer(),
                _buildActionButton(isDark, accent),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: isMuted
                  ? (isDark ? Colors.white38 : Colors.grey.shade400)
                  : (isDark ? Colors.white : AppColors.textPrimaryLight),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: Text(
              subtitle ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: isMuted
                    ? (isDark ? Colors.white24 : Colors.grey.shade400)
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ),
          if (fillInfo) const Spacer() else const SizedBox(height: 10),
          Row(
            children: [
              if (footer != null && footer!.isNotEmpty) ...[
                Expanded(
                  child: Text(
                    footer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isMuted
                          ? (isDark ? Colors.white24 : Colors.grey.shade400)
                          : (isDark
                              ? AppColors.textSecondaryDark
                                  .withValues(alpha: 0.75)
                              : AppColors.textSecondaryLight
                                  .withValues(alpha: 0.8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              _buildActionButton(isDark, accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isDark, Color accent) {
    final isMuted = isLocked || isComingSoon;
    return Container(
      width: compact ? 24 : 36,
      height: compact ? 24 : 36,
      decoration: BoxDecoration(
        color: isMuted
            ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade100)
            : null,
        gradient: isMuted
            ? null
            : LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        border: isMuted
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: isMuted
            ? null
            : [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: compact ? 8 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(
        isMuted ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
        color: isMuted
            ? (isDark ? Colors.white24 : Colors.grey.shade400)
            : Colors.black,
        size: compact ? 13 : 18,
      ),
    );
  }
}
