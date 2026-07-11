// lib/core/utils/app_logger.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message, {String name = 'APP'}) {
    if (kDebugMode) {
      developer.log('\x1B[32mINFO: $message\x1B[0m', name: name);
    }
  }

  static void warning(String message, {String name = 'APP'}) {
    if (kDebugMode) {
      developer.log('\x1B[33mWARNING: $message\x1B[0m', name: name, level: 900);
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String name = 'APP'}) {
    if (kDebugMode) {
      developer.log(
        '\x1B[31mERROR: $message\x1B[0m',
        name: name,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  static void debug(String message, {String name = 'APP'}) {
    if (kDebugMode) {
      developer.log('\x1B[34mDEBUG: $message\x1B[0m', name: name, level: 500);
    }
  }
}
