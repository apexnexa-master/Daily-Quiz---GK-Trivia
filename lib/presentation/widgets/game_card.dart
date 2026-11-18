// lib/presentation/widgets/game_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_colors.dart';
import 'soft_duotone_icon.dart';

/// Modular matte game tile used across every game listing in the app.
///
/// A solid charcoal surface with a crisp directional hairline border replaces
/// ambient glows, so the enlarged 2.5D emblem stays the focal point. Badge /
/// meta pills live in the top row; compact tiles drop the bottom action pill
/// so the icon and title carry the card. The whole card is one tap target.
class GameCard extends StatelessWidget {
  /// Asset image rendered as fallback artwork when no [icon] is supplied.
  final String? imagePath;

  /// Compact flat-shaded vector emblem shown above the title.
  ///
  /// Takes priority over [icon] and artwork. The light-theme variant is loaded
  /// automatically from `assets/covers/light/`.
  final String? emblemPath;

  /// Custom fallback artwork (e.g. gradient + icon block for category tiles).
  final Widget? cover;

  /// Game icon rendered inside the 3D medallion above the title.
  final IconData? icon;

  /// Game / category title.
  final String? title;

  /// Short supporting description shown under the title.
  final String? subtitle;

  /// Small category label rendered as a pill on the top-left.
  final String? badge;

  /// Small metadata string (duration, question count, ...) shown top-right.
  final String? meta;

  /// Optional icon next to [meta].
  final IconData? metaIcon;

  /// Small footer hint rendered as an accent action pill near the bottom.
  ///
  /// Compact tiles omit it and rely on the whole-card tap affordance instead.
  final String? footer;

  /// Accent color driving the icon medallion, badges and glow.
  final Color? accent;

  /// Locked state: dimmed cover, lock badge and disabled tap.
  final bool isLocked;

  /// Live state: pulsing red dot inside the badge.
  final bool isLive;

  /// Coming soon state: frosted blur overlay on the card.
  final bool isComingSoon;

  /// Localized label for the coming soon overlay.
  final String comingSoonLabel;

  /// "New" state: a small accent tag pinned to the top-right corner.
  final bool isNew;

  /// Localized label for the new tag.
  final String newLabel;

  /// Tap target. Disabled automatically when locked / coming soon.
  final VoidCallback? onTap;

  /// Fixed card width. Omit to fill the available width.
  final double? width;

  /// Total tile height when [coverAspectRatio] is not set.
  final double coverHeight;

  /// When set, the whole tile scales with its width (`width / aspectRatio`).
  final double? coverAspectRatio;

  /// Whether the card should stretch to fill its parent height.
  final bool fillHeight;

  /// Compact rendering: smaller type and spacing for dense grids.
  final bool compact;

  const GameCard({
    super.key,
    this.imagePath,
    this.emblemPath,
    this.cover,
    this.icon,
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
    this.isNew = false,
    this.newLabel = 'NEW',
    this.onTap,
    this.width,
    this.coverHeight = 200,
    this.coverAspectRatio,
    this.fillHeight = false,
    this.compact = false,
  }) : assert(cover == null || imagePath == null,
            'Provide either [cover] or [imagePath], not both');

  /// Shared corner radius for every game card in the app.
  static const double radius = 16;

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
    final effectiveAccent = accent ?? AppColors.gamingCyan;
    final isMuted = isLocked || isComingSoon;

    final stack = Stack(
      children: [
        Positioned.fill(
          child: _buildContent(isDark, effectiveAccent, isMuted),
        ),
        if (isLocked) Positioned.fill(child: _buildLockedOverlay(isDark)),
        if (isComingSoon) Positioned.fill(child: _buildComingSoonOverlay()),
      ],
    );

    Widget sized = stack;
    if (!fillHeight) {
      sized = coverAspectRatio != null
          ? AspectRatio(aspectRatio: coverAspectRatio!, child: stack)
          : SizedBox(height: coverHeight, child: stack);
    }

