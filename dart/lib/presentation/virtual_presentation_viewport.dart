import 'package:flutter/widgets.dart';

/// Fits the authored 16:9 composition into the safe area at every window size.
/// Layout and hit testing share the same transform, like Kotlin's FitViewport.
final class VirtualPresentationViewport extends StatelessWidget {
  const VirtualPresentationViewport({required this.child, super.key});

  static const Size designSize = Size(1280, 720);

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff121e2e),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRect(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox.fromSize(size: designSize, child: child),
          ),
        ),
      ),
    ),
  );
}
