// lib/core/utils/offline_manager.dart
// Offline + Performance
// Cache-first strategy:
//   1. Read from Hive (0 Firestore reads)
//   2. On cache miss → read Firestore cache (local SDK cache, still 0 network)
//   3. On SDK cache miss → real network read

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class OfflineManager {
  OfflineManager._();
  static final OfflineManager instance = OfflineManager._();

  final Connectivity _connectivity = Connectivity();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void init() {
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      if (wasOnline != _isOnline) {
        _connectionController.add(_isOnline);
      }
    });
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _connectionController.add(_isOnline);
  }

  // Cache a quiz with today's date key
  Future<void> cacheQuiz(String quizId, String jsonData) async {
    final box = await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
    await box.put('quiz_$quizId', jsonData);
    await box.put('last_cached', quizId);
  }

  Future<String?> getCachedQuiz(String quizId) async {
    final box = await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
    return box.get('quiz_$quizId');
  }

  // Clear old quiz caches (keep only last 3 days to save storage)
  Future<void> pruneOldCache() async {
    final box = await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
    final now = DateTime.now();
    final keysToDelete = box.keys.where((k) {
      if (!k.toString().startsWith('quiz_')) return false;
      try {
        final datePart = k.toString().replaceFirst('quiz_', '').split('_')[0];
        final date = DateTime.parse(datePart);
        return now.difference(date).inDays > 3;
      } catch (_) {
        return false;
      }
    }).toList();
    await box.deleteAll(keysToDelete);
  }
}

// Network Status Banner Widget
class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  late StreamSubscription _subscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = OfflineManager.instance.isOnline;
    _subscription = OfflineManager.instance.connectionStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.orange.shade700,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'You are offline - using cached data',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// lib/core/utils/date_utils.dart
// ─────────────────────────────────────────────────────────────
class AppDateUtils {
  AppDateUtils._();

  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  }

  static String weekId(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final week = ((date.difference(jan1).inDays + jan1.weekday) / 7).ceil();
    return '${date.year}-W${_pad(week)}';
  }

  static String currentWeekId() => weekId(DateTime.now());

  static String formatReadable(String yyyyMmDd, String lang) {
    try {
      final parts = yyyyMmDd.split('-');
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[0]);

      if (lang == 'bn') {
        const bnMonths = [
          'জানুয়ারি',
          'ফেব্রুয়ারি',
          'মার্চ',
          'এপ্রিল',
          'মে',
          'জুন',
          'জুলাই',
          'আগস্ট',
          'সেপ্টেম্বর',
          'অক্টোবর',
          'নভেম্বর',
          'ডিসেম্বর'
        ];
        return '$day ${bnMonths[month - 1]}, $year';
      }
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '$day ${months[month - 1]}, $year';
    } catch (_) {
      return yyyyMmDd;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
