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
    await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows and hides touch controls by configuration', (
    tester,
  ) async {
    final game = await ToyRacersGame.loadDefault();
    final gameFuture = Future<ToyRacersGame>.value(game);
    await tester.pumpWidget(
      ToyRacersApplication(
        gameLoader: () => gameFuture,
        showTouchControls: true,
      ),
    );
    await tester.pump();

    expect(find.byType(TouchControlsOverlay), findsOneWidget);
    await tester.pumpWidget(
      ToyRacersApplication(
        gameLoader: () => gameFuture,
        showTouchControls: false,
      ),
    );
    await tester.pump();

    expect(find.byType(TouchControlsOverlay), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    game.pauseEngine();
    game.dispose();
  });
}
