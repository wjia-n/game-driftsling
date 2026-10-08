import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const DriftSlingApp());

class DriftSlingApp extends StatelessWidget {
  const DriftSlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Drift Sling',
      tagline: 'Sling it. Drift it. Own the clock.',
      emoji: '🏎️',
      slug: 'driftsling',
      howToPlay:
          '• Pull back on your car and release to slingshot-launch it.\n• Drag anywhere while moving to steer through corners.\n• Pass every checkpoint in order — 2 laps to finish.\n• Grab coins for bonus glory. Stay on the road, speedster!',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => DriftSlingScreen(players: players, callbacks: cb),
    );
  }
}
