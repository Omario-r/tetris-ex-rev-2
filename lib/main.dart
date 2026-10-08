import 'package:flutter/material.dart';

import 'application/progress_service.dart';
import 'game_engine/data/ronin_parts.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/ship_screen.dart';

void main() {
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explosive Tetris',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<int>(
        future: ProgressService().getCollectedCount(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final collected = snapshot.data!;
          // Собраны все детали «Ронина-1» — финал «продолжение следует»
          // (без въезда последней детали: она уже на месте).
          if (collected >= RoninParts.parts.length) {
            return const ShipScreen.finale(animateLast: false);
          }
          return GameScreen(levelIndex: collected);
        },
      ),
    );
  }
}
