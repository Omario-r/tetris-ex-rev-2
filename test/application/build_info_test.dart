import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/application/build_info.dart';

void main() {
  group('composeBuildLabel', () {
    test('обе части пусты → «dev»', () {
      expect(composeBuildLabel('', ''), 'dev');
    });

    test('только хеш', () {
      expect(composeBuildLabel('b678a04', ''), 'b678a04');
    });

    test('только время', () {
      expect(composeBuildLabel('', '2026-10-10 12:30'), '2026-10-10 12:30');
    });

    test('хеш и время через « · »', () {
      expect(
        composeBuildLabel('b678a04', '2026-10-10 12:30'),
        'b678a04 · 2026-10-10 12:30',
      );
    });
  });

  test('без --dart-define: подпись «dev», дев-инструменты включены', () {
    expect(kDevTools, isTrue);
    expect(kBuildCommit, isEmpty);
    expect(kBuildTime, isEmpty);
    expect(buildLabel(), 'dev');
  });
}
