// lib/presentation/widgets/profile/profile_overview.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle shapes
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                children: [
                  // App Bar / Top Actions
                  Row(
                    children: [
                      const Spacer(),
                      // Premium tier badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: Colors.amber.shade300, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              isBn
                                  ? 'বিনামূল্যে'
                                  : isHi
                                      ? 'मुफ्त'
                                      : 'Free',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // User Profile Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 42,
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
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (user.isAnonymous)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.warning.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // User details text with Edit Username icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName?.isNotEmpty == true ? user.displayName! : 'Quiz Warrior',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                        onPressed: () => _showEditUsernameDialog(context, ref, user.displayName ?? ''),
                        tooltip: 'Edit Username',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                  if (user.email != null && user.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (user.isAnonymous) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isBn ? 'অতিথি ব্যবহারকারী' : 'Guest User',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
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
