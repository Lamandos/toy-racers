import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

/// Translates the desktop driving keys into the portable player command.
final class KeyboardInputController {
  PlayerInput _input = PlayerInput.none;

  PlayerInput get input => _input;

  KeyEventResult handleKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _input = _inputFor(keysPressed);
    return _driveKeys.contains(event.logicalKey)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  PlayerInput _inputFor(Set<LogicalKeyboardKey> keysPressed) {
    final left = _isPressed(
      keysPressed,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowLeft,
    );
    final right = _isPressed(
      keysPressed,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowRight,
    );
    return PlayerInput(
      throttle: _isPressed(
        keysPressed,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.arrowUp,
      )
          ? 1
          : 0,
      brake: _isPressed(
        keysPressed,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.arrowDown,
      )
          ? 1
          : 0,
      steering: left == right ? 0 : left ? -1 : 1,
    );
  }

  bool _isPressed(
    Set<LogicalKeyboardKey> keysPressed,
    LogicalKeyboardKey primary,
    LogicalKeyboardKey secondary,
  ) => keysPressed.contains(primary) || keysPressed.contains(secondary);

  static const List<LogicalKeyboardKey> _driveKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowRight,
  ];
}
