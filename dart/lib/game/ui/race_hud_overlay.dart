import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import '../toy_racers_game.dart';
import 'game_controls.dart';

/// Screen-space race instruments; the simulation remains the sole data owner.
final class RaceHudOverlay extends StatelessWidget {
  const RaceHudOverlay({required this.game, super.key});

  final ToyRacersGame game;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game.presentationFrame,
    builder: (context, child) {
      final session = game.session;
      final player = session.player;
      return SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 18,
              top: 18,
              child: _HudPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('POSITION', style: _captionStyle),
                    Text(
                      '${session.playerPosition}/${session.participants.length}',
                      style: const TextStyle(
                        color: Color(0xff8ed4ff),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LAP ${(player.progress.completedLaps + 1).clamp(1, session.requiredLaps)}/${session.requiredLaps}',
                      style: _valueStyle,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Center(
                child: _HudPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'TIME  ${_formatTime(player.progress.totalRaceTime)}',
                        style: _valueStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BEST  ${player.progress.bestLapTime == null ? '--:--.---' : _formatTime(player.progress.bestLapTime!)}',
                        style: _captionStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: GameActionButton(
                key: const ValueKey<String>('pause-race'),
                label: 'Ⅱ',
                secondary: true,
                onPressed: game.togglePause,
              ),
            ),
          ],
        ),
      );
    },
  );

  String _formatTime(double seconds) {
    final milliseconds = (seconds.clamp(0, double.infinity) * 1000).floor();
    final minutes = milliseconds ~/ 60000;
    final secondsPart = milliseconds ~/ 1000 % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}.${(milliseconds % 1000).toString().padLeft(3, '0')}';
  }
}

final class RaceCountdownOverlay extends StatelessWidget {
  const RaceCountdownOverlay({required this.game, super.key});

  final ToyRacersGame game;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game.presentationFrame,
    builder: (context, child) {
      if (game.session.raceState.phase != RacePhase.countdown) {
        return const SizedBox.shrink();
      }
      final activeLight = game.session.raceState.countdownRemainingSeconds
          .floor()
          .clamp(0, 2);
      return Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xae000000),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: index == activeLight
                          ? const Color(0xfff2472f)
                          : const Color(0xff41454f),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 44, height: 44),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class RacePauseOverlay extends StatelessWidget {
  const RacePauseOverlay({
    required this.game,
    required this.onQuitToMenu,
    super.key,
  });

  final ToyRacersGame game;
  final VoidCallback onQuitToMenu;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xb8000008),
    child: Center(
      child: SizedBox(
        width: 410,
        child: GamePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              gameHeading('PAUSED'),
              const SizedBox(height: 18),
              GameActionButton(label: 'RESUME', onPressed: game.togglePause),
              const SizedBox(height: 10),
              GameActionButton(label: 'RESTART', onPressed: game.restartRace),
              const SizedBox(height: 10),
              GameActionButton(
                label: 'QUIT TO MENU',
                secondary: true,
                onPressed: onQuitToMenu,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xe810141d),
      border: Border.all(color: const Color(0xff20b8ff)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}

const TextStyle _captionStyle = TextStyle(
  color: Color(0xffc5d5e2),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

const TextStyle _valueStyle = TextStyle(
  color: Color(0xfff7f4e8),
  fontSize: 18,
  fontWeight: FontWeight.w800,
);
