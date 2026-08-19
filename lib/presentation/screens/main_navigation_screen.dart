import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'play_zone_screen.dart';
import 'battle_screen.dart';
import 'leaderboard_screen.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.initialIndex.clamp(0, 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationTabProvider.notifier).state =
          widget.initialIndex.clamp(0, 3);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = ref.watch(navigationTabProvider);

    // Listen to provider changes to animate the PageView
    ref.listen<int>(navigationTabProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showQuitDialog(context, isDark);
      },
      child: Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          TabKeepAliveWrapper(child: HomeScreen()),
          TabKeepAliveWrapper(child: PlayZoneScreen()),
          TabKeepAliveWrapper(child: BattleScreen(isTab: true)),
          TabKeepAliveWrapper(child: LeaderboardScreen(isTab: true)),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          top: 6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F171A).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.primary)
                    .withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: (isDark ? AppColors.primary : Colors.white)
                    .withValues(alpha: isDark ? 0.03 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, -2),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.sports_esports_outlined,
                      activeIcon: Icons.sports_esports_rounded,
                      label: 'Play Zone',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield_rounded,
                      label: 'Battle',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.leaderboard_outlined,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Leaderboard',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    required int currentIndex,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = isDark ? AppColors.primary : AppColors.primaryDark;
    final inactiveColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return GestureDetector(
      onTap: () {
        if (currentIndex != index) {
          ref.read(navigationTabProvider.notifier).state = index;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1))
                : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            if (isSelected && isDark)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 20,
            ),
            AnimatedCrossFade(
              firstChild: Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuitDialog(BuildContext context, bool isDark) {
    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
        title: Text(
          isBn ? 'বিদায় নিচ্ছেন?' : isHi ? 'जा रहे हैं?' : 'Leaving so soon?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        content: Text(
          isBn
              ? 'আপনি কি সত্যিই মাইন্ডসপ্রিন্ট ছেড়ে যেতে চান? আপনার মস্তিষ্ক এখনো প্রশিক্ষণ প্রয়োজন!'
              : isHi
                  ? 'क्या आप सच में MindSprint छोड़ना चाहते हैं? आपके दिमाग को अभी और ट्रेनिंग की ज़रूरत है!'
                  : 'Are you sure you want to quit MindSprint?\nYour brain still needs training!',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isBn ? 'থাকুন' : isHi ? 'रुकें' : 'Stay',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isBn ? 'বিদায়' : isHi ? 'बाहर' : 'Quit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class TabKeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const TabKeepAliveWrapper({super.key, required this.child});

  @override
  State<TabKeepAliveWrapper> createState() => _TabKeepAliveWrapperState();
}

class _TabKeepAliveWrapperState extends State<TabKeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
