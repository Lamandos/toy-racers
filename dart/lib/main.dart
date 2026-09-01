import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'audio/game_audio_controller.dart';
import 'audio/audio_settings.dart';
import 'game/ui/audio_settings_view.dart';
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
  final audio = GameAudioController.production();
  await audio.prepare();
  runApp(ToyRacersApplication(audio: audio));
}

/// Flutter navigation shell around the Flame race presentation.
final class ToyRacersApplication extends StatefulWidget {
  const ToyRacersApplication({
    super.key,
    Future<ToyRacersGame> Function()? gameLoader,
    this.raceGameLoader = ToyRacersGame.loadRace,
    this.showTouchControls,
    this.audio,
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

  /// Optional shared backend; omitting it preserves the silent test shell.
  final GameAudioController? audio;

  @override
  State<ToyRacersApplication> createState() => _ToyRacersApplicationState();
}

final class _ToyRacersApplicationState extends State<ToyRacersApplication>
    with WidgetsBindingObserver {
  _ToyRacersScreen _screen = _ToyRacersScreen.mainMenu;
  CarModel _selectedCar = CarModel.redStripe;
  Future<ToyRacersGame>? _race;
  ToyRacersGame? _activeGame;
  late final GameAudioController _audio;
  bool _audioPausedForLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = widget.audio ?? GameAudioController.silent();
    unawaited(_audio.enterMenu());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_audioPausedForLifecycle) {
          _audioPausedForLifecycle = false;
          unawaited(_audio.resumeForLifecycle());
        }
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        if (!_audioPausedForLifecycle) {
          _audioPausedForLifecycle = true;
          unawaited(_audio.pauseForLifecycle());
        }
    }
  }

  @override
  Widget build(BuildContext context) => GameAudioScope(
    audio: _audio,
    child: GameNavigationScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: switch (_screen) {
          _ToyRacersScreen.mainMenu => MainMenuView(
            onPlay: _showCarSelection,
            onSettings: _showSettings,
          ),
          _ToyRacersScreen.settings => AudioSettingsView(
            settings: _audio.settings,
            onChanged: _updateAudioSettings,
            onBack: _showMainMenu,
          ),
          _ToyRacersScreen.carSelection => CarSelectionView(
            selected: _selectedCar,
            onSelected: _selectCar,
            onContinue: _showTrackSelection,
            onBack: _showMainMenu,
          ),
          _ToyRacersScreen.trackSelection => TrackSelectionView(
            selectedCar: _selectedCar,
            onSelected: _startRace,
            onBack: _showCarSelection,
          ),
          _ToyRacersScreen.race => _RacePresentation(
            race: _race!,
            showTouchControls: _shouldShowTouchControls,
            onGameReady: _setActiveGame,
            onExitRace: _showMainMenu,
          ),
        },
      ),
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
    unawaited(_audio.enterMenu());
    setState(() {
      _race = null;
      _screen = _ToyRacersScreen.mainMenu;
    });
  }

  void _showCarSelection() => setState(() {
    _screen = _ToyRacersScreen.carSelection;
  });

  void _showSettings() => setState(() {
    _screen = _ToyRacersScreen.settings;
  });

  void _updateAudioSettings(AudioSettings settings) => setState(() {
    _audio.settings = settings;
  });

  void _showTrackSelection() => setState(() {
    _screen = _ToyRacersScreen.trackSelection;
  });

  void _selectCar(CarModel car) => setState(() {
    _selectedCar = car;
  });

  void _startRace(TrackId trackId) {
    final race = Future<ToyRacersGame>.sync(
      () =>
          widget._legacyGameLoader?.call() ??
          widget.raceGameLoader(trackId: trackId, playerCarModel: _selectedCar),
    );
    race.ignore();
    setState(() {
      _race = race;
      _screen = _ToyRacersScreen.race;
    });
  }

  void _setActiveGame(ToyRacersGame game) {
    game.attachAudio(_audio);
    _activeGame = game;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeGame?.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }
}

enum _ToyRacersScreen { mainMenu, settings, trackSelection, carSelection, race }

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
                onPause: game.onTouchPause,
                onRestart: game.onTouchRestart,
              ),
          ToyRacersGame.raceHudOverlayId: (context, game) => RaceHudOverlay(
            controller: game,
            showDesktopControls: !showTouchControls,
          ),
          ToyRacersGame.countdownOverlayId: (context, game) =>
              RaceCountdownOverlay(controller: game),
          ToyRacersGame.pauseOverlayId: (context, game) =>
              RacePauseOverlay(controller: game, onQuitToMenu: onExitRace),
          ToyRacersGame.resultsOverlayId: (context, game) =>
              RaceResultsOverlay(controller: game, onMainMenu: onExitRace),
        },
        initialActiveOverlays: <String>[ToyRacersGame.raceHudOverlayId],
      );
    },
  );
}
