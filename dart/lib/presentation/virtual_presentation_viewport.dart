import 'package:flutter/widgets.dart';

/// Scales the presentation target uniformly to the available surface.
///
/// Keeping the child at the authored size makes screen-space HUD geometry
/// deterministic while [FittedBox] handles desktop, web, and landscape phone
/// dimensions without stretching either axis.
final class VirtualPresentationViewport extends StatelessWidget {
  const VirtualPresentationViewport({required this.child, super.key});

  static const Size designSize = Size(1280, 720);

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff121e2e),
    child: ClipRect(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox.fromSize(size: designSize, child: child),
      ),
    ),
  );
}
