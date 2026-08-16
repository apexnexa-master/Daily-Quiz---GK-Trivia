// lib/core/services/battle_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/firestore_models.dart';
import 'question_service.dart';

class BattleService {
  static final BattleService _instance = BattleService._internal();
  factory BattleService() => _instance;
  BattleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of a specific battle room
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _firestore.collection('battle_rooms').doc(roomId).snapshots();
  }

  Future<String> createRoom({
    required String playerNickname,
    required String playerId,
    required String avatarUrl,
    int questionCount = 5,
    String gameType = 'TRIVIA',
  }) async {
    final random = Random();
    final roomId = (100000 + random.nextInt(900000)).toString();

    // Fetch combined questions from Firebase practice questions + local questions
    final questionsList = await QuestionService.instance.fetchCombinedQuestions(examMode: 'GENERAL');
    questionsList.shuffle();
    final selectedQuestions = questionsList
        .take(questionCount)
        .map((q) => q.shuffleOptions())
        .map((q) => q.toFirestore()..['id'] = q.id)
        .toList();

    final roomData = {
      'roomId': roomId,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'questions': selectedQuestions,
      'gameType': gameType,
      'players': {
        playerId: {
          'name': playerNickname,
          'avatar': avatarUrl,
          'score': 0,
          'currentQuestion': 0,
          'ready': true,
          'isFinished': false,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
          'isDisconnected': false,
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
      'lastActive': DateTime.now().millisecondsSinceEpoch,
      'isDisconnected': false,
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
    bool? hasForfeited,
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
        players[playerId]['lastActive'] = DateTime.now().millisecondsSinceEpoch;
        if (hasForfeited != null) {
          players[playerId]['hasForfeited'] = hasForfeited;
        }
      }

      final allFinished = players.values.every((p) => p['isFinished'] == true);
      final anyForfeited = players.values.any((p) => p['hasForfeited'] == true);
      final Map<String, dynamic> updateData = {
        'players': players,
      };
      
      if (allFinished || anyForfeited) {
        updateData['status'] = 'finished';
      }

      transaction.update(docRef, updateData);
    });
  }

  // Update player heartbeat timestamp
  Future<void> updateHeartbeat(String roomId, String playerId) async {
    try {
      final docRef = _firestore.collection('battle_rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        
        if (players.containsKey(playerId)) {
          players[playerId]['lastActive'] = DateTime.now().millisecondsSinceEpoch;
        }

        transaction.update(docRef, {
          'players': players,
        });
      });
    } catch (_) {}
  }

  // Update player connection status
  Future<void> updateConnectionStatus(String roomId, String playerId, bool isConnected) async {
    try {
      final docRef = _firestore.collection('battle_rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        
        if (players.containsKey(playerId)) {
          players[playerId]['isDisconnected'] = !isConnected;
        }

        transaction.update(docRef, {
          'players': players,
        });
      });
    } catch (_) {}
  }

  // Clean up / delete room
  Future<void> deleteRoom(String roomId) async {
    try {
      await _firestore.collection('battle_rooms').doc(roomId).delete();
    } catch (_) {}
  }

  // Request a rematch
  Future<void> requestRematch(String roomId, String playerId) async {
    try {
      await _firestore.collection('battle_rooms').doc(roomId).update({
        'rematchRequestedBy': playerId,
      });
    } catch (_) {}
  }

  // Accept a rematch and restart the lobby
  Future<void> acceptRematch(String roomId, List<QuestionModel> newQuestions) async {
    final docRef = _firestore.collection('battle_rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      
      // Reset all players stats
      players.forEach((key, val) {
        players[key]['score'] = 0;
        players[key]['currentQuestion'] = 0;
        players[key]['isFinished'] = false;
        players[key]['hasForfeited'] = false;
        players[key]['hasLeft'] = false;
        players[key]['lastActive'] = DateTime.now().millisecondsSinceEpoch;
      });

      transaction.update(docRef, {
        'status': 'playing',
        'questions': newQuestions.map((q) => q.toFirestore()..['id'] = q.id).toList(),
        'players': players,
        'rematchRequestedBy': FieldValue.delete(),
      });
    });
  }

  // Mark player as left (without deleting the room document)
  Future<void> markPlayerLeft(String roomId, String playerId) async {
    final docRef = _firestore.collection('battle_rooms').doc(roomId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        
        if (players.containsKey(playerId)) {
          players[playerId]['hasLeft'] = true;
        }

        transaction.update(docRef, {
          'players': players,
        });
      });
    } catch (_) {}
  }
}
