import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import '../game_engine/data/ronin_parts.dart';

class ProgressService {
  static const String _key = 'current_level';
  static const int _min = 0;

  /// Последний валидный индекс уровня. Единый источник истины — `RoninParts.parts`
  /// (Ронин-1/01 T3, было `ShipParts.parts`): уровней ровно `RoninParts.parts.length`,
  /// индексы 0..`_max`. Не хардкодить отдельным числом — расхождение с `LevelMap`
  /// даёт `LevelMap.levelAt` assertion-краш при холодном старте (см. hotfix 2026-07-11).
  static int get _max => RoninParts.parts.length - 1;

  /// Возвращает текущий уровень (0.._max). Если ключ не задан — возвращает 0.
  Future<int> getCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_key) ?? 0;
    return v.clamp(_min, _max);
  }

  /// Сохраняет уровень. Значение автоматически clamp-ится в 0.._max.
  Future<void> setCurrentLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level.clamp(_min, _max));
  }

  /// Вызывать только после победы на уровне.
  /// Возвращает новый уровень (не выходит за _max).
  Future<int> advanceOnWin() async {
    final current = await getCurrentLevel();
    final next = math.min(current + 1, _max);
    await setCurrentLevel(next);
    return next;
  }

  /// Сбрасывает прогресс. Использовать только для отладки и тестов.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
