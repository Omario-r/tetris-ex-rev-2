import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import '../game_engine/data/ronin_parts.dart';

/// Персист прогресса сборки корабля.
///
/// Ключ `current_level` хранит **число собранных деталей** 0..[_parts]
/// (Ронин-1/05 T1). Смысл значения прежний — «уровень i ⇔ собрано i»; верхняя
/// граница — N (`RoninParts.parts.length`), чтобы выразить «собраны все N»
/// (финал «продолжение следует»).
class ProgressService {
  static const String _key = 'current_level';
  static const int _min = 0;

  /// Число деталей (= уровней). Единый источник истины — `RoninParts.parts`
  /// (Ронин-1/01 T3). Не хардкодить отдельным числом —
  /// расхождение с `LevelMap` даёт `LevelMap.levelAt` assertion-краш при
  /// холодном старте (см. hotfix 2026-07-11).
  static int get _parts => RoninParts.parts.length;

  /// Последний валидный индекс уровня (0.._max).
  static int get _max => _parts - 1;

  /// Сколько деталей собрано (0..N). Ключ не задан — 0. Кламп на чтении:
  /// устаревший/повреждённый персист самовосстанавливается.
  Future<int> getCollectedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_key) ?? 0;
    return v.clamp(_min, _parts);
  }

  /// Текущий уровень (0.._max): `min(собрано, N − 1)`. После финала (собрано N)
  /// — последний уровень, индекс всегда валиден для `LevelMap`.
  Future<int> getCurrentLevel() async {
    return math.min(await getCollectedCount(), _max);
  }

  /// Сохраняет уровень. Значение clamp-ится в 0.._max.
  Future<void> setCurrentLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level.clamp(_min, _max));
  }

  /// Сохраняет число собранных деталей (чит «Состояние корабля»). Кламп 0..N.
  Future<void> setCollectedCount(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, n.clamp(_min, _parts));
  }

  /// Засчитывает собранную деталь уровня [levelIndex]: собрано =
  /// `max(собрано, levelIndex + 1)`, кламп 0..N. Идемпотентно по уровню
  /// (повтор не даёт второго +1) и никогда не уменьшает прогресс. Возвращает
  /// новое число собранных.
  Future<int> completeLevel(int levelIndex) async {
    final current = await getCollectedCount();
    final next = math.max(current, levelIndex + 1).clamp(_min, _parts);
    await setCollectedCount(next);
    return next;
  }

  /// Сбрасывает прогресс. Использовать только для отладки и тестов.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
