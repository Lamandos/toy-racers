import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/presentation/virtual_presentation_viewport.dart';

void main() {
  testWidgets('preserves compact constraints on phone-sized surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const VirtualPresentationViewport(
        child: ColoredBox(
          color: Color(0xff000000),
          key: ValueKey<String>('presentation-child'),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(VirtualPresentationViewport)),
      const Size(640, 360),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('presentation-child'))),
      const Size(640, 360),
    );
  });

  testWidgets('keeps authored presentation size on larger surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const VirtualPresentationViewport(
        child: ColoredBox(
          color: Color(0xff000000),
          key: ValueKey<String>('presentation-child'),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('presentation-child'))),
      VirtualPresentationViewport.designSize,
    );
  });

  testWidgets('preserves responsive constraints on smaller surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const VirtualPresentationViewport(
        child: ColoredBox(
          color: Color(0xff000000),
          key: ValueKey<String>('presentation-child'),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('presentation-child'))),
      const Size(800, 600),
    );
  });
}
