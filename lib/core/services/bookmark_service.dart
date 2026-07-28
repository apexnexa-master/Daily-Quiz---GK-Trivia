// lib/core/services/bookmark_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'cloud_sync_service.dart';

class BookmarkService {
  static const String _boxName = 'bookmarks';

  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Map<String, dynamic> _getBookmarksMap() {
    final raw = _box?.get('questions');
    if (raw == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> addBookmark(
      String questionId, Map<String, dynamic> questionData) async {
    final bookmarks = _getBookmarksMap();
    bookmarks[questionId] = questionData;
    await _box?.put('questions', bookmarks);
    await CloudSyncService.instance.syncBookmarkAdded(questionId, questionData);
  }

  Future<void> removeBookmark(String questionId) async {
    final bookmarks = _getBookmarksMap();
    bookmarks.remove(questionId);
    await _box?.put('questions', bookmarks);
    await CloudSyncService.instance.syncBookmarkRemoved(questionId);
  }

  bool isBookmarked(String questionId) {
    final bookmarks = _getBookmarksMap();
    return bookmarks.containsKey(questionId);
  }

  List<Map<String, dynamic>> getAllBookmarks() {
    final bookmarks = _getBookmarksMap();
    return bookmarks.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
