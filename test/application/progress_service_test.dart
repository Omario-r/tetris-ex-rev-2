import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';

/// Число деталей N и последний валидный индекс уровня — тот же единый источник
/// истины, что и в `ProgressService` (`RoninParts.parts.length`, Ронин-1/01 T3,
/// было `ShipParts.parts.length`), чтобы тест не разошёлся с реальным контентом
/// при его росте/сокращении (см. hotfix 2026-07-11).
final _parts = RoninParts.parts.length;
final _maxLevel = _parts - 1;

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
    expect(await s.getCollectedCount(), 0);
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
    expect(await s.getCollectedCount(), _parts);
  });

  group('Число собранных деталей (Ронин-1/05 T1)', () {
    test('getCollectedCount по умолчанию 0', () async {
      expect(await ProgressService().getCollectedCount(), 0);
    });

    test('completeLevel(i) засчитывает деталь: собрано i + 1', () async {
      final s = ProgressService();
      expect(await s.completeLevel(0), 1);
      expect(await s.getCollectedCount(), 1);
      expect(await s.getCurrentLevel(), 1);
    });

    test('completeLevel идемпотентен: дважды → +1 один раз', () async {
      final s = ProgressService();
      await s.setCollectedCount(3);
      expect(await s.completeLevel(3), 4);
      expect(await s.completeLevel(3), 4);
      expect(await s.getCollectedCount(), 4);
    });

    test('completeLevel не уменьшает: completeLevel(2) при собрано 5 → 5',
        () async {
      final s = ProgressService();
      await s.setCollectedCount(5);
      expect(await s.completeLevel(2), 5);
      expect(await s.getCollectedCount(), 5);
    });

    test('completeLevel: потолок N (последняя деталь и выше)', () async {
      final s = ProgressService();
      expect(await s.completeLevel(_maxLevel), _parts);
      expect(await s.completeLevel(_parts + 10), _parts);
      expect(await s.getCollectedCount(), _parts);
    });

    test('getCurrentLevel при собрано N → N − 1', () async {
      final s = ProgressService();
      await s.setCollectedCount(_parts);
      expect(await s.getCollectedCount(), _parts);
      expect(await s.getCurrentLevel(), _maxLevel);
    });

    test('setCollectedCount клампится в 0..N', () async {
      final s = ProgressService();
      await s.setCollectedCount(999);
      expect(await s.getCollectedCount(), _parts);
      await s.setCollectedCount(-3);
      expect(await s.getCollectedCount(), 0);
    });
  });
}
