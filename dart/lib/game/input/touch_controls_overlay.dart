import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'touch_input_controller.dart';

/// Displays the touch controls and forwards simultaneous pointer events.
final class TouchControlsOverlay extends StatelessWidget {
  const TouchControlsOverlay({
    required this.controller,
    this.onPause,
    this.onRestart,
    super.key,
  });

  final MobileTouchInputAdapter controller;
  final void Function()? onPause;
  final void Function()? onRestart;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      controller.configure(constraints.biggest);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) =>
            _handlePointerDown(event, constraints.biggest),
        onPointerMove: (event) => _handlePointerMove(event),
        onPointerUp: (event) => _handlePointerUp(event),
        onPointerCancel: (event) => _handlePointerUp(event),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => CustomPaint(
            painter: _TouchControlsPainter(
              controller.readInput(),
              showActions: onPause != null || onRestart != null,
            ),
            child: child,
          ),
          child: const SizedBox.expand(),
        ),
      );
    },
  );

  void _handlePointerDown(PointerDownEvent event, Size size) {
    if (_isTouch(event)) {
      final action = _actionAt(event.localPosition, size);
      if (action != null) {
        _callbackFor(action)?.call();
        return;
      }
      controller.pointerDown(event.pointer, event.localPosition);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isTouch(event)) {
      controller.pointerMove(event.pointer, event.localPosition);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (_isTouch(event)) {
      controller.pointerUp(event.pointer);
    }
  }

  bool _isTouch(PointerEvent event) => event.kind == PointerDeviceKind.touch;

  _TouchAction? _actionAt(Offset position, Size size) {
    if (onPause != null &&
        _actionBounds(size, _TouchAction.pause).contains(position)) {
      return _TouchAction.pause;
    }
    if (onRestart != null &&
        _actionBounds(size, _TouchAction.restart).contains(position)) {
      return _TouchAction.restart;
    }
    return null;
  }

  void Function()? _callbackFor(_TouchAction action) => switch (action) {
    _TouchAction.pause => onPause,
    _TouchAction.restart => onRestart,
  };

  Rect _actionBounds(Size size, _TouchAction action) {
    const width = 104.0;
    const height = 48.0;
    const margin = 16.0;
    const gap = 8.0;
    final restartLeft = size.width - margin - width;
    final left = action == _TouchAction.restart
        ? restartLeft
        : restartLeft - gap - width;
    return Rect.fromLTWH(left, margin, width, height);
  }
}

enum _TouchAction { pause, restart }

final class _TouchControlsPainter extends CustomPainter {
  _TouchControlsPainter(this.input, {required this.showActions});

  final PlayerInput input;
  final bool showActions;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final top = size.height * 0.58;
    final buttonWidth = size.width / 4;
    for (var index = 0; index < 4; index++) {
      final bounds = Rect.fromLTWH(
        buttonWidth * index + 4,
        top + 4,
        buttonWidth - 8,
        size.height - top - 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
        Paint()..color = _colorFor(index).withValues(alpha: 0.72),
      );
      _drawLabel(canvas, bounds, _labelFor(index));
    }
    if (showActions) {
      _drawActionButton(canvas, size, _TouchAction.pause, 'PAUSE');
      _drawActionButton(canvas, size, _TouchAction.restart, 'RESTART');
    }
  }

  void _drawActionButton(
    Canvas canvas,
    Size size,
    _TouchAction action,
    String label,
  ) {
    final bounds = _actionBounds(size, action);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(10)),
      Paint()..color = const Color(0xff303846).withValues(alpha: 0.82),
    );
    _drawLabel(canvas, bounds, label);
  }

  Rect _actionBounds(Size size, _TouchAction action) {
    const width = 104.0;
    const height = 48.0;
    const margin = 16.0;
    const gap = 8.0;
    final restartLeft = size.width - margin - width;
    final left = action == _TouchAction.restart
        ? restartLeft
        : restartLeft - gap - width;
    return Rect.fromLTWH(left, margin, width, height);
  }

  void _drawLabel(Canvas canvas, Rect bounds, String label) {
    final paragraph = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xfff7f4e8),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bounds.width);
    paragraph.paint(
      canvas,
      Offset(
        bounds.center.dx - paragraph.width / 2,
        bounds.center.dy - paragraph.height / 2,
      ),
    );
  }

  Color _colorFor(int index) => switch (index) {
    0 when input.steering < 0 => const Color(0xff2463a2),
    1 when input.steering > 0 => const Color(0xff2463a2),
    2 when input.brake > 0 => const Color(0xffa45145),
    3 when input.throttle > 0 => const Color(0xff3d8755),
    _ => const Color(0xff303846),
  };

  String _labelFor(int index) => switch (index) {
    0 => '◀',
    1 => '▶',
    2 => 'BRAKE',
    _ => 'GAS',
  };

  @override
  bool shouldRepaint(_TouchControlsPainter oldDelegate) =>
      oldDelegate.input != input || oldDelegate.showActions != showActions;
}
