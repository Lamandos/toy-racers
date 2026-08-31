import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/main.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  testWidgets('guides the player from menu to the selected race', (
    tester,
  ) async {
    final game = Completer<ToyRacersGame>();
    TrackId? selectedTrack;
    CarModel? selectedCar;
    await tester.pumpWidget(
      ToyRacersApplication(
        raceGameLoader: ({required trackId, required playerCarModel}) {
          selectedTrack = trackId;
          selectedCar = playerCarModel;
          return game.future;
        },
      ),
    );

    expect(find.text('TOY RACERS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT TRACK'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('track-track-02')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT CAR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('car-yellow-sport')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('start-race')));
    await tester.pump();

    expect(selectedTrack, TrackId.bathroom);
    expect(selectedCar, CarModel.yellowSport);
    expect(find.byType(SizedBox), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a race-load error only after the player starts a race', (
    tester,
  ) async {
    await tester.pumpWidget(
      ToyRacersApplication(
        raceGameLoader: ({required trackId, required playerCarModel}) async {
          throw StateError('missing track');
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('start-race')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to load the race.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('race-load-error-back')),
    );
    await tester.pumpAndSettle();
    expect(find.text('TOY RACERS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps selection actions reachable on a short landscape view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final race = Completer<ToyRacersGame>();
    var started = false;

    await tester.pumpWidget(
      ToyRacersApplication(
        raceGameLoader: ({required trackId, required playerCarModel}) {
          started = true;
          return race.future;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
    await tester.pumpAndSettle();

    final startButton = find.byKey(const ValueKey<String>('start-race'));
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(startButton, findsOneWidget);

    await tester.tap(startButton);
    await tester.pump();
    expect(started, isTrue);
  });
}
