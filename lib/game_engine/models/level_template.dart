import 'target_mask.dart';

class LevelTemplate {
  final int boardWidth;
  final int boardHeight;
  final TargetMask targetMask;
  final int targetX;
  final int targetY;
  final int objectId;       // индекс объекта (0..3), дефолт 0
  final int fragmentIndex;  // индекс фрагмента (0..3), дефолт 0

  LevelTemplate({
    required this.boardWidth,
    required this.boardHeight,
    required this.targetMask,
    required this.targetX,
    required this.targetY,
    this.objectId = 0,
    this.fragmentIndex = 0,
  });
}

/// Дефолтный уровень MVP.
final defaultLevel = LevelTemplate(
  boardWidth: 10,
  boardHeight: 20,
  targetMask: defaultTargetMask,
  targetX: 2,
  targetY: 14,
);
