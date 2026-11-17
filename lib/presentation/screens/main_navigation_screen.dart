import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'play_zone_screen.dart';
import 'profile_screen.dart';
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
        extendBody: false,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            TabKeepAliveWrapper(child: HomeScreen()),
            TabKeepAliveWrapper(child: PlayZoneScreen()),
            TabKeepAliveWrapper(child: LeaderboardScreen(isTab: true)),
            TabKeepAliveWrapper(child: ProfileScreen()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.tileRaisedDark, AppColors.tileDark]
                    : [AppColors.tileRaisedLight, AppColors.tileLight],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF46515F)
                      : const Color(0xFFD6DEE9),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_rounded,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.sports_esports_rounded,
                      activeIcon: Icons.sports_esports_rounded,
                      label: 'Play',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.leaderboard_rounded,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Ranks',
                      isDark: isDark,
                      currentIndex: currentIndex,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.person_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
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
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (currentIndex != index) {
            HapticFeedback.selectionClick();
            ref.read(navigationTabProvider.notifier).state = index;
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: isSelected ? activeColor : inactiveColor,
              ),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, color, _) => Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: isSelected ? 22 : 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0,
              ),
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
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
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
