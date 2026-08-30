import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/input/touch_controls_overlay.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/main.dart';

void main() {
  testWidgets('provides an empty shell until the Flame game is loaded', (
    tester,
  ) async {
    final game = Completer<ToyRacersGame>();
    await tester.pumpWidget(
      ToyRacersApplication(gameLoader: () => game.future),
    );

    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('shows an error when the Flame game cannot be loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ToyRacersApplication(
        gameLoader: () async => throw StateError('missing track'),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load the race.'), findsOneWidget);
  });

  testWidgets('shows touch controls with the loaded Flame game', (tester) async {
    final game = await ToyRacersGame.loadDefault();
    await tester.pumpWidget(ToyRacersApplication(gameLoader: () async => game));
    await tester.pump();

    expect(find.byType(TouchControlsOverlay), findsOneWidget);
  });
}
