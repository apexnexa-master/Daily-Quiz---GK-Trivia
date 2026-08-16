// lib/presentation/screens/battle_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../data/models/firestore_models.dart';
import '../../data/local_quiz_data.dart';
import '../../core/services/battle_service.dart';
import '../../core/services/question_service.dart';
import '../../core/services/daily_progress_service.dart';
import '../../core/scoring/game_performance.dart';
import '../../core/scoring/progression_service.dart';
import '../widgets/game_card.dart';

enum BattleArenaState {
  selectMode,
  selectGame,
  configureGame,
  searchingOffline,
  lobbyWaiting,
  joinRoom,
  battleActive,
  results,
}

class BattleScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final bool isTab;
  const BattleScreen({super.key, this.roomId, this.isTab = false});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with WidgetsBindingObserver {
  // Screen States
  BattleArenaState _arenaState = BattleArenaState.selectMode;
  bool _isOnlineMode = false;

  // Room / Match Info
  String? _roomId;
  StreamSubscription? _roomSubscription;
  List<QuestionModel> _questions = [];
  int _currentQuestion = 0;
  int _totalQuestions = 5;
  String _selectedGame = 'TRIVIA';
  int _selectedQuestionCount = 5;
  int _mySeriesWins = 0;
  int _opponentSeriesWins = 0;
  int? _selectedAnswer;
  bool _isAnswered = false;

  // Player Scores / Progress
  int _playerScore = 0;
  int _opponentScore = 0;
  String _opponentName = 'Training Bot';
  String _opponentAvatar = '';
  int _opponentCurrentQuestion = 0;
  bool _opponentFinished = false;

  // Connection & Heartbeat states
  int? _opponentLastActive;
  bool _opponentDisconnectedFlag = false;
  bool _showDisconnectOverlay = false;
  int _disconnectCountdown = 10;
  int _lastOpponentUpdateLocalTime = DateTime.now().millisecondsSinceEpoch;
  bool _isBattleOver = false;
  bool _opponentForfeited = false;
  String? _rematchRequestedBy;
  bool _opponentLeftResults = false;
  bool _isResultDialogOpen = false;
  String? _opponentId;

  // Timers
  Timer? _searchTimer;
  Timer? _opponentSimTimer;
  Timer? _heartbeatTimer;
  Timer? _connectionMonitorTimer;
  Timer? _disconnectCountdownTimer;
  Timer? _matchTimer;
  Timer? _idleTimer;
  int _matchTimeRemaining = 120; // 120 seconds (2 mins)
  int _idleSecondsElapsed = 0;
  bool _showIdleWarning = false;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.roomId != null) {
      Future.microtask(() async {
        final user = await ref.read(currentUserProvider.future);
        final lang = ref.read(languageProvider);
        if (user != null && !user.isAnonymous && mounted) {
          setState(() {
            _codeController.text = widget.roomId!;
            _isJoining = true;
          });
          _submitRoomCode(user);
        } else if (mounted) {
          _showLobbyAuthRequiredDialog(lang);
        }
      });
    } else {
      Future.microtask(() async {
        final user = await ref.read(currentUserProvider.future);
        _checkActiveBattleRoom(user);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomSubscription?.cancel();
    _searchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _disconnectCountdownTimer?.cancel();
    _matchTimer?.cancel();
    _idleTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // --- Actions & Handlers ---

  void _navigateToSelectGame(bool isOnline) {
    setState(() {
      _isOnlineMode = isOnline;
      _arenaState = BattleArenaState.selectGame;
      _selectedGame = 'TRIVIA';
      _selectedQuestionCount = 5;
    });
  }

  void _startOfflineMode() {
    if (_selectedGame == 'ARROW_MAZE') {
      Navigator.pushNamed(context, '/arrow-puzzle');
      // Reset state back to selectMode when they return so they don't get stuck
      setState(() {
        _arenaState = BattleArenaState.selectMode;
      });
      return;
    }
    setState(() {
      _arenaState = BattleArenaState.searchingOffline;
      _isOnlineMode = false;
      _playerScore = 0;
      _opponentScore = 0;
      _opponentName = 'Training Bot';
      _opponentId = null;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _isBattleOver = false;
      _opponentForfeited = false;
      _rematchRequestedBy = null;
      _isResultDialogOpen = false;
    });

    _searchTimer = Timer(const Duration(seconds: 2), () async {
      if (mounted) {
        final list = await QuestionService.instance
            .fetchCombinedQuestions(examMode: 'GENERAL');
        list.shuffle();
        if (mounted) {
          setState(() {
            _arenaState = BattleArenaState.battleActive;
            _questions = list
                .take(_selectedQuestionCount)
                .map((q) => q.shuffleOptions())
                .toList();
            _totalQuestions = _questions.length;
          });
          _startOfflineOpponentSimulation();
          _startMatchTimers();
        }
      }
    });
  }

  void _startOfflineOpponentSimulation() {
    _opponentSimTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted &&
          _arenaState == BattleArenaState.battleActive &&
          !_isAnswered) {
        setState(() {
          _opponentScore =
              min(_opponentScore + Random().nextInt(2), _totalQuestions);
          _opponentCurrentQuestion =
              min(_currentQuestion + 1, _totalQuestions - 1);
        });
      }
    });
  }

  Future<void> _createOnlineRoom(UserModel? user) async {
    if (user == null) return;
    setState(() {
      _arenaState = BattleArenaState.lobbyWaiting;
      _isOnlineMode = true;
      _playerScore = 0;
      _opponentScore = 0;
      _opponentId = null;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _isBattleOver = false;
      _opponentForfeited = false;
      _rematchRequestedBy = null;
      _isResultDialogOpen = false;
    });

    try {
      final roomId = await BattleService().createRoom(
        playerNickname: user.displayName,
        playerId: user.uid,
        avatarUrl: user.photoUrl ?? '',
        questionCount: _selectedQuestionCount,
        gameType: _selectedGame,
      );

      setState(() {
        _roomId = roomId;
      });
      await _saveActiveBattleRoom(roomId);

      _subscribeToRoom(roomId, user.uid);
    } catch (e, stack) {
      debugPrint('Error creating room: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create battle room: $e')),
      );
      setState(() {
        _arenaState = BattleArenaState.selectMode;
      });
    }
  }

  void _joinOnlineRoom(UserModel? user) {
    if (user == null) return;
    setState(() {
      _arenaState = BattleArenaState.joinRoom;
      _codeController.clear();
    });
  }

  Future<void> _submitRoomCode(UserModel? user) async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final success = await BattleService().joinRoom(
        roomId: code,
        playerNickname: user?.displayName ?? 'Challenger',
        playerId: user?.uid ?? 'guest_uid',
        avatarUrl: user?.photoUrl ?? '',
      );

      if (success) {
        setState(() {
          _roomId = code;
          _isOnlineMode = true;
          _playerScore = 0;
          _opponentScore = 0;
          _opponentId = null;
          _currentQuestion = 0;
          _selectedAnswer = null;
          _isAnswered = false;
          _arenaState = BattleArenaState.battleActive;
          _isJoining = false;
          _isBattleOver = false;
          _opponentForfeited = false;
          _rematchRequestedBy = null;
          _isResultDialogOpen = false;
        });
        await _saveActiveBattleRoom(code);

        _subscribeToRoom(code, user?.uid ?? 'guest_uid');
      } else {
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid room code or room is full.')),
        );
      }
    } catch (e, stack) {
      debugPrint('Error joining room: $e\n$stack');
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining room: $e')),
      );
    }
  }

  void _subscribeToRoom(String roomId, String myUid) {
    _roomSubscription?.cancel();
    _roomSubscription = BattleService().watchRoom(roomId).listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) {
        if (_arenaState == BattleArenaState.battleActive) {
          // Room deleted / Opponent forfeited during battle -> Declare forfeit victory
          _endBattle();
        } else if (_arenaState == BattleArenaState.lobbyWaiting) {
          // Room deleted / Host left during lobby
          setState(() {
            _arenaState = BattleArenaState.selectMode;
            _roomId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The host closed the room or left.')),
          );
        } else if (_arenaState == BattleArenaState.results) {
          setState(() {
            _opponentLeftResults = true;
          });
        }
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final rematchReq = data['rematchRequestedBy'] as String?;

      if (rematchReq != null &&
          rematchReq != myUid &&
          _rematchRequestedBy != rematchReq) {
        if (_arenaState == BattleArenaState.results) {
          final lang = ref.read(languageProvider);
          final isBn = lang == 'bn';
          final isHi = lang == 'hi';

          // Find opponent name
          String? oppId;
          players.forEach((key, val) {
            if (key != myUid) oppId = key;
          });
          final oppName = oppId != null
              ? (players[oppId]['name'] ?? 'Opponent')
              : 'Opponent';

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isBn
                      ? '$oppName রিম্যাচ খেলতে চায়!'
                      : isHi
                          ? '$oppName रीमैच खेलना चाहता है!'
                          : '$oppName wants a rematch!'),
                  backgroundColor: AppColors.surfaceElevatedDark,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: isBn
                        ? 'খেলুন'
                        : isHi
                            ? 'स्वीकारें'
                            : 'Accept',
                    textColor: AppColors.primary,
                    onPressed: () {
                      if (_roomId != null) {
                        final newQs =
                            LocalQuizData.getAllQuestionsForMode('GENERAL');
                        newQs.shuffle();
                        final questionsToSet = newQs
                            .take(_totalQuestions)
                            .map((q) => q.shuffleOptions())
                            .toList();
                        BattleService().acceptRematch(_roomId!, questionsToSet);
                      }
                    },
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          });
        }
      }

      setState(() {
        _rematchRequestedBy = rematchReq;
      });

      // Parse opponent info
      String? oppId;
      players.forEach((key, val) {
        if (key != myUid) {
          oppId = key;
        }
      });

      if (oppId != null) {
        final oppData = players[oppId];
        final newLastActive = oppData['lastActive'];
        final newIsDisconnected = oppData['isDisconnected'] ?? false;
        final newScore = oppData['score'] ?? 0;
        final newQuestion = oppData['currentQuestion'] ?? 0;
        final newForfeited = oppData['hasForfeited'] ?? false;
        final newLeft = oppData['hasLeft'] ?? false;

        final hasChanged = _opponentLastActive != newLastActive ||
            _opponentDisconnectedFlag != newIsDisconnected ||
            _opponentScore != newScore ||
            _opponentCurrentQuestion != newQuestion ||
            _opponentLeftResults != newLeft ||
            _opponentForfeited != newForfeited;

        setState(() {
          _opponentId = oppId;
          _opponentName = oppData['name'] ?? 'Opponent';
          _opponentAvatar = oppData['avatar'] ?? '';
          _opponentScore = newScore;
          _opponentCurrentQuestion = newQuestion;
          _opponentFinished = oppData['isFinished'] ?? false;
          _opponentLastActive = newLastActive;
          _opponentDisconnectedFlag = newIsDisconnected;
          _opponentForfeited = newForfeited;
          if (newLeft) {
            _opponentLeftResults = true;
          }

          if (hasChanged) {
            _lastOpponentUpdateLocalTime =
                DateTime.now().millisecondsSinceEpoch;
          }
        });

        if (newForfeited && _arenaState == BattleArenaState.battleActive) {
          _endBattle();
          return;
        }
      }

      // If status transitions to playing
      if (status == 'playing' &&
          (_arenaState == BattleArenaState.lobbyWaiting ||
              _questions.isEmpty ||
              _isBattleOver)) {
        final roomGameType = data['gameType'] ?? 'TRIVIA';
        if (roomGameType == 'ARROW_MAZE') {
          Navigator.pushNamed(context, '/arrow-puzzle');
          setState(() {
            _arenaState = BattleArenaState.selectMode;
          });
          return;
        }
        // Parse questions from room
        final list = List<dynamic>.from(data['questions'] ?? []);
        setState(() {
          _questions = list
              .map((q) => QuestionModel.fromMap(Map<String, dynamic>.from(q)))
              .toList();
          _totalQuestions = _questions.length;
          _arenaState = BattleArenaState.battleActive;
          _playerScore = 0;
          _opponentScore = 0;
          _currentQuestion = 0;
          _selectedAnswer = null;
          _isAnswered = false;
          _isBattleOver = false;
          _opponentForfeited = false;
          _opponentFinished = false;
          _rematchRequestedBy = null;
          _opponentLeftResults = false;
        });

        if (_isResultDialogOpen && mounted) {
          Navigator.of(context).pop(); // Close results dialog if somehow open
          _isResultDialogOpen = false;
        }

        _startConnectionMonitoring(roomId, myUid);
        _startMatchTimers();
      }

      // If status transitions to finished, or opponent scores exceed
      if (status == 'finished') {
        _endBattle();
      }
    });
  }

  void _onAnswerSelected(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
    });

    final isCorrect =
        _selectedAnswer == _questions[_currentQuestion].correctIndex;
    if (isCorrect) {
      setState(() {
        _playerScore += 1;
      });
      ref.read(gamificationNotifierProvider.notifier).addXP(20);
    }

    if (_isOnlineMode) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && _roomId != null) {
        final isFinished = _currentQuestion >= _totalQuestions - 1;
        BattleService().updateProgress(
          roomId: _roomId!,
          playerId: user.uid,
          score: _playerScore,
          currentQuestion: _currentQuestion,
          isFinished: isFinished,
        );
      }
    }

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentQuestion < _totalQuestions - 1) {
          setState(() {
            _currentQuestion++;
            _selectedAnswer = null;
            _isAnswered = false;
            _idleSecondsElapsed = 0;
            _showIdleWarning = false;
          });
        } else {
          if (!_isOnlineMode) {
            _endBattle();
          } else {
            // Online: Wait for opponent to finish
            if (_opponentFinished) {
              _endBattle();
            } else {
              // Show waiting screen overlay
              setState(() {
                _isAnswered = true; // Lock UI
              });
            }
          }
        }
      }
    });
  }

  void _endBattle() {
    if (_isBattleOver) return;
    _opponentSimTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _disconnectCountdownTimer?.cancel();
    _matchTimer?.cancel();
    _idleTimer?.cancel();
    _clearActiveBattleRoom();
    setState(() {
      _isBattleOver = true;
      _arenaState = BattleArenaState.results;
      if (_playerScore > _opponentScore) {
        _mySeriesWins++;
      } else if (_opponentScore > _playerScore) {
        _opponentSeriesWins++;
      }
    });

    // Normalized performance score (0-100) shared across every game.
    final battleTotal =
        _totalQuestions > 0 ? _totalQuestions : _selectedQuestionCount;
    final input = BattlePerformanceInput(
      correct: _playerScore,
      total: battleTotal,
    );
    unawaited(
      ProgressionService.instance.recordSession(
        SessionRecord(
          gameId: 'battle',
          mode: SessionMode.battle,
          gameType: GameType.battle,
          primaryPillar: BrainPillar.speed,
          performance: input,
        ),
      ),
    );
    ref.invalidate(dailyProgressProvider);

    // Check if opponent already requested a rematch before we finished
    final user = ref.read(currentUserProvider).value;
    if (user != null &&
        _rematchRequestedBy != null &&
        _rematchRequestedBy != user.uid) {
      final lang = ref.read(languageProvider);
      final isBn = lang == 'bn';
      final isHi = lang == 'hi';
      final oppName = _opponentName.isNotEmpty ? _opponentName : 'Opponent';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isBn
                  ? '$oppName রিম্যাচ খেলতে চায়!'
                  : isHi
                      ? '$oppName रीमैच खेलना चाहता है!'
                      : '$oppName wants a rematch!'),
              backgroundColor: AppColors.surfaceElevatedDark,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: isBn
                    ? 'খেলুন'
                    : isHi
                        ? 'स्वीकारें'
                        : 'Accept',
                textColor: AppColors.primary,
                onPressed: () {
                  if (_roomId != null) {
                    final newQs =
                        LocalQuizData.getAllQuestionsForMode('GENERAL');
                    newQs.shuffle();
                    final questionsToSet = newQs
                        .take(_totalQuestions)
                        .map((q) => q.shuffleOptions())
                        .toList();
                    BattleService().acceptRematch(_roomId!, questionsToSet);
                  }
                },
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      });
    }
  }

  void _startMatchTimers() {
    _matchTimer?.cancel();
    _idleTimer?.cancel();

    _matchTimeRemaining = 120; // 120 seconds (2 mins)
    _idleSecondsElapsed = 0;
    _showIdleWarning = false;

    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _arenaState != BattleArenaState.battleActive ||
          _isBattleOver) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_matchTimeRemaining > 0) {
          _matchTimeRemaining--;
        } else {
          timer.cancel();
          _endBattleDueToTimeout();
        }
      });
    });

    _idleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _arenaState != BattleArenaState.battleActive ||
          _isBattleOver) {
        timer.cancel();
        return;
      }

      if (!_isAnswered) {
        setState(() {
          _idleSecondsElapsed++;
          if (_idleSecondsElapsed >= 30) {
            _showIdleWarning = true;
          }
          if (_idleSecondsElapsed >= 40) {
            timer.cancel();
            _endBattleDueToIdleTimeout();
          }
        });
      } else {
        if (_idleSecondsElapsed > 0 || _showIdleWarning) {
          setState(() {
            _idleSecondsElapsed = 0;
            _showIdleWarning = false;
          });
        }
      }
    });
  }

  void _endBattleDueToTimeout() {
    _matchTimer?.cancel();
    _idleTimer?.cancel();
    if (_isOnlineMode) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && _roomId != null) {
        BattleService().updateProgress(
          roomId: _roomId!,
          playerId: user.uid,
          score: _playerScore,
          currentQuestion: _currentQuestion,
          isFinished: true,
        );
      }
    }
    _endBattle();
  }

  void _endBattleDueToIdleTimeout() {
    _matchTimer?.cancel();
    _idleTimer?.cancel();
    if (_isOnlineMode) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && _roomId != null) {
        BattleService().updateProgress(
          roomId: _roomId!,
          playerId: user.uid,
          score: _playerScore,
          currentQuestion: _currentQuestion,
          isFinished: true,
          hasForfeited: true,
        );
      }
    }
    setState(() {
      _opponentForfeited = false; // player themselves forfeited
    });
    _endBattle();
  }

  void _leaveRoom({bool deleteDoc = true}) {
    if (_roomId != null) {
      if (deleteDoc) {
        BattleService().deleteRoom(_roomId!);
      } else {
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          BattleService().markPlayerLeft(_roomId!, user.uid);
        }
      }
    }
    _roomSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _disconnectCountdownTimer?.cancel();
    setState(() {
      _arenaState = BattleArenaState.selectMode;
      _roomId = null;
      _showDisconnectOverlay = false;
      _opponentLeftResults = false;
      _opponentId = null;
      _mySeriesWins = 0;
      _opponentSeriesWins = 0;
    });
  }

  // --- Connection Monitoring & Lifecycle Observer ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = ref.read(currentUserProvider).value;
    if (user == null || _roomId == null || !_isOnlineMode) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      BattleService().updateConnectionStatus(_roomId!, user.uid, false);
    } else if (state == AppLifecycleState.resumed) {
      BattleService().updateConnectionStatus(_roomId!, user.uid, true);
    }
  }

  void _startConnectionMonitoring(String roomId, String myUid) {
    _heartbeatTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _disconnectCountdownTimer?.cancel();

    _lastOpponentUpdateLocalTime = DateTime.now().millisecondsSinceEpoch;

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_roomId != null && _isOnlineMode) {
        BattleService().updateHeartbeat(_roomId!, myUid);
      }
    });

    _connectionMonitorTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isOnlineMode ||
          _roomId == null ||
          _arenaState != BattleArenaState.battleActive) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - _lastOpponentUpdateLocalTime;
      final isOppDisconnected = _opponentDisconnectedFlag || diff > 20000;

      if (isOppDisconnected && !_opponentFinished) {
        if (!_showDisconnectOverlay) {
          setState(() {
            _showDisconnectOverlay = true;
            _disconnectCountdown = 10;
          });
          _startDisconnectCountdown();
        }
      } else {
        if (_showDisconnectOverlay) {
          setState(() {
            _showDisconnectOverlay = false;
          });
          _disconnectCountdownTimer?.cancel();
        }
      }
    });
  }

  void _startDisconnectCountdown() {
    _disconnectCountdownTimer?.cancel();
    _disconnectCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disconnectCountdown > 1) {
        setState(() {
          _disconnectCountdown--;
        });
      } else {
        _handleOpponentForfeit();
      }
    });
  }

  void _handleOpponentForfeit() {
    _disconnectCountdownTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _heartbeatTimer?.cancel();

    setState(() {
      _showDisconnectOverlay = false;
      _playerScore = _totalQuestions; // Max score for victory
      _opponentFinished = true;
      _opponentForfeited = true;
    });

    if (_roomId != null && _isOnlineMode && _opponentId != null) {
      BattleService().updateProgress(
        roomId: _roomId!,
        playerId: _opponentId!,
        score: _opponentScore,
        currentQuestion: _opponentCurrentQuestion,
        isFinished: true,
        hasForfeited: true,
      );
    }

    _endBattle();
  }

  // --- Active Battle Room Persistence & Rejoin Logic ---
  Future<void> _saveActiveBattleRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_battle_room_id', roomId);
  }

  Future<void> _clearActiveBattleRoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_battle_room_id');
  }

  Future<void> _checkActiveBattleRoom(UserModel? user) async {
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString('active_battle_room_id');

    if (roomId != null && mounted) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('battle_rooms')
            .doc(roomId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final status = data['status'];
          final players = Map<String, dynamic>.from(data['players'] ?? {});

          if (status == 'playing' &&
              players.containsKey(user.uid) &&
              players[user.uid]['isFinished'] == false) {
            if (mounted) {
              _showRejoinDialog(roomId, user, players[user.uid]['score'] ?? 0,
                  players[user.uid]['currentQuestion'] ?? 0);
            }
            return;
          }
        }
      } catch (_) {}

      await _clearActiveBattleRoom();
    }
  }

  void _showRejoinDialog(
      String roomId, UserModel user, int currentScore, int currentQuestion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: const Text(
            'Active Battle Found!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You were in the middle of an online match. Would you like to rejoin and continue playing?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                BattleService().updateProgress(
                  roomId: roomId,
                  playerId: user.uid,
                  score: 0,
                  currentQuestion: 5,
                  isFinished: true,
                );
                _clearActiveBattleRoom();
              },
              child: const Text('Forfeit', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _rejoinMatch(roomId, user, currentScore, currentQuestion);
              },
              child: const Text('Rejoin'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejoinMatch(String roomId, UserModel user, int currentScore,
      int currentQuestion) async {
    setState(() {
      _roomId = roomId;
      _isOnlineMode = true;
      _playerScore = currentScore;
      _currentQuestion = currentQuestion;
      _selectedAnswer = null;
      _isAnswered = false;
      _isJoining = true;
      _isBattleOver = false;
      _opponentForfeited = false;
      _rematchRequestedBy = null;
      _isResultDialogOpen = false;
    });

    try {
      await BattleService().updateConnectionStatus(roomId, user.uid, true);

      final doc = await FirebaseFirestore.instance
          .collection('battle_rooms')
          .doc(roomId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final list = List<dynamic>.from(data['questions'] ?? []);
        setState(() {
          _questions = list
              .map((q) => QuestionModel.fromMap(Map<String, dynamic>.from(q)))
              .toList();
          _totalQuestions = _questions.length;
          _arenaState = BattleArenaState.battleActive;
          _isJoining = false;
        });

        _subscribeToRoom(roomId, user.uid);
        _startConnectionMonitoring(roomId, user.uid);
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rejoin: $e')),
      );
    }
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: const Text(
            'Quit Battle?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'If you quit now, you will forfeit this match, and your opponent will win automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _forfeitMatch();
              },
              child: const Text('Quit & Forfeit'),
            ),
          ],
        );
      },
    );
  }

  void _forfeitMatch() {
    final user = ref.read(currentUserProvider).value;
    if (_roomId != null && _isOnlineMode && user != null) {
      BattleService().updateProgress(
        roomId: _roomId!,
        playerId: user.uid,
        score: 0,
        currentQuestion: _totalQuestions,
        isFinished: true,
        hasForfeited: true,
      );
    }
    _clearActiveBattleRoom();
    _leaveRoom(deleteDoc: false);
  }

  // --- Share Invite link ---
  void _shareCode(String code, bool isBn, bool isHi) {
    final link = 'https://dailyquiz.nexasoft.com/challenge/$code';
    final message = isBn
        ? 'আমার সাথে কুইজ চ্যালেঞ্জ খেলুন! জয়েন করতে এই লিঙ্কে ক্লিক করুন: $link\n(অথবা রুম কোড ব্যবহার করুন: $code)'
        : isHi
            ? 'मेरे साथ लाइव क्विज़ चुनौती खेलें! शामिल होने के लिए इस लिंक पर क्लिक करें: $link\n(या रूम कोड का उपयोग करें: $code)'
            : 'Play a 1v1 Live Quiz Battle with me! Click here to join: $link\n(Or use room code: $code)';

    Share.share(message);
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final user = ref.watch(currentUserProvider).value;

    return PopScope(
      canPop: !_isOnlineMode ||
          _arenaState == BattleArenaState.selectMode ||
          _isBattleOver,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.homeBackdropDark
                : AppColors.homeBackdropGradient,
          ),
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStateView(isDark, isBn, isHi, user),
                ),
              ),
              if (_showDisconnectOverlay)
                _buildDisconnectOverlay(isDark, isBn, isHi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectOverlay(bool isDark, bool isBn, bool isHi) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulseWidget(
                child: Icon(Icons.wifi_off_rounded,
                    size: 64, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              Text(
                isBn
                    ? 'সংযোগ বিচ্ছিন্ন হয়েছে!'
                    : isHi
                        ? 'कनेक्शन टूट गया!'
                        : 'Opponent Disconnected!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBn
                    ? 'আপনার প্রতিপক্ষ সংযোগ ফিরে পাওয়ার চেষ্টা করছে...\n$_disconnectCountdown সেকেন্ডের মধ্যে খেলা শেষ হবে।'
                    : isHi
                        ? 'आपका प्रतिद्वंद्वी पुनः कनेक्ट होने का प्रयास कर रहा है...\n$_disconnectCountdown सेकंड में खेल समाप्त हो जाएगा।'
                        : 'Your opponent is trying to reconnect...\nDeclaring victory in $_disconnectCountdown seconds.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateView(bool isDark, bool isBn, bool isHi, UserModel? user) {
    switch (_arenaState) {
      case BattleArenaState.selectMode:
        return _buildSelectModeView(isDark, isBn, isHi, user);
      case BattleArenaState.selectGame:
        return _buildSelectGameView(isDark, isBn, isHi, user);
      case BattleArenaState.configureGame:
        return _buildConfigureGameView(isDark, isBn, isHi, user);
      case BattleArenaState.searchingOffline:
        return _buildSearchingState(isDark, isBn, isHi);
      case BattleArenaState.lobbyWaiting:
        return _buildLobbyWaitingView(isDark, isBn, isHi);
      case BattleArenaState.joinRoom:
        return _buildJoinRoomView(isDark, isBn, isHi, user);
      case BattleArenaState.battleActive:
        return _buildBattleState(isDark, isBn, isHi, user);
      case BattleArenaState.results:
        return _buildResultsView(isDark, isBn, isHi, user);
    }
  }

  // 1. Selector Mode Screen
  Widget _buildSelectModeView(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded,
                      color:
                          isDark ? Colors.white : AppColors.textPrimaryLight),
                ),
                const SizedBox(width: 4),
              ] else ...[
                IconButton(
                  onPressed: () {
                    ref.read(navigationTabProvider.notifier).state = 0;
                  },
                  icon: Icon(Icons.arrow_back_rounded,
                      color:
                          isDark ? Colors.white : AppColors.textPrimaryLight),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                isBn
                    ? 'কুইজ যুদ্ধ'
                    : isHi
                        ? 'क्विज़ युद्ध'
                        : 'Quiz Battle Arena',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBn
                      ? 'যুদ্ধ ক্ষেত্র চয়ন করুন'
                      : isHi
                          ? 'युद्ध क्षेत्र चुनें'
                          : 'Select Your Battleground',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 32),

                // Offline Training mode
                _buildModeCard(
                  title: isBn
                      ? 'বট প্রশিক্ষণ'
                      : isHi
                          ? 'बॉट प्रशिक्षण'
                          : 'AI Bot Training',
                  subtitle: isBn
                      ? 'একটি সিমুলেটেড কুইজ বটে আপনার গতি ও দক্ষতা পরীক্ষা করুন।'
                      : isHi
                          ? 'एक सिम्युलेटेड क्विज़ बॉट में अपनी गति का परीक्षण करें।'
                          : 'Test your speed and precision against a training bot offline.',
                  gradient: AppColors.primaryGradient,
                  icon: Icons.psychology_rounded,
                  onTap: () => _navigateToSelectGame(false),
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // Online 1v1 Mode
                _buildModeCard(
                  title: isBn
                      ? 'অনলাইন ১ বনাম ১ কুইজ'
                      : isHi
                          ? 'ऑनलाइन 1 बनाम 1 क्विज़'
                          : 'Online 1v1 Duel',
                  subtitle: isBn
                      ? 'রুম কোড শেয়ার করে সরাসরি বন্ধুর সাথে লাইভ লড়াইয়ে নামুন!'
                      : isHi
                          ? 'रूम कोड साझा करें और अपने दोस्त के साथ सीधे खेलें!'
                          : 'Create a room, share the code, and duel your friend in real-time!',
                  gradient: AppColors.successGradient,
                  icon: Icons.people_rounded,
                  onTap: () {
                    if (user?.isAnonymous ?? true) {
                      _showAnonymousWarning(isBn, isHi);
                    } else {
                      _showOnlineLobbyChoiceDialog(isDark, isBn, isHi, user);
                    }
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectGameView(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _arenaState = BattleArenaState.selectMode;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                isBn
                    ? 'খেলা নির্বাচন করুন'
                    : isHi
                        ? 'खेल का चयन करें'
                        : 'Select Game Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category 1: Trivia & GK
                _buildTopicHeader(
                  title: isBn
                      ? 'ট্রিভিয়া এবং জিকে'
                      : isHi
                          ? 'त्रिविया और जीके'
                          : 'Trivia & GK',
                  isDark: isDark,
                  isBn: isBn,
                  isHi: isHi,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _buildGameTile(
                        context: context,
                        isDark: isDark,
                        badgeText: 'TRIVIA',
                        title: isBn
                            ? 'ট্রিভিয়া কুইজ'
                            : isHi
                                ? 'त्रिविया क्विज़'
                                : 'Trivia Duel',
                        subtitle: isBn
                            ? 'সাধারণ জ্ঞান এবং গতি পরীক্ষা করে আপনার প্রতিপক্ষকে হারান।'
                            : isHi
                                ? 'सामान्य ज्ञान और गति का परीक्षण करके प्रतिद्वंद्वी को हराएं।'
                                : 'Duel your opponent in a fast-paced General Knowledge quiz.',
                        isLocked: false,
                        onTap: () {
                          setState(() {
                            _selectedGame = 'TRIVIA';
                            _arenaState = BattleArenaState.configureGame;
                          });
                        },
                        isBn: isBn,
                        isHi: isHi,
                        imagePath: 'assets/icon/quiz3.png',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicHeader({
    required String title,
    required bool isDark,
    required bool isBn,
    required bool isHi,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGameTile({
    required BuildContext context,
    required bool isDark,
    required String badgeText,
    required String title,
    required String subtitle,
    required bool isLocked,
    required VoidCallback onTap,
    required bool isBn,
    required bool isHi,
    String? imagePath,
  }) {
    final categoryColor = isLocked
        ? Colors.grey
        : (badgeText.contains('TRIVIA')
            ? AppColors.primary
            : (badgeText.contains('MAZE') || badgeText.contains('RECALL')
                ? const Color(0xFF00F1FE)
                : const Color(0xFFECB2FF)));

    final meta = switch (badgeText) {
      'TRIVIA' => '~5 min',
      'MAZE' => '2 min',
      'RECALL' => '5 min',
      'MATH' => '1 min',
      _ => null,
    };

    return GameCard(
      width: 260,
      compact: true,
      coverAspectRatio: 2.6,
      imagePath: imagePath,
      accent: categoryColor,
      badge: badgeText,
      isLocked: isLocked,
      meta: meta,
      metaIcon: meta != null ? Icons.timer_outlined : null,
      title: title,
      subtitle: subtitle,
      footer: isLocked
          ? (isBn
              ? 'শীঘ্রই আসছে'
              : isHi
                  ? 'जल्द ही आ रहा है'
                  : 'Coming Soon')
          : (isBn
              ? 'সক্রিয় চ্যালেঞ্জ'
              : isHi
                  ? 'सक्रिय चुनौती'
                  : 'Active Challenge'),
      onTap: onTap,
    );
  }

  Widget _buildConfigureGameView(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _arenaState = BattleArenaState.selectGame;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                isBn
                    ? 'যুদ্ধ কাস্টমাইজ করুন'
                    : isHi
                        ? 'युद्ध अनुकूलित करें'
                        : 'Configure Duel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.quiz_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedGame == 'ARROW_MAZE'
                                  ? (isBn
                                      ? 'অ্যারো পাথ মেজ'
                                      : isHi
                                          ? 'एरो पाथ भूलभुलैया'
                                          : 'Arrow Path Maze')
                                  : (isBn
                                      ? 'ট্রিভিয়া কুইজ'
                                      : isHi
                                          ? 'त्रिविया क्विज़'
                                          : 'Trivia Duel'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedGame == 'ARROW_MAZE'
                                  ? (isBn
                                      ? 'গতিপথ মনে রেখে গোলকধাঁধা সমাধান'
                                      : isHi
                                          ? 'रास्ता याद रखकर भूलभुलैया'
                                          : 'Solve the arrow maze to test memory')
                                  : (isBn
                                      ? 'সাধারণ জ্ঞান ও বুদ্ধিমত্তা'
                                      : isHi
                                          ? 'सामान्य ज्ञान और बुद्धि'
                                          : 'General Knowledge & Intellect'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isBn
                      ? 'প্রশ্নের সংখ্যা নির্বাচন করুন'
                      : isHi
                          ? 'प्रश्नों की संख्या चुनें'
                          : 'Choose Number of Questions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCountButton(5)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCountButton(10)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCountButton(15)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCountButton(20)),
                  ],
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    if (_isOnlineMode) {
                      _createOnlineRoom(user);
                    } else {
                      _startOfflineMode();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isBn
                        ? 'যুদ্ধ শুরু করুন'
                        : isHi
                            ? 'युद्ध शुरू करें'
                            : 'START BATTLE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountButton(int count) {
    final isSelected = _selectedQuestionCount == count;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScaleButton(
      onTap: () {
        setState(() {
          _selectedQuestionCount = count;
        });
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : isDark
                  ? AppColors.cardDark
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primary : AppColors.primaryDark)
                : isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            color: isSelected
                ? (isDark ? AppColors.primary : AppColors.primaryDark)
                : isDark
                    ? Colors.white
                    : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  void _showAnonymousWarning(bool isBn, bool isHi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBn
            ? 'লগইন প্রয়োজন'
            : isHi
                ? 'लॉगिन आवश्यक'
                : 'Sign In Required'),
        content: Text(
          isBn
              ? 'অনলাইন ১ বনাম ১ ম্যাচ খেলতে আপনাকে লগইন করতে হবে।'
              : isHi
                  ? 'ऑनलाइन 1 बनाम 1 खेलने के लिए आपको लॉगिन करना होगा।'
                  : 'You must sign in to host or join online matches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isBn
                ? 'বন্ধ করুন'
                : isHi
                    ? 'बंद करें'
                    : 'Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isBn
                  ? 'লগইন'
                  : isHi
                      ? 'लॉगिन'
                      : 'Login',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showOnlineLobbyChoiceDialog(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Text(
          isBn
              ? '১ বনাম ১ দ্বৈরথ'
              : isHi
                  ? '1 बनाम 1 द्वंद्व'
                  : '1v1 Online Duel',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSelectGame(true);
            },
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  isBn
                      ? 'রুম তৈরি করুন'
                      : isHi
                          ? 'रूम बनाएं'
                          : 'Create Custom Room',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _joinOnlineRoom(user);
            },
            child: Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: AppColors.success),
                const SizedBox(width: 12),
                Text(
                  isBn
                      ? 'কোড দিয়ে জয়েন করুন'
                      : isHi
                          ? 'कोड के साथ जुड़ें'
                          : 'Join with Code',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // 2. Searching Screen (Offline mode)
  Widget _buildSearchingState(bool isDark, bool isBn, bool isHi) {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  _searchTimer?.cancel();
                  setState(() {
                    _arenaState = BattleArenaState.selectMode;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn
                    ? 'বট অনুসন্ধান'
                    : isHi
                        ? 'बॉट खोज'
                        : 'Opponent Search',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    strokeWidth: 4.5,
                    valueColor: AlwaysStoppedAnimation(
                        isDark ? AppColors.primary : AppColors.primaryDark),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isBn
                      ? 'ট্রেনিং বটের সাথে যুক্ত হচ্ছে...'
                      : isHi
                          ? 'ट्रेनिंग बॉट से कनेक्ट हो रहा है...'
                          : 'Connecting with Training Bot...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isBn
                      ? 'অনুগ্রহ করে অপেক্ষা করুন।'
                      : isHi
                          ? 'कृपया प्रतीक्षा करें।'
                          : 'Please wait while match is generated.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. Online Lobby Screen
  Widget _buildLobbyWaitingView(bool isDark, bool isBn, bool isHi) {
    final user = ref.read(currentUserProvider).value;

    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: _leaveRoom,
                icon: Icon(Icons.close_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn
                    ? 'যুদ্ধের লবি'
                    : isHi
                        ? 'युद्ध लॉबी'
                        : 'Battle Lobby',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBn
                      ? 'বন্ধু আমন্ত্রণ কোড'
                      : isHi
                          ? 'मित्र आमंत्रण कोड'
                          : 'Invite Challenge Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_roomId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _roomId!,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _roomId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isBn
                                    ? 'কোড কপি করা হয়েছে!'
                                    : isHi
                                        ? 'कोड कॉपी किया गया!'
                                        : 'Code copied!'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _shareCode(_roomId!, isBn, isHi),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: Text(isBn
                        ? 'কোড শেয়ার করুন'
                        : isHi
                            ? 'कोड शेयर करें'
                            : 'Share Room Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ] else ...[
                  CircularProgressIndicator(
                      color:
                          isDark ? AppColors.primary : AppColors.primaryDark),
                ],
                const SizedBox(height: 48),

                // Matchup Slots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Player Slot
                    _buildLobbyPlayerSlot(
                      name: user?.displayName ?? 'You',
                      avatarUrl: user?.photoUrl ?? '',
                      isDark: isDark,
                      isReady: true,
                    ),
                    const Icon(Icons.bolt_rounded,
                        color: AppColors.warning, size: 40),
                    // Opponent Slot
                    _buildLobbyPlayerSlot(
                      name: isBn
                          ? 'অপেক্ষা করা হচ্ছে...'
                          : isHi
                              ? 'प्रतीक्षा...'
                              : 'Waiting...',
                      avatarUrl: '',
                      isDark: isDark,
                      isReady: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLobbyPlayerSlot({
    required String name,
    required String avatarUrl,
    required bool isDark,
    required bool isReady,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isReady
                  ? AppColors.success
                  : (isDark ? Colors.white10 : Colors.grey.shade300),
              width: 3,
            ),
            color: isDark ? AppColors.cardDark : Colors.white,
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : Icon(
                    Icons.person_rounded,
                    color: isReady
                        ? AppColors.success
                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  // 4. Join Room Screen (Enter 6 digit code)
  Widget _buildJoinRoomView(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _arenaState = BattleArenaState.selectMode;
                }),
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn
                    ? 'কোড প্রবেশ করান'
                    : isHi
                        ? 'कोड दर्ज करें'
                        : 'Enter Room Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBn
                      ? 'খেলায় যোগ দিতে ৬ সংখ্যার চ্যালেঞ্জ রুম কোডটি টাইপ করুন।'
                      : isHi
                          ? 'खेल में शामिल होने के लिए 6 अंकों का चुनौती रूम कोड दर्ज करें।'
                          : 'Enter the 6-digit challenge code to join the live duel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white24 : Colors.grey.shade300),
                    filled: true,
                    fillColor: isDark ? AppColors.cardDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : () => _submitRoomCode(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isJoining
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            isBn
                                ? 'জয়েন করুন'
                                : isHi
                                    ? 'जुड़ें'
                                    : 'Join Match',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. Active Battle Playback
  Widget _buildBattleState(bool isDark, bool isBn, bool isHi, UserModel? user) {
    if (_questions.isEmpty) return const SizedBox();

    final question = _questions[_currentQuestion];
    final questionText = question.getText(isBn
        ? 'bn'
        : isHi
            ? 'hi'
            : 'en');
    final options = question.getOptions(isBn
        ? 'bn'
        : isHi
            ? 'hi'
            : 'en');

    final isWaitingForOpponent = _currentQuestion >= _totalQuestions - 1 &&
        _isAnswered &&
        _isOnlineMode &&
        !_opponentFinished;

    return Column(
      children: [
        // App Bar Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      color: isDark ? AppColors.primary : AppColors.primaryDark,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isBn
                        ? 'অ্যারেনা'
                        : isHi
                            ? 'एरिना'
                            : 'ARENA',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color:
                            isDark ? AppColors.primary : AppColors.primaryDark,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
              Row(
                children: [
                  // Global Match Timer Countdown Capsule
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_rounded,
                            color: AppColors.error, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${_matchTimeRemaining ~/ 60}:${(_matchTimeRemaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? AppColors.primary : AppColors.primaryDark)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isBn
                          ? 'প্রশ্ন ${_currentQuestion + 1}/$_totalQuestions'
                          : isHi
                              ? 'प्रश्न ${_currentQuestion + 1}/$_totalQuestions'
                              : 'QUESTION ${_currentQuestion + 1}/$_totalQuestions',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: isDark
                              ? AppColors.primary
                              : AppColors.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => _showExitDialog(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color:
                      isDark ? AppColors.outlineVariant : Colors.grey.shade300,
                  width: 1),
            ),
            child: Row(
              children: [
                // Me / Player A
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isDark
                                        ? AppColors.primary
                                        : AppColors.primaryDark,
                                    width: 2),
                                image: (user?.photoUrl ?? '').isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(user!.photoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (user?.photoUrl ?? '').isEmpty
                                  ? Icon(Icons.person_rounded,
                                      color: isDark
                                          ? AppColors.primary
                                          : AppColors.primaryDark,
                                      size: 32)
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.displayName ?? 'You',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_playerScore',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? AppColors.primary
                                : AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                // VS Divider
                Column(
                  children: [
                    Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    if (_mySeriesWins > 0 || _opponentSeriesWins > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_mySeriesWins - $_opponentSeriesWins',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? AppColors.primary
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                        width: 32,
                        height: 1,
                        color: isDark
                            ? AppColors.outlineVariant
                            : Colors.grey.shade300),
                  ],
                ),
                // Opponent / Player B
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isDark
                                        ? AppColors.outlineVariant
                                        : Colors.grey.shade300,
                                    width: 2),
                                image: _opponentAvatar.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_opponentAvatar),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _opponentAvatar.isEmpty
                                  ? Icon(Icons.person_rounded,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey.shade400,
                                      size: 32)
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.outlineVariant
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'OPP',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.textSecondaryLight),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _opponentName,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondaryLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_opponentScore',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Linear Progress Timer Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor:
                    ((_currentQuestion + 1) / _totalQuestions).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showIdleWarning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: PulseWidget(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isBn
                          ? 'জলদি উত্তর দিন! ${40 - _idleSecondsElapsed} সেকেন্ডে শেষ হবে'
                          : isHi
                              ? 'जल्दी उत्तर दें! ${40 - _idleSecondsElapsed} सेकंड में समाप्त होगा'
                              : 'Hurry! Battle ends in ${40 - _idleSecondsElapsed}s if no response',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Live Question / Wait block
        Expanded(
          child: isWaitingForOpponent
              ? _buildWaitingForOpponentView(isDark, isBn, isHi)
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Question text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surfaceElevatedLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? AppColors.secondaryDark
                                  : AppColors.secondary, // Indigo bottom accent
                              width: 4,
                            ),
                          ),
                        ),
                        child: Text(
                          questionText,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Options mapping
                      ...List.generate(
                        options.length,
                        (i) => _BattleOptionTile(
                          index: i,
                          text: options[i],
                          isSelected: _selectedAnswer == i,
                          isCorrect: _isAnswered && i == question.correctIndex,
                          isWrong: _isAnswered &&
                              _selectedAnswer == i &&
                              i != question.correctIndex,
                          isDark: isDark,
                          onTap:
                              _isAnswered ? null : () => _onAnswerSelected(i),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResultsView(bool isDark, bool isBn, bool isHi, UserModel? user) {
    final isWin = _opponentForfeited || _playerScore > _opponentScore;
    final isDraw = !_opponentForfeited && _playerScore == _opponentScore;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Emoji/Trophy
              BounceInWidget(
                child: Text(
                  isWin
                      ? '🏆'
                      : isDraw
                          ? '🤝'
                          : '💪',
                  style: const TextStyle(fontSize: 72),
                ),
              ),
              const SizedBox(height: 16),

              // Status text
              Text(
                isWin
                    ? (isBn
                        ? 'আপনার জয়!'
                        : isHi
                            ? 'आपकी जीत!'
                            : 'Victory!')
                    : isDraw
                        ? (isBn
                            ? 'ড্র হয়েছে!'
                            : isHi
                                ? 'मुकाबला बराबरी का!'
                                : 'Draw!')
                        : (isBn
                            ? 'পরাজয়!'
                            : isHi
                                ? 'पराजय!'
                                : 'Defeat!'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isWin
                      ? AppColors.success
                      : isDraw
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),

              // Subtitle (Forfeit / Normal)
              if (_opponentForfeited) ...[
                const SizedBox(height: 8),
                Text(
                  isBn
                      ? 'প্রতিপক্ষ খেলা ছেড়ে দিয়েছে'
                      : isHi
                          ? 'प्रतिद्वंद्वी ने खेल छोड़ दिया'
                          : 'Opponent Forfeited the Match',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Score comparison card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScoreColumnDialog(user?.displayName ?? 'You',
                      _playerScore, AppColors.primary),
                  Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  _buildScoreColumnDialog(
                      _opponentName, _opponentScore, AppColors.error),
                ],
              ),
              const SizedBox(height: 28),

              // XP Reward indicator
              if (isWin) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.xp, color: AppColors.xp, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+${_playerScore * 20} XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Real-Time Rematch Prompts
              if (_isOnlineMode &&
                  !_opponentLeftResults &&
                  _rematchRequestedBy != null &&
                  _rematchRequestedBy != user?.uid) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isBn
                            ? 'প্রতিপক্ষ রিম্যাচ খেলতে চায়!'
                            : isHi
                                ? 'प्रतिद्वंद्वी रीमैच चाहता है!'
                                : 'Opponent wants a rematch!',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          if (_roomId != null) {
                            final newQs =
                                LocalQuizData.getAllQuestionsForMode('GENERAL');
                            newQs.shuffle();
                            final questionsToSet = newQs
                                .take(_totalQuestions)
                                .map((q) => q.shuffleOptions())
                                .toList();
                            BattleService()
                                .acceptRematch(_roomId!, questionsToSet);
                          }
                        },
                        child: Text(isBn
                            ? 'রিম্যাচ খেলুন'
                            : isHi
                                ? 'रीमैच स्वीकारें'
                                : 'Accept Rematch'),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _leaveRoom(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(isBn
                          ? 'বাহির'
                          : isHi
                              ? 'बाहर'
                              : 'Exit'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Rematch button logic slot
                  Expanded(
                    child: _buildRematchButton(isDark, isBn, isHi, user),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRematchButton(
      bool isDark, bool isBn, bool isHi, UserModel? user) {
    if (!_isOnlineMode) {
      // Offline mode: Instant restart!
      return ElevatedButton(
        onPressed: _startOfflineMode,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(isBn
            ? 'আবার খেলুন'
            : isHi
                ? 'पुनः खेलें'
                : 'Rematch'),
      );
    }

    if (_opponentLeftResults || _opponentForfeited) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          disabledForegroundColor:
              isDark ? Colors.white54 : Colors.grey.shade600,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(isBn
            ? 'প্রতিপক্ষ চলে গেছে'
            : isHi
                ? 'प्रतिद्वंद्वी चला गया'
                : 'Opponent Left'),
      );
    }

    // Online mode buttons:
    if (_rematchRequestedBy == null) {
      // Nobody requested rematch yet
      return ElevatedButton(
        onPressed: () {
          if (_roomId != null && user != null) {
            BattleService().requestRematch(_roomId!, user.uid);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(isBn
            ? 'রিম্যাচ অনুরোধ'
            : isHi
                ? 'रीमैच अनुरोध'
                : 'Rematch'),
      );
    } else if (_rematchRequestedBy == user?.uid) {
      // We requested rematch, waiting for opponent
      return PulseWidget(
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            disabledForegroundColor:
                isDark ? Colors.white54 : Colors.grey.shade600,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(isBn
              ? 'অপেক্ষমাণ...'
              : isHi
                  ? 'प्रतीक्षारत...'
                  : 'Waiting...'),
        ),
      );
    } else {
      // Opponent requested, we show a button to Accept!
      return ElevatedButton(
        onPressed: () {
          if (_roomId != null) {
            final newQs = LocalQuizData.getAllQuestionsForMode('GENERAL');
            newQs.shuffle();
            final questionsToSet = newQs
                .take(_totalQuestions)
                .map((q) => q.shuffleOptions())
                .toList();
            BattleService().acceptRematch(_roomId!, questionsToSet);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(isBn
            ? 'রিম্যাচ খেলুন'
            : isHi
                ? 'रीमैच स्वीकारें'
                : 'Accept'),
      );
    }
  }

  Widget _buildWaitingForOpponentView(bool isDark, bool isBn, bool isHi) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(
                    isDark ? AppColors.primary : AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isBn
                  ? 'প্রতিপক্ষের জন্য অপেক্ষা করা হচ্ছে...'
                  : isHi
                      ? 'प्रतिद्वंद्वी की प्रतीक्षा कर रहा है...'
                      : 'Waiting for opponent...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBn
                  ? 'আপনি সব প্রশ্নের উত্তর দিয়েছেন! আপনার প্রতিপক্ষ লড়াই শেষ করলে ফলাফল দেখানো হবে।'
                  : isHi
                      ? 'आपने सभी उत्तर दे दिए हैं! जब आपका प्रतिद्वंद्वी समाप्त कर लेगा तब परिणाम दिखाए जाएंगे।'
                      : 'You finished all questions! Results will display as soon as your opponent submits their final answer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog() {
    final isWin = _playerScore > _opponentScore;
    final isDraw = _playerScore == _opponentScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin
                  ? '🏆'
                  : isDraw
                      ? '🤝'
                      : '💪',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              isWin
                  ? (isBn
                      ? 'আপনার জয়!'
                      : isHi
                          ? 'आपकी जीत!'
                          : 'Victory!')
                  : isDraw
                      ? (isBn
                          ? 'ড্র হয়েছে!'
                          : isHi
                              ? 'मुकाबला बराबरी का!'
                              : 'Draw!')
                      : (isBn
                          ? 'বটের জয়!'
                          : isHi
                              ? 'बॉट की जीत!'
                              : 'Defeat!'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isWin
                    ? AppColors.success
                    : isDraw
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreColumnDialog('You', _playerScore, AppColors.primary),
                Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                _buildScoreColumnDialog(
                    _opponentName, _opponentScore, AppColors.error),
              ],
            ),
            const SizedBox(height: 24),
            if (isWin) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.xp, color: AppColors.xp),
                    const SizedBox(width: 8),
                    Text(
                      '+${_playerScore * 20} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dialog
                      if (_isOnlineMode && _roomId != null) {
                        BattleService().deleteRoom(_roomId!);
                      }
                      Navigator.pop(context); // Screen
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isBn
                        ? 'বাহির'
                        : isHi
                            ? 'बाहर'
                            : 'Exit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dialog
                      if (_isOnlineMode && _roomId != null) {
                        BattleService().deleteRoom(_roomId!);
                      }
                      setState(() {
                        _arenaState = BattleArenaState.selectMode;
                        _roomId = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isBn
                        ? 'আবার খেলুন'
                        : isHi
                            ? 'पुनः खेलें'
                            : 'Rematch'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreColumnDialog(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label.length > 10 ? '${label.substring(0, 8)}..' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showLobbyAuthRequiredDialog(String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              isBn
                  ? 'লগইন প্রয়োজন'
                  : isHi
                      ? 'लॉगिन आवश्यक'
                      : 'Sign In Required',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Text(
          isBn
              ? 'অনলাইন ১ বনাম ১ কুইজ লড়াইয়ে যোগ দিতে আপনাকে অবশ্যই গুগল অ্যাকাউন্ট দিয়ে লগইন করতে হবে।'
              : isHi
                  ? 'ऑनलाइन 1 बनाम 1 क्विज़ लड़ाई में शामिल होने के लिए आपको Google अकाउंट से लॉगिन करना होगा।'
                  : 'To join this live 1v1 Quiz Battle, you must sign in with a Google account. Guest accounts are not allowed in online matches.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            child: Text(
              isBn
                  ? 'বন্ধ করুন'
                  : isHi
                      ? 'बंद करें'
                      : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/login'); // Go to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isBn
                  ? 'লগইন করুন'
                  : isHi
                      ? 'लॉगिन करें'
                      : 'Sign In Now',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Upgraded battle score header bar showing player photo, score, and current question
class _BattleScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isDark;
  final String avatarUrl;
  final String currentProgress;

  const _BattleScoreBar({
    required this.label,
    required this.score,
    required this.color,
    required this.isDark,
    required this.avatarUrl,
    required this.currentProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Player Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                  : Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentProgress,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleOptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isDark;
  final VoidCallback? onTap;

  const _BattleOptionTile({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color getBgColor() {
      if (isCorrect) return const Color(0xFF047857); // emerald dark
      if (isWrong) return const Color(0xFFB91C1C); // red dark
      if (isSelected) return AppColors.primary.withValues(alpha: 0.15);
      return isDark ? AppColors.cardDark : Colors.white;
    }

    Color getBorderColor() {
      if (isCorrect) return const Color(0xFF10B981);
      if (isWrong) return const Color(0xFFEF4444);
      if (isSelected) return isDark ? AppColors.primary : AppColors.primaryDark;
      return isDark ? AppColors.outlineVariant : Colors.black12;
    }

    Color getTextColor() {
      if (isCorrect || isWrong) return Colors.white;
      if (isSelected) return isDark ? AppColors.primary : AppColors.primaryDark;
      return isDark ? Colors.white : AppColors.textPrimaryLight;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: getBgColor(),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: getBorderColor(),
            width: isSelected || isCorrect || isWrong ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: getTextColor(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isCorrect)
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 20)
            else if (isWrong)
              const Icon(Icons.cancel_outlined, color: Colors.white, size: 20)
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.primaryDark)
                    : Colors.grey.withValues(alpha: 0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
