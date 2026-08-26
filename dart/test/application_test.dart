import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/main.dart';

void main() {
  testWidgets(
    'provides an empty application shell during the simulation gate',
    (tester) async {
      await tester.pumpWidget(const ToyRacersApplication());

      expect(find.byType(SizedBox), findsOneWidget);
    },
  );
}
