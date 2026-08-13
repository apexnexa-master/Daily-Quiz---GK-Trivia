// lib/presentation/widgets/profile/profile_overview.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';

class ProfileOverview extends ConsumerWidget {
  final dynamic user;
  final String lang;
  final bool isDark;

  const ProfileOverview({
    super.key,
    required this.user,
    required this.lang,
    required this.isDark,
  });

  static final List<Map<String, String>> _avatarOptions = [
    {'name': 'Scholar', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Buster'},
    {'name': 'Elite', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Felix'},
    {'name': 'Boy', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Jack'},
    {'name': 'Scholar F', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Mia'},
    {'name': 'Tactician', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Zack'},
    {'name': 'Zen', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka'},
    {'name': 'Child', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Liam'},
    {'name': 'Cyber', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Nico'},
    {'name': 'Explorer', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=George'},
    {'name': 'Logic', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Luna'},
    {'name': 'Girl', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Zoe'},
    {'name': 'Sage', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Arthur'},
  ];

  void _showEditAvatarDialog(BuildContext context, WidgetRef ref, String? currentPhotoUrl) {
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.face_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Choose Avatar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null) ...[
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _avatarOptions.length,
                      itemBuilder: (context, index) {
                        final avatar = _avatarOptions[index];
                        final url = avatar['url']!;
                        final name = avatar['name']!;
                        final isSelected = currentPhotoUrl == url;

                        return GestureDetector(
                          onTap: isLoading
                              ? null
                              : () async {
                                  setModalState(() {
                                    isLoading = true;
                                    errorMsg = null;
                                  });

                                  try {
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser != null) {
                                      await currentUser.updatePhotoURL(url);
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUser.uid)
                                          .update({'photo_url': url});
                                      
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setString('temp_photo_url', url);
                                    }
                                    ref.invalidate(authStateProvider);
                                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  } catch (e) {
                                    setModalState(() {
                                      isLoading = false;
                                      errorMsg = 'Error: $e';
                                    });
                                  }
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person)),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    left: 4,
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black54,
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
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUsernameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Change Username',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'Enter new username',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) {
                          setModalState(() => errorMsg = 'Name cannot be empty');
                          return;
                        }

                        setModalState(() {
                          isLoading = true;
                          errorMsg = null;
                        });

                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            await currentUser.updateDisplayName(newName);
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .update({'display_name': newName});
                          }
                          ref.invalidate(authStateProvider);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            errorMsg = 'Error updating name: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle shapes
          Positioned(
            top: -45,
            right: -25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -25,
            left: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  // App Bar / Top Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back arrow only when there's a route to pop (e.g. pushed
                      // via /profile). Hidden when Profile is a bottom-nav tab.
                      if (Navigator.of(context).canPop())
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        const SizedBox(width: 24),
                      // Premium tier badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: Colors.amber.shade300, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              isBn
                                  ? 'বিনামূল্যে'
                                  : isHi
                                      ? 'मुफ्त'
                                      : 'Free',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // User Profile Avatar
                  GestureDetector(
                    onTap: user.isAnonymous
                        ? null
                        : () => _showEditAvatarDialog(context, ref, user.photoURL),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.white.withValues(alpha: 0.4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundImage:
                                user.photoURL != null && user.photoURL!.isNotEmpty
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: user.photoURL == null || user.photoURL!.isEmpty
                                ? Text(
                                    (user.displayName?.isNotEmpty == true
                                            ? user.displayName!
                                            : 'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (!user.isAnonymous)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.black, size: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // User details text with Edit Username icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName?.isNotEmpty == true ? user.displayName! : 'Quiz Warrior',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (!user.isAnonymous) ...[
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showEditUsernameDialog(context, ref, user.displayName ?? ''),
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.edit_rounded, 
                                color: Colors.white70, 
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.email != null && user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (user.isAnonymous) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                            isBn ? 'অতিথি ব্যবহারকারী' : 'Guest User',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
