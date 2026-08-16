// lib/core/scoring/scoring_store.dart
// Tiny storage layer for the progression engine.
//
// Backed by a Hive box when the app is running; falls back to an in-memory
// map so unit tests and un-initialized flows never throw. State that must
// survive restarts (skill ratings, brain score, XP) is written as JSON.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ScoringStore {
  ScoringStore._();
  static final ScoringStore instance = ScoringStore._();

  static const String _boxName = 'progression_v2';
  static const String keySkillRatings = 'skill_ratings';
  static const String keyBrainState = 'brain_state';
  static const String keyXpState = 'xp_state';
  static const String keyCompletedChallenges = 'completed_challenges';
  static const String keyWeeklyResults = 'weekly_results';
  static const String keyActivityStats = 'activity_stats';
  static const String keyCompetitionStats = 'competition_stats';

  Box<String>? _box;
  final Map<String, String> _memory = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Only callable after Hive.init / Hive.initFlutter (see main.dart).
      // Falls back to the in-memory map when Hive is unavailable.
      _box = await Hive.openBox<String>(_boxName);
    } catch (_) {
      _box = null;
    }
  }

  String? get(String key) {
    try {
      final value = _box?.get(key);
      if (value != null) return value;
    } catch (_) {}
    return _memory[key];
  }

  Future<void> put(String key, String value) async {
    _memory[key] = value;
    try {
      await _box?.put(key, value);
    } catch (_) {}
  }

  Map<String, dynamic> readJson(String key) {
    final raw = get(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      put(key, jsonEncode(value));

  /// Test-only: clears all cached and persisted state so each test starts
  /// from a clean slate.
  @visibleForTesting
  Future<void> resetForTest() async {
    _memory.clear();
    try {
      await _box?.clear();
    } catch (_) {}
    _initialized = false;
  }
}
