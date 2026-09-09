import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/presentation/virtual_presentation_viewport.dart';

void main() {
  testWidgets('scales authored layout down on phone-sized surfaces', (
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

  testWidgets('fits authored layout on smaller surfaces', (tester) async {
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
      VirtualPresentationViewport.designSize,
    );
  });

  testWidgets('fits authored layout inside the safe area', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
        child: const VirtualPresentationViewport(
          child: ColoredBox(
            color: Color(0xff000000),
            key: ValueKey<String>('presentation-child'),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('presentation-child'))),
      VirtualPresentationViewport.designSize,
    );
  });

  testWidgets('preserves child state when surface crosses authored threshold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _StateProbe();

    await tester.pumpWidget(VirtualPresentationViewport(child: probe));
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pump();

    expect(probe.initializeCount.value, 1);
    expect(probe.disposeCount.value, 0);
  });
}

final class _StateProbe extends StatefulWidget {
  _StateProbe();

  final ValueNotifier<int> initializeCount = ValueNotifier<int>(0);
  final ValueNotifier<int> disposeCount = ValueNotifier<int>(0);

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

final class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.initializeCount.value++;
  }

  @override
  void dispose() {
    widget.disposeCount.value++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
