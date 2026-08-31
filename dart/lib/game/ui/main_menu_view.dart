import 'package:flutter/widgets.dart';

import 'game_controls.dart';

/// Entry screen preserving the reference game's full-bleed menu composition.
final class MainMenuView extends StatelessWidget {
  const MainMenuView({required this.onPlay, super.key});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      Image.asset('assets/ui-main-background.png', fit: BoxFit.cover),
      const ColoredBox(color: Color(0x6610141d)),
      SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GamePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    gameHeading('TOY RACERS', size: 44),
                    const SizedBox(height: 28),
                    GameActionButton(
                      key: const ValueKey<String>('main-menu-play'),
                      label: 'PLAY',
                      onPressed: onPlay,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
