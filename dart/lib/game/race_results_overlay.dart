import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'toy_racers_game.dart';

/// Presents the completed race standings and a touch-friendly retry action.
final class RaceResultsOverlay extends StatelessWidget {
  const RaceResultsOverlay({required this.game, super.key});

  final ToyRacersGame game;

  @override
  Widget build(BuildContext context) {
    final playerResult = game.session.playerResult;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xcc10141d),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff7f4e8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'RACE RESULTS',
                        style: TextStyle(
                          color: Color(0xff18202d),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (playerResult != null)
                        Text(
                          'POSITION ${playerResult.finishPosition} / '
                          '${playerResult.competitorCount}  ·  '
                          '${_formatTime(playerResult.totalRaceTime)}',
                          style: const TextStyle(
                            color: Color(0xff4c5668),
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 20),
                      ..._resultRows(game.session.finishResults),
                      const SizedBox(height: 20),
                      Semantics(
                        button: true,
                        label: 'Restart race',
                        child: GestureDetector(
                          key: const ValueKey<String>('restart-race-button'),
                          onTap: game.restartRace,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xff2463a2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              child: Text(
                                'RESTART RACE',
                                style: TextStyle(
                                  color: Color(0xfff7f4e8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resultRows(List<ParticipantRaceResult> results) => [
    for (final entry in results)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              child: Text(
                '${entry.result.finishPosition}.',
                style: const TextStyle(
                  color: Color(0xff18202d),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _participantLabel(entry.participantId),
                style: const TextStyle(color: Color(0xff18202d)),
              ),
            ),
            Text(
              _formatTime(entry.result.totalRaceTime),
              style: const TextStyle(color: Color(0xff4c5668)),
            ),
          ],
        ),
      ),
  ];

  String _participantLabel(String participantId) =>
      participantId == 'player' ? 'YOU' : participantId.toUpperCase();

  String _formatTime(double seconds) => '${seconds.toStringAsFixed(2)} s';
}
