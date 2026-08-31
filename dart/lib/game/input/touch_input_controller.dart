import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:toy_racers/simulation.dart';

import 'player_input_adapter.dart';

/// Translates simultaneous touch control presses into a player command.
///
/// The controller keeps pointer IDs separate so that steering and either pedal
/// can be held at the same time. The bottom 42% of the overlay is divided into
/// four controls: steer left, steer right, brake/reverse, and throttle.
final class MobileTouchInputAdapter extends ChangeNotifier
    implements PlayerInputAdapter {
  Size _surfaceSize = Size.zero;
  final Map<int, _TouchControl> _activePointers = <int, _TouchControl>{};

  /// Retained for the control widget to paint the current driving command.
  PlayerInput get input => readInput();

  @override
  PlayerInput readInput() => PlayerInput(
    throttle: _hasControl(_TouchControl.throttle) ? 1 : 0,
    brake: _hasControl(_TouchControl.brake) ? 1 : 0,
    steering: _steeringInput,
  ).normalized();

  /// Updates the overlay dimensions used to classify new touches.
  void configure(Size size) {
    if (_surfaceSize == size) {
      return;
    }
    _surfaceSize = size;
  }

  /// Records a newly pressed touch control.
  void pointerDown(int pointerId, Offset position) {
    _activePointers[pointerId] = _controlAt(position);
    notifyListeners();
  }

  /// Keeps a held steering control active while the finger moves.
  void pointerMove(int pointerId, Offset position) {
    final control = _activePointers[pointerId];
    if (control == null || !_isSteeringControl(control)) {
      return;
    }
    final nextControl = _controlAt(position);
    if (!_isSteeringControl(nextControl) || nextControl == control) {
      return;
    }
    _activePointers[pointerId] = nextControl;
    notifyListeners();
  }

  /// Releases one touch control.
  void pointerUp(int pointerId) {
    if (_activePointers.remove(pointerId) != null) {
      notifyListeners();
    }
  }

  /// Releases all controls, for example after a cancelled gesture or pause.
  void clear() {
    if (_activePointers.isEmpty) {
      return;
    }
    _activePointers.clear();
    notifyListeners();
  }

  double get _steeringInput {
    final steerLeft = _hasControl(_TouchControl.steerLeft);
    final steerRight = _hasControl(_TouchControl.steerRight);
    if (steerLeft == steerRight) {
      return 0;
    }
    return steerLeft ? -1 : 1;
  }

  bool _hasControl(_TouchControl control) =>
      _activePointers.values.contains(control);

  bool _isSteeringControl(_TouchControl control) =>
      control == _TouchControl.steerLeft || control == _TouchControl.steerRight;

  _TouchControl _controlAt(Offset position) {
    if (_surfaceSize.isEmpty || position.dy < _surfaceSize.height * 0.58) {
      return _TouchControl.none;
    }
    final column = position.dx / _surfaceSize.width;
    if (column < 0.25) {
      return _TouchControl.steerLeft;
    }
    if (column < 0.5) {
      return _TouchControl.steerRight;
    }
    if (column < 0.75) {
      return _TouchControl.brake;
    }
    return _TouchControl.throttle;
  }
}

/// Backwards-compatible name for the mobile platform adapter.
typedef TouchInputController = MobileTouchInputAdapter;

enum _TouchControl { none, steerLeft, steerRight, brake, throttle }
