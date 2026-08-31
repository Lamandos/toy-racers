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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < _compactMenuBreakpoint;
            final horizontalPadding = (constraints.maxWidth * 0.06)
                .clamp(_minimumMenuPadding, _maximumMenuPadding)
                .toDouble();
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: _minimumMenuPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > _minimumMenuPadding * 2
                      ? constraints.maxHeight - _minimumMenuPadding * 2
                      : 0,
                ),
                child: Align(
                  alignment: isCompact
                      ? Alignment.center
                      : Alignment.centerLeft,
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
            );
          },
        ),
      ),
    ],
  );
}

const double _compactMenuBreakpoint = 700;
const double _minimumMenuPadding = 20;
const double _maximumMenuPadding = 52;
