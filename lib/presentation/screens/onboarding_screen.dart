// lib/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/username_utils.dart';
import '../providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _usernameController = TextEditingController();
  int _selectedAvatarIndex = 1; // Default to Felix
  bool _isLoading = false;

  final List<AvatarOption> _avatars = [
    AvatarOption(
      name: 'Scholar',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Buster',
    ),
    AvatarOption(
      name: 'Elite',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Felix',
    ),
    AvatarOption(
      name: 'Boy',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Jack',
    ),
    AvatarOption(
      name: 'Scholar F',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Mia',
    ),
    AvatarOption(
      name: 'Tactician',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Zack',
    ),
    AvatarOption(
      name: 'Zen',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka',
    ),
    AvatarOption(
      name: 'Child',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Liam',
    ),
    AvatarOption(
      name: 'Cyber',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Nico',
    ),
    AvatarOption(
      name: 'Explorer',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=George',
    ),
    AvatarOption(
      name: 'Logic',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Luna',
    ),
    AvatarOption(
      name: 'Girl',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Zoe',
    ),
    AvatarOption(
      name: 'Sage',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Arthur',
    ),
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _skipSetup() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      final username = user?.displayName ?? 'Explorer';
      final photoUrl = user?.photoUrl ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('temp_username', username);
      await prefs.setString('temp_photo_url', photoUrl);

      // Save onboarding_complete: true to Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'onboarding_complete': true,
          });
        } catch (_) {}
      }

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skip failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeSetup() async {
    final username = _usernameController.text.trim();
    final error = await UsernameUtils.validateWithUniqueness(username);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('temp_username', username);
      final avatarUrl = _avatars[_selectedAvatarIndex].url;
      await prefs.setString('temp_photo_url', avatarUrl);

      // Update Firebase Auth & Firestore user document if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.updateDisplayName(username);
          await currentUser.updatePhotoURL(avatarUrl);
        } catch (_) {}
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'display_name': username,
            'photo_url': avatarUrl,
            'onboarding_complete': true,
          });
        } catch (_) {}
      }

      ref.invalidate(authStateProvider);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
            ),
          ),
          // Atmospheric glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: isDark ? 0.05 : 0.02),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Title Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Create Your Identity',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _skipSetup,
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a username and select an avatar to represent you in the Arena.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Username input
                        Text(
                          'Enter Username',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.outlineVariant : Colors.black12,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _usernameController,
                            maxLength: UsernameUtils.maxLength,
                            style: TextStyle(color: fgColor, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'MindAthlete123',
                              hintStyle: TextStyle(color: fgColor.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              counterText: '',
                              suffixIcon: Icon(
                                Icons.edit_rounded,
                                color: AppColors.primary.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Avatar Selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CHOOSE ATHLETE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              '12 Styles Available',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _avatars.length,
                          itemBuilder: (context, index) {
                            final avatar = _avatars[index];
                            final isSelected = _selectedAvatarIndex == index;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedAvatarIndex = index);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : (isDark ? AppColors.outlineVariant : Colors.black12),
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      // Image
                                      Image.network(
                                        avatar.url,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                                            child: const Icon(Icons.person_rounded, color: AppColors.outline),
                                          );
                                        },
                                      ),
                                      // Bottom gradient overlay
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: 30,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Name Label
                                      Positioned(
                                        bottom: 4,
                                        left: 8,
                                        child: Text(
                                          avatar.name,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      // Selection Indicator
                                      if (isSelected)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              size: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer Continue Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _completeSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Complete Setup',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can change these later in your Profile settings.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white30 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarOption {
  final String name;
  final String url;

  AvatarOption({required this.name, required this.url});
}