    final card = Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: isDark
            ? (isMuted ? AppColors.gamingBg : AppColors.tileDark)
            : (isMuted ? AppColors.tileRaisedLight : AppColors.tileLight),
        border: isDark ? AppColors.tileBorderDark : AppColors.tileBorderLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: sized,
    );

    return AnimatedScaleButton(
      onTap: isMuted ? null : onTap,
      pressedScale: 0.97,
      child: card,
    );
  }

  // ── Main content ─────────────────────────────────────────────────────

  Widget _buildContent(bool isDark, Color accent, bool isMuted) {
    final pad = compact ? 8.0 : 15.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad * 0.85, pad, pad * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopRow(isDark, accent, isMuted),
          Expanded(child: _buildHero(isDark, accent)),
          Text(
            title ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 14 : 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.25,
              height: 1.15,
              color: isMuted
                  ? (isDark ? Colors.white54 : Colors.black45)
                  : (isDark ? Colors.white : AppColors.textPrimaryLight),
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            SizedBox(height: compact ? 2 : 5),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 9.5 : 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: isMuted
                    ? (isDark ? Colors.white30 : Colors.black38)
                    : (isDark
                        ? AppColors.gamingTextSecondary.withValues(alpha: 0.82)
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
          if (!compact && footer != null && footer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: _buildFooterPill(isDark, accent, isMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hero icon / artwork ──────────────────────────────────────────────

  Widget _buildHero(bool isDark, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        if (available <= 0) return const SizedBox.shrink();

        if (emblemPath != null) {
          final preferred = compact ? 80.0 : 92.0;
          final size = available < preferred ? available : preferred;
          return Center(child: _buildEmblem(isDark, size));
        }

        if (icon == null && (cover != null || imagePath != null)) {
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: available,
                width: double.infinity,
                child: _buildArtwork(isDark, accent),
              ),
            ),
          );
        }

        final preferred = compact ? 64.0 : 76.0;
        final size = available < preferred ? available : preferred;
        return Center(child: _buildIconMedallion(isDark, accent, size));
      },
    );
  }

  Widget _buildEmblem(bool isDark, double size) {
    var path = emblemPath!;
    if (!isDark &&
        path.startsWith('assets/covers/') &&
        path.endsWith('.svg') &&
        !path.contains('covers/light/')) {
      path = path.replaceFirst('assets/covers/', 'assets/covers/light/');
    }
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildArtwork(bool isDark, Color accent) {
    if (cover != null) return cover!;
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
    return _buildIconMedallion(isDark, accent, 60);
  }

  Widget _buildIconMedallion(bool isDark, Color accent, double size) {
    if (size <= 4) return const SizedBox.shrink();
    return SoftDuotoneIcon(
      icon: icon ?? Icons.sports_esports_rounded,
      accent: accent,
      size: size,
      isDark: isDark,
    );
  }

  // ── Top pills ────────────────────────────────────────────────────────

  Widget _buildTopRow(bool isDark, Color accent, bool isMuted) {
    final showBadge = badge != null && badge!.isNotEmpty;
    final showMeta = meta != null && meta!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metaMaxWidth = constraints.maxWidth * 0.46;
        return SizedBox(
          height: compact ? 17 : 22,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showBadge
                      ? _buildBadge(
                          accent: accent,
                          compact: compact,
                          isDark: isDark,
                          isMuted: isMuted,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (showMeta)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metaMaxWidth),
                  child: _buildMetaPill(isDark, compact),
                ),
              if (isNew) ...[
                if (showMeta) const SizedBox(width: 5),
                _buildNewTag(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required Color accent,
    required bool compact,
    required bool isDark,
    required bool isMuted,
  }) {
    final tint = isMuted
        ? (isDark ? Colors.white38 : Colors.black38)
        : _chipAccent(accent, isDark);
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 110 : 150),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.tileRaisedDark : AppColors.tileLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMuted
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08))
              : accent.withValues(alpha: isDark ? 0.40 : 0.32),
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
                  color: Color(0xFFFF4D6D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: compact ? 4 : 5),
          ],
          Flexible(
            child: Text(
              badge!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 7.5 : 9,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.5 : 0.7,
                color: tint,
              ),
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
        color: isDark ? AppColors.tileRaisedDark : AppColors.tileLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF46515F) : const Color(0xFFD6DEE9),
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
              color: isDark ? AppColors.gamingTextSecondary : Colors.black54,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              meta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTag() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gamingCyan, AppColors.gamingGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.gamingCyan.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        newLabel,
        style: TextStyle(
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: AppColors.gamingBg,
        ),
      ),
    );
  }

  Widget _buildFooterPill(bool isDark, Color accent, bool isMuted) {
    if (footer == null || footer!.isEmpty) {
      return SizedBox(height: compact ? 16 : 18);
    }

    final tint = isMuted ? (isDark ? Colors.white38 : Colors.black38) : accent;
    final textColor = isMuted
        ? (isDark ? Colors.white38 : Colors.black38)
        : (isDark
            ? Colors.white.withValues(alpha: 0.90)
            : AppColors.textPrimaryLight);

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: tint.withValues(alpha: isDark ? 0.26 : 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 8.5 : 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_rounded,
            size: compact ? 11 : 13,
            color: tint,
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

  /// Brightens [accent] until it reads cleanly on dark artwork pills.
  static Color _readableOnDark(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness < 0.72) {
      return hsl.withLightness(0.78).toColor();
    }
    return accent;
  }

  // ── State overlays ───────────────────────────────────────────────────

  Widget _buildLockedOverlay(bool isDark) {
    return Container(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.38),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.gamingSurface : Colors.white)
                .withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.gamingBorder : Colors.black12,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
        color: AppColors.gamingBg.withValues(alpha: 0.42),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gamingBg.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.gamingBorder,
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
