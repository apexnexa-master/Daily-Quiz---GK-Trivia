// lib/presentation/widgets/shimmer_loading.dart
import 'package:flutter/material.dart';

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Curated high-end colors for premium look
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [
                0.1,
                0.5,
                0.9,
              ],
              transform: _SlideGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double percent;

  const _SlideGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1.0), 0.0, 0.0);
  }
}

// ── Reusable Basic Shimmer Shapes ────────────────────────────────────
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Reusable Component Shimmer Loaders ───────────────────────────────
class QuizCardShimmer extends StatelessWidget {
  const QuizCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 16, borderRadius: BorderRadius.circular(4)),
              ShimmerBox(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerBox(width: 220, height: 24, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 12),
          ShimmerBox(width: 150, height: 16, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ShimmerBox(height: 48, borderRadius: BorderRadius.circular(14)),
              ),
              const SizedBox(width: 12),
              ShimmerCircle(size: 48),
            ],
          )
        ],
      ),
    );
  }
}

class CategoryGridShimmer extends StatelessWidget {
  const CategoryGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerCircle(size: 32),
                  ShimmerBox(width: 36, height: 16, borderRadius: BorderRadius.circular(4)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 90, height: 14, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  ShimmerBox(width: 60, height: 10, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              ShimmerBox(width: 24, height: 24, borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 12),
              ShimmerCircle(size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 70, height: 10, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ),
              ShimmerBox(width: 50, height: 22, borderRadius: BorderRadius.circular(11)),
            ],
          ),
        );
      },
    );
  }
}

class StatsCardShimmer extends StatelessWidget {
  const StatsCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 5,
              right: index == 2 ? 0 : 5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                ShimmerCircle(size: 32),
                const SizedBox(height: 10),
                ShimmerBox(width: 40, height: 18, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                ShimmerBox(width: 50, height: 10, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class QuestionShimmer extends StatelessWidget {
  const QuestionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question timer and count placeholder
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerBox(width: 60, height: 16, borderRadius: BorderRadius.circular(4)),
            ShimmerBox(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
          ],
        ),
        const SizedBox(height: 12),
        // Timer bar
        ShimmerBox(height: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 24),
        // Question Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 20, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 10),
              ShimmerBox(width: 250, height: 20, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 10),
              ShimmerBox(width: 150, height: 20, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Options Shimmer
        ...List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ShimmerCircle(size: 24),
                  const SizedBox(width: 16),
                  ShimmerBox(width: 180, height: 14, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
