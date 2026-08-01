// lib/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _usernameController = TextEditingController();
  int _selectedAvatarIndex = 5; // Default to Avatar 6 ("Prime")
  bool _isLoading = false;

  final List<AvatarOption> _avatars = [
    AvatarOption(
      name: 'Elite',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDJwTazYlei65w4uEOjSsNStg-LmPZRp35ymd6lSEAViDTgkyDLuyDMJGSPKx7zBZbbAtUhv_OJnABWKrgrz_KfKqgj6Fu_d5JqOVLjQ84QRETVRIpOKOekM8cB7k7-tCpFANUItkBUfUIWUrlfumfhWzauBr7_f0xJptk00Aw5NjtmseWOUFEiUGquICen-_uLcCsWGYPwB3OZzyCDC503NwmtZg87g6sZFARhffQXw1UrLMaegicnAw',
    ),
    AvatarOption(
      name: 'Scholar',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD2bgZ177KVrJ6BjCpUqOTbazZ_mIAzQUyRj9ltBAixtz3874_u5jD4CtBDLw9nDnxqRsXKTSOAdykJmSc5o24ecixcWHFgSGwJqkFVMQyueV3_g94NlFvYPJSEjt1LKD90GF7-WQlVQRpoZWBM0Z3rmH6yW-BBHqZd5HP1PDqQjOmn4Bl57gE78qr3uVbgG2FURMrtPeoh0lCrfkOYF2wcGLkLurorQoavg8_rCl41vDAVRICiXQWvBQ',
    ),
    AvatarOption(
      name: 'Tactician',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDBDRy5TFeOtG4yG5VJwaSlzl0SGbTyo9Yk1-6Tt9RoCaEXoxAA-oz4uPYXQAnAC_45MrX6ea3V4o1fi2_B289DziHX8F0x2ENoatOnK6eZb40Sc1j5qQdIQVuYwe-tgMZI2vWGAmvOOLkqD7inJylHqck1wLEKDFHyuUuuo2NnYKTBWVWAVjSTWSUxzRpolZXhwfU4-3fhA7X_AGBEKSrTQH0w6E0qLJtRRNR9KC6ccGxTlnPJHZp9jQ',
    ),
    AvatarOption(
      name: 'Zen',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC9Qf316sjT8E4et5znGbJvSKDo2QCByntrbF2wLqNB7q7pO5QIPdoz0glaUho5Em-WNdNgDpVwKJNvnfTidIZAMNrWnajERQOx_fzD1OuGEmgyZQOmqnZWLMFCpWa5A-zK3Zn2qt3P6ANTlWkOpr9F6BLQpBRHDwtcTMCb9oWA57z6aVrhvdr4cbUNg8BHd4SHwWa17KNEoxgAqyiSjtwHjV3Eo7n0qWQuWJPEYjA3j3qxpJiW_-SzZA',
    ),
    AvatarOption(
      name: 'Logic',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAH2EaqXxPaQ8_9-2MsetPATtji6Lf3aikljo8s5LXQd7fQVR3uWgiV1nbJqYU83jKYk3itIC8N52TbsKVDETVJcqK0WqaGpLGoicCUnEsyjxOTcuGOljLM66fHMnhu4fMvCh4etS87Ln5_rLcrUpjnZRgGAE-GhxLQroZ8Eb09KdfjIY7BLbA6mF7frornHoDnpns8YWjn0qo20jhzLQuu_VEnvsQIFmZaEk69ubcPMTVT1ADa_R1a7Q',
    ),
    AvatarOption(
      name: 'Prime',
      url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAMqKOrT2GFjwQfNMiSGpWaWoMLncV7Auc98xmRW3lhnJdfX2H8TJBZOkWY_A4FJ2oWmgckfrdu7a2XGSCdUDE45nrqbkunYCwHKlFbfDxT8jpF1U2XjqWAX-zcQR_xRQ4OXxRTSzU8-qb1HkJVPZfN88ZJ-GwOJSmGrxlWugv3fWmHgdL4edqoilFxiYgNNW6n7zjAkR4VnKKmft6GtfRKQJSkEW7K50mnNgVstuUkxvZ_F6JOV2DWCA',
    ),
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a username'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('temp_username', username);
      await prefs.setString('temp_photo_url', _avatars[_selectedAvatarIndex].url);
      
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
                        Text(
                          'Create Your Identity',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
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
                            style: TextStyle(color: fgColor, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'MindAthlete123',
                              hintStyle: TextStyle(color: fgColor.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                              '6 Styles Available',
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
