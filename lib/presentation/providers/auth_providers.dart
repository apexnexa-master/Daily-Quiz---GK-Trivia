// lib/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/firestore_models.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) => CloudSyncService.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  } catch (_) {
    return null;
  }
});

final cloudUserStatsProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  try {
    await ref.read(cloudSyncServiceProvider).syncStatsToCloud();
  } catch (_) {}

  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  } catch (_) {
    return null;
  }
});

// ── Language State ────────────────────────────────────────────
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(AppConstants.defaultLanguage) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(AppConstants.prefLanguage) ?? AppConstants.defaultLanguage;
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLanguage, lang);
  }
}

// ── Sound Settings State ────────────────────────────────────────
class SoundSettingsNotifier extends StateNotifier<SoundSettings> {
  SoundSettingsNotifier() : super(const SoundSettings()) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = SoundSettings(
      soundEnabled: prefs.getBool('soundEnabled') ?? true,
      tapFeedback: prefs.getBool('tapFeedback') ?? true,
      correctAnswerSound: prefs.getBool('correctAnswerSound') ?? true,
      wrongAnswerSound: prefs.getBool('wrongAnswerSound') ?? true,
    );
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', enabled);
  }

  Future<void> setTapFeedback(bool enabled) async {
    state = state.copyWith(tapFeedback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tapFeedback', enabled);
  }

  Future<void> setCorrectSound(bool enabled) async {
    state = state.copyWith(correctAnswerSound: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('correctAnswerSound', enabled);
  }

  Future<void> setWrongSound(bool enabled) async {
    state = state.copyWith(wrongAnswerSound: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wrongAnswerSound', enabled);
  }
}

class SoundSettings {
  final bool soundEnabled;
  final bool tapFeedback;
  final bool correctAnswerSound;
  final bool wrongAnswerSound;

  const SoundSettings({
    this.soundEnabled = true,
    this.tapFeedback = true,
    this.correctAnswerSound = true,
    this.wrongAnswerSound = true,
  });

  SoundSettings copyWith({
    bool? soundEnabled,
    bool? tapFeedback,
    bool? correctAnswerSound,
    bool? wrongAnswerSound,
  }) {
    return SoundSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      tapFeedback: tapFeedback ?? this.tapFeedback,
      correctAnswerSound: correctAnswerSound ?? this.correctAnswerSound,
      wrongAnswerSound: wrongAnswerSound ?? this.wrongAnswerSound,
    );
  }
}

final soundSettingsProvider = StateNotifierProvider<SoundSettingsNotifier, SoundSettings>((ref) {
  return SoundSettingsNotifier();
});

// ── Pro Status ────────────────────────────────────────────────
final isProProvider = FutureProvider<bool>((ref) async {
  final box = await ref.watch(_hiveBoxProvider.future);
  return box.get(AppConstants.hiveKeyIsPro) == 'true';
});

final _hiveBoxProvider = FutureProvider((ref) async {
  return Hive.openBox<String>(AppConstants.hiveBoxUser);
});
