// lib/core/services/gamification/power_up_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/gamification_models.dart';

class PowerUpService {
  PowerUpService._();
  static final PowerUpService instance = PowerUpService._();

  late Box _powerUpsBox;

  Future<void> init() async {
    _powerUpsBox = await Hive.openBox('power_ups');
  }

  Map<PowerUpType, PowerUpModel> getPowerUps() {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});

    return {
      PowerUpType.extraTime: PowerUpModel(
        type: PowerUpType.extraTime,
        nameKey: 'Extra Time',
        descriptionKey: '+15 seconds for current question',
        icon: '⏰',
        cost: 20,
        quantity: saved['extraTime'] ?? 0,
      ),
      PowerUpType.fiftyFifty: PowerUpModel(
        type: PowerUpType.fiftyFifty,
        nameKey: '50-50',
        descriptionKey: 'Remove 2 wrong answers',
        icon: '🎯',
        cost: 30,
        quantity: saved['fiftyFifty'] ?? 0,
      ),
      PowerUpType.skipQuestion: PowerUpModel(
        type: PowerUpType.skipQuestion,
        nameKey: 'Skip',
        descriptionKey: 'Skip current question',
        icon: '⏭️',
        cost: 15,
        quantity: saved['skipQuestion'] ?? 0,
      ),
      PowerUpType.doubleXp: PowerUpModel(
        type: PowerUpType.doubleXp,
        nameKey: '2X XP',
        descriptionKey: 'Double XP for this quiz',
        icon: '✨',
        cost: 50,
        quantity: saved['doubleXp'] ?? 0,
      ),
    };
  }

  Future<void> addPowerUp(PowerUpType type) async {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});
    final keyMap = {
      PowerUpType.extraTime: 'extraTime',
      PowerUpType.fiftyFifty: 'fiftyFifty',
      PowerUpType.skipQuestion: 'skipQuestion',
      PowerUpType.doubleXp: 'doubleXp',
    };

    final safeKey = keyMap[type] ?? type.name;
    saved[safeKey] = (saved[safeKey] ?? 0) + 1;
    await _powerUpsBox.put('power_ups', saved);
  }

  Future<bool> usePowerUp(PowerUpType type) async {
    final saved = _powerUpsBox.get('power_ups', defaultValue: <String, int>{});
    final keyMap = {
      PowerUpType.extraTime: 'extraTime',
      PowerUpType.fiftyFifty: 'fiftyFifty',
      PowerUpType.skipQuestion: 'skipQuestion',
      PowerUpType.doubleXp: 'doubleXp',
    };

    final key = keyMap[type] ?? type.name;
    if ((saved[key] ?? 0) <= 0) return false;

    saved[key] = (saved[key] ?? 1) - 1;
    await _powerUpsBox.put('power_ups', saved);
    return true;
  }
}
