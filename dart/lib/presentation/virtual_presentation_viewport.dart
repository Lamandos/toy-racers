import 'package:flutter/widgets.dart';

/// Presents the game at its authored size when the surface can contain it.
///
/// Smaller surfaces keep their real constraints so responsive layouts and
/// Flame's aspect-aware camera can adapt before any presentation scaling is
/// applied. Larger surfaces use the authored 16:9 composition.
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
            child: SizedBox.fromSize(
              size: _contentSize(constraints.biggest),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  Size _contentSize(Size availableSize) =>
      _usesAuthoredSize(availableSize) ? designSize : availableSize;

  bool _usesAuthoredSize(Size availableSize) =>
      availableSize.width >= designSize.width &&
      availableSize.height >= designSize.height;
}
