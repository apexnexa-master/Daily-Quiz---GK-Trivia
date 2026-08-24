// lib/presentation/widgets/game_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_colors.dart';

/// Cinematic full-bleed game tile used across every game listing in the app.
///
/// The artwork fills the entire card (Netflix / Apple Arcade poster style);
/// title, description and a small footer chip float over a soft bottom scrim.
/// There is no separate play button - the whole tile is one tap target and a
/// subtle chevron hints at navigation. All game tiles (daily challenges,
/// play zone, battle, category grids) share this single design system.
class GameCard extends StatelessWidget {
  /// Asset image rendered as the full-bleed artwork of the card.
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

  /// Small footer hint rendered as an accent glass chip near the bottom.
  final String? footer;

  /// Accent color driving badge ring, footer chip dot and glow shadow.
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

  /// Total tile height when [coverAspectRatio] is not set. The artwork now
  /// fills the entire card, so this is the full card height.
  final double coverHeight;

  /// When set, the whole tile scales with its width (`width / aspectRatio`)
  /// keeping consistent poster proportions.
  final double? coverAspectRatio;

  /// Whether the card should stretch to fill its parent height
  /// (used inside fixed-extent grids).
  final bool fillHeight;

  /// Compact rendering: smaller type and spacing for dense grids.
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
    this.coverHeight = 150,
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
    final baseColor = isDark ? AppColors.cardDark : Colors.white;
    final effectiveAccent = accent ?? AppColors.primary;
    final isMuted = isLocked || isComingSoon;

    Widget stack = Stack(
      children: [
        Positioned.fill(child: _buildArtwork(isDark, effectiveAccent)),
        Positioned.fill(child: _buildScrim(isDark)),
        if (badge != null)
          Positioned(
            top: compact ? 8 : 10,
            left: compact ? 8 : 10,
            child: _buildBadge(
                accent: effectiveAccent, compact: compact, isDark: isDark),
          ),
        if (meta != null)
          Positioned(
            top: compact ? 8 : 10,
            right: compact ? 8 : 10,
            child: _buildMetaPill(isDark, compact),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildPosterContent(isDark, effectiveAccent, isMuted),
        ),
        if (isLocked) Positioned.fill(child: _buildLockedOverlay(isDark)),
        if (isComingSoon) Positioned.fill(child: _buildComingSoonOverlay()),
      ],
    );

    if (!fillHeight) {
      stack = coverAspectRatio != null
          ? AspectRatio(aspectRatio: coverAspectRatio!, child: stack)
          : SizedBox(height: coverHeight, child: stack);
    }

    final card = Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          if (!isMuted)
            BoxShadow(
              color: effectiveAccent.withValues(alpha: isDark ? 0.14 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: stack,
    );

    return AnimatedScaleButton(
      onTap: isMuted ? null : onTap,
      child: card,
    );
  }

  // ── Artwork ────────────────────────────────────────────────────────────

  Widget _buildArtwork(bool isDark, Color accent) {
    if (cover != null) return cover!;
    // Light theme uses the pastel "morning" variants of the cover art.
    String? artPath = imagePath;
    if (!isDark &&
        artPath != null &&
        artPath.startsWith('assets/covers/') &&
        artPath.endsWith('.svg') &&
        !artPath.contains('covers/light/')) {
      artPath = artPath.replaceFirst('assets/covers/', 'assets/covers/light/');
    }
    if (artPath != null && artPath.endsWith('.svg')) {
      return SvgPicture.asset(
        artPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (artPath != null) {
      return Image.asset(
        artPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return _buildIconCover(isDark, accent);
  }

  /// Fallback artwork when no image/cover is supplied: a calm accent mesh
  /// with a ghosted watermark glyph that keeps the lower-left text zone clear.
  Widget _buildIconCover(bool isDark, Color accent) {
    final base = isDark ? AppColors.cardDark : Colors.white;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, accent, isDark ? 0.26 : 0.24)!,
            Color.lerp(base, accent, isDark ? 0.08 : 0.08)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.14 : 0.16),
              ),
            ),
          ),
          Positioned(
            left: -34,
            top: 40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.08 : 0.10),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 22,
            child: Icon(
              Icons.sports_esports_rounded,
              size: 46,
              color: accent.withValues(alpha: isDark ? 0.30 : 0.38),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom scrim so overlaid text always stays legible over any artwork.
  /// Dark theme: black veil under white text. Light theme: soft white veil
  /// under ink text over the pastel covers.
  Widget _buildScrim(bool isDark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.0, 0.55, 1.0],
          colors: isDark
              ? [
                  Colors.black.withValues(alpha: 0.82),
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.0),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  Colors.white.withValues(alpha: 0.34),
                  Colors.white.withValues(alpha: 0.0),
                ],
        ),
      ),
    );
  }

  // ── Overlaid content ──────────────────────────────────────────────────

  Widget _buildPosterContent(bool isDark, Color accent, bool isMuted) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          compact ? 11 : 14, 0, compact ? 10 : 13, compact ? 10 : 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: compact ? 13.5 : 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.1,
              color: isMuted
                  ? (isDark ? Colors.white54 : Colors.black45)
                  : (isDark ? Colors.white : AppColors.textPrimaryLight),
              shadows: isDark
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 10.5,
                height: 1.3,
                color: isMuted
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              if (footer != null && footer!.isNotEmpty)
                Flexible(child: _buildFooterChip(accent, isMuted, isDark))
              else
                const Spacer(),
              const SizedBox(width: 8),
              _buildChevron(isMuted, compact, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterChip(Color accent, bool isMuted, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMuted
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08))
              : accent.withValues(alpha: isDark ? 0.30 : 0.40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMuted
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : _chipAccent(accent, isDark),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 8.5 : 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isMuted
                    ? (isDark ? Colors.white54 : Colors.black45)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.textPrimaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Accent color used inside chips/pills, readable on the pill surface.
  static Color _chipAccent(Color accent, bool isDark) {
    if (isDark) return _readableOnDark(accent);
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness > 0.42) {
      return hsl.withLightness(0.34).toColor();
    }
    return accent;
  }

  /// Minimal affordance replacing the old play button - the whole card is
  /// already tappable, this only signals "there is more this way".
  Widget _buildChevron(bool isMuted, bool compact, bool isDark) {
    final size = compact ? 22.0 : 26.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.88),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: size * 0.52,
        color: isMuted
            ? (isDark ? Colors.white24 : Colors.black26)
            : (isDark
                ? Colors.white.withValues(alpha: 0.85)
                : AppColors.textPrimaryLight),
      ),
    );
  }

  // ── Top pills ─────────────────────────────────────────────────────────
  Widget _buildBadge({
    required Color accent,
    required bool compact,
    required bool isDark,
  }) {
    final isMuted = isLocked || isComingSoon;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMuted
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08))
              : accent.withValues(alpha: isDark ? 0.45 : 0.50),
          width: 1,
        ),
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
                  color: Color(0xFFFF6B81),
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
                  ? (isDark ? Colors.white54 : Colors.black45)
                  : _chipAccent(accent, isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Brightens [accent] until it reads cleanly on dark artwork pills.
  static Color _readableOnDark(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness < 0.72) {
      return hsl.withLightness(0.78).toColor();
    }
    return accent;
  }

  Widget _buildMetaPill(bool isDark, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.82),
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
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── State overlays ────────────────────────────────────────────────────

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
}
