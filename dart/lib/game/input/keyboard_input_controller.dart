import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'player_input_adapter.dart';

/// Translates the desktop driving keys into the portable player command.
final class DesktopKeyboardInputAdapter implements PlayerInputAdapter {
  DesktopKeyboardInputAdapter({this.onAction});

  final void Function(KeyboardAction action)? onAction;

  PlayerInput _input = PlayerInput.none;

  /// Retained for widgets that need to display the current driving command.
  PlayerInput get input => readInput();

  @override
  PlayerInput readInput() => _input;

  KeyEventResult handleKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _input = _inputFor(keysPressed);
    if (event is KeyDownEvent) {
      final action = _actionFor(event.logicalKey);
      if (action != null) {
        onAction?.call(action);
      }
    }
    return _driveKeys.contains(event.logicalKey) ||
            _actionKeys.contains(event.logicalKey)
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
      throttle:
          _isPressed(
            keysPressed,
            LogicalKeyboardKey.keyW,
            LogicalKeyboardKey.arrowUp,
          )
          ? 1
          : 0,
      brake:
          _isPressed(
            keysPressed,
            LogicalKeyboardKey.keyS,
            LogicalKeyboardKey.arrowDown,
          )
          ? 1
          : 0,
      steering: left == right
          ? 0
          : left
          ? -1
          : 1,
    ).normalized();
  }

  bool _isPressed(
    Set<LogicalKeyboardKey> keysPressed,
    LogicalKeyboardKey primary,
    LogicalKeyboardKey secondary,
  ) => keysPressed.contains(primary) || keysPressed.contains(secondary);

  KeyboardAction? _actionFor(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.escape => KeyboardAction.togglePause,
    LogicalKeyboardKey.keyR => KeyboardAction.restart,
    _ => null,
  };

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

  static const List<LogicalKeyboardKey> _actionKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.keyR,
  ];
}

/// Backwards-compatible name for the desktop platform adapter.
typedef KeyboardInputController = DesktopKeyboardInputAdapter;

enum KeyboardAction { togglePause, restart }
