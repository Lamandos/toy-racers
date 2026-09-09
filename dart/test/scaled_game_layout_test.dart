import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/game/ui/car_selection_view.dart';
import 'package:toy_racers/game/ui/race_hud_overlay.dart';
import 'package:toy_racers/presentation/virtual_presentation_viewport.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  for (final size in <Size>[
    const Size(640, 360),
    const Size(844, 390),
    const Size(800, 600),
  ]) {
    testWidgets('selection and HUD fit and respond at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var difficulty = AiDifficulty.normal;
      await tester.pumpWidget(
        _framed(
          StatefulBuilder(
            builder: (context, setState) => CarSelectionView(
              selected: CarModel.redStripe,
              onSelected: (_) {},
              difficulty: difficulty,
              onDifficultySelected: (value) =>
                  setState(() => difficulty = value),
              onContinue: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hard = find.byKey(const ValueKey<String>('difficulty-hard'));
      final next = find.byKey(const ValueKey<String>('continue-to-track'));
      _expectVisible(tester, hard, size);
      _expectVisible(tester, next, size);
      expect(
        _screenRect(tester, hard).overlaps(_screenRect(tester, next)),
        isFalse,
      );
      await tester.tapAt(_screenRect(tester, hard).center);
      await tester.pump();
      expect(difficulty, AiDifficulty.hard);
      expect(find.text('HARD ✓'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'selection', size);

      final game = (await tester.runAsync(ToyRacersGame.loadDefault))!;
      await tester.pumpWidget(_framed(RaceHudOverlay(controller: game)));
      await tester.pumpAndSettle();
      final position = find.text('POSITION');
      final lap = find.textContaining('LAP ');
      final pause = find.byKey(const ValueKey<String>('pause-race'));
      for (final element in [position, lap, pause]) {
        _expectVisible(tester, element, size);
      }
      expect(
        _screenRect(tester, position).overlaps(_screenRect(tester, lap)),
        isFalse,
      );
      expect(
        _screenRect(tester, lap).overlaps(_screenRect(tester, pause)),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, 'hud', size);
      await tester.pumpWidget(const SizedBox.shrink());
      game.dispose();
    });
  }
}

Widget _framed(Widget child) => RepaintBoundary(
  key: const ValueKey<String>('capture'),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: VirtualPresentationViewport(child: child),
  ),
);

Rect _screenRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

void _expectVisible(WidgetTester tester, Finder finder, Size size) {
  final rect = _screenRect(tester, finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
}

Future<void> _capture(WidgetTester tester, String scene, Size size) async {
  if (!const bool.fromEnvironment('TOY_RACERS_CAPTURE_LAYOUT')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey<String>('capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File(
      'build/layout/$scene-${size.width.toInt()}x${size.height.toInt()}.png',
    );
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
