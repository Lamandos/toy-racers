import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'input/touch_controls_overlay.dart';
import 'race_results_overlay.dart';
import 'toy_racers_game.dart';
import 'ui/race_hud_overlay.dart';

/// The production race overlays, shared by the app and performance probe.
final class RaceGameView extends StatelessWidget {
  const RaceGameView({
    required this.game,
    required this.showTouchControls,
    required this.onExitRace,
    super.key,
  });

  final ToyRacersGame game;
  final bool showTouchControls;
  final VoidCallback onExitRace;

  @override
  Widget build(BuildContext context) {
    game.configureTouchControls(showTouchControls);
    return GameWidget<ToyRacersGame>(
      game: game,
      overlayBuilderMap: <String, OverlayWidgetBuilder<ToyRacersGame>>{
        ToyRacersGame.touchControlsOverlayId: (context, game) =>
            TouchControlsOverlay(
              controller: game.touchInputController,
              onPause: game.onTouchPause,
              onRestart: game.onTouchRestart,
            ),
        ToyRacersGame.raceHudOverlayId: (context, game) =>
            RaceHudOverlay(controller: game),
        ToyRacersGame.countdownOverlayId: (context, game) =>
            RaceCountdownOverlay(controller: game),
        ToyRacersGame.pauseOverlayId: (context, game) =>
            RacePauseOverlay(controller: game, onQuitToMenu: onExitRace),
        ToyRacersGame.resultsOverlayId: (context, game) =>
            RaceResultsOverlay(controller: game, onMainMenu: onExitRace),
      },
      initialActiveOverlays: <String>[ToyRacersGame.raceHudOverlayId],
    );
  }
}
