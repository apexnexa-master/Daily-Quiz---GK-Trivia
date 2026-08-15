// lib/presentation/games/widgets/game_scaffold.dart
// Shared background shell for every game screen so all games share one
// consistent look. Deliberately minimal: one gradient, no decoration noise.

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class GameScaffold extends StatelessWidget {
  final Widget child;
  final bool safeArea;

  const GameScaffold({
    super.key,
    required this.child,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.homeBackdropDark
              : AppColors.homeBackdropGradient,
        ),
        child: safeArea ? SafeArea(child: child) : child,
      ),
    );
  }
}
