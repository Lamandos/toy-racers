import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'game/input/touch_controls_overlay.dart';
import 'game/race_results_overlay.dart';
import 'game/toy_racers_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ToyRacersApplication());
}

class ToyRacersApplication extends StatefulWidget {
  const ToyRacersApplication({
    super.key,
    this.gameLoader = ToyRacersGame.loadDefault,
    this.showTouchControls,
  });

  final Future<ToyRacersGame> Function() gameLoader;
  final bool? showTouchControls;

  @override
  State<ToyRacersApplication> createState() => _ToyRacersApplicationState();
}

class _ToyRacersApplicationState extends State<ToyRacersApplication> {
  late final Future<ToyRacersGame> _game = widget.gameLoader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ToyRacersGame>(
      future: _game,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: Text('Unable to load the race.')),
          );
        }
        if (snapshot.hasData) {
          final game = snapshot.requireData;
          game.configureTouchControls(_shouldShowTouchControls);
          return GameWidget<ToyRacersGame>(
            game: game,
            overlayBuilderMap: <String, OverlayWidgetBuilder<ToyRacersGame>>{
              ToyRacersGame.touchControlsOverlayId: (context, game) =>
                  TouchControlsOverlay(
                    controller: game.touchInputController,
                    onPause: game.togglePause,
                    onRestart: game.restartRace,
                  ),
              ToyRacersGame.resultsOverlayId: (context, game) =>
                  RaceResultsOverlay(game: game),
            },
            initialActiveOverlays: _shouldShowTouchControls
                ? <String>[ToyRacersGame.touchControlsOverlayId]
                : null,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  bool get _shouldShowTouchControls =>
      widget.showTouchControls ??
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
