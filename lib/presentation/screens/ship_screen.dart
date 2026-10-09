import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../../game_engine/data/ronin_parts.dart';
import '../ship_render/ronin_art.dart';
import '../ship_render/ship_art.dart';
import '../ship_render/ship_composite_painter.dart';
import 'game_screen.dart';

/// Режим экрана корабля (Ронин-1/05 T1).
enum _ShipMode { manual, afterWin, finale }

/// Экран корабля-композит (канон — `docs/design/ronin-ship.html`): сверху
/// заголовок «РОНИН · СБОРКА» / «N / 15», в центре корабль из рисунка
/// ([ShipCompositePainter]), снизу одна кнопка (или надпись финала). Три режима:
///
/// - **ручной** (`ShipScreen()`) — собранное к моменту
///   (`ProgressService.getCollectedCount`); слева «Назад», внизу «Продолжить
///   сборку» (`Navigator.pop`). Вход — кнопка корабля на `GameScreen`.
/// - **после сборки** (`ShipScreen.afterWin(...)`) — маршрут «К кораблю» с паузы
///   «деталь собрана»: только что собранная деталь въезжает scale-in, «Назад»
///   нет, «Продолжить сборку» → [onContinue] (следующий уровень).
/// - **финал** (`ShipScreen.finale(...)`) — собраны все детали «Ронина-1»:
///   надпись «ПРОДОЛЖЕНИЕ СЛЕДУЕТ», ни кнопок, ни «Назад»; прогресс не
///   сбрасывается (решение PO 2026-07-29). В дев-сборке — «Сброс прогресса (dev)».
///
/// Рисунок — через интерфейс [ShipArt] ([art]; по умолчанию — «Ронин»).
class ShipScreen extends StatefulWidget {
  final _ShipMode _mode;
  final int? _afterWinCount;

  /// Колбэк «Продолжить сборку» в режиме после сборки.
  final VoidCallback? onContinue;

  /// Финал: последняя деталь въезжает scale-in (`false` — холодный старт
  /// приложения на финале, деталь уже на месте).
  final bool animateLast;

  /// Рисунок корабля; `null` — общий экземпляр [RoninArt].
  final ShipArt? art;

  /// Пауза перед въездом детали (`afterWin`, `finale` с [animateLast]): сначала
  /// корабль без новой детали, затем деталь въезжает scale-in
  /// ([kRevealDuration]). Отсчёт — от конца анимации входа маршрута экрана
  /// (нет маршрута или он уже открыт — от показа). Одно число для подстройки
  /// на устройстве.
  static const Duration kRevealDelay = Duration(milliseconds: 600);

  /// Длительность самого въезда детали (scale-in).
  static const Duration kRevealDuration = Duration(milliseconds: 400);

  /// Ручной экран корабля: собранное к моменту, «Назад» и «Продолжить сборку».
  const ShipScreen({super.key, this.art})
    : _mode = _ShipMode.manual,
      _afterWinCount = null,
      onContinue = null,
      animateLast = false;

  /// После сборки детали (маршрут «К кораблю»): корабль с [collectedCount]
  /// деталями, деталь `collectedCount − 1` въезжает; «Продолжить сборку» →
  /// [onContinue].
  const ShipScreen.afterWin({
    super.key,
    required int collectedCount,
    required VoidCallback this.onContinue,
    this.art,
  }) : _mode = _ShipMode.afterWin,
       _afterWinCount = collectedCount,
       animateLast = true;

  /// Финал «Ронина-1»: собраны все детали, надпись «ПРОДОЛЖЕНИЕ СЛЕДУЕТ».
  const ShipScreen.finale({super.key, this.art, this.animateLast = true})
    : _mode = _ShipMode.finale,
      _afterWinCount = null,
      onContinue = null;

  @override
  State<ShipScreen> createState() => _ShipScreenState();
}

// Токены DESIGN.md (`ronin-ship.html`).
const Color _spaceBg = Color(0xFF0F1114); // hsl(220 14% 7%)
const Color _matteBlack = Color(0xFF1D2025); // hsl(220 12% 13%)
const Color _gunmetal = Color(0xFF32363E); // hsl(220 10% 22%)
const Color _hudIcon = Color(0xFFB1B7BE); // hsl(215 9% 72%)
const Color _hazardOrange = Color(0xFFBE642D); // hsl(23 62% 46%)
const Color _doneGlow = Color(0x8CE09952); // hsla(30 70% 60% / 55%)
const Color _kickColor = Color(0xFF7C848D); // `.dtop .t .k`
const Color _countColor = Color(0xFFD7DDE3); // `.dtop .t .n`
const Color _primaryText = Color(0xFFF0D6C2); // `.btn.primary`

/// Высота нижней кнопки `.dfoot .btn` — её же держит надпись финала.
const double _footHeight = 44;

