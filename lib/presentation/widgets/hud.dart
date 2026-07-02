import 'package:flutter/material.dart';

import '../../game_engine/game/game_controller.dart';
import '../../game_engine/game/game_state.dart';
import '../theme/overlays.dart';

/// On-screen control panel for movement, arm, and detonate actions.
class GameHud extends StatelessWidget {
  /// Creates a HUD bound to the game [controller] and [state].
  const GameHud({
    super.key,
    required this.controller,
    required this.state,
  });

  /// Game controller for player commands.
  final GameController controller;

  /// Current game state snapshot.
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left, color: Colors.white),
            onPressed: () => controller.moveLeft(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            onPressed: () => controller.softDrop(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.rotateCW(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right, color: Colors.white),
            onPressed: () => controller.moveRight(),
          ),
          const SizedBox(width: 24),
          Opacity(
            opacity: state.canArm ? 1.0 : 0.3,
            child: IconButton(
              key: const Key('arm_button'),
              icon: SizedBox(
                width: 32,
                height: 32,
                child: CustomPaint(
                  painter: const CreeperFacePainter(),
                ),
              ),
              tooltip: 'Arm explosive',
              onPressed: state.canArm ? () => controller.armExplosive() : null,
            ),
          ),
          Opacity(
            opacity: state.canDetonate ? 1.0 : 0.3,
            child: IconButton(
              icon: const Text(
                '💥',
                style: TextStyle(fontSize: 24),
              ),
              onPressed:
                  state.canDetonate ? () => controller.detonate() : null,
            ),
          ),
        ],
      ),
    );
  }
}
