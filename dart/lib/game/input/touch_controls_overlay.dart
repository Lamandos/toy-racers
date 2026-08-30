import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'touch_input_controller.dart';

/// Displays the touch controls and forwards simultaneous pointer events.
final class TouchControlsOverlay extends StatelessWidget {
  const TouchControlsOverlay({required this.controller, super.key});

  final TouchInputController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      controller.configure(constraints.biggest);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _handlePointerDown(event),
        onPointerMove: (event) => _handlePointerMove(event),
        onPointerUp: (event) => _handlePointerUp(event),
        onPointerCancel: (event) => _handlePointerUp(event),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => CustomPaint(
            painter: _TouchControlsPainter(controller.input),
            child: child,
          ),
          child: const SizedBox.expand(),
        ),
      );
    },
  );

  void _handlePointerDown(PointerDownEvent event) {
    if (_isTouch(event)) {
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
}

final class _TouchControlsPainter extends CustomPainter {
  _TouchControlsPainter(this.input);

  final PlayerInput input;

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
      oldDelegate.input != input;
}
