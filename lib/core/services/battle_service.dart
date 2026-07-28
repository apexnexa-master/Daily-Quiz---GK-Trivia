// lib/core/services/battle_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/firestore_models.dart';
import '../../data/local_quiz_data.dart';

class BattleService {
  static final BattleService _instance = BattleService._internal();
  factory BattleService() => _instance;
  BattleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of a specific battle room
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _firestore.collection('battle_rooms').doc(roomId).snapshots();
  }

  // Create a room
  Future<String> createRoom({
    required String playerNickname,
    required String playerId,
    required String avatarUrl,
  }) async {
    final random = Random();
    final roomId = (100000 + random.nextInt(900000)).toString();

    // Select 5 random questions from general quiz mode
    final localQuestions = LocalQuizData.getAllQuestionsForMode('GENERAL');
    localQuestions.shuffle();
    final selectedQuestions = localQuestions
        .take(5)
        .map((q) => q.toFirestore()..['id'] = q.id)
        .toList();

    final roomData = {
      'roomId': roomId,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'questions': selectedQuestions,
      'players': {
        playerId: {
          'name': playerNickname,
          'avatar': avatarUrl,
          'score': 0,
          'currentQuestion': 0,
          'ready': true,
          'isFinished': false,
        }
      }
    };

    await _firestore.collection('battle_rooms').doc(roomId).set(roomData);
    return roomId;
  }

  // Join a room
  Future<bool> joinRoom({
    required String roomId,
    required String playerNickname,
    required String playerId,
    required String avatarUrl,
  }) async {
    final docRef = _firestore.collection('battle_rooms').doc(roomId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return false;
    final data = snapshot.data()!;
    if (data['status'] != 'waiting') return false;

    final players = Map<String, dynamic>.from(data['players'] ?? {});
    if (players.length >= 2) return false;

    players[playerId] = {
      'name': playerNickname,
      'avatar': avatarUrl,
      'score': 0,
      'currentQuestion': 0,
      'ready': true,
      'isFinished': false,
    };

    await docRef.update({
      'players': players,
      'status': 'playing',
    });
    return true;
  }

  // Update player progress in room
  Future<void> updateProgress({
    required String roomId,
    required String playerId,
    required int score,
    required int currentQuestion,
    required bool isFinished,
  }) async {
    final docRef = _firestore.collection('battle_rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      
      if (players.containsKey(playerId)) {
        players[playerId]['score'] = score;
        players[playerId]['currentQuestion'] = currentQuestion;
        players[playerId]['isFinished'] = isFinished;
      }

      final allFinished = players.values.every((p) => p['isFinished'] == true);
      final Map<String, dynamic> updateData = {
        'players': players,
      };
      
      if (allFinished) {
        updateData['status'] = 'finished';
      }

      transaction.update(docRef, updateData);
    });
  }

  // Clean up / delete room
  Future<void> deleteRoom(String roomId) async {
    try {
      await _firestore.collection('battle_rooms').doc(roomId).delete();
    } catch (_) {}
  }
}
