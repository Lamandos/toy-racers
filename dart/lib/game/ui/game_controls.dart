import 'package:flutter/widgets.dart';

const Color _buttonIdle = Color(0xffc72914);
const Color _buttonSecondary = Color(0xff172331);

/// Shared non-Material controls matching the reference game's dark panels.
final class GameActionButton extends StatelessWidget {
  const GameActionButton({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: secondary ? _buttonSecondary : _buttonIdle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xfff7f4e8).withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xfff7f4e8),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ),
    ),
  );
}

final class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xe010141d),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xff8ed4ff).withValues(alpha: 0.32),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

Text gameHeading(String value, {double size = 32}) => Text(
  value,
  textAlign: TextAlign.center,
  style: TextStyle(
    color: const Color(0xfff7f4e8),
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  ),
);
