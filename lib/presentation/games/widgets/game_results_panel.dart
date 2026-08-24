// lib/presentation/games/widgets/game_results_panel.dart
// Shared full-screen results overlay. One consistent layout for every game:
// title -> score count-up -> stats grid -> actions. The panel only renders
// data; localization and share/play-again logic live in each game screen.
//
// Modern glass treatment: translucent scrim (lets a game's aurora background
// show through), gradient score and glass stat cards.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class GameResultStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const GameResultStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class GameResultsPanel extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int score;
  final bool isNewBest;

  /// Optional 1-3 star rating shown under the score. Null hides the row.
  final int? stars;
  final List<GameResultStat> stats;
  final String playAgainLabel;
  final String? shareLabel;
  final String exitLabel;
  final String? footerHint;
  final VoidCallback onPlayAgain;
  final VoidCallback? onShare;
  final VoidCallback onExit;

  /// When set, the panel renders a single primary "Continue" action instead of
  /// the play-again / share / exit stack. Used while a game runs inside a
  /// workout: the player must advance to the next game, not replay this one.
  final String? continueLabel;
  final VoidCallback? onContinue;

  const GameResultsPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.score,
    required this.isNewBest,
    this.stars,
    required this.stats,
    required this.playAgainLabel,
    this.shareLabel,
    required this.exitLabel,
    this.footerHint,
    required this.onPlayAgain,
    this.onShare,
    required this.onExit,
    this.continueLabel,
    this.onContinue,
  });

  @override
  State<GameResultsPanel> createState() => _GameResultsPanelState();
}

class _GameResultsPanelState extends State<GameResultsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Material(
        color: (isDark ? const Color(0xFF05080E) : Colors.white).withValues(alpha: isDark ? 0.95 : 0.97),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? const Color(0xFF0B0E14) : Colors.white).withValues(alpha: 0.0),
                (isDark ? const Color(0xFF0B0E14) : Colors.white).withValues(alpha: 0.55),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEyebrow(isDark),
                        if (widget.isNewBest) ...[
                          AppSpacing.vMd,
                          _buildNewBestPill(),
                        ],
                        AppSpacing.vLg,
                        _buildScore(),
                        if (widget.stars != null) ...[
                          AppSpacing.vSm,
                          _buildStars(),
                        ],
                        if (widget.subtitle != null) ...[
                          AppSpacing.vMd,
                          Text(
                            widget.subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                        if (widget.footerHint != null) ...[
                          AppSpacing.vXs,
                          Text(
                            widget.footerHint!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                        AppSpacing.vXxl,
                        _buildStatsGrid(isDark),
                        AppSpacing.vXxl,
                        _buildActions(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEyebrow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Text(
        widget.title.toUpperCase(),
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
        ),
      ),
    );
  }

  Widget _buildNewBestPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.rRound),
        boxShadow: [
          BoxShadow(
            color: AppColors.coin.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 17, color: Colors.black),
          const SizedBox(width: 7),
          Text(
            'NEW BEST!',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScore() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: widget.score),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3EE6B0), Color(0xFF00F1FE)],
          ).createShader(bounds),
          child: Text(
            '$value',
            style: GoogleFonts.montserrat(
              fontSize: 88,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStars() {
    final stars = widget.stars!.clamp(0, 3);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.scale(
                scale: Curves.easeOutBack
                    .transform(((t * 3 - i).clamp(0.0, 1.0))),
                child: Icon(
                  i < stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 34,
                  color: i < stars
                      ? const Color(0xFFFBBF24)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.black26),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        for (var i = 0; i < widget.stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _buildStatCard(widget.stats[i], isDark)),
        ],
      ],
    );
  }

  Widget _buildStatCard(GameResultStat stat, bool isDark) {
    final accent = stat.color;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)]
              : [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.65)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.rXl),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.40 : 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(stat.icon, size: 14, color: accent),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    if (widget.onContinue != null) {
      return SizedBox(
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3EE6B0), Color(0xFF00E7A0)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.continueLabel!,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3EE6B0), Color(0xFF00E7A0)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.onPlayAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.replay_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.playAgainLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onShare != null) ...[
          AppSpacing.vMd,
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: widget.onShare,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                side: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.rLg),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ios_share_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.shareLabel!,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        AppSpacing.vMd,
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: widget.onExit,
            child: Text(
              widget.exitLabel,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
