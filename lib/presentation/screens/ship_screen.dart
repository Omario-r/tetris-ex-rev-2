import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../widgets/ship.dart';

/// Экран корабля. Два режима:
///
/// - **ручной** (`ShipScreen()`) — статичный вид собранного к моменту корабля,
///   `min(current_level, kShipPartCount)` деталей; читает [ProgressService];
///   есть «Назад» (Стори 01).
/// - **авто-показ** (`ShipScreen.reveal(...)`) — после победы: фиксированное число
///   деталей, только что заработанная въезжает scale-in; кнопка «Далее»/«Начать
///   заново», без «Назад» (Стори 03).
class ShipScreen extends StatefulWidget {
  final int? _revealCount;
  final VoidCallback? _onNext;
  final bool _isComplete;

  const ShipScreen({super.key})
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
  }) : _revealCount = collectedCount;

  bool get _isReveal => _onNext != null;

  @override
  State<ShipScreen> createState() => _ShipScreenState();
}

class _ShipScreenState extends State<ShipScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _revealController;
  late final Animation<double> _revealAnim;

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
    }
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget._isReveal ? _buildReveal(context) : _buildManual(context);
  }

  /// Ручной режим (Стори 01): читает прогресс, статичный вид, «Назад».
  Widget _buildManual(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корабль')),
      body: FutureBuilder<int>(
        future: ProgressService().getCurrentLevel(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final collected = math.min(snapshot.data!, kShipPartCount);
          return _column(
            context,
            collected,
            CustomPaint(
              size: const Size(300, 300),
              painter: ShipPainter(collectedCount: collected),
            ),
          );
        },
      ),
    );
  }

  /// Авто-показ (Стори 03): деталь `collected-1` въезжает scale-in + кнопка перехода.
  Widget _buildReveal(BuildContext context) {
    final collected = widget._revealCount!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Корабль'),
        automaticallyImplyLeading: false,
      ),
      body: _column(
        context,
        collected,
        AnimatedBuilder(
          animation: _revealAnim,
          builder: (_, _) => CustomPaint(
            size: const Size(300, 300),
            painter: ShipPainter(
              collectedCount: collected,
              revealPartIndex: collected - 1,
              revealProgress: _revealAnim.value,
            ),
          ),
        ),
        action: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            key: const Key('ship_next_button'),
            onPressed: widget._onNext,
            child: Text(widget._isComplete ? 'Начать заново' : 'Далее'),
          ),
        ),
      ),
    );
  }

  Widget _column(
    BuildContext context,
    int collected,
    Widget shipPaint, {
    Widget? action,
  }) {
    return Column(
      children: [
        Expanded(child: Center(child: shipPaint)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Собрано $collected из $kShipPartCount',
            key: const Key('ship_collected_text'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?action,
      ],
    );
  }
}
