// lib/core/services/bookmark_service.dart

import 'package:hive_flutter/hive_flutter.dart';

class BookmarkService {
  static const String _boxName = 'bookmarks';

  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> addBookmark(
      String questionId, Map<String, dynamic> questionData) async {
    final bookmarks = _box?.get('questions', defaultValue: <String, dynamic>{})
        as Map<String, dynamic>;
    bookmarks[questionId] = questionData;
    await _box?.put('questions', bookmarks);
  }

  Future<void> removeBookmark(String questionId) async {
    final bookmarks = _box?.get('questions', defaultValue: <String, dynamic>{})
        as Map<String, dynamic>;
    bookmarks.remove(questionId);
    await _box?.put('questions', bookmarks);
  }

  bool isBookmarked(String questionId) {
    final bookmarks = _box?.get('questions', defaultValue: <String, dynamic>{})
        as Map<String, dynamic>;
    return bookmarks.containsKey(questionId);
  }

  List<Map<String, dynamic>> getAllBookmarks() {
    final bookmarks = _box?.get('questions', defaultValue: <String, dynamic>{})
        as Map<String, dynamic>;
    return bookmarks.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> toggleBookmark(
      String questionId, Map<String, dynamic> questionData) async {
    if (isBookmarked(questionId)) {
      await removeBookmark(questionId);
    } else {
      await addBookmark(questionId, questionData);
    }
  }
}