class _ShipScreenState extends State<ShipScreen>
    with SingleTickerProviderStateMixin {
  /// Рисунок: заданный или общий «Ронин» ([RoninArt.shared] — картинки слоёв
  /// записываются один раз за запуск, тот же экземпляр рисует поле укладки).
  ShipArt get _art => widget.art ?? RoninArt.shared;

  AnimationController? _revealController;
  Animation<double>? _revealAnim;
  late final Future<int> _collected;

  /// Анимация входа маршрута, пока на неё висит слушатель старта въезда.
  Animation<double>? _routeAnim;
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    final animate = switch (widget._mode) {
      _ShipMode.manual => false,
      _ShipMode.afterWin => true,
      _ShipMode.finale => widget.animateLast,
    };
    if (animate) {
      // Один контроллер на паузу + въезд: пауза — начальный отрезок кривой
      // (прогресс 0, деталь не видна). Отдельного таймера нет — контроллер
      // гасится в dispose вместе с экраном. Запуск — в didChangeDependencies,
      // после перехода маршрута.
      final delay = ShipScreen.kRevealDelay;
      final total = delay + ShipScreen.kRevealDuration;
      final c = AnimationController(vsync: this, duration: total);
      _revealController = c;
      _revealAnim = CurvedAnimation(
        parent: c,
        curve: Interval(
          delay.inMilliseconds / total.inMilliseconds,
          1.0,
          curve: Curves.easeOut,
        ),
      );
    }
    if (widget._mode == _ShipMode.manual) {
      _collected = ProgressService().getCollectedCount();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Маршрут доступен только здесь (не в initState). Старт — один раз.
    if (_revealController != null && !_revealScheduled) {
      _revealScheduled = true;
      _startRevealAfterRoute();
    }
  }

  /// Пауза [ShipScreen.kRevealDelay] отсчитывается от конца перехода экрана:
  /// нет маршрута или он уже открыт — старт сразу, иначе по `completed`
  /// анимации входа маршрута (слушатель снимается в [dispose]).
  ///
  /// Первый кадр push маршрут строится `offstage` (приём Hero): его анимация
  /// тогда показывает `completed`, хотя переход ещё не начался, — в этом случае
  /// ждём настоящего `completed` после выхода из `offstage`.
  void _startRevealAfterRoute() {
    final route = ModalRoute.of(context);
    final routeAnim = route?.animation;
    if (route == null ||
        routeAnim == null ||
        (!route.offstage && routeAnim.status == AnimationStatus.completed)) {
      _revealController!.forward();
      return;
    }
    _routeAnim = routeAnim;
    routeAnim.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnim?.removeStatusListener(_onRouteStatus);
    _routeAnim = null;
    if (mounted) _revealController!.forward();
  }

  @override
  void dispose() {
    _routeAnim?.removeStatusListener(_onRouteStatus);
    _revealController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _spaceBg,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 22), // `.safe.b`
        child: switch (widget._mode) {
          _ShipMode.manual => _buildManual(context),
          _ShipMode.afterWin => _buildAfterWin(),
          _ShipMode.finale => _buildFinale(context),
        },
      ),
    );
  }

  /// Ручной режим: читает прогресс, статичный корабль, «Назад» и «Продолжить сборку».
  Widget _buildManual(BuildContext context) {
    return FutureBuilder<int>(
      future: _collected,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final collected = math.min(snapshot.data!, RoninParts.parts.length);
        return _layout(
          collected: collected,
          onBack: () => Navigator.of(context).pop(),
          ship: _ship(collected),
          foot: _PrimaryButton(
            key: const Key('ship_continue_button'),
            label: 'Продолжить сборку',
            onTap: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  /// После сборки: деталь `collected-1` въезжает scale-in + «Продолжить сборку».
  Widget _buildAfterWin() {
    final collected = widget._afterWinCount!;
    return _layout(
      collected: collected,
      ship: _ship(collected),
      foot: _PrimaryButton(
        key: const Key('ship_continue_button'),
        label: 'Продолжить сборку',
        onTap: widget.onContinue!,
      ),
    );
  }

  /// Финал: все детали, надпись «ПРОДОЛЖЕНИЕ СЛЕДУЕТ» на месте кнопки; в дев-сборке
  /// под ней — сброс прогресса.
  Widget _buildFinale(BuildContext context) {
    final collected = RoninParts.parts.length;
    return _layout(
      collected: collected,
      ship: _ship(collected),
      foot: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: _footHeight,
            child: Center(
              child: Text(
                'ПРОДОЛЖЕНИЕ СЛЕДУЕТ',
                key: Key('ship_finale_text'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hazardOrange,
                  fontSize: 12,
                  letterSpacing: 2.88, // .24em @ 12px
                  shadows: [Shadow(color: _doneGlow, blurRadius: 12)],
                ),
              ),
            ),
          ),
          if (kDebugMode)
            TextButton(
              key: const Key('ship_dev_reset'),
              onPressed: () => _devReset(context),
              child: const Text('Сброс прогресса (dev)'),
            ),
        ],
      ),
    );
  }

  /// Дев-сброс с финала: прогресс 0 → первый уровень.
  Future<void> _devReset(BuildContext context) async {
    // Захватить navigator ДО await/перехода, пока context валиден.
    final navigator = Navigator.of(context);
    await ProgressService().reset();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen(levelIndex: 0)),
    );
  }

  /// Корабль с [collected] деталями; при анимации — деталь `collected-1`
  /// въезжает scale-in.
  Widget _ship(int collected) {
    final anim = _revealAnim;
    if (anim == null) {
      return CustomPaint(
        painter: ShipCompositePainter(art: _art, collectedCount: collected),
      );
    }
    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) => CustomPaint(
        painter: ShipCompositePainter(
          art: _art,
          collectedCount: collected,
          revealPartIndex: collected - 1,
          revealProgress: anim.value,
        ),
      ),
    );
  }

  /// Макет мокапа: `.dtop` → `.shipstage` (вся свободная область) → `.dfoot`.
  Widget _layout({
    required int collected,
    required Widget ship,
    required Widget foot,
    VoidCallback? onBack,
  }) {
    return Column(
      children: [
        _Header(collected: collected, onBack: onBack),
        Expanded(child: SizedBox.expand(child: ship)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: foot,
        ),
      ],
    );
  }
}

/// `.dtop`: кнопка 34×34 слева (после сборки и в финале — пусто), по центру
/// заголовок в две строки. Правой кнопки «⤢» нет (функции нет) — справа пустое
/// место той же ширины, чтобы заголовок стоял по центру.
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
          height: _footHeight,
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
