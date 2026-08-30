import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'game/input/touch_controls_overlay.dart';
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
  });

  final Future<ToyRacersGame> Function() gameLoader;

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
          return Stack(
            alignment: Alignment.topLeft,
            fit: StackFit.expand,
            children: <Widget>[
              GameWidget(game: game),
              TouchControlsOverlay(controller: game.touchInputController),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
