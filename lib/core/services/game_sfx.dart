// lib/core/services/game_sfx.dart
// Lightweight SFX playback for the brain games.
//
// Sounds are short procedurally-generated WAV clips in assets/sfx so the app
// ships with zero audio licensing concerns. Playback is fire-and-forget and
// silently no-ops when disabled or on platforms without audio support.

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound cues shared across every game. Adding a new cue only requires a new
/// enum value plus a WAV in `assets/sfx` named `sfx_<name>.wav`.
enum GameSfx {
  tap,
  countdown,
  correct,
  combo,
  wrong,
  levelUp,
  gameOver,
}

class GameSfxService {
  GameSfxService._();
  static final GameSfxService instance = GameSfxService._();

  final Map<GameSfx, AudioPlayer> _players = {};
  bool _enabled = true;
  bool _initialized = false;

  static const String prefKey = 'game_sfx_enabled';

  static String _asset(GameSfx sfx) => 'sfx/sfx_${sfx.name}.wav';

  /// Loads the muted preference. Safe to call from main(); repeated calls no-op.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(prefKey, value);
      });
    } catch (_) {}
  }

  AudioPlayer _playerFor(GameSfx sfx) {
    return _players.putIfAbsent(sfx, () => AudioPlayer());
  }

  /// Plays a cue. Never throws; failures are swallowed so a missing sound can
  /// never crash a game. Calling [play] while the same cue is still sounding
  /// simply restarts it (no per-call stop dance that could queue up work on the
  /// platform channel and stall under rapid taps).
  Future<void> play(GameSfx sfx) async {
    if (!_enabled) return;
    try {
      final player = _playerFor(sfx);
      await player.play(AssetSource(_asset(sfx)));
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
