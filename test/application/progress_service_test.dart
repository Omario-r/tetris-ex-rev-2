import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';

/// Последний валидный индекс уровня — тот же единый источник истины, что и в
/// `ProgressService._max` (`ShipParts.parts.length - 1`), чтобы тест не разошёлся
/// с реальным контентом при его росте/сокращении (см. hotfix 2026-07-11).
final _maxLevel = ShipParts.parts.length - 1;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Default level is 0', () async {
    final s = ProgressService();
    expect(await s.getCurrentLevel(), 0);
  });

  test('setCurrentLevel / getCurrentLevel round-trip', () async {
    final s = ProgressService();
    await s.setCurrentLevel(5);
    expect(await s.getCurrentLevel(), 5);
  });

  test('advanceOnWin increments level', () async {
    final s = ProgressService();
    await s.setCurrentLevel(0);
    expect(await s.advanceOnWin(), 1);
    expect(await s.getCurrentLevel(), 1);
  });

  test('advanceOnWin clamps at _maxLevel (== ShipParts.parts.length - 1)', () async {
    final s = ProgressService();
    await s.setCurrentLevel(_maxLevel);
    expect(await s.advanceOnWin(), _maxLevel);
    expect(await s.getCurrentLevel(), _maxLevel);
  });

  test('Out-of-range values are clamped', () async {
    final s = ProgressService();
    await s.setCurrentLevel(999);
    expect(await s.getCurrentLevel(), _maxLevel);
    await s.setCurrentLevel(-10);
    expect(await s.getCurrentLevel(), 0);
  });

  test('reset clears progress', () async {
    final s = ProgressService();
    await s.setCurrentLevel(3);
    await s.reset();
    expect(await s.getCurrentLevel(), 0);
  });

  test(
      'значение, оставшееся persisted вне диапазона (напр. из старой сборки '
      'с большим числом уровней), самовосстанавливается clamp-ом на чтении',
      () async {
    SharedPreferences.setMockInitialValues({'current_level': 999});
    final s = ProgressService();
    expect(await s.getCurrentLevel(), _maxLevel,
        reason: 'clamp на чтении защищает от краша LevelMap.levelAt на '
            'устаревшем/повреждённом персисте — регрессия к hotfix 2026-07-11');
  });
}
