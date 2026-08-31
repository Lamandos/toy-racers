import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/game/ui/track_selection_view.dart';
import 'package:toy_racers/main.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  testWidgets(
    'lays out track cards side by side at the two-column breakpoint',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TrackSelectionView(onSelected: (_) {}, onBack: () {}),
        ),
      );

      final livingRoom = find.byKey(const ValueKey<String>('track-track-01'));
      final bathroom = find.byKey(const ValueKey<String>('track-track-02'));

      expect(tester.getTopLeft(livingRoom).dy, tester.getTopLeft(bathroom).dy);
      expect(
        tester.getTopLeft(livingRoom).dx,
        lessThan(tester.getTopLeft(bathroom).dx),
      );
    },
  );

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
    expect(find.text('SELECT CAR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('car-yellow-sport')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('continue-to-track')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT TRACK'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('track-track-02')));
    await tester.pump();

    expect(selectedTrack, TrackId.bathroom);
    expect(selectedCar, CarModel.yellowSport);
    expect(find.byType(SizedBox), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps legacy gameLoader callable while using the new flow', (
    tester,
  ) async {
    final game = Completer<ToyRacersGame>();
    var calls = 0;
    Future<ToyRacersGame> legacyLoader() {
      calls++;
      return game.future;
    }

    final application = ToyRacersApplication(gameLoader: legacyLoader);

    expect(application.gameLoader, same(legacyLoader));
    await tester.pumpWidget(application);
    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('continue-to-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
    await tester.pump();

    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('navigation targets activate with keyboard input', (
    tester,
  ) async {
    final race = Completer<ToyRacersGame>();
    TrackId? selectedTrack;
    await tester.pumpWidget(
      ToyRacersApplication(
        raceGameLoader: ({required trackId, required playerCarModel}) {
          selectedTrack = trackId;
          return race.future;
        },
      ),
    );

    Focus.of(tester.element(find.text('PLAY'))).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await tester.pumpAndSettle();

    final carText = find.descendant(
      of: find.byKey(const ValueKey<String>('car-red-stripe')),
      matching: find.text('RED STRIPE'),
    );
    Focus.of(tester.element(carText)).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
    await tester.pumpAndSettle();

    Focus.of(tester.element(find.text('SELECT TRACK'))).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await tester.pumpAndSettle();

    final trackText = find.descendant(
      of: find.byKey(const ValueKey<String>('track-track-01')),
      matching: find.text('LIVING ROOM'),
    );
    Focus.of(tester.element(trackText)).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
    await tester.pump();

    expect(selectedTrack, TrackId.livingRoom);
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
    await tester.tap(find.byKey(const ValueKey<String>('continue-to-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
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

  testWidgets('keeps selection actions reachable on a compact view', (
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

    final startButton = find.byKey(const ValueKey<String>('continue-to-track'));
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(startButton, findsOneWidget);

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    final trackCard = find.byKey(const ValueKey<String>('track-track-01'));
    await tester.scrollUntilVisible(
      trackCard,
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(trackCard, findsOneWidget);
    await tester.tap(trackCard);
    await tester.pump();
    expect(started, isTrue);
  });
}
