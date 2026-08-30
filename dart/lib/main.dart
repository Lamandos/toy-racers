import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game/toy_racers_game.dart';

void main() {
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
          return GameWidget(game: snapshot.requireData);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
