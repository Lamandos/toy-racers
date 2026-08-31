import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'game/input/touch_controls_overlay.dart';
import 'game/race_results_overlay.dart';
import 'game/toy_racers_game.dart';
import 'game/ui/car_selection_view.dart';
import 'game/ui/game_controls.dart';
import 'game/ui/main_menu_view.dart';
import 'game/ui/race_hud_overlay.dart';
import 'game/ui/track_selection_view.dart';

typedef RaceGameLoader = Future<ToyRacersGame> Function({
  required TrackId trackId,
  required CarModel playerCarModel,
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ToyRacersApplication());
}

/// Flutter navigation shell around the Flame race presentation.
final class ToyRacersApplication extends StatefulWidget {
  const ToyRacersApplication({
    super.key,
    Future<ToyRacersGame> Function()? gameLoader,
    this.raceGameLoader = ToyRacersGame.loadRace,
    this.showTouchControls,
  }) : gameLoader = gameLoader ?? ToyRacersGame.loadDefault,
       _legacyGameLoader = gameLoader;

  /// Legacy no-argument loader, retained for source compatibility.
  ///
  /// The selection flow uses [raceGameLoader] unless an explicit legacy
  /// loader was supplied to the constructor.
  final Future<ToyRacersGame> Function() gameLoader;
  final Future<ToyRacersGame> Function()? _legacyGameLoader;
  final RaceGameLoader raceGameLoader;
  final bool? showTouchControls;

  @override
  State<ToyRacersApplication> createState() => _ToyRacersApplicationState();
}

final class _ToyRacersApplicationState extends State<ToyRacersApplication> {
  _ToyRacersScreen _screen = _ToyRacersScreen.mainMenu;
  TrackId _selectedTrack = TrackId.livingRoom;
  CarModel _selectedCar = CarModel.redStripe;
  Future<ToyRacersGame>? _race;
  ToyRacersGame? _activeGame;

  @override
  Widget build(BuildContext context) => GameNavigationScope(
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: switch (_screen) {
        _ToyRacersScreen.mainMenu => MainMenuView(onPlay: _showTrackSelection),
        _ToyRacersScreen.trackSelection => TrackSelectionView(
          onSelected: _showCarSelection,
          onBack: _showMainMenu,
        ),
        _ToyRacersScreen.carSelection => CarSelectionView(
          selected: _selectedCar,
          onSelected: _selectCar,
          onStart: _startRace,
          onBack: _showTrackSelection,
        ),
        _ToyRacersScreen.race => _RacePresentation(
          race: _race!,
          showTouchControls: _shouldShowTouchControls,
          onGameReady: _setActiveGame,
          onExitRace: _showMainMenu,
        ),
      },
    ),
  );

  bool get _shouldShowTouchControls =>
      widget.showTouchControls ??
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _showMainMenu() {
    final game = _activeGame;
    _activeGame = null;
    game?.pauseEngine();
    game?.dispose();
    setState(() {
      _race = null;
      _screen = _ToyRacersScreen.mainMenu;
    });
  }

  void _showTrackSelection() => setState(() {
    _screen = _ToyRacersScreen.trackSelection;
  });

  void _showCarSelection(TrackId track) => setState(() {
    _selectedTrack = track;
    _screen = _ToyRacersScreen.carSelection;
  });

  void _selectCar(CarModel car) => setState(() {
    _selectedCar = car;
  });

  void _startRace() {
    final race = Future<ToyRacersGame>.sync(
      () =>
          widget._legacyGameLoader?.call() ??
          widget.raceGameLoader(
            trackId: _selectedTrack,
            playerCarModel: _selectedCar,
          ),
    );
    race.ignore();
    setState(() {
      _race = race;
      _screen = _ToyRacersScreen.race;
    });
  }

  void _setActiveGame(ToyRacersGame game) {
    _activeGame = game;
  }

  @override
  void dispose() {
    _activeGame?.dispose();
    super.dispose();
  }
}

enum _ToyRacersScreen { mainMenu, trackSelection, carSelection, race }

final class _RacePresentation extends StatelessWidget {
  const _RacePresentation({
    required this.race,
    required this.showTouchControls,
    required this.onGameReady,
    required this.onExitRace,
  });

  final Future<ToyRacersGame> race;
  final bool showTouchControls;
  final ValueChanged<ToyRacersGame> onGameReady;
  final VoidCallback onExitRace;

  @override
  Widget build(BuildContext context) => FutureBuilder<ToyRacersGame>(
    future: race,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ColoredBox(
          color: const Color(0xff121e2e),
          child: Center(
            child: GamePanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Unable to load the race.',
                    style: TextStyle(
                      color: Color(0xfff7f4e8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GameActionButton(
                    key: const ValueKey<String>('race-load-error-back'),
                    label: 'BACK',
                    secondary: true,
                    onPressed: onExitRace,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox.expand();
      }
      final game = snapshot.requireData;
      onGameReady(game);
      game.configureTouchControls(showTouchControls);
      return GameWidget<ToyRacersGame>(
        game: game,
        overlayBuilderMap: <String, OverlayWidgetBuilder<ToyRacersGame>>{
          ToyRacersGame.touchControlsOverlayId: (context, game) =>
              TouchControlsOverlay(
                controller: game.touchInputController,
                onPause: game.togglePause,
                onRestart: game.restartRace,
              ),
          ToyRacersGame.raceHudOverlayId: (context, game) =>
              RaceHudOverlay(game: game),
          ToyRacersGame.countdownOverlayId: (context, game) =>
              RaceCountdownOverlay(game: game),
          ToyRacersGame.pauseOverlayId: (context, game) =>
              RacePauseOverlay(game: game, onQuitToMenu: onExitRace),
          ToyRacersGame.resultsOverlayId: (context, game) =>
              RaceResultsOverlay(game: game, onMainMenu: onExitRace),
        },
        initialActiveOverlays: <String>[ToyRacersGame.raceHudOverlayId],
      );
    },
  );
}
