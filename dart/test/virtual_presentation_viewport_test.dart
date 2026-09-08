import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/presentation/virtual_presentation_viewport.dart';

void main() {
  testWidgets('keeps the authored presentation size inside the surface', (
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
      VirtualPresentationViewport.designSize,
    );
  });
}
