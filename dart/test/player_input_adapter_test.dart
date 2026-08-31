import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/input/keyboard_input_controller.dart';
import 'package:toy_racers/game/input/player_input_adapter.dart';
import 'package:toy_racers/game/input/touch_input_controller.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('desktop adapter creates a normalized command from driving keys', () {
    final desktopAdapter = DesktopKeyboardInputAdapter();
    final PlayerInputAdapter adapter = desktopAdapter;

    desktopAdapter.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyW,
        logicalKey: LogicalKeyboardKey.keyW,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      },
    );

    expect(adapter.readInput(), PlayerInput(throttle: 1, brake: 1));
    expect(adapter.readInput(), adapter.readInput().normalized());
  });

  test('desktop adapter sends pause only for a key-down event', () {
    final actions = <KeyboardAction>[];
    final adapter = DesktopKeyboardInputAdapter(onAction: actions.add);

    adapter.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      ),
      const <LogicalKeyboardKey>{},
    );
    adapter.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.escape},
    );

    expect(actions, <KeyboardAction>[KeyboardAction.togglePause]);
  });

  test('mobile adapter keeps multi-touch pedals and steering independent', () {
    final mobileAdapter = MobileTouchInputAdapter()
      ..configure(const Size(400, 200));
    final PlayerInputAdapter adapter = mobileAdapter;

    mobileAdapter
      ..pointerDown(1, const Offset(20, 180))
      ..pointerDown(2, const Offset(280, 180))
      ..pointerDown(3, const Offset(380, 180));

    expect(
      adapter.readInput(),
      PlayerInput(throttle: 1, brake: 1, steering: -1),
    );
    expect(adapter.readInput(), adapter.readInput().normalized());

    mobileAdapter
      ..pointerDown(4, const Offset(140, 180))
      ..pointerUp(4);
    expect(
      adapter.readInput(),
      PlayerInput(throttle: 1, brake: 1, steering: -1),
    );

    mobileAdapter
      ..pointerUp(1)
      ..pointerUp(2)
      ..pointerUp(3);
    expect(adapter.readInput(), PlayerInput.none);
    mobileAdapter.dispose();
  });

  test('combined adapter exposes one normalized command to the simulation', () {
    final adapter = CombinedPlayerInputAdapter(<PlayerInputAdapter>[
      CallbackPlayerInputAdapter(
        () => PlayerInput(throttle: 2, brake: -1, steering: -2),
      ),
      CallbackPlayerInputAdapter(() => PlayerInput(brake: 1, steering: 2)),
    ]);

    expect(
      adapter.readInput(),
      PlayerInput(throttle: 1, brake: 1, steering: 0),
    );
  });
}
