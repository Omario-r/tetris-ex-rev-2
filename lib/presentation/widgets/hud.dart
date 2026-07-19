import 'package:flutter/material.dart';

import '../../game_engine/game/game_controller.dart';
import '../../game_engine/game/game_state.dart';
import '../theme/canister_charge_painter.dart';

/// On-screen control panel for movement and the boom (arm/detonate) button.
class GameHud extends StatelessWidget {
  /// Creates a HUD bound to the game [controller] and [state].
  const GameHud({
    super.key,
    required this.controller,
    required this.state,
    this.animValue = 0.0,
  });

  /// Game controller for player commands.
  final GameController controller;

  /// Current game state snapshot.
  final GameState state;

  /// Animation phase (`0..1`) driving the armed boom button's glow pulse —
  /// same source/period as `BoardPainter.animValue` (`GameScreen`'s ticker,
  /// `el-halo`/`armedGlow`); the HUD does not run its own timer.
  final double animValue;

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
          _BoomButton(
            controller: controller,
            state: state,
            animValue: animValue,
          ),
        ],
      ),
    );
  }
}

/// Объединённая кнопка взрыва — «канистра-заряд» (Стори 02 T1, канон
/// `docs/design/game-field.html` `.boom`/`.can`/`.armedcore`/`.cnt`).
///
/// State-машина (UI-триггер двух существующих команд контроллера, своей
/// логики нет): **Взведён** (`state.canDetonate`) → тап `controller.detonate`;
/// иначе **Готов** (`state.charges > 0`) → тап `controller.armExplosive`
/// (активность — `state.canArm`); иначе **Пусто** — неактивна, задымлена.
class _BoomButton extends StatelessWidget {
  const _BoomButton({
    required this.controller,
    required this.state,
    required this.animValue,
  });

  final GameController controller;
  final GameState state;
  final double animValue;

  // Mockup `.boom`: 76×76, radius 18, darkNiche fill, hazardOrange 1px border.
  static const double _size = 76.0;
  static const Color _darkNiche = Color(0xFF272A30); // darkNiche token
  static const Color _hazardOrange = Color(0xFFBE642D); // hazardOrange token
  static const Color _gunmetal = Color(0xFF32363E); // gunmetal token
  static const Color _badgeTextDark = Color(0xFF1A130C); // `.boom .cnt` text
  static const Color _badgeTextGray = Color(0xFF9AA2AB); // empty `.cnt` text

  @override
  Widget build(BuildContext context) {
    final ChargeIconState iconState;
    final bool active;
    final VoidCallback? onTap;
    if (state.canDetonate) {
      iconState = ChargeIconState.armed;
      active = true;
      onTap = controller.detonate;
    } else if (state.charges > 0) {
      iconState = ChargeIconState.ready;
      active = state.canArm;
      onTap = state.canArm ? controller.armExplosive : null;
    } else {
      iconState = ChargeIconState.empty;
      active = false;
      onTap = null;
    }
    final empty = iconState == ChargeIconState.empty;
    // Пусто — кнопка задымлена (opacity ~0.55, мокап); Готов, но временно
    // неактивна (canArm false при charges > 0) — прежняя HUD-конвенция
    // дизаблинга (opacity 0.3), мокап это отдельно не описывает.
    final opacity = empty ? 0.55 : (active ? 1.0 : 0.3);

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        key: const Key('boom_button'),
        onTap: onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _boomChrome(),
              Center(
                child: SizedBox(
                  width: iconState == ChargeIconState.armed ? 36.0 : 34.0,
                  height: iconState == ChargeIconState.armed ? 36.0 : 46.0,
                  child: CustomPaint(
                    painter: CanisterChargePainter(
                      state: iconState,
                      pulse: animValue,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -9,
                right: -9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: empty ? _gunmetal : _hazardOrange,
                    borderRadius: BorderRadius.circular(9.0),
                  ),
                  child: Text(
                    '×${state.charges}',
                    key: const Key('charges_indicator'),
                    style: TextStyle(
                      color: empty ? _badgeTextGray : _badgeTextDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // `.boom` container chrome: darkNiche fill + hazardOrange border + inset
  // top-light/bottom-dark bevel bands (approximates mockup's inset box-shadow).
  Widget _boomChrome() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.0),
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: _darkNiche,
          border: Border.fromBorderSide(
            BorderSide(color: _hazardOrange, width: 1.0),
          ),
        ),
        child: Column(
          children: [
            Container(height: 3, color: Colors.white.withValues(alpha: 0.06)),
            Expanded(child: Container()),
            Container(height: 4, color: Colors.black.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
