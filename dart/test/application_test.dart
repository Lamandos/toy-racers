import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
