import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../../game_engine/data/ronin_parts.dart';
import '../ship_render/ronin_art.dart';
import '../ship_render/ship_art.dart';
import '../ship_render/ship_composite_painter.dart';

/// Экран корабля-композит (канон — `docs/design/ronin-ship.html`): сверху
/// заголовок «РОНИН · СБОРКА» / «N / 15», в центре корабль из рисунка
/// ([ShipCompositePainter]), снизу одна кнопка. Два режима:
///
/// - **ручной** (`ShipScreen()`) — собранное к моменту, `min(current_level, 15)`
///   деталей; читает [ProgressService]; слева «Назад», внизу «Продолжить сборку»
///   (`Navigator.pop`).
/// - **авто-показ** (`ShipScreen.reveal(...)`) — после победы: фиксированное число
///   деталей, только что заработанная въезжает scale-in; кнопка «Далее»/«Начать
///   заново», без «Назад» (поток меняется в Ронин-1/05).
///
/// Рисунок — через интерфейс [ShipArt] ([art]; по умолчанию — «Ронин»).
class ShipScreen extends StatefulWidget {
  final int? _revealCount;
  final VoidCallback? _onNext;
  final bool _isComplete;

  /// Рисунок корабля; `null` — общий экземпляр [RoninArt].
  final ShipArt? art;

  const ShipScreen({super.key, this.art})
    : _revealCount = null,
      _onNext = null,
      _isComplete = false;

  /// Авто-показ прироста после победы: корабль с [collectedCount] деталями и кнопкой
  /// «Далее» (или «Начать заново», если [isComplete] — собран последний уровень).
  const ShipScreen.reveal({
    super.key,
    required int collectedCount,
    required this._onNext,
    this._isComplete = false,
    this.art,
  }) : _revealCount = collectedCount;

  bool get _isReveal => _onNext != null;

  @override
  State<ShipScreen> createState() => _ShipScreenState();
}

// Токены DESIGN.md (`ronin-ship.html`).
const Color _spaceBg = Color(0xFF0F1114); // hsl(220 14% 7%)
const Color _matteBlack = Color(0xFF1D2025); // hsl(220 12% 13%)
const Color _gunmetal = Color(0xFF32363E); // hsl(220 10% 22%)
const Color _hudIcon = Color(0xFFB1B7BE); // hsl(215 9% 72%)
const Color _hazardOrange = Color(0xFFBE642D); // hsl(23 62% 46%)
const Color _kickColor = Color(0xFF7C848D); // `.dtop .t .k`
const Color _countColor = Color(0xFFD7DDE3); // `.dtop .t .n`
const Color _primaryText = Color(0xFFF0D6C2); // `.btn.primary`

class _ShipScreenState extends State<ShipScreen>
    with SingleTickerProviderStateMixin {
  /// Рисунок: заданный или общий «Ронин» ([RoninArt.shared] — картинки слоёв
  /// записываются один раз за запуск, тот же экземпляр рисует поле укладки).
  ShipArt get _art => widget.art ?? RoninArt.shared;

  AnimationController? _revealController;
  late final Animation<double> _revealAnim;
  late final Future<int> _level;

  @override
  void initState() {
    super.initState();
    if (widget._isReveal) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _revealController = c;
      _revealAnim = CurvedAnimation(parent: c, curve: Curves.easeOut);
      c.forward();
    } else {
      _level = ProgressService().getCurrentLevel();
    }
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _spaceBg,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 22), // `.safe.b`
        child: widget._isReveal ? _buildReveal(context) : _buildManual(context),
      ),
    );
  }

  /// Ручной режим: читает прогресс, статичный корабль, «Назад» и «Продолжить сборку».
  Widget _buildManual(BuildContext context) {
    return FutureBuilder<int>(
      future: _level,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final collected = math.min(snapshot.data!, RoninParts.parts.length);
        return _layout(
          collected: collected,
          onBack: () => Navigator.of(context).pop(),
          ship: CustomPaint(
            painter: ShipCompositePainter(art: _art, collectedCount: collected),
          ),
          button: _PrimaryButton(
            key: const Key('ship_continue_button'),
            label: 'Продолжить сборку',
            onTap: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  /// Авто-показ: деталь `collected-1` въезжает scale-in + кнопка перехода.
  Widget _buildReveal(BuildContext context) {
    final collected = widget._revealCount!;
    return _layout(
      collected: collected,
      ship: AnimatedBuilder(
        animation: _revealAnim,
        builder: (_, _) => CustomPaint(
          painter: ShipCompositePainter(
            art: _art,
            collectedCount: collected,
            revealPartIndex: collected - 1,
            revealProgress: _revealAnim.value,
          ),
        ),
      ),
      button: _PrimaryButton(
        key: const Key('ship_next_button'),
        label: widget._isComplete ? 'Начать заново' : 'Далее',
        onTap: widget._onNext!,
      ),
    );
  }

  /// Макет мокапа: `.dtop` → `.shipstage` (вся свободная область) → `.dfoot`.
  Widget _layout({
    required int collected,
    required Widget ship,
    required Widget button,
    VoidCallback? onBack,
  }) {
    return Column(
      children: [
        _Header(collected: collected, onBack: onBack),
        Expanded(child: SizedBox.expand(child: ship)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: button,
        ),
      ],
    );
  }
}

/// `.dtop`: кнопка 34×34 слева (в авто-показе — пусто), по центру заголовок
/// в две строки. Правой кнопки «⤢» нет (функции нет) — справа пустое место
/// той же ширины, чтобы заголовок стоял по центру.
class _Header extends StatelessWidget {
  const _Header({required this.collected, this.onBack});

  final int collected;
  final VoidCallback? onBack;

  static const double _btn = 34;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            if (onBack != null)
              _IconButton(
                key: const Key('ship_back_button'),
                icon: Icons.arrow_back_ios_new,
                tooltip: 'Назад',
                onTap: onBack!,
              )
            else
              const SizedBox(width: _btn),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'РОНИН · СБОРКА',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kickColor,
                      fontSize: 9,
                      letterSpacing: 1.44, // .16em @ 9px
                    ),
                  ),
                  Text(
                    '$collected / ${RoninParts.parts.length}',
                    key: const Key('ship_collected_text'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _countColor,
                      fontSize: 13,
                      letterSpacing: 1.3, // .1em @ 13px
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _btn),
          ],
        ),
      ),
    );
  }
}

/// `.iconbtn`: 34×34, радиус 9, `matteBlack`, рамка 1 `gunmetal`, глиф `hudIcon`.
class _IconButton extends StatelessWidget {
  const _IconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _Header._btn,
          height: _Header._btn,
          decoration: BoxDecoration(
            color: _matteBlack,
            border: Border.all(color: _gunmetal),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _hudIcon, size: 15),
        ),
      ),
    );
  }
}

/// `.dfoot .btn.primary`: на всю ширину, высота 44, радиус 10, фон `matteBlack`,
/// рамка 1 + внутренняя обводка 1 `hazardOrange` (= 2 px), текст 12 px `.05em`.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _matteBlack,
            border: Border.all(color: _hazardOrange, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 12,
              letterSpacing: 0.6, // .05em @ 12px
            ),
          ),
        ),
      ),
    );
  }
}
