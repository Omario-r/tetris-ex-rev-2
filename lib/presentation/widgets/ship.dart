import 'package:flutter/material.dart';

/// Число деталей-заглушек единого корабля (дев-контент).
///
/// Единый источник истины для связки «3 уровня ↔ 3 детали» (Стори 01).
/// Прогресс сборки клампится этим числом: собрано = `min(current_level, kShipPartCount)`.
const int kShipPartCount = 3;

/// Деталь-заглушка корабля: прямоугольник в нормализованной сетке 10×10.
///
/// Реального дизайна деталей здесь нет — это временные заглушки (эпик «Контент»
/// заменит их боевыми деталями). Порядок в [Ship.parts] = порядок сборки:
/// деталь i встаёт после прохождения уровня i.
class ShipPart {
  /// Имя детали (для отладки/тестов).
  final String name;

  /// Область детали в сетке 10×10 (левый-верх — (0,0), y растёт вниз).
  final Rect unit;

  const ShipPart({required this.name, required this.unit});
}

/// Корабль = упорядоченный список деталей-заглушек.
///
/// Ровно [kShipPartCount] деталей, сложенных в грубый силуэт «ракеты» (нос → корпус →
/// основание), чтобы читалось «строю что-то большое».
class Ship {
  /// Детали в порядке сборки. Длина == [kShipPartCount].
  static const List<ShipPart> parts = <ShipPart>[
    ShipPart(name: 'нос', unit: Rect.fromLTWH(4, 1, 2, 2)),
    ShipPart(name: 'корпус', unit: Rect.fromLTWH(3, 3, 4, 4)),
    ShipPart(name: 'основание', unit: Rect.fromLTWH(2, 7, 6, 2)),
  ];
}

/// Рисует единый корабль из [Ship.parts]: первые [collectedCount] деталей —
/// установлены (залиты), остальные — ещё не собраны (контур).
class ShipPainter extends CustomPainter {
  /// Сколько деталей уже собрано (0..[kShipPartCount]). Клампится в конструкторе.
  final int collectedCount;

  ShipPainter({required int collectedCount})
      : collectedCount = collectedCount.clamp(0, kShipPartCount);

  @override
  void paint(Canvas canvas, Size size) {
    // Квадратная сетка 10×10, вписанная в canvas и отцентрованная.
    final cell = (size.width < size.height ? size.width : size.height) / 10;
    final dx = (size.width - cell * 10) / 2;
    final dy = (size.height - cell * 10) / 2;

    final fillPaint = Paint()..color = Colors.deepOrange;
    final installedStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ghostStroke = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < Ship.parts.length; i++) {
      final u = Ship.parts[i].unit;
      final rect = Rect.fromLTWH(
        dx + u.left * cell,
        dy + u.top * cell,
        u.width * cell,
        u.height * cell,
      );
      if (i < collectedCount) {
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, installedStroke);
      } else {
        canvas.drawRect(rect, ghostStroke);
      }
    }
  }

  @override
  bool shouldRepaint(ShipPainter oldDelegate) =>
      oldDelegate.collectedCount != collectedCount;
}
