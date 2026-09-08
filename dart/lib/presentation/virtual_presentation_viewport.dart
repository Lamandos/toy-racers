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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final surfaceSize = constraints.biggest;
      final content = _usesAuthoredSize(surfaceSize)
          ? FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox.fromSize(size: designSize, child: child),
            )
          : child;
      return ColoredBox(
        color: const Color(0xff121e2e),
        child: SafeArea(child: ClipRect(child: content)),
      );
    },
  );

  bool _usesAuthoredSize(Size surfaceSize) =>
      surfaceSize.width >= designSize.width &&
      surfaceSize.height >= designSize.height;
}
